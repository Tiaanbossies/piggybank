# Piggybank QA Log

Running log for `plans/piggybank-full-suite-qa.md`. Every step (0-9) appends
its own dated section: data/accounts used, notes, discrepancies found vs.
`QA_FINDINGS.md` (2026-08-21, known stale — see that plan's header), issues,
and (Step 8 only) exact chatbot prompts/responses. Do not delete prior
sections — this is a historical record, newest section at the bottom.

---

## Step 0 — Shared test harness (2026-08-26)

**What was built:**
- `test/test_helpers/pump_app.dart` — `pumpApp(tester, widget, {overrides,
  useAppTheme})`, wraps a widget in `ProviderScope` + `MaterialApp` with
  `sharedPreferencesProvider` pre-overridden to an in-memory instance (it
  throws `UnimplementedError` unless overridden — every widget test needs
  this override, not just theme-specific ones).
- `test/test_helpers/mocktail_setup.dart` — `registerCommonFallbackValues()`,
  registers mocktail fallback values for enums used in `any()` matchers
  (currently just `TransactionType`; extend as later steps need more).

**Plan deviation from the original blueprint (documented, not silent):** the
plan's Step 0 called for a shared `fake_api_client.dart` faking the
`ApiClient`/Dio layer. On reading `lib/core/api/api_client.dart` and
`lib/features/transactions/data/transactions_api.dart`, this app's actual
architecture doesn't have a shared API interface to fake — each feature
(`TransactionsApi`, etc.) is its own concrete class wrapping `ApiClient`
directly, and each is exposed via its own `Provider<XApi>` (e.g.
`transactionsApiProvider`). The correct, idiomatic seam for mocktail here is
to mock each feature's concrete `*Api` class directly
(`class MockTransactionsApi extends Mock implements TransactionsApi {}`) and
override that feature's own provider in `ProviderScope` — not to fake Dio
underneath a shared client. This is simpler and matches the existing
`transactionFiltersProvider`/`transactionPaginationProvider` override
pattern already used implicitly by the app's own provider design. No shared
fake-API file was created; `mocktail_setup.dart` covers the one genuinely
shared need (fallback-value registration).

**Baseline before this step:** 15 test files, all in `test/core/` +
`test/features/expenses/expenses_chart_test.dart` + `test/widget_test.dart`.

**MAJOR DISCREPANCY FOUND:** the plan's premise ("zero tests exist for
transactions, accounts, budgets, goals, assets, liabilities, portfolios,
imports, chatbot, insights, or dashboard") was wrong — it was derived from a
`find test -maxdepth 3` survey that silently missed anything nested past 3
directories deep (e.g. `test/features/accounts/data/accounts_api_test.dart`
is 4 levels deep). The real count is **45 test files**, not 15. Actual
coverage as of 2026-08-26:
- **Well covered already:** Accounts, Chatbot, Insights, Settings, Consent,
  TFSA, RA, Auth (lock screen).
- **Partially covered:** Transactions (filters/categories/pagination
  providers tested, but no `transactions_screen_test.dart` — the actual
  regression test for the empty-state bug is still missing), Portfolios
  (only `ticker_models_test.dart` — no holdings/dividends/trades/paywall
  tests), Liabilities (only `liability_payment_test.dart` — no full
  CRUD/smart-toggle test), Imports (only `imports_models_test.dart` — no
  wizard step-transition tests).
- **Zero coverage, confirmed genuinely missing:** Budgets, Goals, Assets,
  Dashboard, Calculators.

Remaining plan steps are re-scoped around this real gap list rather than the
original (wrong) full-domain assumption.

**Baseline test run result (before any Step 1+ work):** `flutter test` →
**247 tests, 242 passing, 5 pre-existing failures**, none caused by this
session's changes:
- `test/features/accounts/screens/account_edit_screen_test.dart` — 2
  failures: `Found 0 widgets with text "Account type: bank"` and
  `"Currency: ZAR"` — looks like a copy/format mismatch between the test's
  expected string and the screen's actual rendered text, not investigated
  further this step.
- `test/features/transactions/providers/transaction_categories_test.dart` —
  3 failures, not yet triaged.

**Pre-existing bug fixed this step (not new work, a baseline defect):**
`test/features/transactions/providers/transaction_pagination_test.dart`'s
`AccumulatedTransactionsNotifier` group asserted a `reset(items)`/
`loadMore(items)` public API that no longer exists anywhere in `lib/`
(confirmed via grep — only the no-arg `transactionPaginationProvider`
methods are called in app code). This test was testing the **pre-2026-08-25-fix**
shape of the class and had been silently broken (an `undefined_method`
`flutter analyze` **error**, not just a failing test) since that refactor
shipped, because nobody re-ran `flutter analyze`/`flutter test` after it.
Rewrote the group to test the actual current behavior — automatic sync via
`ref.listen` in the constructor, using a `MockTransactionsApi` — including
the exact assertion that would have caught the original "always empty" bug
(list is non-empty and matches mocked data after the provider resolves).

**Post-fix verification:** `flutter analyze` → 0 errors (24 pre-existing
info-level lints, untouched). `flutter test` → confirmed the fixed file's 6
tests all pass now.

---

## Step 7 (partial) — Dashboard/Calculators: real test hang, root-caused and fixed (2026-08-26)

While verifying the parallel Dashboard/Calculators workstream, a specific
widget test genuinely hung — not slow, a real deadlock, reproduced twice
(6+ min and 2+ min, both times only killable via `taskkill` on
`flutter_tester.exe`/`dart.exe`, zero test-runner output while hung): the
Pull-to-refresh "reloads every section independently" test in
`test/features/dashboard/dashboard_screen_test.dart`. The coordinator's first
attempt (bounding the trailing `pumpAndSettle()` with a manual `pump()` loop)
did not fix it and a `skip:` workaround was applied instead — but the
parallel agent that originally wrote this test then correctly root-caused it
independently: `RefreshIndicatorState.show()`'s returned `Future` only
completes once the indicator's own retract animation finishes, and that
animation is driven by `SchedulerBinding`/`Ticker` callbacks that only
advance via `tester.pump()` calls — not by fake-async time elapsing on its
own. **Directly `await`ing `.show()` therefore deadlocks unconditionally**
(reproduces on the very first pull-to-refresh call, unrelated to the
`cashflow()` throw stub). Fix (standard Flutter test idiom, matches
`flutter/packages/flutter/test/material/refresh_indicator_test.dart`): call
`.show()` wrapped in `unawaited(...)` instead of `await`ing it directly, then
drive a bounded `pump()` loop to let the animation/microtask queue resolve.
**Confirmed working**: `flutter test test/features/dashboard/
test/features/calculators/` → 18/18 passing in ~3s, no hang. The `skip:`
workaround was superseded by this real fix (not left in place).

**Also confirmed NOT a production bug**: read `dashboard_screen.dart`'s
`onRefresh` — five synchronous `ref.invalidate(...)` calls, nothing that
could loop or block in the real app; the deadlock was entirely a test-only
artifact of awaiting `.show()` incorrectly.

**Bug found and fixed in `lib/features/calculators/screens/calculators_screen.dart`**
(small, localized, same step): both Loan Calculator and Loan Accelerator
tabs used `double.tryParse(...) ?? 0` for every input, so an empty or
negative principal/outstanding balance silently rendered a confident
"Monthly payment R 0,00" / "0 months saved" card instead of any validation
error. Added explicit validation (principal/outstanding/term must be > 0,
rate/extra must be ≥ 0) with an inline error message at the screen-wiring
layer only — `lib/core/calc/loan_calc.dart`'s pure math functions were left
untouched (already covered by `test/core/calc/loan_calc_test.dart`, and
other callers may legitimately rely on its existing 0-for-non-positive-input
behavior).

---

## Step 1 — Transactions domain tests + baseline fixes (2026-08-26)

**Triage of the 5 baseline failures carried over from Step 0:**

1. `account_edit_screen_test.dart` — `"Account type: bank"` / `"Currency:
   ZAR"` (2 failures). **Verdict: stale test, not an app bug.**
   `lib/features/accounts/screens/account_edit_screen.dart` renders these as
   a `GroupCard`/`GroupRow` list-row pattern (`GroupRow(title: 'Account
   type', trailing: Text(widget.account.accountType))`) — a title label and
   value are two separate `Text` widgets, not one combined string. This is a
   deliberate, reasonable UI (matches the row pattern used elsewhere in the
   app, e.g. currency/type rows), not a regression — there is no code path
   in the screen that ever produces a combined `"Label: value"` string. The
   test was written against an older/assumed format that never matched
   current `lib/` code. Fixed the test to assert on the title and trailing
   text separately (`find.text('Account type')` + `find.text('bank')`, same
   for `Currency`/`ZAR`).

2. `transaction_categories_test.dart` — 3 failures (`sorted alphabetically`,
   `includes common categories`, `returns common categories when no
   transactions`). **Verdict: stale test (harness misuse), not an app bug.**
   The failures were not assertion failures at all — the full stack trace
   showed `container.read(transactionCategoriesProvider)` throwing before
   any assertion ran, because `transactionCategoriesProvider` watches
   `accumulatedTransactionsProvider`, whose `AccumulatedTransactionsNotifier`
   listens to `transactionsProvider` in its own constructor, which in turn
   watches `transactionsApiProvider` → `apiClientProvider` →
   `authControllerProvider` → `sharedPreferencesProvider`. A bare
   `ProviderContainer()` (what the original test used) hits
   `sharedPreferencesProvider`'s `UnimplementedError` (it has no default,
   per its own doc comment and `pump_app.dart`'s doc comment) as soon as the
   provider chain is read — this test simply predates the
   `transactionsApiProvider.overrideWithValue(mock)` pattern established in
   `transaction_pagination_test.dart`. Fixed by overriding
   `transactionsApiProvider` with a `MockTransactionsApi` (mocktail) that
   answers with an empty `TransactionsPage`, which short-circuits the chain
   before it reaches the auth/prefs providers — no `lib/` changes needed.

No `lib/` code was changed for either baseline failure; both were test-only
fixes. `flutter analyze` and `flutter test` on the two affected files
confirm 0 errors, all tests green (verified: `account_edit_screen_test.dart`
8/8, `transaction_categories_test.dart` 6/6).

**New file: `test/features/transactions/screens/transactions_screen_test.dart`**
(did not exist before this step). 5 widget tests against the real
`TransactionsScreen`, using `pumpApp` + a mocktail `MockTransactionsApi`
overriding `transactionsApiProvider`:

1. **2026-08-25 regression test** — mocks a non-empty `TransactionsPage`,
   pumps the real screen, and asserts `'No transactions match this filter.'`
   is absent while both mocked transactions' merchant names render. This is
   the exact widget-level assertion that would have caught the original bug
   (`AccumulatedTransactionsNotifier`'s predecessor mutated its own state as
   a side effect of a widget-build-time `ref.watch`, which Riverpod
   disallows; the mutation threw silently and the list stayed stuck at `[]`
   forever, so the screen always rendered the empty state regardless of
   what the backend returned — already fixed in `transactions_provider.dart`
   prior to this session).
2. **Empty state still renders correctly** when the mocked API returns zero
   transactions (guards against overcorrecting #1 into never showing the
   empty state).
3. **Grouped by date** — two transactions on different dates produce two
   distinct date-group headers (`'20 Aug 2026'`, `'18 Aug 2026'`).
4. **Type filter chips actually filter** — mock's `list()` stub filters its
   canned data by the `transactionType` argument it's called with (mirroring
   real backend filtering); tapping the `Expense`/`Income` `ChoiceChip`s
   changes `transactionFiltersProvider`, which re-fetches, and the visible
   rows change accordingly.
