# Piggybank Fix-It Blueprint

Fixes every open finding from `docs/qa/QA_FULL_SUITE_2026-08-31.md` (18 findings: 0 Critical, 6
High, 6 Medium, 6 Low), grouped by shared code/domain rather than by severity, so each step
touches one coherent area once. Grounded against the live codebase on 2026-09-01 — file/line
references below were re-verified against current source, not copied blind from the QA report.

**One correction to the QA report, made while grounding this plan:** finding H4 (chatbot
guardrail inversion)'s hypothesis — "the Settings → AI Assistant screen probably calls the wrong,
unauthenticated `/ai/chat` endpoint" — is **refuted**. `lib/features/chatbot/data/chatbot_api.dart`
calls `/chatbot/chat` (relative to the configured base URL, which already includes `/api`),
correctly hitting the authenticated `POST /api/chatbot/chat`. That endpoint's system prompt
(`backend/app/chatbot/service.py:208-239`) already has a well-written topic-scope guardrail
clause telling the model exactly when to refuse and exactly what to say. The live-observed
inversion (answers off-topic, refuses on-topic) is therefore most likely **the 3B local model
(`qwen2.5:3b-instruct-q4_K_M`) unreliably following a conditional instruction**, not a
routing/wiring bug — see Step 1 for the fix direction this implies.

---

## Dependency graph

```
Step 0  (AI/chatbot: currency guardrail + unauthenticated-endpoint fixes)
Step 1  (AI/chatbot: topic-guardrail reliability fix) ── depends on Step 0's grounding, not its code
Step 2  (CSV import wizard: 3 fixes, same screen/files)
Step 3  (Client network resilience: Dio timeout) ── independent, can run any time
Step 4  (UI/test polish: 4 small independent fixes)
Step 5  (Seed data corrections) ── touches a different file than Step 4; independent
Step 6  (Deferred / needs a product decision from the user — not implemented here)
Step 7  (Regression + live re-verification, update QA docs) ── depends on Steps 0–5 all being done
```

Steps 0–5 have no cross-dependencies on each other's *code* (different files/domains) and can be
done in any order or in parallel across sessions. Step 7 must run last. Step 6 is a checklist of
decisions to bring back to the user, not implementation work — do not silently implement any of
its items.

---

## Step 0 — AI/chatbot: currency guardrail + unauthenticated endpoint

**Status (2026-09-01): DONE, live-verified against the deployed backend.** User chose to delete
`/ai/chat` (Task 4) rather than secure it — confirmed no Flutter or test-suite caller before
deleting `routes/chat.py` and its sole dependency `services/ollama_agent.py`. Currency guardrail
added to `chatbot/service.py`'s system prompt. Live curl verification: `/ai/chat` now 404s;
`/api/chatbot/chat` returned `R` (never `$`) across every test run. All 1089 backend tests pass
locally; deployed via the standard tar+scp path and rebuilt on `100.121.165.7`.

**Fixes:** H2 (chatbot `$` instead of `R`), H3 (`/ai/chat` unauthenticated + unrate-limited), M6
(currency-formatting inconsistency, the `$`-symbol half of it — the number-grouping half is a
client-side display concern, not this step's scope; see Step 4 if it needs its own fix).

**Type:** Backend only (`piggybank-backend`). **Depends on:** nothing.

### Task 1 — Add the missing currency guardrail to the chatbot's system prompt (H2, part of M6)

`backend/app/chatbot/service.py`'s `system_prompt` (lines 208-239) has no currency-formatting
instruction at all. The sibling prompt in `backend/app/services/ai_context.py:267-273` (used by
`/api/ai/insights`, which does not have this bug) already has the exact guardrail text needed:

```python
"Every amount in the context is in South African Rand (ZAR). Present each amount using the "
"exact value from the context, prefixed with 'R'; you may insert spaces as a thousands "
"separator for readability, e.g. the context value 12345.67 is shown as R 12 345.67. "
"... it to another currency. Never use $, €, or £. "
```

Add an equivalent clause to `chatbot/service.py`'s `system_prompt`, right after the existing
"snapshot's net_worth" paragraph (after line 226, before the "Topic scope" comment at line 227) —
keep it as its own paragraph so it survives future edits to either the topic-scope or the
net-worth clauses independently.

### Task 2 — Require authentication on `/ai/chat` (H3)

`backend/app/routes/chat.py`'s `chat()` handler (lines 1-16) has no `Depends(...)`. Its sibling in
the same directory, `routes/ai.py`'s `/ai/web-search`, already has `Depends(get_current_user)` at
line 19 — use the identical pattern:

```python
from ..auth.dependencies import get_current_user  # match ai.py's existing import
from ..models import User

@router.post("/chat")
async def chat(request: ChatRequest, current_user: User = Depends(get_current_user)):
    return await ask_ollama(request.message)
```

Confirm the import path matches what `routes/ai.py` actually uses (grep it) rather than assuming
— the backend's own `CLAUDE.md` documents `chat.py` and `ai.py` as siblings, but don't assume
identical import paths without checking.

### Task 3 — Rate-limit `/ai/chat` (H3)

Add `@limiter.limit(...)` matching a comparable-cost endpoint's existing threshold. The QA
report's Step 2 finding noted general CRUD sits at `20-60/minute` and destructive-bulk at
`3/hour` — an LLM-inference endpoint should sit closer to the chatbot's own limit if
`chatbot/router.py`'s `/chat` has one (check; if it doesn't either, pick something conservative
like `10/minute` per user and note the choice in the commit message, since there's no existing
precedent to match exactly for this specific endpoint class).

