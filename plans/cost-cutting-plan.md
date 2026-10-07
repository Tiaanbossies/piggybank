# Plan: savings target and cost cutting ("afford the rent")

Written 2026-10-07. Plan only, no code. Waiting for approval.

## Goal

Every Piggybank user can set a monthly target (for Tiaan: rent, so he can move out), see
how far their current spending leaves them from it, find the recurring costs worth
cutting, check whether their insurance premiums look high for what they insure, and
watch the gap close as they cut.

This goal now comes **before** the friends & family beta (`next-goal-friends-family-beta.md`
is paused behind it). It is built for every user from day one, not just for Tiaan, so it
carries straight into the beta later.

**Done means:** Tiaan opens Piggybank and sees, in one place, "Rent target R X · you
have R Y left over · gap R Z", a confirmed list of every recurring cost with the ones to
cut marked, each insurance policy with a data check and Penny's sourced market read,
and a running "savings found" total.

## What already exists (read first, and what fits)

| Existing piece | What it does | Fit for this goal |
|---|---|---|
| `GET /transactions/recurring-patterns` (`transactions/router.py:384`) | Last 6 months of expenses, grouped **by category**, ≥3 hits, ≤10% amount spread, skips names that already exist as liabilities | **Partial.** Grouping by category merges Netflix and Showmax (both "Subscriptions") into one averaged row, and the 10% spread rule then often drops it. Debit orders for insurance usually pass. Logic worth reusing; grouping needs to move to merchant level |
| `GET /summaries/recurring-expenses` (`summaries/router.py:181`) | 3-month window, category seen in ≥2 months. Shown on the Trends screen | **Leave as is.** Trends depends on it. It answers "which categories recur", not "which charges recur" |
| `POST /liabilities/from-pattern` + the Liability model | Debts: outstanding balance, interest, term, payments | **Does not fit.** Liabilities are debts and count against net worth. A Netflix subscription or a car premium is not a debt. `from-pattern` sets `outstanding_amount = monthly_amount`, so every subscription filed this way currently cuts net worth by a month's cost (separate bug, see "Side findings") |
| Goals (`Goal` model, `lib/features/goals`) | A pot you save **up to**: target amount, current amount, optional date | **Does not fit.** A rent target is a monthly **gap**, not a pot. Re-using Goal would make the Home progress card and Penny's goal pace read "R0 of R8 000 saved" forever |
| Asset model (`AssetType.VEHICLE`, `PROPERTY`) | User's car or home with a current value | **Fits.** A car policy can link an existing vehicle asset for its value instead of asking again |
| Penny (`chatbot/service.py`) | qwen2.5:3b on a shared 4 GB GPU, Pro-gated, 20/min, persona + scope + no-fabrication + FAIS guardrails | **Fits, with changes.** See the next row |
| Penny's web search (`_build_tavily_context`, `services/web_search.py`, `routes/ai.py`) | **Already wired.** When `TAVILY_API_KEY` is set, every finance-sounding chat message is sent **verbatim** to Tavily, and the top results are pasted into the prompt. The response says `web_search_enabled` | **The premise "Penny has no web access" is out of date.** Whether production has a Tavily key set is unknown (I can't read prod config). Two problems to fix before building on it: the raw user message (which can contain names, amounts and account details) leaves the server (**POPIA**), and `/ai/web-search` is mounted outside `/api`, ignores `AI_FEATURES_ENABLED`, is not Pro-gated and has no rate limit, so any logged-in user can spend Tavily credits |
| Python-computed facts pattern (`_trend`, `_budget_pace`, `_zar`) | The 3B model is bad at arithmetic, so the backend computes numbers and the model only narrates | **Fits.** All premium maths (cost per year, % of asset value, year-on-year increase) is done the same way |
| CSV import (`imports/`) | Backfill bank statements | **Fits.** It is the fix for "not enough history" (see Risks) |

## Design in one paragraph

Three new backend tables: a per-user **savings target**, a **recurring cost** list
(subscriptions, debit orders, premiums, filled from improved detection, confirmed or
dismissed by the user, each marked keep / cut candidate / cut), and **insurance policy
details** hanging off a recurring cost. An overview endpoint computes, in Python,
income − fixed costs − everyday spending = left over, against the target. Penny's
insurance research does **not** use model tool-calling: the backend builds a generic,
whitelisted search query from the policy's fields, searches, caches, computes the
numbers, and hands Penny a small, fixed prompt to narrate. Sources come from the server,
not the model, so they can't be made up.

## Items (8 PRs, all against `master`, ordered by how soon the gap is visible)

