# Piggybank Production-Readiness Audit (2026-09-11)

Two-phase audit per the `flutter-production-audit` skill: a static codebase scan followed by a
live Android-emulator walkthrough against the shared demo account on the real Tailscale backend
(`http://100.121.165.7:8000/api`, confirmed reachable — `GET /api/health` → `200`). This is **not**
a re-run of the full-suite QA blueprint; nearly every prior finding
(`docs/qa/QA_FULL_SUITE_2026-08-31.md`, 19 findings) and the fix-it blueprint
(`plans/piggybank-fix-it.md`, 8 steps) closing them is already done and live-verified as of
2026-09-01. This pass spot-checks that prior work still holds and focuses on genuinely new ground:
categories the prior manual walkthrough didn't systematically check (const-correctness, provider
watch-scoping, image caching, isolate usage, animation-controller disposal, accessibility/
Semantics, scalable-text support) plus a fresh live pass since real work has landed since
2026-09-01.

---

## Top-line summary

**7 new findings**: **0 Critical, 0 High, 4 Medium, 3 Low**, plus one **regression re-test** that
turned up a partial fix, and a substantial confirmed-clean list.

| Severity | Count | Theme |
| --- | --- | --- |
| Critical | 0 | — |
| High | 0 | — |
| Medium | 4 | Unprotected auth-client timeout, non-lazy paginated list, FAB obscuring list content, chatbot currency-format regression |
| Low | 3 | Icon-button accessibility labels, stale form-validation text, a holdings-data discrepancy worth a quick DB check |

**Most important new finding:** the Transactions screen's `FloatingActionButton.extended` ("Add
transaction") has no bottom padding reserved in its `ListView`, so whichever transaction row ends
up under the button at a given scroll position has its **amount value fully hidden** — reproduced
twice, on two different rows ("Monthly salary" and "Consulting"), at two different scroll depths.
This is a real, user-visible defect (the amount is the single most important piece of data on that
row) that the prior exploratory walkthroughs did not catch because it depends on scroll position,
not initial screen state.

**Clean / confirmed still-holding (regression-verified live today):** login → dashboard flow, net
worth figure and formatting, Transactions/Dashboard income-expense green/red colour convention
(M1, 2026-08-31 report), Accounts/Budgets/Settings screens, `flutter analyze` (2 trivial info-lints
only), `flutter test` (427/427 passing). **Clean by static scan, not just unchecked:** no
`AnimationController` usage anywhere (nothing to leak), no `Image.network` usage anywhere (no
network-image caching gap applies), const-correctness lints are enabled and pass with zero
findings, and the Dashboard's provider-watch pattern (one `ConsumerWidget` per metric card) already
scopes rebuilds narrowly without needing `.select()`.

---

## Regression re-test: partial fix found

### R1. Chatbot ("Penny") still formats currency with a period decimal separator, inconsistent with the rest of the app
**This is the previously-logged M6** (`QA_FULL_SUITE_2026-08-31.md`) — its close-out in
`QA_FINDINGS.md`'s 2026-09-01 update names only a **currency-symbol** fix ("chatbot currency
guardrail (ZAR/`R`, never `$`)"), not a fix to the number-formatting convention that M6's original
text also flagged (US comma-thousands/period-decimal vs SA space-thousands/comma-decimal).
**Repro (live, today):** Assistant tab → tap "Show my net worth trend" → response reads *"R 5 286
030.50 in September is your current net worth"* — space-thousands (correct) but a **period**
decimal separator. Same figure on Dashboard: **"R 5 286 030,50"** — comma decimal separator, the
convention used everywhere else in the app (Accounts, Budgets, Goals).
**Severity:** Medium — the currency *symbol* fix (the credibility-critical half) holds; this is a
smaller, cosmetic locale-formatting miss, not a new class of bug. Flagging because the fix-it
blueprint's own close-out text describes it as fully closed, and it isn't, quite.
**File:** chatbot response text is server-generated (`piggybank-backend`), not client-formatted —
the money-value pre-formatting mentioned in `QA_FINDINGS.md`'s 2026-09-01 update
(space-thousands separators before reaching the model) evidently doesn't also force a comma
decimal point.

