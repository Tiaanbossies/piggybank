# Piggybank Full-Suite QA & Test Coverage Blueprint

**Objective:** Test the app end-to-end across every domain from Transactions
through the AI features (Insights + Chatbot), using dispatched agents, with
TDD-style unit/widget tests backing every domain plus an exploratory pass
against the live demo account. Log all findings, data, and issues for review.

**Mode:** Direct (no git remote configured on this repo, no `gh` available —
confirmed via pre-flight check on 2026-08-26). Work happens as commits on
`master` directly, one commit per step, no branches/PRs.

**Status as of this plan's creation (2026-08-26):** The 9-step production
blueprint (`plans/piggybank-production-completion.md`) is fully done — all
features including Insights (Step 7) and Chatbot (Step 8) are built and
`AI_FEATURES_ENABLED=true` on the deployed backend. This plan is a pure
testing/QA initiative on top of a feature-complete app, **not** further
feature work. Current automated test coverage is thin: 15 test files, all in
`test/core/` and one `test/features/expenses/` file — zero tests exist for
transactions, accounts, budgets, goals, assets, liabilities, portfolios,
imports, chatbot, insights, or dashboard.

**Known pre-existing facts that steps below must not rediscover from scratch:**
- The demo account (`demo@financeapp.co.za` / `Demo@1234!` on `100.121.165.7`)
  is free-tier — **Insights is Pro-gated**, so Step 8 (exploratory pass) must
  upgrade its subscription tier first or it cannot screenshot/exercise
  Insights at all. See `piggybank_demo_account` memory.