Backend PRs are in `piggybank-backend`, app PRs are in `Piggybank`. Each app PR
depends only on its backend PR being **deployed**, never on another open PR.

### 1. Backend: savings target, recurring costs, overview

- **What:** `savings_targets` (one active per user: `label`, `monthly_amount`,
  `target_date?`, `income_override?`) and `recurring_costs` (`name`, `merchant_key`,
  `kind` = subscription / insurance / debit_order / utility / other, `monthly_amount`,
  `source` = manual / detected, `status` = suggested / confirmed / dismissed,
  `decision` = undecided / keep / cut_candidate / cut, `saved_amount?`, `cut_on?`,
  `last_seen_on?`). CRUD for both. `GET /savings/overview` returns, computed in Python
  with Decimal:
  - **income:** the override, or the average of the last 3 full months' income, with
    transfers and reimbursements excluded (same rules as the snapshot)
  - **fixed costs:** the sum of confirmed recurring costs, minus those marked cut
  - **everyday spending:** the 3-month average of expenses **not** matched to a
    recurring cost
  - **left over**, **gap to target** (zero when the target is met), **savings found**
    (the sum of `saved_amount` on items marked cut)
  - **months of data used**, so the app can say "based on 1 month, add history for a
    better number"
- **Files:** `models.py`, new `savings/` module (`router.py`, `schemas.py`,
  `service.py`), `api/router.py`, alembic migration, `tests/test_savings.py`.
- **DB:** two new tables, an additive migration, nothing existing changed. Hard delete,
  per `docs/delete-policy.md`.