### Task 4 — Decide whether `/ai/chat` should exist at all

Before shipping Tasks 2-3, re-read the backend `CLAUDE.md`'s own framing: `/ai/chat`
"functionally overlaps with `/api/chatbot/chat`" and is described as the less-developed,
never-fully-wired sibling. Once Step 1 (below) is done, `/api/chatbot/chat` will be the correct,
guarded, authenticated, currency-safe path. **Ask the user whether `/ai/chat` should be secured
(Tasks 2-3) or simply deleted** as dead/duplicate surface — deleting it removes both the security
issue and the maintenance burden of two chat implementations, and per this app's `CLAUDE.md`
conventions, dead code should be deleted outright rather than kept "just in case." Do not decide
this unilaterally; it's a product/architecture call, not a bug fix.

**Verification:** `curl -X POST /api/chatbot/chat` with a net-worth question → response contains
`R`, never `$`. `curl -X POST /ai/chat` with no `Authorization` header → `401`, not `200`. Same
call repeated 11 times in under a minute → the 11th returns `429`.

**Exit criteria:** Both currency and auth/rate-limit fixes deployed and curl-verified against the
live Tailscale backend; Task 4's decision recorded (implemented or the route deleted) before this
step is marked done.

---

## Step 1 — AI/chatbot: topic-guardrail reliability fix

