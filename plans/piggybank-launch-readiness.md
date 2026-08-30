# Blueprint: Piggybank Launch Readiness — Security, Payments & AI Refinement

**Objective:** Close the four gaps the user flagged as still open before a real production
launch: (1) confirm screen/mockup parity is actually complete rather than assumed, (2) audit
and harden security, (3) stand up a real payment gateway behind the currently-mocked
Subscription upgrade flow, (4) refine the AI chatbot/insights persona and fix its known
data-accuracy gap.

**Mode:** Direct (no `gh` CLI / PR workflow in use on this machine — edit-in-place, commit
directly, no branches).

**How this plan was grounded** (2026-08-30, before writing a single step): read
`plans/piggybank-production-completion.md` (15/15 steps done), `plans/piggybank-full-suite-qa.md`
(10/10 steps done) and `QA_FINDINGS.md`'s 2026-08-28 update section, `docs/chatbot-design-note.md`,
today's own Settings mockup-parity commit (`d6402d0`), and the real backend repo
(`../piggybank-backend/backend/app/{chatbot,subscriptions}/`, `Caddyfile`, `main.py`, `config.py`)
— not the retired `finance-app.v3-main` template. This is a **second** blueprint layered on top
of the completed production-completion one, not a re-scope of it.

**Explicitly out of scope for this blueprint:**
- Anything the production-completion blueprint already closed (Admin implementation — still
  gated on its own future blueprint per that doc's Step 0; Dashboard customization — still
  dropped by explicit user decision).
- Manual Google Play Console submission steps (content rating, Data safety section) — still
  out of scope per that blueprint too.
- Choosing a specific payment gateway or writing gateway-integration code before Step 5's
  scoping conversation happens — real money and a merchant-account signup are involved, this
  is a hard gate, same pattern as Admin's Step 0.

---

## Current-state summary (grounded, not assumed)

**Screens/Stitch parity — essentially done.** All screens from both prior blueprints are built,
tested (406+ automated tests, `flutter analyze` clean), and — as of today's session — verified
against freshly-generated Stitch mockups for all 5 Settings sub-screens (commit `d6402d0`).
There is **no backlog of unbuilt major screens**. What remains is a short tail of small,
already-known gaps (Step 4 below) — not new screen work.

**Security — never formally audited.** Individual good practices exist (argon2id password
hashing, JWT with in-memory-only access tokens + HttpOnly-cookie refresh tokens, a fail-fast
guard against the default JWT secret in production, slowapi rate limiting, CORS restricted to
configured origins, CSP deliberately left to Caddy not FastAPI, Caddy auto-TLS via
`{$DOMAIN}`). But no one has ever walked the app end-to-end with a security checklist — mobile
secure-storage of tokens, certificate pinning, release-build obfuscation, dependency CVEs,
secrets-in-repo, and POPIA data-handling practice (a foundation doc exists at
`../piggybank-backend/docs/compliance-foundation.md` but hasn't been checked against what's
actually implemented) are all unverified either way. Step 0 below is that first real audit.

**Payments — literally does not exist.** `grep`-confirmed zero mentions of any payment
provider anywhere in either repo. `subscriptions_router.upgrade()` just flips a DB row to
`tier=PRO` for 30 days — no charge, no card, no webhook, no refund path. This is 100%
greenfield, and picking a provider is a business decision (fees, SA banking rails, compliance)
as much as a technical one.

**AI chatbot/insights — functional but has one known correctness bug and no persona.**
`chat_with_ollama()`'s system prompt is generic ("You are a personal finance copilot...") with
no name, no brand voice, and — per the 2026-08-28 QA pass — no guardrail against off-topic
questions (it answered "capital of France" directly). More importantly, the **High-severity QA
finding is still open**: Chatbot and Insights both build their context snapshot from
Assets/Liabilities/Transactions only, never Accounts or Portfolio balances — so the Dashboard
shows one net-worth figure and the AI features show a different, wrong one for the same account
at the same moment, and the Chatbot's own answer text incorrectly claims investments are
included when asked. Any "refine the persona" work should not ship on top of this — the numbers
have to be right before the voice matters.

---

## Dependency graph