5. **Pull-to-refresh triggers a refetch** — flings the `ListView` to trigger
   `RefreshIndicator`, then `verify(() => mockApi.list(...)).called(greaterThan(1))`.

Result: all 5 pass. Full run of `test/features/transactions/` +
`test/features/accounts/` after this step: **44 tests, 0 failures.**
`flutter analyze` on `lib/features/transactions`, `lib/features/accounts`,
`test/features/transactions`, `test/features/accounts`: **0 errors**, 9
pre-existing info-level lints only (in files this step did not touch:
`accounts_context_menu.dart` missing widget key, two test files missing a
trailing newline, and `transaction_category_picker_test.dart` missing
`const` on some constructor calls).

**Filter-UI finding (re: `QA_FINDINGS.md`, 2026-08-21, which claimed only
the transaction-type filter existed in the UI):** stale claim, not current.
Reading `lib/features/transactions/screens/transactions_screen.dart` in
full confirms all 5 fields of the `TransactionFilters` model
(`accountId`, `transactionType`, `dateFrom`, `dateTo`, `category`) have UI:

- **Type** is inline on the main screen as `ChoiceChip`s ('All' / 'Income' /
  'Expense' / 'Transfer').
- **Account**, **date range** (`From date`/`To date` via `showDatePicker`),
  and **category** (free-text `TextFormField`) all live in
  `_TransactionFilterSheet`, a modal bottom sheet opened via the app bar's
  filter (`Icons.filter_list`) icon button — not inline on the main list,
  which is presumably why the earlier audit missed them (they're one tap
  away, not visible in a static screenshot of the list screen). All 5
  filters correctly write into `transactionFiltersProvider` via the
  documented `copyWith`/notifier setters, which `transactionsProvider`
  watches as a single combined object (avoiding the stale-closure bug the
  code comment on `TransactionFilters` describes). This step's new test #4
  above only exercises the inline type chips; the modal sheet's
  account/date/category filters are UI-verified by reading the source but
  are not yet covered by a widget test (opening the sheet, picking a date,
  asserting the refetch) — flagged as a gap for a future step rather than
  added here, to stay in scope.