**Status (2026-09-01): DONE, live-verified — plus one new finding surfaced and fixed during
verification.** A code-level hard pre-filter (keyword-based) was tried first per this step's
original Task 2 wording and **reverted** — it broke two already-tested, real inputs ("How am I
doing?", "Give me a quick summary") that match zero `_FINANCE_KEYWORDS` despite being legitimate
in-scope questions, which would have been a worse regression than H4 itself. The actual fix was
prompt engineering instead: the topic-scope guardrail moved to immediately follow the persona
intro (small quantized models weight earlier instructions more reliably) plus explicit
disambiguating examples. Live re-test: off-topic ("capital of France") refused 3/3 (previously
answered); on-topic repro prompts ("Am I on track with my budget?", "Show my net worth trend")
answered 3/3 and 1/1 respectively (previously refused); vague-but-in-scope messages ("How am I
doing?", "Give me a quick summary") still correctly answered, confirming the reverted hard-filter
approach was the right call to avoid.

**New finding surfaced and fixed during this step's live verification (not in the original QA
report):** the chatbot's net-worth *figure* (not just its currency symbol) was wrong by ~10x in
roughly 2/3 of repeated identical queries (e.g. "R180,803" instead of the real "R1,808,030").
Root-caused in two stages: (1) `chat_with_ollama`'s snapshot was f-string-interpolated as raw
Python `repr()`, not real JSON despite being labelled "(JSON)" — fixed with `json.dumps()`, but
this alone made the bug **100% reproducible instead of intermittent**, ruling out malformed-JSON
as the actual cause; (2) the real cause was the small model dropping a digit when copying a long
(7+ digit) unbroken number string verbatim — fixed by adding `_zar()`, pre-formatting every money
amount in the snapshot with space-thousands separators before it reaches the model, so it only
copies shorter chunked segments and prefixes with 'R' rather than reproducing one long digit run
and also doing its own grouping. Live re-test: 5/5 repeated net-worth queries now return the
exact correct figure (`R 1 808 030.50`), plus spot-checks on assets and a goal figure, both
exact. `test_net_worth_parity.py` updated to strip the new separators before its `Decimal()`
parity check. This finding and its fix are **not yet added to
`docs/qa/QA_FULL_SUITE_2026-08-31.md`** — do that in Step 7's doc-update task, since the QA
report is a frozen historical snapshot per its own convention; this blueprint file is the correct
place to record it until then.

**Fixes:** H4 (guardrail inversion), informed by this plan's corrected root-cause understanding
above.

**Type:** Backend only. **Depends on:** Step 0 grounding (read first), not its code changes.

**Context:** The existing system-prompt guardrail (`chatbot/service.py:208-239`) is well-written
and *should* work — asking the model to refuse off-topic questions and answer on-topic ones with
a specific redirect sentence when it declines. Live testing found the opposite: it answered
"What is the capital of France" directly and refused "Am I on track with my budget?" (one of the
UI's own three suggested questions). This is very likely `qwen2.5:3b-instruct-q4_K_M` — a small,
quantized model — unreliably following a conditional natural-language instruction, not a code bug
to patch in the traditional sense.

### Task 1 — Reproduce methodically before changing anything

Run the exact two failing prompts from the QA report ("Show my net worth trend", "Am I on track
with my budget?") against the live Ollama endpoint directly (bypassing the FastAPI layer, straight
`curl` to `OLLAMA_BASE_URL/api/chat` with the same system prompt) at least 3 times each. If the
model is inconsistent run-to-run (refuses sometimes, answers sometimes, on identical input), that
confirms model unreliability over a deterministic code bug and rules out a caching/session issue.

### Task 2 — Add a hard pre-filter as a safety net, don't rely on the model alone

`chatbot/service.py` already has `_looks_finance_related()` (lines 298-300) and its keyword set
`_FINANCE_KEYWORDS` (lines 288-295) — currently used *only* to gate the Tavily web-search call,
not to gate the refusal logic itself (per the comment at lines 284-287, "the point is to stop
obviously off-topic messages from spending a Tavily call," explicitly *not* claiming to enforce
the topic scope). Extend its use: before calling Ollama, run the latest user message through
`_looks_finance_related()` (or a slightly tightened variant — "capital of France" won't match any
current keyword, which is good; "budget"/"net worth" will, which is also good). If it returns
`False`, skip the LLM call entirely and return the exact fixed redirect string the prompt already
specifies ("I can only help with questions about your finances here in Piggybank.") directly from
Python. This removes the model's discretion on the *refuse* half of the guardrail — it can no
longer answer an off-topic question, because the app never sends one to it.

**Do not** flip this into a hard *allow* filter for the other direction (i.e., don't skip the LLM
and auto-answer everything that matches a finance keyword) — the false-refusal half (on-topic
questions like "Am I on track with my budget?" being declined) is a model-following-instructions
problem that a keyword allowlist can't fix, since the input already *is* finance-related; only
better prompting, a larger/different model, or a temperature/sampling change can address that
half. Investigate Ollama request parameters (`temperature`, currently unset/default) as a
secondary lever if a quick prompt tweak (e.g. moving the topic-scope clause earlier in the system
prompt, since small models are known to weight instructions unevenly by position) doesn't resolve
the false-refusal cases in Task 1's repro testing.

### Task 3 — Re-test after each change

Re-run Task 1's exact repro set after every prompt/parameter change — don't ship on a single
passing run given the model's demonstrated inconsistency.

**Verification:** The three original repro prompts (French capital, net worth trend, budget
on-track) run 5 times each post-fix; off-topic questions refused 5/5, on-topic questions answered
5/5 with real account data.

**Exit criteria:** Documented in the commit message: how many repro runs were done, the pass
rate, and which of Task 2's levers (hard pre-filter / prompt reordering / sampling params) ended
up shipped. If full reliability isn't achievable with the current model, say so explicitly and
flag a possible model upgrade for a future blueprint rather than silently shipping a
still-flaky guardrail as "fixed."

---

## Step 2 — CSV import wizard fixes

**Status (2026-09-01): DONE, live-verified.** All three fixes shipped and confirmed on the
Tailscale backend + emulator, not just unit-tested. H5: `_buildRowErrors()` added to
`imports_screen.dart`, decodes `errorMessage`'s JSON list and renders `Row N: <error>` lines
under a "Row errors" label (falls back to the raw string on a decode failure). M2: `_upload()`
split into `_onUploadPressed()` (shows an `AlertDialog` confirm when `_selectedAccountId == null`)
+ the original `_upload()`, wired to the Upload button. M3: root-caused by reading
`app/imports/router.py` directly — `category` is always non-blank (required field), so the
originally-hypothesized "blank check" fix doesn't apply as literally stated; the real fix gates
the learned-rule override on `template is not None`, since `category` only holds untrustworthy
raw-bank-description text for templated imports (`templates.py` maps `category: "Description"`
for most banks) — a generic/direct upload's `category` is real user intent and is now always
preserved. New regression test added
(`test_generic_upload_never_overwrites_explicit_category_with_learned_rule`); templated imports
still auto-categorize correctly (spot-checked live: FNB-template upload still returned
`auto_categorized_rows: 1`). All 1090 local backend tests + `flutter analyze` pass.

**Fixes:** H5 (silent failure UI), M2 (silent account-orphaning), M3 (category overwrite).

**Type:** Flutter client (H5, M2) + backend (M3 investigation). **Depends on:** nothing.

### Task 1 — Surface `error_message` in the failure UI (H5)

The data is already there and unused: `lib/features/imports/models/import_job.dart` already
parses `errorMessage` (`json['error_message']`) into `ImportJob.errorMessage`, but
`lib/features/imports/screens/imports_screen.dart`'s `_ResultCard` (lines 590-661) never renders
it — only `Imported: X / Y`, `Failed rows: Z`, `Auto-categorized`, and `Duplicates skipped` (lines
636-639). Add a conditional block: `if (job.errorMessage != null) ...` showing the parsed
per-row error list. **Note:** `errorMessage` is a JSON-encoded string of a list
(`"[{\"row\": 2, \"error\": \"...\"}]"`), not already a Dart list — decode it with `jsonDecode`
before rendering, and handle a decode failure gracefully (show the raw string as a fallback
rather than crashing the result screen on a malformed value).

### Task 2 — Make "No account" a deliberate choice, not a silent default (M2)

In the Configure step (the dropdown defaulting to "No account"), add either (a) a confirmation
step before Upload when the account field is still "No account" — a simple `showDialog` warning
"Transactions won't be linked to any account. Continue?" — or (b) a visible warning banner on the
Review step when `account_id` is unset. Prefer (a): it's a smaller diff and catches the mistake
before the import runs rather than after. Do not remove the "No account" option entirely — some
real use cases (e.g. cash transactions) legitimately have no account.

### Task 3 — Investigate the category-overwrite bug before fixing it (M3)

Not yet root-caused. `auto_categorized_rows` incremented and both a supplied `"Groceries"` and a
supplied `"Salary"` were overwritten with `"Freelance"` in testing. Find the categorization logic
in the backend's imports module (likely `backend/app/imports/` — grep for where
`auto_categorized_rows` gets incremented and what decides the replacement category) before
writing a fix. Two plausible root causes with different fixes:
- The categorizer is unconditionally replacing every row's category (bug: should check `if not
  category` first) — fix: add the blank-check.
- The categorizer is correctly checking for blank/generic categories but its own classification
  logic is defaulting to "Freelance" incorrectly for these specific inputs (a classification bug,
  not a control-flow bug) — fix: investigate why "QA test import row 1"/"row 2" (the
  descriptions used in QA testing) classify as "Freelance" specifically.
Do not guess which one it is without reading the actual categorization code first.

**Verification:** H5 — import the same known-bad CSV from the QA report, confirm the failure card
now shows the row-level error text. M2 — attempt an import with "No account" selected, confirm a
warning appears before the import proceeds. M3 — re-run the exact repro CSV (`category:
"Groceries"` on an expense row, `category: "Salary"` on an income row) via direct API call,
confirm both categories are preserved (or correctly left blank if that's the intended behavior
for unrecognized categories — confirm intent with the user if genuinely ambiguous after reading
the code).

**Exit criteria:** All three fixes live-verified against the Tailscale backend and the emulator
UI, not just unit-tested.

---

## Step 3 — Client network resilience: Dio timeout

**Status (2026-09-01): DONE, live-verified.** `ApiClient`'s shared `Dio` now sets
`connectTimeout: 8s`, `sendTimeout: 15s`, `receiveTimeout: 15s` as global defaults;
`chatbot_api.dart`'s `sendMessage` and `insights_api.dart`'s `ask` each override
`receiveTimeout: 60s` per-request via `Options(...)`, per the plan's own preference for a
short global default over a blanket 45-60s receive timeout. Live-verified both halves: (1)
normal-latency path — asked Insights a real question against the Tailscale backend, got a
correct answer back in a few seconds, no spurious timeout; (2) fast-fail path — built a
throwaway debug APK with `--dart-define=API_BASE_URL=http://10.255.255.1:8000/api` (a
non-routable black-hole address), attempted login, got "Network error. Check your connection
and try again." instead of an indefinite hang, consistent with the 8s `connectTimeout`. The
throwaway build was discarded and the real backend build reinstalled afterward. `flutter
analyze` clean; all 14 existing tests across `api_client_test.dart`, `chatbot_api_test.dart`,
and `insights_api_test.dart` still pass unmodified.

