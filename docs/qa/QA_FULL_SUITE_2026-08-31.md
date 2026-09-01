# Piggybank Full-Suite QA Report (2026-08-31 → 2026-09-01)

Consolidated findings from `plans/piggybank-full-suite-qa-v2.md`'s Steps 0–4: Tailscale-only
network lockdown, automated regression baseline, API performance & error-response audit,
database integrity audit, and a full-app exploratory screen-by-screen walkthrough (including a
live-verified CSV import flow and TFSA/Retirement Annuity ledgers). This report is written to be
handed directly to a **new, separate fix-it blueprint** — every entry below has a reproduction
path, a severity with justification, and its originating step. It does not re-run or duplicate
`docs/qa/QA_LOG.md` / the 2026-08-28 `QA_FINDINGS.md` update's already-closed work.

---

## Top-line summary

**18 findings** across four severity tiers, **0 Critical**, plus a substantial "confirmed
working" list — most of the app is clean.

| Severity | Count | Theme |
| --- | --- | --- |
| Critical | 0 | — |
| High | 6 | AI/chatbot cost-abuse surface, wrong currency symbol, portfolio P&L seed-data bug, silent import-error UI, unbounded client network calls |
| Medium | 6 | Import UX gaps, income-colour inconsistency, a real widget-test regression |
| Low | 6 | Cosmetic/formatting issues, a stale DNS record, seed-data date staleness |

**Clean domains** (opened, exercised, zero findings): Dashboard, Accounts, Assets, Liabilities,
both Calculators tabs, Goals, Expenses, Privacy & consent, Security, Appearance, Subscription
polish, Notifications, Instrument Comparison's Correlation-tab gating, general CRUD error paths,
and — after this session's live unlock — **both the TFSA and Retirement Annuity ledgers**.

**Needs the most attention:** the AI/chatbot surface (4 of the 6 High findings touch it directly
or indirectly — wrong currency, an unauthenticated inference endpoint with no rate limit, an
inverted topic guardrail, and no client-side request timeout) and the CSV import wizard (1 High,
2 Medium findings — a silent failure UI, a status that doesn't reflect account-assignment
outcome, and category-overwrite behaviour).

---

## Critical

None found across any of Steps 0–4.

---

## High