---

## Medium

### M1. `AuthApi`'s Dio client has no request timeout, unlike the main `ApiClient`
**File:** `lib/core/auth/auth_api.dart:21` — `AuthApi({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));`
**Contrast:** `lib/core/api/api_client.dart:27-31` sets `connectTimeout`/`sendTimeout`/`receiveTimeout`
explicitly (the H6 fix from the 2026-08-31 report). `AuthApi` is a deliberately separate,
unauthenticated Dio instance (by design, to avoid a circular dependency with the refresh
interceptor — see the class doc comment) used for `/auth/register`, `/auth/login`, `/auth/refresh`,
and `/auth/password-reset/request`.
**Why it matters:** H6 closed the timeout gap for every *authenticated* request but missed this
second, separate Dio instance. A stalled connection during login/register/password-reset (bad
mobile network, VPN hiccup, backend hang) leaves the user on a spinner indefinitely with no
client-side timeout ever firing — for a mobile finance app, that's precisely the pre-auth path
where a slow SA mobile network is most likely to bite.
**Severity justification:** Medium, not High — narrower blast radius than the original H6 (four
endpoints, all pre-authentication, not the whole app), but the same underlying gap the prior fix
was meant to close app-wide.

### M2. Transactions list is a plain `ListView(children: [...])`, not lazy, over an unbounded/paginated dataset
**File:** `lib/features/transactions/screens/transactions_screen.dart:96-113`
**What it is:** the screen builds one `Padding`/date-header + `GroupCard` widget per date group,
covering every accumulated transaction, inside `ListView(children: [...])` rather than
`ListView.builder`. The list grows via an explicit "Load more (N of total)" pagination button
(`transactionPaginationProvider`) that appends to `accumulatedTransactionsProvider` — i.e. this is
exactly the "unbounded list rendered without `.builder`" pattern the audit checklist calls out,
and it's on the one screen in the app where the item count is designed to grow without limit.
**Why it matters:** every widget for every accumulated transaction is built and kept in the tree at
once, instead of lazily as rows scroll into view — a user who taps "Load more" repeatedly (a power
user with years of transaction history) pays an increasing per-rebuild cost with no upper bound.
**Severity justification:** Medium — no correctness impact and not visible at the demo account's
current data volume (small), but it's the screen most likely to actually accumulate hundreds of
rows over a real user's lifetime, unlike the smaller lists below.
**Related, lower-priority instances:** `lib/features/ra/screens/ra_ledger_screen.dart:39` and
`lib/features/tfsa/screens/tfsa_ledger_screen.dart:39` render their contribution history the same
way — logged as Low (L1 below) since annual-contribution limits keep realistic row counts small
for years.

### M3. Transactions screen's floating "Add transaction" button permanently obscures whatever row scrolls beneath it
**File:** `lib/features/transactions/screens/transactions_screen.dart` (FAB at line ~127; the
`ListView`'s `padding: const EdgeInsets.all(16)` at line ~96 reserves no extra bottom inset for it).
**Repro (live, today):** scrolled to two different depths on the demo account's transaction list —
first showing "Monthly salary R 35 000,00", then further down "Consulting" — in both cases the
`FloatingActionButton.extended("+ Add transaction")` sits directly on top of the row's amount text,
fully hiding it. The FAB doesn't move with the scroll (correct Material behaviour), but the list's
scrollable content isn't padded to keep rows clear of the FAB's footprint, so any row that happens
to land in that fixed screen band has its most important value unreadable until the user scrolls
past it.
**Severity justification:** Medium — genuinely broken (not just an opportunity for polish): a real
value on a real row is invisible at a reachable, unremarkable scroll position, on the single screen
where amounts are the entire point.
**Fix direction (not applied — logged only):** add bottom padding to the `ListView` sized to the
FAB's height + margin (a common `SliverPadding`/`MediaQuery`-based pattern), or switch to a
`floatingActionButtonLocation` that docks above content rather than overlaying it.

### M4. Login screen's inline validation error text does not clear as the user corrects the field
**Repro (live, today):** typed an intentionally-short password, saw "password: String should have
at least 8 characters" appear; corrected the field to the full valid password (verified via the
reveal-password eye icon — "Demo@1234!", 10 characters) — the red error text remained on screen,
unchanged, until the form was actually submitted (at which point login succeeded and the error
disappeared with the screen transition). The field's green "valid" border state and label colour
*did* update correctly; only the error microcopy was stale.
**Severity justification:** Medium-low — not a functional blocker (submission works once the field
is actually valid) but a real point of user confusion: a visible, specific error message
contradicts the field's own success-styling for as long as the user is looking at it.