```
Step 0  (Security audit — investigative, produces docs/security-audit.md) ── independent
        │
        ▼
Step 1  (Security remediation — scope set by Step 0's findings)

Step 2  (Fix AI context gap: Insights + Chatbot see Accounts/Portfolios) ── independent
        │
        ▼
Step 3  (Chatbot/Insights persona + guardrail refinement) ── depends on Step 2
                                                               (don't polish wrong numbers)

Step 4  (Small screen-polish backlog: Goals deadline field, Invest "See all"
         destination, Instrument Comparison ticker gap, stray demo portfolio
         cleanup) ── independent, can run any time

Step 5  (Payment gateway scoping conversation — hard gate, produces
         docs/payment-gateway-scope.md) ── independent
        │
        ▼
Step 6  (Payment gateway integration — scope set by Step 5's decision)
```

**Recommended execution order:** 2 → 3 (fix the AI data bug before polishing its voice) run
early since they're both concrete and independent of everything else; 0 → 1 in parallel with
that; 4 whenever convenient; 5 as soon as the user has 15 minutes for the scoping conversation,
with 6 following once a provider is chosen.

---

## Step 0 — Security audit pass

**Type:** Investigative (read-only), Flutter + backend. **Model:** default, but budget for a
long single session — this touches both repos.

**Context brief:** No security audit has ever been done on this app. It is a personal-finance
app handling real account balances, transaction history, and (once Step 6 lands) real payment
data — the bar is higher than a typical MVP. Ground every finding in the actual code, not a
generic checklist recited from memory; this repo already has real practices in place (see
"Current-state summary" above) that a generic audit would waste time re-discovering as if new.

**Task list:**
1. **Backend**: read `../piggybank-backend/backend/app/security.py`, `config.py`, `main.py`,
   `limiter.py` in full. Confirm: JWT secret fail-fast guard actually fires in the deployed
   config (not just in theory); rate-limit coverage on auth endpoints specifically (login,
   register, password reset if one exists); whether refresh-token rotation/reuse-detection
   exists; SQL injection surface (should be near-zero via SQLAlchemy ORM, but check any raw
   SQL); whether `pytest -m live` tests touch real external APIs safely (no real secrets
   committed to run them).
2. **Backend dependencies**: run `pip list --outdated` / check for a `pip-audit` or `safety`
   pass across `requirements.txt`; flag any known-CVE package versions.
3. **Secrets hygiene**: scan across both repos' git history for committed `.env` values, API
   keys, the JWT secret, DB credentials. Cross-check against `.gitignore` coverage.
4. **Flutter/mobile**: confirm where JWT access/refresh tokens actually live on-device
   (`flutter_secure_storage` or equivalent vs. plain `SharedPreferences`); confirm the release
   build has code obfuscation/shrinking enabled (`--obfuscate --split-debug-info` or R8/
   ProGuard via `build.gradle.kts`); confirm no hardcoded backend URLs/secrets in
   `lib/core/api/api_config.dart` beyond what's expected; confirm biometric/PIN data genuinely
   never leaves the device (re-verify the claim already shown in the Security screen's own
   disclaimer text, added this session).
5. **Transport security**: confirm the production `DOMAIN` Caddy is actually serving HTTPS
   with a valid cert (not just configured to — check live), and that the Flutter app's base URL
   uses `https://`, not the bare Tailscale IP, for anything that isn't dev/local testing.
6. **POPIA/compliance**: read `../piggybank-backend/docs/compliance-foundation.md` in full,
   then check it against what's actually implemented — consent screens exist and are gated
   (`require_current_consents` dependency, confirmed already wired into `subscriptions_router`
   above), but verify data-export/data-deletion user rights (POPIA access/erasure rights) have
   a real implementation path, not just a policy statement.
7. Write findings to a new `docs/security-audit.md` (in `Piggybank/`, alongside the existing
   `docs/compliance-foundation.md` reference) using the same Critical/High/Medium/Low structure
   `QA_FINDINGS.md` already established — don't invent a new format.

**Verification:** N/A (investigative step). The verification is that every finding cites a
specific file/line or a reproduced command output, not a general claim.

**Exit criteria:** `docs/security-audit.md` exists with a prioritized, evidence-backed finding
list. Step 1's scope is written from this document, not guessed in advance.