**Fixes:** H6.

**Type:** Flutter client only. **Depends on:** nothing.

`lib/core/api/api_client.dart:12-24` constructs `Dio(BaseOptions(baseUrl: baseUrl))` with no
timeout fields set. Add `connectTimeout`, `receiveTimeout`, and `sendTimeout` to the
`BaseOptions(...)` call. **Pick values deliberately, don't copy a generic default:**
- `connectTimeout`: short (5-10s) — a connection that can't even establish shouldn't wait long.
- `sendTimeout`: short-to-medium (10-15s) — covers CSV/image uploads (imports, receipt scans),
  which are larger payloads than typical JSON requests but still shouldn't hang indefinitely.
- `receiveTimeout`: must accommodate the AI endpoints' legitimate 10-26s+ response times (per the
  QA report's Step 2 latency findings) — set this comfortably above the slowest observed AI
  endpoint (`/api/ai/insights` at 26.1s), e.g. 45-60s, or the fix will itself introduce false
  timeout errors on the app's own slowest legitimate calls.

Consider whether AI-backed calls need a *longer* per-request override via Dio's per-request
`Options(receiveTimeout: ...)` rather than raising the global default for every request — a 45-60s
global receive timeout means a genuinely hung non-AI request (which should fail fast) now waits
just as long as a legitimate AI response. Prefer a shorter global default (10-15s) plus an
explicit longer override on the specific AI-endpoint call sites (`chatbot_api.dart`, the
insights API) if that's a small enough diff.