- The Transactions "always empty" bug is **already fixed** (2026-08-25) — root
  cause was a `FutureProvider` used as a side-effect trigger watched via
  `ref.watch` during widget build instead of `ref.listen` in a
  `StateNotifier`'s own constructor. Step 1 below must add a **regression
  test** for this exact shape, and every other domain step should grep its
  own providers for the same anti-pattern (a `FutureProvider` whose body only
  mutates another provider's state) rather than assuming it's isolated to
  Transactions.
- No `integration_test` package is configured and no device/emulator is
  assumed to be attached during automated steps — all steps 1-7 are
  `flutter test` (unit + widget, using `mocktail` to fake the API layer and
  `ProviderScope` overrides), runnable headless. Only Step 8 requires a
  running device/emulator, and is scoped separately for that reason.

---

## Dependency Graph

```
Step 0 (test harness) ──┬─→ Step 1 (Transactions)      ──┐
                         ├─→ Step 2 (Accounts + Budgets) ──┤
                         ├─→ Step 3 (Goals+Assets+Liab.)  ──┤
                         ├─→ Step 4 (Portfolios/TFSA/RA + Calc) ──┤
                         ├─→ Step 5 (Imports)             ──┼─→ Step 8 (exploratory, device) ─→ Step 9 (final report)
                         ├─→ Step 6 (Chatbot)             ──┤
                         └─→ Step 7 (Insights + Dashboard/Settings) ──┘
```

Steps 1–7 have no shared files (each touches only its own `lib/features/<x>/`
and `test/features/<x>/`) and can run **in parallel** once Step 0's shared
harness exists. Step 8 needs all of them done (it's exercising the whole app
in order). Step 9 aggregates everything.

---

## Step 0 — Shared test harness

**Type:** Test infra. **Model:** default. **Depends on:** nothing.

**Context brief:** `pubspec.yaml` already has `mocktail: ^1.0.4` in
`dev_dependencies` — no new package dependency needed. There is no shared
helper today for faking the API client or wrapping widgets in an overridden
`ProviderScope`; every future feature-test step needs the same two things, so
build them once here rather than duplicating per-step.

**Task list:**
1. Create `test/test_helpers/fake_api_client.dart` — a `mocktail`-based fake
   implementing whatever interface `lib/core/api/` exposes (check
   `lib/core/api/api_client.dart` for the actual class/method shape before
   assuming), with helpers to stub success/error responses per endpoint.
2. Create `test/test_helpers/pump_app.dart` — a `pumpApp(WidgetTester, {overrides})`
   helper that wraps a widget in `ProviderScope(overrides: ...)` +
   `MaterialApp`, matching this app's actual theme setup
   (`lib/core/theme/`) so widget layout tests aren't fighting missing
   `Directionality`/`MediaQuery` boilerplate.
3. Create `docs/qa/QA_LOG.md` — the running log file every subsequent step
   appends to (data used, notes, issues found, exact prompts/repro steps).
   Seed it with a header and this plan's link.
4. Run `flutter analyze` and `flutter test` to confirm the existing 15 tests
   still pass unmodified (baseline, nothing broken by adding the helpers).

**Verification:**
```
flutter analyze
flutter test
```
Both clean; existing test count unchanged (no accidental deletions).

**Exit criteria:** `test/test_helpers/fake_api_client.dart` and
`test/test_helpers/pump_app.dart` exist and are used successfully by at least
one throwaway smoke test in this step (delete the smoke test before
committing, or fold it into Step 1). `docs/qa/QA_LOG.md` exists.

**Rollback:** Delete the two new helper files and the log; no other code touched.

---

## Step 1 — Transactions domain tests

**Type:** Flutter unit + widget tests. **Model:** default. **Depends on:** Step 0.

**Context brief:** `lib/features/transactions/` has 4 files: `data/transactions_api.dart`,
`models/transaction.dart`, `providers/transactions_provider.dart`,
`screens/transactions_screen.dart`. This domain has zero tests today, and it's
the one with the recently-fixed side-effect bug (see plan header) — the
regression test for that bug is this step's highest-priority item.

**Task list:**
1. `test/features/transactions/transaction_model_test.dart` — `fromJson`/
   `toJson` round-trip, edge cases (zero amount, missing optional fields like
   notes/merchant, each transaction type: income/expense/transfer).
2. `test/features/transactions/transactions_provider_test.dart` — using the
   Step 0 fake API client: list loads correctly, create/edit/delete mutate
   state as expected, error path (API failure surfaces as `AsyncError`, not
   silently swallowed). **Regression test**: assert that a provider driving
   `accumulatedTransactionsProvider` uses `ref.listen`/constructor-time sync,
   not a widget-build-time `ref.watch` on a side-effecting `FutureProvider` —
   write this as a test that would have failed before the 2026-08-25 fix
   (e.g., pump the screen, assert the transaction list is non-empty and
   matches the fake API's seeded data, not stuck at `[]`).
3. `test/features/transactions/transactions_screen_test.dart` — widget tests:
   list renders grouped by date, type filter chips (Income/Expense/Transfer)
   actually filter the visible list, empty state renders when the fake API
   returns zero transactions (and does NOT render when it returns data —
   this exact assertion is what would have caught the original bug), pull-to-refresh
   triggers a refetch.
4. Note in `docs/qa/QA_LOG.md`: confirm whether account/date-range/category
   filter UI (flagged as missing in `QA_FINDINGS.md` from 2026-08-21) has
   since been built — check `transactions_screen.dart` directly rather than
   trusting the stale doc, and log the current true state either way.

**Verification:**
```
flutter test test/features/transactions/
flutter analyze
```

**Exit criteria:** 3 new test files, all passing, including one test that
explicitly encodes the previously-fixed side-effect bug as a regression
guard. `QA_LOG.md` updated with the filter-UI status finding.

**Rollback:** Delete the 3 test files; no `lib/` changes in this step unless
a genuinely new bug is found (see "if you find a bug" note at the bottom).

---

## Step 2 — Accounts + Budgets domain tests

**Type:** Flutter unit + widget tests. **Model:** default. **Depends on:** Step 0.

**Context brief:** Two domains bundled because both are small, both are
CRUD-shaped, and per `QA_FINDINGS.md` (2026-08-21, verify currency before
trusting) Accounts was missing an edit screen and Budgets was reported fully
functional with hierarchy (sub-category budgets). Re-verify both claims
against current code rather than assuming the 5-day-old doc is still accurate.

**Task list:**
1. `test/features/accounts/` — model round-trip, provider CRUD + deactivate/
   restore toggle (the Phase 2 mutation provider), widget test for
   active/inactive list rendering and running balance.
2. `test/features/budgets/` — model round-trip, provider CRUD, month-picker
   navigation state, progress-bar color logic (green on-track vs. red
   over-budget — this is a pure function worth a focused unit test), sub-category
   indentation/hierarchy rendering.
3. Log in `QA_LOG.md`: does an Accounts edit screen exist now or not (Tier 1
   gap from the stale audit)? Any other discrepancy between what
   `QA_FINDINGS.md` claims and what the code actually does.

**Verification:** `flutter test test/features/accounts/ test/features/budgets/`, `flutter analyze`

**Exit criteria:** Both domains have model + provider + at least one widget
test each, all passing. Discrepancy log entries written regardless of outcome.

**Rollback:** Delete the new test files.

---

## Step 3 — Goals, Assets, Liabilities domain tests

**Type:** Flutter unit + widget tests. **Model:** default. **Depends on:** Step 0.

**Context brief:** Three small CRUD domains bundled together. Liabilities has
the more interesting logic here — the "smart toggle" between simple
outstanding-amount entry and full loan-detail entry (rate/term/start date →
auto-computed balance via `lib/core/calc/loan_calc.dart`, which already has a
unit test at `test/core/calc/loan_calc_test.dart` — reuse/extend that rather
than re-deriving loan math tests inside the liabilities test file).

**Task list:**
1. `test/features/goals/` — model, provider CRUD, progress-bar percentage
   calculation (saved/target).
2. `test/features/assets/` — model, provider CRUD, type-picker coverage
   (Cash/Savings/Property/Vehicle/Investment/Retirement/Other — verify all
   are actually still handled in the picker widget, one parametrized test
   for the enum-to-UI mapping is enough).
3. `test/features/liabilities/` — model, provider CRUD, smart-toggle test:
   simple mode computes outstanding correctly, loan-detail mode calls into
   `lib/core/calc/loan_calc.dart` correctly (don't re-test the math itself,
   just that the liability screen wires the inputs/outputs correctly).
4. Log in `QA_LOG.md` any gap between current code and the stale
   `QA_FINDINGS.md` claims for these three domains (e.g. payment-history
   screen status).

**Verification:** `flutter test test/features/goals/ test/features/assets/ test/features/liabilities/`, `flutter analyze`

**Exit criteria:** All three domains covered, all passing, log entries written.

**Rollback:** Delete the new test files.

---

## Step 4 — Portfolios/TFSA/RA + Calculators domain tests

**Type:** Flutter unit + widget tests. **Model:** default. **Depends on:** Step 0.

**Context brief:** Per `QA_FINDINGS.md`, Portfolios (Phase 4) was UI-complete
but backend-untested as of 2026-08-21 — that was before the backend fork/deploy
work in later sessions, so backend connectivity should now actually work; this
step's job is to prove that with real tests, not just re-read the stale claim.
Ticker search uses live data (a Plankton MCP-backed endpoint per the doc) —
mock that at the API-client boundary like everything else, don't hit live
ticker data from a unit test.

**Task list:**
1. `test/features/portfolios/` — model round-trips (portfolio, holding,
   dividend, trade), provider CRUD for holdings/dividends/trades, TFSA/RA
   contribution ledger read-only rendering, paywall UI test (renders when the
   fake API reports the user has hit their subscription limit, doesn't render
   otherwise).
2. `test/features/calculators/` — Loan Calculator and Loan Accelerator: these
   likely already have most math covered by `test/core/calc/`
   (`loan_calc_test.dart`, `growth_projection_test.dart`) — this step's tests
   should focus on the screen wiring (input validation, output display), not
   re-deriving math already tested at the `core/calc` layer.
3. Log in `QA_LOG.md`: confirm current real state of "backend connectivity
   untested" for Portfolios — does it actually work against the fake API
   contract, and (if a device is available by Step 8) does it work against
   the real deployed backend too.

**Verification:** `flutter test test/features/portfolios/ test/features/calculators/`, `flutter analyze`

**Exit criteria:** Both domains covered, all passing, log entry on Portfolios'
real backend-connectivity status.

**Rollback:** Delete the new test files.

---

## Step 5 — Imports wizard tests

**Type:** Flutter unit + widget tests. **Model:** default. **Depends on:** Step 0.

**Context brief:** `lib/features/imports/` has 5 files — this is a multi-step
wizard (per the Batch 4 Stitch design work referenced in memory: file
selection → column mapping → preview/confirm). This is the most stateful of
the untested domains (a wizard has step-transition logic, not just CRUD), so
give it more attention than the other bundled steps.

**Task list:**
1. Read `lib/features/imports/*` fully first (don't assume the exact step
   names/shape — verify against the real code) to scope what actually needs
   testing.
2. `test/features/imports/` — wizard step-transition tests (forward/back
   navigation preserves state, can't skip ahead of an incomplete step),
   file-parsing/column-mapping logic as pure-function unit tests where
   possible (separate from widget tests), error handling for malformed/empty
   import files, final confirm step correctly calls the create-transactions
   API in bulk (mocked).
3. Log in `QA_LOG.md`: this domain was flagged in `QA_FINDINGS.md` as "Phase 5,
   not started" as of 2026-08-21 but per the production-completion blueprint
   it's since been built — confirm and log the real current scope (does it
   support CSV only, or OCR too, per the "No CSV/OCR import" known-limitation
   note in the stale doc).

**Verification:** `flutter test test/features/imports/`, `flutter analyze`

**Exit criteria:** Wizard state-transition tests and at least one parsing/mapping
unit test exist and pass. Log entry on actual current import capability scope.

**Rollback:** Delete the new test files.

---

## Step 6 — Chatbot tests

**Type:** Flutter unit + widget tests. **Model:** default. **Depends on:** Step 0.

**Context brief:** `lib/features/chatbot/` (4 files) is an AI feature gated by
`AI_FEATURES_ENABLED=true` on the backend (confirmed on, per production-completion
plan Step 6). The chat UI talks to a backend endpoint that proxies Ollama —
this step mocks that endpoint like any other API call; it does not need Ollama
running locally.

**Task list:**
1. Read `lib/features/chatbot/*` fully to scope the actual message/provider
   shape before writing tests.
2. `test/features/chatbot/` — model tests (message round-trip, role/sender
   distinction), provider tests (send message → optimistic UI update →
   response replaces/appends correctly, error path when the backend returns
   an error or times out — chat UIs commonly swallow this, verify it
   surfaces visibly), widget tests (message list renders in order, input box
   clears after send, loading/typing indicator state).
3. Log in `QA_LOG.md`: any subscription-tier gating on Chatbot (mirroring
   Insights' Pro-gate) — check the code, don't assume symmetry with Insights.

**Verification:** `flutter test test/features/chatbot/`, `flutter analyze`

**Exit criteria:** Model/provider/widget tests exist and pass, including an
explicit error-path test. Log entry on Chatbot's gating status.

**Rollback:** Delete the new test files.

---

## Step 7 — Insights, Dashboard, Settings tests

**Type:** Flutter unit + widget tests. **Model:** default. **Depends on:** Step 0.

**Context brief:** Insights (4 files) is the other AI feature, and per memory
is Pro-gated on the free tier — this step must test **both** the paywall path
(free-tier user sees the gate, per `QA_FINDINGS.md`'s and the demo-account
memory's confirmation this is real, current, intended behavior) and the
unlocked path (Pro-tier user sees actual charts), using the fake API to
simulate both tiers rather than needing a real Pro account. Dashboard (1 file)
and Settings are bundled in because they're both small and this keeps the
parallel step count reasonable.

**Task list:**
1. Read `lib/features/insights/*` fully to scope what's actually rendered
   (net-worth chart, expense trends, savings rate, budget-vs-actual — per
   Step 7 of the production-completion plan) before writing tests.
2. `test/features/insights/` — paywall-gate widget test (free tier → gate
   shown, no chart calls made), unlocked-tier widget test (chart data
   renders), model tests for whatever insights payload shape the backend
   returns.
3. `test/features/dashboard/` — net-worth hero, cashflow strip, progress
   block (goal-or-budget fallback logic — verify which one shows when both
   exist vs. neither), recent-transactions preview, pull-to-refresh
   reloading all sections independently (per `QA_FINDINGS.md`'s claim — verify
   it's actually independent, not one shared future).
4. `test/features/settings/` — whatever currently exists (profile display,
   logout) — even a "minimal" screen deserves a smoke test that it renders
   and logout actually clears session state.
5. Log in `QA_LOG.md`: current real scope of Insights' charts (which of the
   4 chart types from the recommendation actually shipped), and Settings'
   current feature list vs. the Tier 3 gaps the stale doc lists.

**Verification:** `flutter test test/features/insights/ test/features/dashboard/ test/features/settings/`, `flutter analyze`

**Exit criteria:** All three covered including the explicit Pro-gate/unlocked
dual-path test for Insights. Log entries on real current scope for all three.

**Rollback:** Delete the new test files.

---

## Step 8 — Exploratory end-to-end pass (device/emulator required) — DONE (2026-08-28)

**Type:** Manual/agent-driven exploratory QA. **Model:** default. **Depends
on:** Steps 1–7 (needs the automated baseline established first, so any
exploratory finding can be checked against "did the automated tests already
catch this" before being logged as new).

**Completed 2026-08-28** — demo account upgraded to Pro via the existing
`POST /api/subscription/upgrade` endpoint (the "how to upgrade" open question
resolved: no new endpoint needed), full walk on a fresh `piggybank` AVD, 2
findings logged (portfolio P&L seed-data bug, AI context excludes account
balances) and 1 bug found+fixed (Transactions list not auto-refreshing after
CSV import). See `docs/qa/QA_LOG.md`'s "Step 8" section for the full record.

**Context brief:** This is the one step that needs a real running app — an
Android emulator or the physical test device, logged in as the shared demo
account (`demo@financeapp.co.za` / `Demo@1234!` on `100.121.165.7` — see
`piggybank_demo_account` memory for exact seeded-data counts). **Before
touching Insights**, the demo account's subscription tier must be bumped to
Pro server-side (ask the user how — no documented "upgrade demo account"
procedure exists yet; this is a genuine open question, don't invent an
endpoint) or Insights testing in this step will only ever exercise the
paywall path, which Step 7 already covers automatically.

**Task list:**
1. Navigate the full flow in the order the user specified: Transactions →
   Accounts → Budgets → Expenses → Goals → Assets → Liabilities →
   Portfolios/TFSA/RA → Calculators → Imports → Chatbot → Insights →
   Dashboard/Settings. For each screen: exercise create/edit/delete where
   applicable, note actual behavior vs. expected.
2. For Imports specifically: attempt a real file import against the demo
   account (a small CSV — construct one that matches whatever format Step 5
   discovered the wizard expects) and confirm the resulting transactions
   appear correctly in the Transactions list afterward (this is the one true
   cross-domain integration check in this plan — imports writes data that
   transactions then reads).
3. For Chatbot: send at least 3 real messages covering different intents
   (a balance question, a budget question, something out of scope) and log
   the actual Ollama-backed responses verbatim — this is real, reviewable
   output the user asked to be logged, not just "worked/didn't work."
4. For Insights (once/if Pro-upgraded): confirm each chart type renders with
   real data from the demo account's seeded transactions/budgets, not just
   that the screen loads.
5. Log every finding into `docs/qa/QA_LOG.md` under an "Exploratory Pass"
   section: what was tested, what data was used, exact repro steps for
   anything that didn't behave as expected, and the exact chatbot
   prompts/responses from item 3.

**Verification:** N/A (this step produces findings, not passing/failing
tests) — but any bug found with a clear repro should get a regression test
added to the relevant Step 1–7 test file before this step is considered done,
not just logged and left.

**Exit criteria:** Full flow walked end-to-end on a real device against the
demo account, `docs/qa/QA_LOG.md`'s Exploratory Pass section is complete with
concrete data/notes/issues/prompts, and any newly-found bug either has a
regression test added or is explicitly logged as "found, not yet fixed" with
severity.

**Rollback:** This step only writes to `QA_LOG.md` and possibly adds
regression tests to existing files from Steps 1-7 — nothing to roll back
structurally; a bad log entry can just be edited.

---

## Step 9 — Final QA report — DONE (2026-08-28)

Completed: `flutter analyze`/`flutter test` re-run clean (406/406, 37
pre-existing info lints), `QA_FINDINGS.md` updated with a new dated section
superseding stale 2026-08-21 claims and a prioritized issue list, this plan
marked done, everything committed.

**Type:** Documentation/aggregation. **Model:** default (strongest model
recommended for the discrepancy-reconciliation pass, since it requires
judgment about what's actually a bug vs. a documented known-limitation).
**Depends on:** Step 8.

**Task list:**
1. Run the full suite one final time: `flutter analyze` (must be clean) and
   `flutter test` (record final pass/fail count and, if `flutter test
   --coverage` is available/practical, the resulting coverage percentage vs.
   the 5% baseline noted in the stale `QA_FINDINGS.md`).
2. Rewrite `QA_FINDINGS.md` (or add a clearly-dated new section rather than
   silently overwriting the historical 2026-08-21 audit — preserve it as
   history) reflecting the now-current, test-verified state of every domain,
   explicitly superseding the stale "Insights Tab: NOT IMPLEMENTED" and
   "Imports: not started" claims that this plan's steps have since disproven.
3. Produce a single prioritized issue list (severity: critical/high/medium/low)
   from everything logged across Steps 1-8's `QA_LOG.md` entries — this is the
   actual deliverable the user asked for ("issues or discrepancies").
4. Commit everything: all new test files, `docs/qa/QA_LOG.md`, the updated
   `QA_FINDINGS.md`, and this plan file itself, in logical commits (test
   infra, per-domain tests, final report — doesn't need to be one commit per
   step if that's cleaner).

**Verification:** `flutter analyze && flutter test` clean; `QA_LOG.md` and
`QA_FINDINGS.md` both read coherently end-to-end (no orphaned TODOs from
mid-step notes).

**Exit criteria:** A single prioritized issue list exists and is presented to
the user; full suite is green; all work is committed.

**Rollback:** N/A — this step is aggregation/reporting, not risky code change.

---

## Notes for whoever executes this plan

- **If a step finds a real bug** (not a doc-staleness discrepancy, an actual
  code defect): fix it in that same step if it's small and localized to that
  step's domain (mirrors how the Transactions accumulator bug was fixed in
  its own session), write the regression test alongside the fix, and note it
  clearly in `QA_LOG.md` as "found + fixed" rather than just "found." If the
  fix is large/cross-cutting, stop and log it as "found, needs its own step"
  instead of scope-creeping this plan.
- Steps 1–7 can be dispatched to parallel sub-agents since they touch
  disjoint file sets; Step 0 must complete and be verified first since every
  other step imports its helpers.
- This plan deliberately does not touch `lib/features/consent/`, `lib/core/auth/`,
  or `lib/core/router/` — those already have test coverage
  (`auth_controller_test.dart`, `biometric_preference_test.dart`,
  `app_router_test.dart`) and are out of scope for "transactions through AI
  insights."
- Per the repo-wide convention already established in this plan's own
  research: always re-verify claims in `QA_FINDINGS.md` against actual code
  before trusting them — it is 5 days stale relative to this plan and has
  already been shown to be wrong about Insights and Imports.