---

## Step 1 — Security remediation

**Status:** Scope intentionally left open — this step's concrete task list is written from
Step 0's findings, not predicted here. **Do not skip Step 0 and start "fixing security stuff"
directly** — that's exactly the un-grounded, checklist-recited-from-memory failure mode this
plan is trying to avoid.

**Exit criteria (fixed regardless of findings):** every Critical and High finding from Step 0
is either fixed or has a written, user-acknowledged reason it's deferred (e.g. "requires a
paid WAF service, deferred to post-launch budget").

---

## Step 2 — Fix AI context gap: Insights + Chatbot see Accounts/Portfolios

**Type:** Backend (Python/FastAPI). **Model:** default.

**Context brief:** This is the single open High-severity finding from the 2026-08-28 QA pass,
carried forward unfixed. `../piggybank-backend/backend/app/chatbot/service.py`'s
`build_user_context_snapshot()` (read in full this session — lines 19–157) computes
`net_worth` as `assets_total - liabilities_total` only, pulling from the `Asset` and
`Liability` tables. It never queries `Account` balances or `Portfolio`/`Holding` values. The
Dashboard, by contrast, computes net worth as Assets + Accounts − Liabilities (per the
2026-08-28 QA finding). `backend/app/insights/service.py` almost certainly shares the same gap
— read it first; it was not read this session and may or may not reuse
`build_user_context_snapshot()` or duplicate similar logic.

**Task list:**
1. Read `backend/app/insights/service.py` in full to confirm whether it shares
   `build_user_context_snapshot()` or has its own, separately-broken copy.
2. Add `Account.balance` (or the correct field name — verify against `models.py`) summed per
   user, and Portfolio/Holding current market value (reuse whatever the Portfolio detail
   screen's own backend endpoint already computes for this — don't reimplement valuation math
   twice) into the snapshot dict.