### H1. Portfolio holdings' cost-basis is stored as total invested, not per-unit — 60x-overstated unrealized losses
**Found in:** Step 3 (DB query) and Step 4 (live UI, finding 1).
**Repro:** `SELECT symbol, quantity, cost_basis FROM holdings WHERE portfolio_id = '<demo portfolio>'` — dividing `cost_basis` by `quantity` yields plausible real per-share prices (e.g. NPN.JO: 64000/20 = R3 200, in Naspers' real range). But `backend/app/portfolios/router.py` (lines 546, 749, 814–815, 1207–1208, 1249) treats `cost_basis` as already-per-unit and multiplies by `quantity` again. Live in the app: Invest tab shows Total value R90 103,88 against **-R5 391 896,12 unrealized P&L**.
**Severity justification:** High — cosmetically alarming and would erode trust in the whole Invest section for any account seeded this way, but it is a **seed-data defect, not an app calculation bug** (the math is exactly correct given its input). Downgraded from Critical because zero risk to real (non-seeded) users and a one-file seed-script fix.
**Fix-it recommendation:** correct the seed script's cost-basis-per-unit values; do not touch the P&L formula.

### H2. Chatbot quotes net worth in `$` (USD) instead of `R`/ZAR
**Found in:** Step 2 (`POST /api/chatbot/chat`, 10.2s, curl).
**Repro:** `curl -X POST /api/chatbot/chat` with a net-worth question on the demo account → correct real account data, wrong currency symbol in the response text.
**Severity justification:** High — a South African app quoting a South African user's own money in the wrong currency symbol is a visible, credibility-damaging bug, not cosmetic. Not previously logged.

### H3. `POST /ai/chat` requires no authentication and triggers real LLM inference, with no rate limiting
**Found in:** Step 2 (findings 3 and 4, combined here — same endpoint, compounding).
**Repro:** `curl -X POST http://100.121.165.7:8000/ai/chat -d '{...}'` with and without an `Authorization` header → identical 200 responses either way, 3.3s latency (real inference). `grep -r "@limiter.limit" backend/app/routes/ai.py backend/app/routes/chat.py backend/app/ai/routes.py backend/app/chatbot/router.py` → zero matches, vs. sane limits everywhere else in the backend (auth login `5/minute`, etc.).
**Severity justification:** High — an unauthenticated endpoint that costs 3+ seconds of real LLM inference per call, reachable by anyone on the tailnet (not just app users), with no request cap, is a live cost/abuse surface today, not a theoretical one.
**Note:** this is a *separate* implementation from the authenticated `POST /api/chatbot/chat` (H2) — same product surface, two different code paths with very different maturity. See H4 for the likely client-side consequence of this split.

### H4. Settings → AI Assistant ("Penny") chatbot guardrail is inverted — answers off-topic questions, refuses on-topic ones
**Found in:** Step 4 (finding 9, live-confirmed).
**Repro:** Settings → AI Assistant → ask "What is the capital of France" → answered directly, no redirect. Ask "Am I on track with my budget?" (one of the screen's own three suggested-question chips) → refused with "I can only help with questions about your finances here in Piggybank...". Reproducible 2/2 finance questions deflected, 1/1 off-topic answered.
**Severity justification:** High — the exact opposite of the intended guardrail is visible on a headline app feature, reachable in two taps from Settings.
**Root-cause hypothesis (not yet source-verified):** the symptom profile — answers everything generically, refuses anything requiring real account grounding — matches H3's separate, unauthenticated `/ai/chat` exactly (no account context, no guardrail, generic textbook answers), not the properly-wired `/api/chatbot/chat`. Likely the Settings screen is calling the wrong endpoint. **Confirm by grepping `lib/features/chatbot/` and `lib/features/settings/` for the base URL/path used before treating this as fact in a fix-it blueprint** — flagged, not yet done.

### H5. CSV import wizard's failure UI shows zero diagnostic detail, though the backend already computes it
**Found in:** Step 4 (finding 20, live-confirmed via UI + direct API comparison).
**Repro:** Import a CSV missing the `type`/`category` columns the generic parser requires → app shows only "Imported: 0 / 2", "Failed rows: 2", no reason. Same file via `POST /api/imports/` directly → `error_message: "[{\"row\": 2, \"error\": \"row 2: invalid type ''\"}, {\"row\": 3, \"error\": \"row 3: invalid type ''\"}]"` (`backend/app/imports/router.py`'s `_parse_row`, lines 121–158).
**Severity justification:** High — a real user whose bank-statement CSV fails import has no way to learn what to fix; the fix is entirely UI-side (surface the already-returned `error_message`), making this both high-impact and cheap to close.

### H6. Dio HTTP client has no request timeout configured anywhere
**Found in:** Step 2 (finding 5).
**Repro:** `grep -rn "connectTimeout\|receiveTimeout\|sendTimeout" lib/core/api/api_client.dart` → no matches; `Dio(BaseOptions(baseUrl: baseUrl))` is constructed with nothing else set, and Dio's default when unset is unlimited.
**Severity justification:** High — a stalled connection (bad mobile network, backend hang) leaves the app waiting indefinitely with no client-side timeout ever firing; the backend's own `OLLAMA_TIMEOUT_SECONDS` (120s default) is server-side only and doesn't protect the client. Not fixed here — needs a considered value given the AI endpoints' legitimate 10–26s+ response times, not a blind short timeout.

---

## Medium

### M1. Full Transactions list never colours income green (Dashboard preview does)
**Found in:** Step 4 (finding 10, live-confirmed).
**Repro:** Dashboard's Recent-transactions preview shows "Test import consulting fee" (R500, income) in green. Transactions screen, All/Income tabs, same row: plain black bold, identical styling to expenses.
**Severity justification:** Medium — visible inconsistency for the same data between two screens, no functional impact.

### M2. CSV import silently orphans transactions when "No account" (the default) is left selected, with no warning
**Found in:** Step 3 (finding 2, 2 orphaned `account_id IS NULL` rows) + Step 4 (findings 13 and 23, root-caused).
**Repro:** Import a CSV via the wizard's Configure step with Account left at its default "No account" → import correctly reports `status: "completed"` / a green "COMPLETED" chip, but the resulting transactions have `account_id: NULL` and never appear against any account. Confirmed via direct API test (`POST /api/imports/?account_id=<uuid>` correctly assigns `account_id`/`account_name` when specified — the mechanism works, the UX doesn't guide the user to it).
**Severity justification:** Medium — not a data-corruption bug (the FK is nullable by design) and the underlying mechanism works correctly when used, but "No account" being the unlabelled default with a "COMPLETED" status that gives no hint anything is unlinked is a real trap for a real user.
**Fix-it recommendation:** make account selection a more deliberate choice (e.g. a confirmation step, or a warning banner on the Review step when no account is set) rather than a silent default.

### M3. CSV import auto-categorization overwrites the CSV's own supplied category
**Found in:** Step 4 (finding 24, live-confirmed).
**Repro:** Import a CSV with `category: "Groceries"` on an expense row and `category: "Salary"` on an income row via `POST /api/imports/` → both rows saved with `category: "Freelance"` instead, `auto_categorized_rows: 2` in the response confirming the categorizer ran and replaced both.
**Severity justification:** Medium — silently discards user/bank-supplied data with an unrelated default; worth checking whether the categorizer should only fill *blank* categories or is meant to always override (and is simply picking the wrong bucket).

### M4. Compare Instruments' ticker-autocomplete dropdown triggers a debug-mode layout overflow
**Found in:** Step 4 (finding 21, live-confirmed).
**Repro:** Invest tab → Compare instruments icon → type a ticker (e.g. "GLD") with the keyboard open → the suggestions dropdown triggers a `RenderFlex` overflow banner ("BOTTOM OVERFLOWED BY 166 PIXELS", persisting at 1.9px even after a ticker chip is added and the list closes).
**Severity justification:** Medium — debug-build-only banner, doesn't crash or block the flow (ticker selection still works), but indicates a real unbounded-height layout under keyboard+dropdown that deserves a release-mode check.

### M5. `flutter test` regression: LoginScreen widget test fails, unrelated to network config
**Found in:** Step 1.
**Repro:** `flutter test test/widget_test.dart` → *"LoginScreen renders email/password fields and a submit button"*: `Found 0 widgets with type "TextField" that are ancestors of widgets with text "Email"`.
**Severity justification:** Medium — a genuine widget-tree assertion failure (not a stale-test artifact like the sibling failure resolved below), but not diagnosed further within Step 1's 15-minute-per-failure budget. Full stack trace captured in that step's run log for whoever picks this up.

### M6. Two AI endpoints format currency inconsistently with each other and with the rest of the app
**Found in:** Step 2 (finding 3, `$` vs `R` symbol between `chatbot/chat` and `ai/insights`) + Step 4 (finding 11, US comma-decimal grouping vs SA space-thousands convention in Insights' own live-asked answers, reproduced on a saved 2026-08-28 past insight too, so not a one-off).
**Repro:** Ask Insights "What is my net worth?" → "Your net worth is R 1,808,030.50" (US grouping). Same figure everywhere else in the app (Dashboard, Accounts, Budgets, Goals): "R 1 808 030,50" (SA convention). Separately, `chatbot/chat`'s net-worth answer uses `$` instead of either.
**Severity justification:** Medium — three different currency-formatting behaviours across two AI endpoints and the rest of the app is confusing but not functionally broken (the numeric value itself is correct everywhere, confirmed by cross-check).

---

## Low

### L1. Budgets screen shows an empty state for the current month — demo data only covers May 2026
**Found in:** Step 4 (finding 12, live-confirmed).
**Repro:** Open Budgets on 2026-09-01 (today) → "No budgets for this month" for September, August, and June 2026. Navigate back to May 2026 → all 6 budget categories render correctly (progress bars, over/under-budget states all correct).
**Severity justification:** Low — data/seeding issue, not an app defect; a real cosmetic/sales problem for anyone doing a live demo walkthrough. Fix-it recommendation: re-seed demo data with rolling/relative dates instead of fixed 2026 months.

### L2. Compare Instruments chart has an overlapping Y-axis top label
**Found in:** Step 4 (finding 22, live-confirmed).
**Repro:** Compare instruments → add GLD, 1-year view → the exact max value label ("41,2") renders directly on top of the rounded gridline label ("40").
**Severity justification:** Low — purely cosmetic, both values remain partially legible.

### L3. Stale public DNS record for `piggybank.fynboscreative.co.za`
**Found in:** Step 0 (Task 8 investigation).
**Repro:** DNS resolves `piggybank.fynboscreative.co.za` → `102.214.9.185`, but that VPS's live Caddy config (confirmed via its own admin API at `localhost:2019/config/`) has no route for that hostname, and an HTTPS request with that SNI fails the TLS handshake outright (no cert configured). The Piggybank host (`100.121.165.7`) was always the real, sole server.
**Severity justification:** Low — doesn't affect the currently-Tailscale-only app (which uses the IP directly), but will need correcting before any future public-HTTPS relaunch, or it will silently misdirect real users. Out of this plan's scope to fix, flagged for the DNS owner.

### L4. Tapping an account row on the Accounts screen opens Edit mode directly, not a read-only detail/transaction view
**Found in:** Step 4 (finding 2).
**Repro:** Accounts screen → tap any account row → lands in "Edit Account" mode immediately.
**Severity justification:** Low — may be intentional given accounts are simple and transactions are filtered separately elsewhere; flagged as a product-owner judgment call, not logged as a defect.

### L5. `flutter analyze`: 41 info-level lints, +4 vs. the 2026-08-28 baseline of 37
**Found in:** Step 1.
**Repro:** `flutter analyze` full output — all `info`-level (const-constructor suggestions, tearoffs, key params, EOL), zero new warnings or errors.
**Severity justification:** Low — trivial drift, not investigated further per this step's logging-only scope.

### L6. `docs/admin-scope.md` describes an Admin feature with no corresponding client screen
**Found in:** Step 2 (finding 1, `POST /api/admin/refresh-prices` orphaned backend route) + Step 4 (finding 19, confirmed via `find`: no `lib/features/admin/` directory exists).
**Severity justification:** Low — a documented-but-unbuilt feature, not a defect in what exists; listed for completeness since Step 4's walk list explicitly checked for it.

---

## Confirmed working / false alarms on re-check

These were either suspected issues going into Steps 0–4, or areas a prior QA pass left
unconfirmed, and are now positively confirmed clean — listed so a fix-it blueprint doesn't
re-investigate them from scratch.

- **`subscription_api_test.dart`'s Step 1 failure is RESOLVED, not open.** It failed because it expected the Tailscale-IP base URL while `api_config.dart` still defaulted to the public domain; Step 0 Task 9 reverted the default to the Tailscale IP, and the test was re-run and confirmed 4/4 green the same session. Do not re-list this as an open failure.
- **TFSA and Retirement Annuity ledger screens work correctly.** Previously verified only by static code review, never live. This session unlocked them (they're gated on **portfolio type**, not account type as originally assumed — `lib/features/portfolios/screens/portfolio_detail_screen.dart`'s `AppBar.actions`) by creating two new demo portfolios, then live-verified both: TFSA shows correct lifetime/per-tax-year contribution figures and a working growth projection; RA shows the correct empty state with the annual limit intact. No defects on either screen.
- **CSV import correctly assigns `account_id` to transactions when one is specified at upload time.** Direct API test (`POST /api/imports/?account_id=<uuid>`) confirms both `account_id` and `account_name` come back populated on the created transactions. The mechanism works — see M2 for the UX gap when it's *not* specified.
- **AI net-worth parity holds across Dashboard, Insights, and Chatbot** — same account, same moment, same numeric value (R1 808 030,50) everywhere, confirmed live. Only the *formatting* differs (M6), not the underlying number.
- **General CRUD error paths are clean across the board**: invalid/expired JWT → `401`; no auth header → `401`; not-found id → `404` with a sensible message; missing required fields → `422` with a precise per-field list; malformed JSON → `422`; duplicate-email registration → `409`. No leaky internals, no stack traces, on every path tested.
- **Rate limiting is present and reasonably tuned everywhere except the AI/chatbot surface** (see H3) — auth login `5/minute`, destructive bulk-delete `3/hour`, general CRUD `20–60/minute`.
- **Database integrity is otherwise clean**: `alembic_version` matches the latest migration file (no pending migration), zero dangling `user_id` rows across `goals`/`assets`/`liabilities`, no implausible transaction dates, single-portfolio invariant held (until this session's deliberate TFSA/RA unlock, documented above, not a regression).
- **PayFast ITN webhook confirmation being unreachable is an accepted, deliberate consequence of the Tailscale-only lockdown (Step 0), not a bug** — the user was told explicitly and agreed to proceed. Do not log this as a newly-found defect in any fix-it blueprint.
- **The `paymenttransactionstatus` enum migration crash-loop is fully fixed, not a latent risk.** Step 3's DB log sweep found a real 46-minute incident on 2026-08-31 (`db` container logs repeating `ERROR: type "paymenttransactionstatus" already exists` roughly every 61s). Cross-checking the migration source directly (rather than relying on Step 3's characterization) shows commit `6585c6c` ("Fix payment_transactions migration double-creating its own enum type", 2026-08-31 19:04:55 — minutes before the incident's own end timestamp) already replaced the unguarded `CREATE TYPE` with a `DO $$ ... EXCEPTION WHEN duplicate_object` guard and `create_type=False` on the column definition. **Do not re-open this as a fix-it item** — it was closed same-day, before this report was even written.
- **Dashboard, Accounts, Assets, Liabilities, both Calculators tabs, Goals, Expenses, and every Settings sub-screen except AI Assistant (Privacy & consent, Security, Appearance, Subscription, Import history's entry rendering, Notifications)** — opened and exercised with zero findings across all three Step 4 sessions.

---

## Methodology notes and caveats

- **Data-integrity caveat on Step 4's live testing.** While testing the CSV import success path via a direct API call, a cleanup `DELETE` pass accidentally included one pre-existing transaction (`d1a78d20…`, "Test import Woolworths" — one of Step 3's original two orphaned rows referenced in M2) alongside the two new QA test rows it was meant to remove. It was immediately recreated with matching date/amount/category/description, restoring the demo account's total transaction count to the pre-mutation baseline of 75. However the recreated row has a **new UUID, a new `created_at`, and `source: "manual"` instead of the original `source: "csv_import"`** — an exact row-level diff against Step 3's original snapshot (as opposed to a count-level check) will show this one row as changed. Not a product bug; a testing-methodology artifact, documented here so it isn't mistaken for a new finding.
- **Row-count snapshot** established by Step 3 for contamination-checking Steps 2/4: `accounts=3, transactions=75, portfolios=1, holdings=5, goals=3, assets=6, liabilities=3, budgets=16`. Portfolio count is now intentionally 3 (see TFSA/RA confirmation above) as of this session's end.
- Every finding above cites its originating step (0–4) and either a curl command, a SQL query, an exact tap sequence, or a file/line reference — no paraphrased "tests passed"/"looks fine" claims per this plan's own verification requirement.