---

## Low

### L1. `ra_ledger_screen.dart` / `tfsa_ledger_screen.dart` render contribution history via `ListView(children:)`, not `.builder`
**Files:** `lib/features/ra/screens/ra_ledger_screen.dart:39`, `lib/features/tfsa/screens/tfsa_ledger_screen.dart:39`.
Same pattern as M2, downgraded to Low because annual TFSA/RA contribution caps keep realistic row
counts in the tens-to-low-hundreds even over a long-held account, unlike Transactions.

### L2. Icon-only `IconButton`s without a `tooltip` (missing accessible label) in 12 files
**Grep:** `IconButton(` occurrences vs `tooltip:` occurrences per file — 12 files have at least one
icon-only button with no `tooltip` set (which, in Flutter, is also what supplies the
`Semantics` label a screen reader announces): `lib/features/auth/screens/login_screen.dart`,
`register_screen.dart`, `reset_password_screen.dart`, `lib/features/budgets/screens/budgets_screen.dart`
(2 of 2), `lib/features/insights/screens/insights_screen.dart`, `lib/features/liabilities/screens/liability_detail_screen.dart`
(2 of 2), `lib/features/portfolios/screens/holding_detail_sheet.dart` (2 of 2), `invest_screen.dart`
(1 of 2 — one already has a tooltip), `portfolio_detail_screen.dart` (1 of 3), `lib/features/ra/screens/ra_ledger_screen.dart`,
`lib/features/settings/screens/data_export_screen.dart`, `lib/features/tfsa/screens/tfsa_ledger_screen.dart`.
**Confirmed clean elsewhere:** zero explicit `Semantics(` widgets exist anywhere in `lib/`, but the
app doesn't lean on that pattern at all — the gap is specifically these untooltipped icon buttons,
not a systemic absence of accessibility support.
**Severity justification:** Low — none of these are the app's primary CTAs (those use labelled
`ElevatedButton`s throughout), but a screen-reader user gets an unannounced, unlabelled control at
each of these spots.