3. Update `net_worth` calculation to match the Dashboard's formula exactly: Assets + Accounts
   + Portfolios − Liabilities (confirm the exact Dashboard formula from
   `lib/features/dashboard/` before assuming this is right — the QA note above says "Assets +
   Accounts − Liabilities" without mentioning Portfolios explicitly; resolve that ambiguity
   against the real Dashboard code, don't guess).
4. Update the system prompt / snapshot description so the model doesn't have to infer what's
   included — state explicitly in the JSON keys or an accompanying comment which balances are
   covered.
5. Backend test: extend `backend/tests/test_chatbot.py` (and `test_insights.py` if it has its
   own snapshot logic) with a fixture that has non-zero Account and Portfolio balances, and
   assert the snapshot's `net_worth` reflects them.
6. Manual re-verification: repeat the QA session's own test — ask the Chatbot "what's my net
   worth" and "does this include my investments" against the demo account, confirm the answer
   now matches the Dashboard figure and correctly claims investment inclusion.

**Verification:**
```bash
cd ../piggybank-backend/backend && python -m pytest tests/test_chatbot.py tests/test_insights.py -v
```
Manual: live chatbot/insights query against demo account, cross-checked against Dashboard's
displayed net worth for the same account at the same moment.

**Exit criteria:** Dashboard, Insights, and Chatbot all report the same net-worth figure for
the same account state. Backend tests pass. No regression in existing chatbot/insights tests.

---

## Step 3 — Chatbot/Insights persona + guardrail refinement

**Type:** Backend (Python/FastAPI), possibly a small Flutter copy change. **Model:** default.

**Depends on:** Step 2 — refining tone/persona on top of numbers that are still wrong would
ship a more confident-sounding wrong answer, which is worse than the current generic one.

**Context brief:** Current system prompt (`chat_with_ollama()` in
`../piggybank-backend/backend/app/chatbot/service.py`, lines 170–175) is four sentences with
no name, no brand voice, and no scope boundary. The 2026-08-28 QA pass explicitly logged the
chatbot answering "capital of France" using real LLM inference rather than declining — logged
as Low severity / "product decision, not a defect," meaning this plan is the first time a
product decision on it is actually being made. `docs/chatbot-design-note.md` establishes the UI
shape (conversational thread, non-streaming, Settings-entry-point, paywall-on-send) but has
**no persona direction at all** — it explicitly says design mockups "defer" the chatbot,
meaning there's no brand-voice reference to follow other than `DESIGN.md`/`PRODUCT.md`'s
general "no bank-app look, no gamification" constraints (from `piggybank-backend/CLAUDE.md`).

**Task list:**
1. **Persona decision** (ask the user, don't invent unilaterally): does the chatbot get a name/
   character (tying into the Piggybank mascot already used in Stitch assets — see
   "Piggybank mascot.jpeg" in the Stitch project), or does it stay a nameless "assistant" but
   with a sharper, more consistent voice? This is a brand decision, not a pure engineering one
   — flag it as a checkpoint before writing the new system prompt.
2. Rewrite the system prompt in `chat_with_ollama()` to: establish whatever persona was decided
   in step 1, add an explicit finance-topic guardrail (decline or redirect off-topic questions
   — write the exact decline behavior, e.g. "politely redirect to what it can help with"
   rather than a bare refusal), and keep the existing "concise, factual, plain text" instructions
   that already work well per QA.
3. Consider (discuss with user, not a given): should Insights get a different, more clinical
   tone than Chatbot's more conversational one, given they're deliberately different UX shapes
   per `docs/chatbot-design-note.md`? If so, this needs two separate prompts, not one shared
   constant.
4. Guardrail test: add a test case to `backend/tests/test_chatbot.py` asserting an off-topic
   question ("what's the capital of France") gets a redirect-style answer, not a direct one —
   this will likely need to be a live/manual check rather than a unit test, since Ollama output
   isn't deterministic; document that limitation rather than writing a flaky test.
5. Re-verify the paywall/entry-point/thread-UI decisions from `docs/chatbot-design-note.md`
   still hold — this step should not silently change UI behavior while touching the prompt.

**Verification:** Manual, live-model verification (prompt changes aren't unit-testable in the
normal sense) — a scripted set of test prompts (balance question, budget question, off-topic
question, at minimum) run against the deployed Ollama model, with transcripts logged the same
way `docs/qa/QA_LOG.md`'s Step 8 already did.

**Exit criteria:** New system prompt live, off-topic questions demonstrably redirected rather
than answered, persona decision documented in `docs/chatbot-design-note.md` (update it, don't
leave it stale).

---

## Step 4 — Small screen-polish backlog

**Type:** Flutter, client-only. **Model:** default.

**Context brief:** Not new screens — a short tail of already-known, already-logged small gaps
that don't warrant their own step each. Carried over from `QA_FINDINGS.md`'s 2026-08-28 update
and the resumed-session notes from earlier today:

**Task list:**
1. **Goals: no deadline field in Add Goal UI** despite `targetDate` being fully supported by
   the backend/model — re-confirmed still open as of 2026-08-28. Add the date field to the Add
   Goal sheet.
2. **Invest tab's "See all" link has no destination** — wire it to whatever the intended target
   screen is (check `docs/ui-ux-mockup-brief.md` §5 for what it was meant to link to; if
   ambiguous, ask rather than guessing a destination).
3. **Instrument Comparison ticker UX gap** — noted in a resumed session's carried-over blockers
   list without further detail; re-read the current `instrument_comparison_screen.dart` fresh
   to determine what specifically is missing before assuming last session's characterization is
   still accurate.
4. **Stray "Test/General" demo portfolio cleanup** — delete or retype it (blocked all prior
   attempts on backend reachability; check `tailscale status` / reach the real
   `piggybank-backend` host before attempting again).

**Verification:**
```bash
flutter analyze
flutter test
```
Manual: exercise each of the 4 fixed flows on-device against the demo account.

**Exit criteria:** All 4 items resolved or explicitly re-scoped with a written reason if one
turns out to be larger than expected.

---

## Step 5 — Payment gateway scoping conversation

**Type:** Conversation, not code. **Model:** default. **Hard gate — same pattern as the
production-completion blueprint's Step 0 (Admin): no gateway-integration code, however small,
until this step produces a written decision.**

**Context brief:** Zero payment infrastructure exists today — confirmed by grep across both
repos. Subscription upgrade is a pure DB-flag flip. This is real money, a merchant-account
signup, and (for a South African fintech-adjacent app) POPIA + card-industry compliance
obligations — it needs an explicit decision, not an engineering default. Below is neutral,
factual comparison research to bring to that conversation — **not a recommendation baked into
this plan**, since fees/features change and the actual choice depends on business factors
(existing SA bank account, expected transaction volume, whether recurring/subscription billing
specifically is needed vs. one-off charges) that only the user can weigh.

**Options to compare in the conversation** (verify current fees directly with each provider
before deciding — published rates change):
- **PayFast** — South African, widely used for SaaS/subscription billing specifically, simple
  hosted-checkout integration, supports recurring billing tokens.
- **Paystack** — pan-African (Stripe-owned), modern REST API and docs, expanding SA support,
  supports subscriptions.
- **Peach Payments** — South African, used by several SA fintechs at larger scale, stronger
  recurring-billing and multi-currency support, historically more enterprise-oriented
  onboarding.
- **Ozow** — South African instant-EFT (bank-to-bank), typically lower or flat fees vs.
  card-based providers, but instant EFT does not naturally support *recurring/subscription*
  billing the way a saved card token does — worth flagging as a potential mismatch for a
  monthly-subscription product specifically.
- **Yoco** — South African, historically POS/in-person-focused with online payments added
  later — worth confirming current online-subscription support before considering seriously.

**Task list:**
1. Confirm with the user: is Free/Pro subscription billing (recurring monthly) the only
   near-term use case, or is one-off payment (e.g. paying an advisor, in-app purchases) also
   planned? This changes which providers fit.
2. Confirm whether the user already banks with an institution that has a preferred/discounted
   gateway partnership (common in SA) before treating this as a cold comparison.
3. For the top 2 candidates from the conversation, verify **current** published fee structures
   and recurring-billing support directly (rates in this plan are directional, not to be
   treated as current — verify before committing).
4. Write the decision, chosen provider, fee structure, and rationale to
   `docs/payment-gateway-scope.md`.
5. Confirm compliance posture: does the chosen provider's SDK/API introduce new PCI-DSS scope
   for the backend (hosted-checkout / tokenization keeps scope minimal; anything that touches
   raw card numbers server-side does not) — this should be a deciding factor, not an
   afterthought.

**Verification:** N/A.

**Exit criteria:** `docs/payment-gateway-scope.md` exists with a concrete chosen provider,
verified current fee structure, and PCI-scope assessment. Step 6 is planned from this document.

---

## Step 6 — Payment gateway integration

**Status:** Scope intentionally left open — written from Step 5's decision, not predicted here.
Expect this to need both backend work (webhook handler for payment confirmation, replacing the
current pure-DB-flag `upgrade()`/`cancel()` with real charge-then-confirm flow, secrets
management for the provider's API keys) and a small Flutter change (hosted checkout WebView or
redirect flow from the existing `subscription_screen.dart` Upgrade button).

**Exit criteria (fixed regardless of provider chosen):** a real charge can be made and
confirmed end-to-end in the provider's sandbox/test mode; `subscriptions_router.upgrade()` no
longer grants PRO tier without a confirmed payment; a webhook or polling mechanism handles
subscription renewal/expiry without requiring the user to reopen the app on the exact day it
lapses; secrets (API keys) are not committed to either repo (verify against Step 0's secrets-
hygiene finding).

---

## Notes for whoever executes this plan

- This plan assumes `plans/piggybank-production-completion.md` and
  `plans/piggybank-full-suite-qa.md` are both still fully done (15/15 and 10/10 respectively) —
  re-verify their status markers before trusting this plan's "current-state summary" if a long
  gap has passed since 2026-08-30.
- Steps 1 and 6 are deliberately left without a concrete task list — writing one now, before
  Step 0/Step 5 produce real findings/decisions, would be exactly the un-grounded planning this
  blueprint is trying to avoid (see the production-completion blueprint's own adversarial-review
  history for why that matters: 6 critical issues came from planning ahead of verified facts).
- No adversarial (Opus-tier) review sub-agent was run against this draft — flagging that
  honestly rather than claiming a review that didn't happen. Recommend running one before
  executing Step 1 or Step 6 specifically, since those are the two steps most likely to grow
  once their gating step's findings are in.