---

## Step 2/3 — Budgets, Goals, Assets domain tests (2026-08-26)

**Baseline before this step:** zero test files under `lib/features/budgets/`,
`lib/features/goals/`, `lib/features/assets/` — confirmed via `find` before
writing anything, matching the task brief.

**What was read (full source, before writing tests):** `models/`, `data/*Api`,
`providers/`, and `screens/` for all three domains, plus the shared
`ProgressCard` (`lib/shared/widgets/progress_card.dart`, used by both Budgets
and Goals for their progress bars), `group_card.dart`/`hero_metric_card.dart`
(Assets' list rows/total), and `core/format/money.dart`/`core/api/api_error.dart`.

**Test files added (9 new files, 86 tests, all passing):**

- `test/features/budgets/models/budget_test.dart` (8 tests) — `Budget` and
  `BudgetProgress` `fromJson` round-trip, including the recursive `children`
  tree, a missing `children` key defaulting to `[]`, over-budget flag, and
  numeric-vs-string JSON values for the Decimal fields.
- `test/features/budgets/providers/budgets_provider_test.dart` (13 tests) —
  `SelectedMonthNotifier` month-picker navigation (`next()`/`previous()`,
  round-trip, year-boundary rollover), `budgetProgressProvider` and
  `budgetsForMonthProvider` refetch/filter behaviour against a mocked
  `BudgetsApi`, and create/update/delete CRUD call-argument verification.
- `test/features/budgets/widgets/progress_card_color_test.dart` (6 tests) —
  focused unit coverage of the over-budget colour conditional in
  `ProgressCard.build()` (`barColor = overBudget ? semantic?.danger :
  colorScheme.primary`): on-track uses the theme's primary colour and muted
  footnote text, over-budget uses the semantic danger colour for both the
  bar and the footnote, plus the `pct` clamp-to-1.0 and indented-margin
  behaviour.
- `test/features/budgets/screens/budgets_screen_test.dart` (5 widget tests) —
  `BudgetsBody` renders a row per budget from a mocked API, empty state,
  error state, sub-category indentation (verifies `ProgressCard.indented`
  is `false` for the parent and `true` for the child), and that tapping the
  month-navigation chevron re-fetches.
- `test/features/goals/models/goal_test.dart` (6 tests) — `goalStatusFromJson`
  mapping (including the unrecognised-value throw), `Goal.fromJson`
  round-trip for active/completed goals, nullable fields, and int-vs-double
  JSON for `progress_pct`.
- `test/features/goals/providers/goals_provider_test.dart` (5 tests) —
  `goalsProvider` fetch/error-propagation against a mocked `GoalsApi`, and
  create/update (including a status transition to `completed`)/delete CRUD
  call-argument verification.
- `test/features/goals/screens/goals_screen_test.dart` (5 widget tests) —
  `GoalsBody` renders a row per goal, empty state, error state, and
  specifically asserts the progress-percentage calculation: `progressPct /
  100` is what's passed as `ProgressCard.pct` (saved/target ratio), verified
  both for a partial goal (37% -> 0.37) and a completed goal (100% -> a
  fully-filled `LinearProgressIndicator`).
- `test/features/assets/models/asset_test.dart` (20 tests: 6 static + a
  7-way parametrized loop over every `AssetType` value contributing 2 tests
  each) — `assetTypeToJson`/`assetTypeFromJson` round-trip per type
  (confirming `savings_account` is the one wire value that departs from
  `.name`), a non-empty UI label per type, `assetTypeLabels` covering every
  type with no gaps, unknown wire values falling back to `AssetType.other`,
  and `Asset.fromJson` round-trip.
- `test/features/assets/providers/assets_provider_test.dart` (5 tests) —
  `assetsProvider` fetch/error-propagation against a mocked `AssetsApi`, and
  create/update/delete CRUD call-argument verification (including the
  `AssetType` wire-format field).
- `test/features/assets/screens/assets_screen_test.dart` (13 widget tests) —
  `AssetsScreen` renders a row per asset, the "Total assets" hero card
  (client-side sum), empty state (and hero card correctly absent), error
  state, conditional institution-name subtitle, and **the type-picker
  parametrized test the task asked for**: one `testWidgets` per
  `AssetType.values` entry confirming its `assetTypeLabels` text is a
  selectable, hit-testable option in the add-asset sheet's
  `DropdownButtonFormField<AssetType>`, plus a summary test asserting the
  dropdown's menu items exactly cover the enum (`AssetType.values.toSet()`)
  with no gaps.

Verified the actual current `AssetType` enum via
`lib/features/assets/models/asset.dart` rather than assuming the task
brief's example list — it matches exactly (`cash, savingsAccount, property,
vehicle, investment, retirement, other`).

**Mocktail fallback-value registration:** `GoalStatus` and `AssetType` are
passed via `any(named: ...)` in stubs. Per the task's file-scope restriction,
`test/test_helpers/mocktail_setup.dart` (owned by Step 0) was not edited;
instead each provider test file registers its own fallback value locally in
a `setUpAll` (`registerFallbackValue(GoalStatus.active)` /
`registerFallbackValue(AssetType.cash)`). This works identically (mocktail's
registry is a single global map) but means the fallback is only guaranteed
registered when that specific test file has run its `setUpAll` — worth
consolidating into the shared helper in a later pass since Budgets, Goals,
and Assets are unlikely to be the last domains needing this.

**Test run:**
`flutter test test/features/budgets/ test/features/goals/ test/features/assets/`
→ **86/86 passed, 0 failures.**
`flutter analyze` (whole project) → **0 errors**; 37 info-level lints total,
all pre-existing style nits (`unnecessary_lambdas` on the `when(() =>
mock.method())` mocktail idiom used throughout the existing test suite,
one `cast_nullable_to_non_nullable`, missing trailing `const`s, etc.) —
none introduced a new *error*, and the lambda-vs-tearoff lint is the same
false positive already present in `test/features/transactions/` and
`test/features/accounts/` (mocktail's `when()` requires a closure, not a
tearoff, to stub correctly).

**Discrepancies found vs. `QA_FINDINGS.md` (2026-08-21) for these three
domains specifically:**

1. **Goals — stale claim about date fields in the create form.**
   `QA_FINDINGS.md` line 81 claims "Create goal (name, target amount,
   **start date, deadline**)". Reading the actual `_GoalSheet` in
   `lib/features/goals/screens/goals_screen.dart` (both add and edit modes)
   shows only three fields: goal name, target amount, starting amount —
   **no date picker of any kind**, despite `Goal.targetDate` existing on the
   model and `GoalsApi.create()`/`update()` both accepting a `targetDate`
   parameter end-to-end. The API plumbing is there; the UI to set it is not.
   This is a real, verified gap (not a doc-staleness issue in the other
   direction) — flagged here as "found, not fixed" per the task instructions
   since it's a UI feature addition, not a small localized bug. No test
   asserts a date field exists (asserting an absence isn't meaningful
   regression coverage), so this is a documentation note, not a test.

2. **Budgets — stale claim that sub-category budgets are "read-only from
   month view."** `QA_FINDINGS.md` line 73 describes sub-category budgets
   in the month view as "(indented, read-only from month view)". Reading
   `BudgetsBody`/`_BudgetProgressRow` in `budgets_screen.dart` shows indented
   child rows use the exact same `_BudgetProgressRow` as top-level budgets,
   wired to the same `onTap: () => showEditBudgetSheet(context, progress)`
   — sub-category budgets are fully editable (and deletable) by tapping
   them, identical to top-level budgets. Covered indirectly by this step's
   `_BudgetsBody` sub-category indentation test, which pumps a
   parent+child tree and asserts both render as `ProgressCard`s (the
   `indented` flag differs; tap-to-edit behaviour is identical for both).

3. **Assets — `QA_FINDINGS.md` line 154's claim that "Assets valuation
   date (capture + display)" is missing from the UI is accurate, confirmed
   independently.** `Asset.valuationDate` exists on the model and
   `AssetsApi.create()`/`update()` accept it, but `_AssetSheet` in
   `assets_screen.dart` has no date field (name, type, value, institution
   only) and `_AssetRow`'s subtitle never displays it. No new bug — this
   one was already correctly flagged in the stale doc; noted here only to
   confirm the audit checked it rather than skipping the one true claim
   among the two false ones above.

**Bugs found:** none in these three domains beyond the documentation gaps
above — no code changes were made to `lib/features/budgets/`,
`lib/features/goals/`, or `lib/features/assets/` this step.

---

## Step 4/5 (partial) — Portfolios, Liabilities, Imports domain tests (2026-08-26)

**Scope:** `lib/features/portfolios/`, `lib/features/liabilities/`,
`lib/features/imports/` — filled the gaps left by each domain's pre-existing
models-only test file. Read every file under all three `lib/features/`
trees (providers, data/*Api, models, screens) before writing anything.
`lib/features/tfsa/` and `lib/features/ra/` were not touched (already have
their own coverage per this step's brief).

**Test files added (6 new files, 62 tests total in the three
`test/features/{portfolios,liabilities,imports}/` trees including the 3
pre-existing model-test files):**

- `test/features/portfolios/providers/portfolios_provider_test.dart` (25
  tests) — every `FutureProvider`/`.family` in `portfolios_provider.dart`
  (`portfoliosProvider`, `investmentOverviewProvider`,
  `portfolioHoldingsProvider`, `portfolioValueProvider`,
  `portfolioDividendSummaryProvider` keyed by the `{portfolioId, year}`
  record, `holdingTradesProvider`, `holdingDividendsProvider`) against a
  mocked `PortfoliosApi`, plus CRUD wiring tests for portfolios, holdings,
  dividends, and trades (create/update/delete each verify the exact
  arguments `PortfoliosApi` receives, since there's no CRUD logic in the
  provider layer itself to test independently — see finding 1 below).
- `test/features/portfolios/screens/portfolio_sheet_paywall_test.dart` (3
  tests) — the paywall UI test asked for in the brief: a mocked
  `createPortfolio` throwing a 402 `ApiError` pops the sheet and shows the
  "Upgrade to PRO" `AlertDialog` (`showPaywallPrompt`) with the backend's
  message; a non-402 error keeps the sheet open with an inline error and
  never shows that dialog; a successful create shows neither.
- `test/features/liabilities/providers/liabilities_provider_test.dart` (13
  tests) — `liabilitiesProvider`, `liabilityProgressProvider` and
  `liabilityPaymentsProvider` (both `.family` keyed by `liabilityId`), and
  full CRUD wiring for liabilities and payments, including both `create()`
  call shapes (`outstandingAmount` vs. the loan-params set).
- `test/features/liabilities/screens/liability_sheet_smart_toggle_test.dart`
  (6 tests) — the "smart toggle" test asked for in the brief:
  `_LiabilitySheet`'s `SegmentedButton<bool>` ("Amount owed" / "Loan
  details") swaps the outstanding-amount field for
  original-balance/interest-rate/term-months/start-date fields, and Save
  posts the correct field set for whichever mode is active (verified via the
  mocked `LiabilitiesApi.create()` call's exact arguments, not just which
  fields render). Also covers that editing an existing liability never shows
  the toggle at all (type/mode is fixed at creation, per
  `liabilities_screen.dart`'s own doc comment).
- `test/features/imports/providers/imports_provider_test.dart` (6 tests) —
  `bankTemplatesProvider`, `importHistoryProvider` (including its error
  state), and `normalizeCategories` wiring. `uploadCsv`/`ocrReceipt` are
  deliberately not exercised here — see finding 2 below.
- `test/features/imports/screens/imports_screen_test.dart` (5 tests) — the
  parts of `ImportsScreen` reachable without a real file: the Upload
  button's disabled-until-a-file-is-chosen state, the bank-template dropdown
  populated from `bankTemplatesProvider`, and the import-history
  list's populated/empty/error rendering.

**`flutter analyze lib/features/portfolios lib/features/liabilities
lib/features/imports test/features/portfolios test/features/liabilities
test/features/imports`: 0 issues.** `flutter test test/features/portfolios/
test/features/liabilities/ test/features/imports/`: 62/62 passing, 0
failures.

**Finding 1 — Portfolios/Liabilities have no CRUD logic in the provider
layer to unit-test independently of the API class.** Unlike
`transactionPaginationProvider`'s `StateNotifier`, `portfolios_provider.dart`
and `liabilities_provider.dart` are pure `FutureProvider`/`.family` reads;
every create/update/delete is a screen-local `ConsumerState` method calling
`ref.read(xApiProvider).method(...)` directly, then `ref.invalidate(...)`
the relevant read providers. So "CRUD provider tests" here necessarily test
the api-call contract (arguments in, model out) rather than any
provider-owned business logic — which is genuinely what's testable and
matches this app's actual architecture (same conclusion Step 0 already
reached for Transactions). Screen-level wiring (does tapping Save actually
call the right api method with the right args) is additionally covered by
the two widget-test files above rather than for every mutation, to keep the
suite proportionate.

**Finding 2 — the Imports task brief's assumed wizard does not exist; real
scope is materially different from what was described.** The brief asked
for "wizard step-transition tests (file selection → column mapping →
preview/confirm... forward/back navigation preserving state, can't skip an
incomplete step... final confirm step calling the bulk-create-transactions
API)". Reading `imports_screen.dart` end to end: there is no multi-step
wizard, no column-mapping step, no preview/confirm step, and no
bulk-create-transactions API call anywhere in `lib/features/imports/`.
`ImportsApi` (`lib/features/imports/data/imports_api.dart`) has exactly one
CSV entry point, `uploadCsv()`, which uploads the raw file as
`multipart/form-data` to `POST /imports/` and gets back a single
`ImportJob` — **the backend does the parsing, column-mapping, dedup, and
transaction-creation in one shot, server-side.** The UI is one flat screen:
pick a CSV → optionally pick a bank template / account → tap Upload → see
an `ImportJob` result card (imported/failed/auto-categorized/duplicate row
counts, an optional "Normalize with AI" follow-up call) → the job also
appears in a "Past imports" history list (`importHistoryProvider`). There is
nothing to skip, no per-step validation gate, and nothing analogous to
"forward/back preserving state" because there are no separate steps. The
closest thing this screen has to a step-based confirm flow is the *separate*
"Scan Receipt" (OCR) feature also on this screen: pick a photo/PDF →
`POST /imports/ocr` returns extracted fields → the user edits them in a form
→ "Save transaction" calls `TransactionsApi.create()` (a real, single
transaction create, not a bulk import). This OCR review-then-save step *is*
tested for its reachable states in `imports_screen_test.dart`, but its
"process a receipt" entry point — like CSV upload — is gated behind
`file_picker`/`image_picker`, both real native platform plugins with no
platform-channel fake wired into this test harness (`file_picker` in
particular ships no separate `_platform_interface` package to substitute
easily; faking it would mean standing up per-platform mock channel
responses, out of scope for this pass). **This is a genuine, documented test
gap**: `uploadCsv`, `ocrReceipt`, and everything downstream of them that
depends on a real picked file (the result card, "Normalize with AI", and the
full OCR review→save path) are exercised only at the API-contract level
(model parsing + `ImportsApi` method signatures), not through a real
file-picker-driven widget interaction. Closing it would need a
`file_picker`/`image_picker` platform-channel fake (or refactoring
`ImportsScreen` to take an injectable file-source abstraction) as
follow-up work — flagged here as "found, not fixed" since it's a test-harness
gap, not an app bug, and wiring platform-channel fakes is out of proportion
for this pass.

**Finding 3 — `QA_FINDINGS.md`'s "Liabilities is missing a payment history
screen" claim is stale/false, confirmed independently.**
`lib/features/liabilities/screens/liability_detail_screen.dart` has a full
payment-log ledger: a progress card (paid-off %, principal/interest paid,
payment count, projected payoff date — gated on `originalBalance` being
set), a "Payment history" `GroupCard` list with per-row delete (with
confirm), and a "Log payment" FAB opening a sheet that posts to
`LiabilitiesApi.createPayment()`. This is backed end-to-end by
`liabilityPaymentsProvider`/`liabilityProgressProvider` and the
`/liabilities/{id}/payments`+`/progress` endpoints in `liabilities_api.dart`
— none of it is a stub. (`liability.dart`'s own doc comment is itself
half-stale here too: it says "Payment-log/progress tracking... is a
documented v1 gap, not built," which was true only for the *model file's*
comment, not the actual shipped screen.) Covered by this step's
`liabilities_provider_test.dart` (payments/progress provider + CRUD wiring).

**Finding 4 — Portfolios' backend connectivity is provable via the mocked
contract, not via a live backend.** Every `PortfoliosApi` method (list/
create/update/delete for portfolios, holdings, dividends, trades; value/
overview/dividend-summary aggregation; ticker lookup/search/history) has a
concrete `Future<T>` signature this step exercised against a mocked
`PortfoliosApi`, confirming the provider layer's request/response contract
end-to-end for every case except live-network behaviour. That's the
practical ceiling for "backend-untested" in this codebase's test harness (no
integration/e2e layer exists here — see Step 0's harness note); it directly
contradicts `QA_FINDINGS.md`'s blanket "backend-untested" framing for
Portfolios, which is now stale as of this step.

**Bugs found:** none required a code fix in
`lib/features/{portfolios,liabilities,imports}/` this step — Finding 2 is a
test-harness/coverage gap (native file-picker plugins, no app code
involved), not an app defect.

---

## Step 4/7 (resolved) — Dashboard/Calculators: pull-to-refresh hang root-caused and fixed (2026-08-26)

**Test files (from the earlier partial pass, confirmed complete):**
`test/features/dashboard/dashboard_screen_test.dart` (8 tests: net-worth
hero, cashflow stat strip, progress block goal-or-budget fallback x3,
recent-transactions preview x2, pull-to-refresh x1) and
`test/features/calculators/calculators_screen_test.dart` (10 tests: Loan
Calculator tab x5, Loan Accelerator tab x3, tab navigation x2) — screen-
wiring tests only for Calculators, reusing `test/core/calc/loan_calc_test.dart`
as the math oracle per the plan's Step 4 scoping note.

**The Step 7 (partial) entry above logged a genuine, reproduced deadlock in
the Pull-to-refresh test and shipped it `skip:`ped rather than blocked. This
step isolated the actual root cause and fixed it — the skip has been
removed and the test now passes for real, not bypassed.**

Root cause: the test called
`await tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();`
— but `RefreshIndicatorState.show()`'s returned `Future` only completes once
the indicator's own retract animation finishes, and that animation is driven
by `SchedulerBinding`/`Ticker` callbacks that only advance when the test
calls `tester.pump()`. Directly `await`ing `.show()` blocks the single test
isolate on a Future that can only resolve via a `pump()` call the test body
never reaches — a straight deadlock, reproducible on the very first
pull-to-refresh trigger regardless of whether any mocked API call throws
(disproving the Step 7 (partial) entry's "indeterminate
`CircularProgressIndicator`" theory — verified by reproducing the exact same
hang with `pumpAndSettle()` swapped for a bounded manual `pump()` loop
placed *after* the awaited `.show()` call: still hung, before any of those
`pump()`s ran). This is the standard, documented Flutter testing pitfall for
`RefreshIndicator` — Flutter's own test suite
(`flutter/packages/flutter/test/material/refresh_indicator_test.dart`) calls
`.show()` **without** `await`, then pumps. Confirmed **not** a production
bug: `DashboardScreen`'s `onRefresh` is five synchronous `ref.invalidate(...)`
calls with no internal `await`, so the real app never depends on this
test-only await pattern.

**Fix applied:** in `test/features/dashboard/dashboard_screen_test.dart`,
changed `await tester.state<RefreshIndicatorState>(...).show();` to
`unawaited(tester.state<RefreshIndicatorState>(...).show());` (added `import
'dart:async';` for `unawaited`), kept the bounded 10x `pump(100ms)` loop, and
added a trailing `pumpAndSettle()` once frames are actually being pumped.
Removed the `skip:` parameter and its explanation entirely — the test is
live and passing, not bypassed.

**Pull-to-refresh independence finding (now verified, not just asserted):**
with the deadlock fixed, the test proves `DashboardScreen`'s pull-to-refresh
reloads its five sections independently, per its `onRefresh`'s five separate
`ref.invalidate(...)` calls — one section's fetch failing does not block or
stale-lock the others. Concretely: after refresh, `cashflow()` is stubbed to
throw and the cashflow stat strip correctly renders nothing (`SizedBox.shrink()`
on `AsyncError`, per `_CashflowStatStrip`'s `error` branch) while, in the same
refresh cycle, net worth updates to the new value (R 2 000,00), the goal
progress card swaps to the newly-returned goal ("New car", replacing
"Holiday"), and the recent-transactions preview swaps to the newly-returned
transaction ("Rent", replacing "Coffee") — all three succeeding sections show
genuinely fresh post-refresh data, not stale pre-refresh state left behind by
the one failing section. This confirms Riverpod's per-provider
`invalidate()` + `autoDispose` `FutureProvider` design (`netWorthProvider`,
`cashflowProvider`, `goalsProvider`, `budgetProgressProvider`,
`recentTransactionsProvider` in their respective `providers/` files) gives
true section-level isolation on refresh failure, with no shared future or
`Future.wait` coupling the five sections' error states together.

**Final verification:**
```
flutter test test/features/dashboard/ test/features/calculators/
```
→ **18 tests, 18 passing, 0 failing** (up from 17/18 with 1 skipped).
`flutter analyze` → clean, same 37 pre-existing info-level lints as every
prior step (no errors, none introduced by this fix).

**Bugs found:** none in `lib/` — the hang was entirely a test-code defect
(direct `await` on `.show()`), now fixed. No production code touched this
step.