### L3. Invest tab's "Top holdings" shows two identical-ticker rows with a suspiciously large P&L delta — worth a quick DB check before assuming it's real
**Repro (live, today):** Invest tab → Top holdings → two rows, both "GLD — SPDR Gold Shares ETF",
both showing the identical current value **R 32 463,50**, but one shows **-R 767 536,50**
unrealized loss and the other **+R 16 463,50** unrealized gain — an ~R784k swing between two rows
that otherwise look identical. The account has 3 portfolios, so two legitimately separate lots (a
gold position bought in two different portfolios at very different cost bases) is plausible and
would not be a bug. It's flagged rather than dismissed because this app's own QA history
(`QA_FINDINGS.md`'s 2026-09-01 update) documents a real seed-script dedup gap for transactions
(`create_transactions()` re-running without a duplicate check), so a similarly-unguarded holdings
seed producing a phantom duplicate lot is a plausible, not far-fetched, explanation.
**Severity justification:** Low — cosmetically odd but not verified as wrong; logged as a
"confirm, don't assume" item rather than a defect. A one-query check
(`SELECT id, symbol, quantity, cost_basis, portfolio_id FROM holdings WHERE symbol = 'GLD'` against
the demo account) would resolve it in under a minute.

---

## Confirmed clean (regression-verified live, or genuinely clean by static scan)

- **Login → Dashboard flow** against the live Tailscale backend: demo login succeeds, net worth
  renders (**R 5 286 030,50** at time of test — data has evolved since the 2026-09-01 report's
  R1 808 030,50 snapshot, expected drift, not a bug).
- **Transactions/Dashboard income-expense colour convention (M1, 2026-08-31 report):** still
  green/red consistently on both the Dashboard preview and the full Transactions list — the fix
  holds.
- **Accounts, Budgets, Settings, Calculators, Assistant, Invest tab screens:** all load without
  error, no debug-mode `RenderFlex overflowed` banners observed on any screen visited.
- **`flutter analyze`:** 2 issues, both trivial info-lints (`use_null_aware_elements` in
  `lib/features/settings/data/profile_api.dart:22-23`) — not present in the prior report, cheap to
  fix, not logged as a numbered finding given their triviality.
- **`flutter test`:** 427/427 passing, 0 failures.
- **No `AnimationController` usage anywhere in `lib/`** — nothing to check for missing `dispose()`.
- **No `Image.network` usage anywhere in `lib/`** — the app uses only local/bundled imagery, so the
  "network images without caching" checklist item doesn't apply.
- **const-correctness:** `prefer_const_constructors`, `prefer_const_constructors_in_immutables`,
  and `prefer_const_literals_to_create_immutables` are all enabled in `analysis_options.yaml`, and
  `flutter analyze` reports zero violations — genuinely enforced, not just unchecked.
- **Provider watch-scoping:** the Dashboard (the screen most likely to over-rebuild, since it
  aggregates 6 independent data sources) already splits each metric into its own private
  `ConsumerWidget` (`_NetWorthHero`, `_CashflowStatStrip`, `_ProgressBlock`,
  `_RecentTransactionsPreview`, etc.), each calling `ref.watch` on only the one provider it needs.
  Zero `.select()` usage exists anywhere in the codebase, but none was needed given this
  widget-per-provider scoping — flagged as a non-issue, not a finding.
- **Scalable text:** `lib/app.dart:23-25` explicitly clamps `MediaQuery.textScalerOf(context)` to a
  max of 1.3x app-wide, a deliberate anti-layout-breakage measure. Noted as a product-level
  trade-off (it also caps how large a low-vision user can make text via OS accessibility settings)
  rather than a defect — no action taken.
- **SafeArea coverage:** 35 of 36 screen files use `SafeArea` directly; the two apparent gaps
  (`budgets_screen.dart`, `goals_screen.dart`) are sub-view body widgets nested inside a parent
  `Scaffold` elsewhere in the tab shell, not top-level screens — not a real gap, not logged.

---

## Notes on scope

- No fixes were applied during this audit beyond what's noted above (none were — every item here
  is logged only, per the skill's find-and-log convention).
- Phase 2 (live emulator) **did run**: the `piggybank` AVD booted successfully, a debug APK was
  built and installed fresh (`pm clear` beforehand), and the walkthrough covered Login → Dashboard,
  Calculators, Transactions (including a scroll-depth check for M3), Invest, Assistant/chatbot
  (live query against the real backend), Budgets, Settings, and Accounts. Screens not
  re-walked this pass (Assets, Liabilities, Goals, Consent, Expenses, Insights, Imports, RA/TFSA
  ledgers) were exercised live as recently as the 2026-08-31 report and are covered by this
  report's static-only pass (M2's related instances, L2's tooltip grep) rather than a fresh visual
  walkthrough — no regressions assumed there, just not re-screenshotted today.