- **Tests:** ownership scoping (another user's rows → 404), overview maths with fixtures
  (no income, no target, target already met, cut items excluded, transfers excluded),
  Decimal rounding, migration up/down.
- **Verify:** `pytest`, `ruff check .`, migration against a local DB. After merge,
  deploy per `docs/runbook.md` and `make migrate`, then hit `/api/savings/overview` with
  Tiaan's own login from the app (not a prod DB read).

### 2. App: Savings plan screen and Home card

- **What:** a pushed **Savings plan** screen (no new tab, see D2):
  - **target card:** label, target, left over, gap, and a progress bar
  - **"Set your target" sheet:** amount, label, optional date, optional income
    override
  - **recurring costs list:** manual add, edit, delete, and a Keep / Cut candidate /
    Cut control. Marking an item Cut asks for the amount saved, defaulting to the
    full monthly amount
  - **"Savings found" line**

  On Home, one card: "Rent target · gap R Z" (or "Set a savings target" when there is
  none), which opens the screen. The card sits below the review banner and the
  spend strip, so the daily flow from the UX plan is unchanged.
- **Files:** new `lib/features/savings/` (data, models, providers, screens, widgets),
  `dashboard_screen.dart` (card), `app_router.dart` (route), tests under
  `test/features/savings/`.
- **DB:** none.
- **Tests:** widget tests for the empty, partial-data ("based on 1 month") and
  target-met states, plus Retry on error (InlineError `onRetry`, the same as UX item 5).
  Model JSON round-trip. Home card navigation.
- **Verify:** `flutter analyze`, `flutter test`, emulator walkthrough: set a target, add
  three costs, mark one cut, and watch the gap and savings found change. Count taps from
  Home (goal: the gap is visible in 1 tap).

**After items 1–2, Tiaan sees his gap** using costs he types in himself. Everything
after this automates the list and adds the insurance checks.

### 3. Backend: merchant-level recurring detection and "still charged" check

- **What:** a new detection service, separate from the two existing endpoints, which
  stay as they are:
  - **grouping:** by `merchant_name`, or the description cleaned with
    `merchant_name_cleaner`, not by category
  - **cadence:** roughly monthly (26–35 days between charges), at least 2 charges
  - **amount tolerance:** about 15%, so price increases still match
  - **output:** writes `suggested` recurring costs, never re-suggesting anything the
    user dismissed or already has
  - **kind guess:** `insurance` when the category, description or merchant matches an
    insurer list or words like "premium", "assur", "insure", "debit order"

  Runs on demand (`POST /savings/recurring/detect`) and nightly via the existing
  scheduler. It also sets `last_seen_on`, so an item marked **cut** that charges again
  is flagged `still_charged=true`.
- **Files:** `savings/detection.py`, `scheduler.py`, `savings/router.py`, tests.
- **DB:** a `dismissed_merchant_keys` column, or rows kept with status `dismissed` (the
  latter is preferred because it needs no extra table).
- **Tests:** the Netflix + Showmax split case, a price increase within tolerance, a
  weekly charge not counted as monthly, dismissed items not re-suggested, the
  still-charged flag, and ownership scoping.
- **Verify:** pytest with fixture histories, then a manual detect run for Tiaan after
  deploy. Report counts only (no amounts) in the PR.

### 4. App: review suggestions, keep or cut

- **What:** a "Found N recurring costs" section at the top of the Savings plan list:
  - **one-tap actions:** Confirm or Dismiss, the same swipe and undo pattern as pending
    review (reuse the `_settle` undo idea, with `persist: false` SnackBars)
  - **Cut candidate badge,** with a sort order: cut candidates first, then by amount
  - **"Still charged" warning** on cut items that charged again
  - **"Find recurring costs" button** (the detect endpoint)
- **Files:** `lib/features/savings/…`, tests.
- **DB:** none.
- **Tests:** confirm, dismiss and undo; still-charged badge; empty suggestions.
- **Verify:** flutter test, emulator walkthrough with detected suggestions; time a full
  first pass over the suggestions.

### 5. Backend: insurance policy details and data-only checks

- **What:** an `insurance_policies` table, one row per recurring cost of kind
  `insurance`:
  - **Shared fields:** `policy_type` (car, home_contents, building, life, funeral,
    disability, medical_aid, gap_cover), `insurer` (text), `province?`, and
    `monthly_premium`, which comes from the recurring cost
  - **Car:** `asset_id?` (links a vehicle Asset), `make`, `model`, `year`,
    `vehicle_value`, `cover_type` (comprehensive / third-party fire & theft /
    third-party), `excess`
  - **Home contents / building:** `insured_value`, plus `asset_id?` linking a property
    Asset
  - **Life / funeral / disability:** `cover_amount`
  - **Medical aid / gap cover:** `plan_name`

  **No** policy number, ID number, or free-text notes field (notes invite pasted policy
  numbers). Validation rejects anything that looks like a 13-digit SA ID in text
  fields.

  `GET /savings/policies/{id}/check` returns facts computed in Python:
  - **premium per year**
  - **premium as % of vehicle or insured value**
  - **insured value vs the linked asset's current value:** over-insured means paying
    for cover you can't claim, under-insured means a short payout
  - **year-on-year premium increase,** from the transaction history of the matched
    recurring cost
  - **premium as % of monthly income**

  It gives no opinion on whether the premium is "too high". It only reports facts.
- **Files:** `models.py`, `savings/policies.py`, schemas, migration, tests.
- **DB:** one new table, plus enum types for policy and cover type.
- **Tests:** per-type validation (car needs make/model/year), ID-number rejection, each
  computed fact including missing-value cases (no linked asset → that fact is null, not
  0), ownership scoping.
- **Verify:** pytest, ruff, migration up/down; after deploy, create one policy from the
  app (item 6) and check the facts by hand against the premium.

### 6. App: policy forms and the data check

- **What:** on an insurance recurring cost:
  - **"Add policy details" form** that changes by policy type, with a picker to link an
    existing vehicle or property asset (value pre-filled)
  - **"Policy check" card:** premium/year, % of value, over- or under-insured
    warning, premium increase, % of income. Each fact has a one-line explanation in
    plain words
- **Files:** `lib/features/savings/…` (policy form + check widgets), tests.
- **DB:** none.
- **Tests:** form validation per type, asset link pre-fill, check card with null facts
  hidden rather than shown as "R0".
- **Verify:** flutter test; enter the real car policy on the emulator against a dev
  backend.

### 7. Backend: Penny insurance research (own item, `security-reviewer` before merge)

- **What:**
  1. **Safe query builder.** Builds the search text only from whitelisted policy
     fields and a fixed template, e.g. `"{year} {make} {model} {cover_type} car
     insurance premium South Africa {current_year}"`, or `"gap cover premiums South
     Africa {current_year} {plan_name}"`. Rules:
     - insurer and province are optional extras
     - never a name, amount, email, phone, ID, account number, or the user's own
       words
     - 2–3 queries per check (a market range, the insurer's recent premium
       increases, and what affects premiums for this asset)
  2. **Search** through the existing `services/web_search.py` (one client, not two
     copies).
  3. **Cache** in a `web_search_cache` table keyed by a hash of the query text:
     - stored with `retrieved_at`
     - reused for 14 days, then refetched on demand
     - an answer built from cache always shows "sources checked on {date}"
     - results older than 60 days are never used
     - no `user_id` in the cache, because the queries are generic and shared between
       users
  4. **Limits:**
     - 5 policy checks per user per day (slowapi)
     - a monthly credit budget counter (default 800 of Tavily's 1,000 free). Above
       it, the check returns the data-only facts plus "market research is paused
       until {1st of next month}"
  5. **`POST /api/chatbot/policy-check/{policy_id}`** (Pro). It hands Penny a
     **small, separate prompt**, not the full chat snapshot, made of:
     - the item 5 facts, already computed and formatted
     - the search snippets (title, domain, date, text)
     - the existing persona, scope, injection and FAIS clauses
     - a new clause: Penny compares only against what the sources say, says plainly
       when sources give no comparable number, ends with "questions to ask your
       broker" and "get 2–3 comparison quotes", **never** names an insurer to switch
       to, and **never** suggests dropping life, disability or medical cover outright
       (only "review it with a licensed FSP")

     The response returns `reply` and a server-built `sources: [{title, domain, url,
     retrieved_at}]`. The model's reply is not trusted for URLs.
  6. **"Where should I cut?"** The chat snapshot gains a `savings` block, with every
     value already computed:
     - the target, left over and gap
     - the top 5 cut candidates
     - recurring costs ranked by monthly amount
     - overlapping subscriptions of the same kind
     - any over-insured policy

     So the existing chat answers it from facts.
  7. **POPIA fix for the existing chat search.** Stop sending the raw user message to
     Tavily. Either (a) only search from a server-built query when the message matches
     an intent such as "insurance/premium" and has a policy attached, or (b) drop
     free-chat web search entirely and keep search for policy checks only. See D1b.
  8. **Close `/ai/web-search`:** delete it, or move it under `/api` behind
     `require_pro_tier` with a rate limit. Nothing in the app calls it (checked: no
     Dart caller).
- **Files:** `chatbot/service.py`, `chatbot/router.py`, `chatbot/schemas.py`, new
  `savings/research.py`, `services/web_search.py`, `routes/ai.py` / `main.py`,
  migration, `tests/test_chatbot.py`, `tests/test_policy_research.py`.
- **DB:** a `web_search_cache` table, plus a tiny `web_search_usage` (month, count) row.
- **Tests:**
  - **query builder:** property test that random policy data with injected names, IDs,
    emails and amounts never shows up in the query
  - **chat search:** a raw-message test proving the chat no longer forwards user text
  - **cache:** hit/miss/expiry; budget exhaustion falls back to data-only
  - **sources:** come only from search results
  - **prompts:** existing persona/FAIS assertions still pass, and new assertions cover
    the broker/quotes/never-switch clauses
  - **live set** (`pytest -m live`, run by hand): ~10 real policy shapes, read by Tiaan
    for advice leaks and made-up numbers
- **Verify:** pytest, ruff, the `security-reviewer` agent on the diff (focus: what
  leaves the server), the live set, then deploy. **Before merge, Tiaan confirms
  whether production has `TAVILY_API_KEY` set** (it decides whether D1 needs a new key).

### 8. App: "Ask Penny about this policy" and "Where should I cut?"

- **What:** an "Ask Penny" button on the Policy check card. It shows Penny's reply
  under the facts, with a **Sources** list (domain, title, "checked {date}", opens in
  the browser) and a fixed footnote: "Information, not advice. Confirm changes with a
  licensed financial adviser or your broker." It handles the Pro paywall (402) the same
  way chat does, and shows "research paused until {date}" when the budget is used up.
  The Savings plan screen gets a "Where should I cut?" chip that opens chat with that
  question pre-filled.
- **Files:** `lib/features/savings/…`, `lib/features/chatbot/…` (pre-filled question),
  tests.
- **DB:** none.
- **Tests:** sources render, budget-paused state, 402 → paywall, the footnote is always
  present.
- **Verify:** flutter test; emulator run against the deployed backend with Tiaan's real
  car policy. Read the answer together before release.

## Decisions for Tiaan

| # | Decision | Options | Recommendation |
|---|---|---|---|
| **D1** | Search provider | **Tavily** (already wired and tested; 1,000 free credits/mo, then $0.008/credit) · **Brave Search API** (independent index, $5 free credit/mo ≈ 1,000 searches, then $5/1k) · **self-hosted SearXNG** (no third party sees the query, but it scrapes other engines, breaks often, and adds a container to a server already shared with stringmonitor) | **Keep Tavily.** It already works, and the expected load is far below the free tier: 5 users × ~10 checks × 3 queries ≈ 150 credits a month, plus caching. Revisit only if it fails on SA results in the live set |
| **D1b** | Free-chat web search (today: raw message → Tavily) | (a) server-built query only, for insurance intents · (b) turn it off in free chat; search only from policy checks | **(b).** It is the simplest way to be sure no personal text leaves the server. Policy checks cover the research use case |
| **D2** | Where the screen lives (the 5-tab nav is locked in DESIGN.md) | (a) pushed screen opened from a Home card · (b) a third segment in the Budgets tab ("Budgets / Goals / Savings") · (c) a new tab, which **breaks the DESIGN.md lock** | **(a)**, plus a row in Settings. No nav change, and the gap is 1 tap from Home. (c) is listed only because the lock requires it to be flagged |
| **D3** | Data model | (a) new `savings_targets`, `recurring_costs` and `insurance_policies` tables · (b) extend Liabilities and Goals | **(a).** Liabilities are debts that count against net worth, and Goals are pots you fill up. Both would show wrong numbers |
| **D4** | Free vs Pro | Target, recurring list and data-only policy check: free or Pro · Penny research: Pro | **Target, list and data check free** (they are the reason to open the app daily); **Penny research Pro** (Tavily credits and the shared GPU). Beta testers get Pro free anyway |
| **D5** | Who writes the research answer | (a) qwen2.5:3b (local, free; weak at reading snippets) · (b) Claude Haiku via the existing `ANTHROPIC_API_KEY` (better at pulling ranges out of articles; costs cents; sends the policy facts, including the premium amount, to Anthropic, so the consent text must cover it) | **(a) first**, with the item 7 live set as the gate. Switch to (b) only if Penny gets the sources wrong, and update the consent document in the same PR |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| **Ollama tool-calling is unreliable on qwen2.5:3b (q4)** | High if relied on | **Not relied on.** The backend decides when to search and what to search for; the model only narrates. Works the same if the model is ever swapped |
| **Ollama context overflow.** The chat call sets no `num_ctx`; Ollama's default context (2k–4k tokens depending on version) is likely below snapshot + system prompt + search results, and gets **silently truncated** | Medium–high | The policy check uses its own small prompt (no full snapshot) and sets `options.num_ctx` explicitly. Item 7 measures prompt token counts in a test and logs them in production |
| **Insurers don't publish quotes.** Web results are articles, averages and press releases about increases, not "your exact premium elsewhere" | Certain | Set expectations in the copy: Penny says "published ranges and recent increases suggest…", and the recommended action is always "get 2–3 quotes". No scraping quote forms (out of scope and against most sites' terms) |
| **Not enough history.** Auto-capture started about 2026-09-24, so detection (≥2 monthly charges) finds little in October | High for Tiaan right now | Manual add in item 2 works on day one. Overview shows "based on N months". Backfill 3–6 months via the existing CSV import before item 3 ships |
| **Advice line (FAIS).** "Cut this policy" about life or medical cover is advice-shaped; `compliance-foundation.md` §9 lists "giving individualized financial advice" as a review trigger | Medium | Penny's research is facts plus sourced ranges plus broker questions only, never "switch to X" or "drop this cover". There is a fixed footnote in the app. Before the beta (other users), re-read §9 and decide whether a regulatory review is needed |
| **POPIA.** Data leaving the server | Exists today (raw chat text to Tavily) | Item 7 fixes the existing leak and allows only whitelisted generic fields in queries; security-reviewer checks it |
| **Shared GPU.** Policy checks add load to stringmonitor's Ollama | Low | 5 checks/user/day, cached results, and a small prompt |
| **Item 3 changes nothing existing, but Trends and the liabilities flow keep the old category-level logic** | Low | Deliberate. Note in the PR; retire the old endpoints later if the new detection proves better |

## Side findings (not in this plan, flag only)

1. `POST /liabilities/from-pattern` sets `outstanding_amount = monthly_amount`, so a
   recurring expense saved as a liability lowers net worth by one month's cost. Worth a
   small separate fix.
2. `/ai/web-search` is open to any logged-in user without a Pro check or a rate limit.
   It is covered by item 7, step 8, but it is live today if a Tavily key is set.

## Out of scope

Cancelling, changing or contacting any subscription or insurer; moving money; naming
products to buy; quote-form scraping; iOS; visual redesign; prod DB reads (Tiaan
enters his own numbers through the app).

## Acceptance

- [ ] Tiaan can set a target and see left over, gap and savings found, 1 tap from Home
- [ ] Every recurring cost is in one list, detected or manual, with confirm/dismiss and
      keep/cut
- [ ] Each of his policies has details and a data check
- [ ] Penny's policy answer cites dated sources and never names an insurer to switch to
- [ ] No search query contains user-entered text, names, amounts or IDs (test-proven)
- [ ] All 8 PRs merged to master; backend and app tests and ruff/analyze green