**Verification:** Manually verify (e.g. via a debugger breakpoint or a temporary firewall rule to
a scratch endpoint) that a hung connection now fails after the configured timeout instead of
waiting forever. Confirm the AI endpoints still complete successfully end-to-end at their normal
10-26s latency without spuriously timing out.

**Exit criteria:** Timeout values set and justified in the commit message; both a fast-fail path
and the AI endpoints' normal-latency path verified live.

---

## Step 4 — UI/test polish (4 independent small fixes)

**Status (2026-09-01): DONE, live-verified.** All four tasks shipped. M1: the user chose
"green/red everywhere" over "ordinary ink everywhere" — `_TransactionRow` in
`transactions_screen.dart` now tints income `semantic?.success` and expense `semantic?.danger`
(previously plain ink for both), and `dashboard_screen.dart`'s `_RecentTransactionsPreview` was
extended to also tint expenses `danger` (it previously only tinted income `success`, leaving
expenses in plain ink — the actual source of the QA report's "inconsistent styling" observation).
`DESIGN.md` §5 updated to match, noting the 2026-09-01 supersession. M4: `TickerAutocompleteField`
rewritten to render its suggestions via `OverlayEntry`/`CompositedTransformFollower` instead of
inline in the parent `Column`, so it can never overflow the parent's layout constraints regardless
of keyboard state — live-verified on the emulator: typed "GLD" into Compare Instruments' ticker
field with the keyboard open, suggestions floated correctly with no debug overflow banner. M5:
one-line fix, `test/widget_test.dart`'s expected label changed from `'Email'` to `'Email address'`;
`Password`/`Log in` were already exact matches (re-verified). L2: `_ComparisonLineChart`'s
`leftTitles` given an explicit `getTitlesWidget` that suppresses fl_chart's auto-added exact-max
label whenever it falls within 15% of an interval-below it (fl_chart always draws that label in
addition to the regular interval-spaced ones, which is what caused the overlap) — live-verified in
both percent and Abs mode on the 1-year GLD chart; Abs mode's non-round max (`798.8`) rendered
cleanly above the `750` gridline label with no overlap. All 422 Flutter tests pass; `flutter
analyze` clean on every modified file (one pre-existing, unrelated info-lint at
`dashboard_screen.dart:60` noted but out of scope, deferred to Step 6's L5).

**Fixes:** M1 (income color), M4 (Compare Instruments overflow), M5 (LoginScreen test), L2
(chart Y-axis label overlap).

**Type:** Flutter client only. **Depends on:** nothing. Each task below is independent of the
others — fine to split across sessions or people.

### Task 1 — M1: Transactions list income color

`lib/features/transactions/screens/transactions_screen.dart:210-219`'s `_TransactionRow` has an
explicit code comment: *"Per DESIGN.md § Transactions and the Stitch mockup: amount trailing in
ordinary ink for every row — never red/green by direction."* **This is a deliberate design
decision already documented in the codebase, not an oversight** — the QA report's framing
("inconsistent styling for the same data") is accurate as an observation but the fix-it call here
is a genuine product decision, not a bug fix: either (a) the Dashboard's `_RecentTransactionsPreview`
(`lib/features/dashboard/screens/dashboard_screen.dart:262-273`, which does colour income green)
should be changed to match the Transactions screen's documented convention, or (b) `DESIGN.md`
and the Transactions screen should be updated to match the Dashboard. **Ask the user which
direction is correct before touching either file** — this is not implementable without that
decision, unlike the rest of this step.

### Task 2 — M4: Compare Instruments ticker-autocomplete overflow

`lib/shared/widgets/ticker_autocomplete_field.dart`'s `_Suggestions` (lines 90-134) renders
inline as a fixed-height (`maxHeight: 220`) `Card`/`ListView` directly in
`instrument_comparison_screen.dart`'s plain `Column` (lines 92-196), which isn't keyboard-safe-
scroll-aware around this specific field. Two fix directions:
- Convert `_Suggestions` to render via an `OverlayEntry`/`CompositedTransformFollower` (the
  standard Flutter pattern for autocomplete dropdowns, avoids the parent layout's height
  constraints entirely) — larger diff, more correct long-term.
- Wrap the comparison screen's body in a `SingleChildScrollView` if it isn't already effectively
  one, and ensure `Scaffold(resizeToAvoidBottomInset: true)` (Flutter's default) actually has
  room to push content — smaller diff, may not fully fix it if the screen has other height
  constraints (the chart, the stats table) competing for space.
Prefer the overlay approach given this is used across multiple tabs (Summary/Risk metrics/
Correlation) — a layout-based fix would need re-verifying on all three.

### Task 3 — M5: Fix the stale widget test

`test/widget_test.dart:16` searches for `find.widgetWithText(TextField, 'Email')`, but
`lib/features/auth/screens/login_screen.dart:74-82`'s actual `TextField` now has `labelText:
'Email address'` (changed at some point after the test was written, along with adding a
`hintText` and `prefixIcon` — cosmetic polish that broke an exact-text-match test). One-line fix:
change the test's expected text to `'Email address'`. Confirm the Password field/button text
(`'Password'`, `'Log in'`) are still exact matches too before considering this test fully green
again — the research pass confirmed both still match, but re-verify at fix time in case of drift.

### Task 4 — L2: Compare Instruments chart Y-axis label overlap

Cosmetic-only — the exact max value label overlaps the nearest rounded gridline label on the
price chart. Locate the chart's Y-axis label-rendering logic (likely in the same
`instrument_comparison_screen.dart` or a shared chart widget it uses) and either suppress the
exact-max label when it's within a few pixels of a gridline label, or increase the label's
vertical offset slightly. Low priority — batch with Task 2 (same screen) if convenient.

**Verification:** M1 needs the user's decision first, then a one-line style change either way.
M4 — reproduce the exact repro from the QA report (type a ticker with keyboard open) and confirm
no debug overflow banner. M5 — `flutter test test/widget_test.dart` passes. L2 — visual check on
the 1-year GLD chart, labels no longer overlap.

**Exit criteria:** Tasks 2-4 shipped and verified independently; Task 1 blocked on a product
decision, tracked separately if the user doesn't resolve it in this pass.

---

## Step 5 — Seed data corrections

**Status (2026-09-01): Code DONE, live-verified against a scratch account. User explicitly
declined re-seeding the real shared demo account for now ("Not now") — leaving its existing
cost-basis/budget data as-is. Revisit if/when the user wants it refreshed; note the fixed script
is additive/idempotent, so a future re-seed run alone won't retroactively correct the demo
account's already-existing bad holdings or stale budget months — those would need explicit
deletion first (via the API) before re-running the script, same choice offered and declined here.**
H1: `HOLDINGS`' `cost_basis` values divided by `quantity` per the QA report's own math
(AAPL 2800.00, MSFT 10500.00, NPN.JO 3200.00, GLD 320.00, SBK.JO 210.00). L1:
`create_budgets()`'s hardcoded `["2026-04-01", "2026-05-01"]` replaced with
`date.today().replace(day=1)` and the month before it via `dateutil.relativedelta`, so the seed
script always produces budget rows for "this month" regardless of when it's run. Live-verified by
seeding a throwaway scratch account (`scratch-fixit-verify@financeapp.co.za`, not the shared demo
login) against the production Tailscale backend: holdings' `cost_basis` came back per-unit exactly
as expected via `GET /portfolios/{id}/holdings`; budgets came back correctly dated `2026-09-01`
(today's actual month, the script having run on 2026-09-01) via
`GET /budgets/?month=2026-09-01` — 8 rows for Sept, 8 for Aug. Scratch account deleted afterward
(`DELETE /auth/me`, `204`). Full 1090-test backend suite still passes (the seed script isn't
test-covered directly, so this confirms no regression elsewhere).

**Scope note on Transactions' matching staleness:** `TRANSACTIONS` (Step 4 of the script, Jan–Jun
2026 hardcoded) has the same kind of fixed-year staleness as the Budgets bug did, and is now
several months in the past relative to any real seeding date — but the QA report's L1 finding was
scoped to Budgets only, and Transactions carries hand-authored narrative content tied to specific
months (a May "intentionally exceeds budget" scenario cross-referenced against the old Apr/May
budget window, a Feb 14 "Valentine's" flavor description) that a relative-date rewrite would need
to preserve deliberately, not just shift mechanically. Left out of this pass as a genuine scope
call, not an oversight — flagging here per the plan's own instruction to "consider... before
considering this step fully done." A future pass could shift the whole 6-month block by a
computed offset (preserving month-to-month relative narrative) if this is judged worth fixing.

**Fixes:** H1 (portfolio cost-basis), L1 (budget dates).

**Type:** Backend seed script only (`backend/scripts/seed_test_user.py`). **Depends on:**
nothing. **Consequence to flag before running:** re-seeding the demo account will change data
that Step 3 of the QA pass snapshotted (`accounts=3, transactions=75, portfolios=1, holdings=5,
goals=3, assets=6, liabilities=3, budgets=16` — portfolio count is now 3, see the QA report's
TFSA/RA confirmation) and that the shared demo login (`demo@financeapp.co.za`) may be actively
used elsewhere (client demos, the `piggybank_demo_account` memory notes it's now Pro tier on
prod) — **confirm with the user whether/when to run this against the live demo account**, since
it's a destructive re-seed, not an additive fix.

### Task 1 — Fix holdings' cost-basis to be genuinely per-unit (H1)

`backend/scripts/seed_test_user.py:487-491` currently has (total-invested, not per-unit):
```python
{"ticker": "AAPL",   "quantity": "15",  "cost_basis": "42000.00", ...}   # → should be ~2800/share
{"ticker": "MSFT",   "quantity": "8",   "cost_basis": "84000.00", ...}   # → should be ~10500/share
{"ticker": "NPN.JO", "quantity": "20",  "cost_basis": "64000.00", ...}   # → should be ~3200/share
{"ticker": "GLD",    "quantity": "50",  "cost_basis": "16000.00", ...}   # → should be ~320/share
{"ticker": "SBK.JO", "quantity": "100", "cost_basis": "21000.00", ...}   # → should be ~210/share
```
Divide each `cost_basis` by its `quantity` (values above are the QA report's own math, already
correct) — this is the one-line-per-row fix the QA report recommended. **Do not touch
`backend/app/portfolios/router.py`'s cost/P&L formula** — it is correct; the bug is purely in
this seed data.

### Task 2 — Use rolling/relative dates for budget seed data (L1)

`backend/scripts/seed_test_user.py:273` hardcodes `months = ["2026-04-01", "2026-05-01"]`
(transactions span Jan-Jun 2026, lines 125-234). Replace the fixed months with dates computed
relative to the script's run time (e.g. the current month and the previous month), so a demo
account always has budget data for "this month" regardless of when it's seeded or when someone
demos the app. Check whether the transaction seed data (lines 125-234) has the same fixed-2026
staleness problem and consider whether it needs the same relative-date treatment — the QA report
only flagged Budgets specifically, but re-verify Transactions/Expenses don't have a parallel gap
before considering this step fully done.

**Verification:** Re-seed a fresh (non-demo, scratch) account, confirm Invest tab's unrealized
P&L is now a plausible, small figure rather than -R5M+. Confirm Budgets shows populated data for
whatever month the seed script was run in, not a fixed past month.

**Exit criteria:** Seed script fixed and verified against a scratch account; re-seeding the real
shared demo account done only after explicit user confirmation, not automatically as part of this
step.

---

## Step 6 — Deferred / needs a product decision (not implemented here)

These QA findings are not code fixes — bring them back to the user rather than silently acting or
silently dropping them:

- **L3 (stale DNS record)** — `piggybank.fynboscreative.co.za` → `102.214.9.185`, which serves
  nothing for that name. **User decision (2026-09-01): remove the record.** Not a code fix and no
  DNS/registrar tool access from this session — flagged as a manual action item for the user
  (whoever manages DNS for `fynboscreative.co.za`) to delete the stale A record while the backend
  stays Tailscale-only. Not yet done.
- **L4 (account row tap → Edit mode)** — explicitly framed in the QA report as "may be
  intentional... flagged for product-owner judgment call," not a defect. **User decision
  (2026-09-01): build a read-only detail view.** **Status: DONE.** New
  `lib/features/accounts/screens/account_detail_screen.dart` (`AccountDetailScreen`) shows the
  account's balance/type/institution/currency read-only plus its 20 most recent transactions (new
  `accountTransactionsProvider` family in `transactions_provider.dart`, scoped via
  `TransactionsApi.list(accountId: ...)`); an AppBar edit icon opens the existing
  `AccountEditScreen` as the now-separate explicit edit action. `accounts_screen.dart`'s
  `_AccountRow.onTap` repointed from `AccountEditScreen` to `AccountDetailScreen`; `onLongPress`
  (deactivate context menu) unchanged. Verified via a new automated widget test suite
  (`test/features/accounts/screens/account_detail_screen_test.dart`, 3 tests: read-only fields
  render with no editable `TextField`, empty state, transactions correctly scoped to the account
  via a mocked `TransactionsApi`) rather than manual emulator/adb verification at the time, given
  that session's tight remaining context budget. **Live-verified in Step 7 (2026-09-01):**
  tapped the FNB Cheque Account row on the emulator against the Tailscale backend — read-only
  balance/type/currency plus 5 scoped, correctly-tinted recent transactions rendered, no editable
  fields; the AppBar edit-pencil icon correctly opened the existing `AccountEditScreen`.
  `flutter analyze`: No issues found. Full suite: 425/425 passing (422 prior + 3 new).
- **L5 (41 info-level lints)** — **User decision (2026-09-01): batch-fix now as its own pass.**
  **Status: DONE.** All 41 `flutter analyze` info-lints fixed across 12 files (mechanical fixes:
  `use_key_in_widget_constructors`, `prefer_const_literals_to_create_immutables`,
  `prefer_const_constructors`, `eol_at_end_of_file`, `unnecessary_lambdas` → tearoffs,
  `cast_nullable_to_non_nullable`, `directives_ordering`). Fixing some `prefer_const_constructors`
  cases (adding `const` to an outer `AuthState`/widget-tree constructor) surfaced two follow-on
  lints from the outer `const` making an inner one redundant/misordered
  (`always_put_required_named_parameters_first` on `AccountContextMenu`'s new `super.key` param,
  `unnecessary_const` on nested `User(...)` literals in `lock_screen_test.dart`) — both fixed in
  the same pass. `flutter analyze` → "No issues found!"; full 422-test suite passes.
- **L6 (Admin has no client UI)** — `docs/admin-scope.md` describes a feature that was never
  built client-side. **User decision (2026-09-01): leave both as-is** — backend route and doc stay
  untouched, client UI remains unbuilt. Closed, no further action.

---

## Step 7 — Regression + live re-verification, update QA docs

**Status (2026-09-01): DONE.** Automated regression: backend `pytest` 1090 passed / 6 deselected
(live-only) / 0 failures; `flutter analyze` no issues found; `flutter test` 425/425 passing. Live
re-verification against the Tailscale backend on a freshly-booted emulator (clean `pm clear`,
fresh debug APK build reflecting Steps 0-6, demo login): M1 (green/red convention, confirmed on
both Dashboard and Transactions), L4 (new detail view + its edit-icon handoff, see Step 6 above),
M4 (ticker-autocomplete overlay, no overflow with keyboard open — the pre-existing, unrelated
1.9px bottom overflow re-observed unchanged, confirming it's not a regression), L2 (chart label
fix, Abs mode's non-round 798.8 max), H2+H4 (chatbot currency + topic guardrail, both refusal and
answer directions live-tested via "What is the capital of France" and "Am I on track with my
budget?"), and the Step 1 net-worth digit-dropping fix (1/1 re-test exact: `R 1 808 030.50`).
H1/L1 confirmed indirectly — the real demo account's Accounts/Budgets screens still show the
documented pre-fix state (re-seed declined, nothing since has changed that). H3/H5/H6/M2/M3/M5/M6
not independently re-exercised live this pass (backend-only, or code unchanged since their own
step's live verification) but covered by the automated regression. `QA_FINDINGS.md` updated with
a new 2026-09-01 top section summarizing this whole blueprint and pointing back here; the Step 1
net-worth finding is now folded in there (not into the frozen `QA_FULL_SUITE_2026-08-31.md`, per
that file's own historical-snapshot convention). Still open: L3 (DNS removal, needs manual
registrar access) and the real demo account re-seed (still declined/pending).

**Depends on:** Steps 0-5 all being done (whichever subset the user chose to run — this step
re-verifies whatever was actually shipped, not a fixed list).

### Task 1 — Automated regression
Re-run the same three suites Step 1 of the QA pass ran: backend pytest (`docker compose
--env-file .env.docker run --rm --entrypoint '' backend-test python -m pytest tests/ -v`),
`flutter analyze`, `flutter test` — full output, not summarized. Diff against the QA report's
baseline (1083 backend passed/6 skipped, 41 info-lints, 420 passed/2 failing) — both Flutter
failures should now be resolved (M5's fix here; the `subscription_api_test.dart` one was already
resolved before the QA report was written).

### Task 2 — Live re-verification on the emulator
For every fix in Steps 0-5 that has a UI-visible effect, re-run its exact QA-report repro steps
live against the Tailscale backend (same emulator setup as the QA pass: clean
`pm clear`/reinstall, demo login, screenshot evidence for anything non-obvious). Don't rely on
automated tests alone for the AI/chatbot fixes (Steps 0-1) — those need live LLM calls to confirm
mid-run behavior actually changed, not just that the code compiles.

### Task 3 — Update the QA docs
Add a new dated update-section to `QA_FINDINGS.md` (matching its existing convention) summarizing
what shipped from this blueprint, what's still open (Step 6 items, plus anything from Steps 0-5
the user chose to defer), and pointing to this file (`plans/piggybank-fix-it.md`) as the record
of what was done and why. Do not delete or rewrite `docs/qa/QA_FULL_SUITE_2026-08-31.md` — it's
a historical snapshot, same convention as `docs/qa/QA_LOG.md`.

**Verification:** Every finding from Steps 0-5 that was actually implemented has a fresh,
dated confirmation (automated test result or live repro) — not "should be fixed now," an actual
re-check.

**Exit criteria:** Regression suites green (or any remaining failures explicitly classified, same
standard as the original QA pass), every implemented fix live-re-verified, `QA_FINDINGS.md`
updated, everything committed (`piggybank-backend` pushed to `origin`; `Piggybank` committed
locally, no remote).

---

## Notes for whoever executes this plan

- Steps 0-5 are independent of each other's code — a session can pick any subset rather than
  working strictly in order, but Step 7 needs whichever subset was actually done to know what to
  re-verify.
- Three items across this plan are explicitly **not** yours to decide unilaterally: Step 0 Task 4
  (delete vs. secure `/ai/chat`), Step 4 Task 1 (which screen's income-colour convention wins),
  and Step 5's re-seed timing against the live shared demo account. Surface these to the user;
  don't guess.
- This plan corrects one QA-report hypothesis (H4's "wrong endpoint" theory) based on re-grounding
  against live source before writing fix instructions — if a future session finds another QA
  finding's premise doesn't match current code, prefer the code over the report and note the
  correction here, the same way this plan's own header does.
