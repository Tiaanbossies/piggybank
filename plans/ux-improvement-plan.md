# UX improvement plan: the daily flow

Written 2026-10-06. Serves the goal in `next-goal-friends-family-beta.md`, Phase A: make
daily use take **under 1 min/day** before the 14-day streak, then the beta.

The evidence comes from two sources:
- **Emulator walkthrough** (2026-10-06, v1.0.3, demo account). The backend wasn't reachable
  from the emulator, so this pass measured screens and taps, not live numbers.
- **Critique snapshot.** The daily flow scored 21/40 (Acceptable). Saved at
  `.impeccable/critique/2026-10-06T05-29-47Z__…dashboard-screen-dart.md`.

Budget: a few hours a week. **Each item is one small PR** with its own widget tests.

## Already done (on `feat/one-tap-review`, not yet merged)

- One-tap confirm when a suggested category exists. Swipe right confirms, swipe left
  discards, with about 4s to Undo. The sheet is still available behind Edit.
- A "N new transactions to review" card on Home.
- **Remaining:** update `pending_review_screen_test.dart`, then cover the dashboard card
  and the no-detection-API case in `dashboard_screen_test.dart`. Run the suite and merge.
  This is item 0 below.

## Core daily tasks: tap counts

| Task | Before (v1.0.4) | After this plan |
|---|---|---|
| See today's spend | **Not possible.** Home only shows "Cashflow · This month". Recent rows have no dates. | **0 taps** (on Home when the app opens) |
| Review new transactions | 3 taps to reach the screen (Settings → Detection → Review), then ~4 per item (Confirm → pick category → Confirm) | **1 tap + 1 per item** (done in item 0) |
| Add a manual transaction | **8 taps + 1 scroll + typing** (scroll Home → See all → FAB → Amount → Category ▾ → pick → Account ▾ → pick → Save) | **3 taps + typing** (Add → category chip → Save) |
| Check a budget | 1–3 taps (Budgets tab, but it can reopen on **Goals**, and on **last month**: it showed September in October) | **1 tap**, or 0 if an at-risk budget shows on Home |

## The plan, in shipping order

Items 1–3 should ship before the 14-day streak starts. Items 4–5 follow.

### 0. Land one-tap review (S): finish what's in flight
- **Problem:** the code is built but untested and unmerged.
- **Change:** tests only. The card's Confirm now commits directly when a suggestion exists
  (the existing "Confirm opens sheet" tests need to use Edit, or a no-suggestion event).
  Swipe right confirms, swipe left discards, Undo stops the API call, and a failed commit
  brings the card back. Override `detectionApiProvider` in the dashboard tests.
- **Files:** `test/features/detection/screens/pending_review_screen_test.dart`,
  `test/features/dashboard/dashboard_screen_test.dart`.
- **Done when:** `flutter test` is green, and on the phone the About screen shows
  1.0.5+6 and the review card appears on Home.

### 1. "Today" on Home (S): the reason to open the app
- **Problem:** nothing on Home changes from day to day. Net worth barely moves, and
  "This month" read R0,00 / R0,00 on 6 October. There's no reason to look, so no habit forms.
- **Change:** turn the cashflow strip into **Today · This month**: today's spend next to the
  month's totals. Compute today client-side from the existing transactions endpoint
  filtered to today (no backend change). Add a muted relative date ("Today", "Yesterday",
  "3 Oct") to Home's recent-transaction rows.
- **Files:** `lib/features/dashboard/screens/dashboard_screen.dart` (`_CashflowStatStrip`,
  `_RecentTransactionsPreview`), plus a small `todaySpendProvider` beside
  `recentTransactionsProvider` in `lib/features/transactions/providers/transactions_provider.dart`.
- **DESIGN.md:** fits. The compact stat strip allows "2-3 small stat blocks" (§ Signature
  components 2). It does **not** touch the net-worth hero (see decision D1).
- **Tests:** the strip shows today's expense total from mocked transactions and an
  empty-day state ("R 0,00 today"). Recent rows show "Today" or "Yesterday".
- **Done when:** opening the app answers "what did I spend today?" with zero taps.

### 2. Quick add from Home (M): 8 taps down to 3
- **Problem:** Add lives three levels deep (Home → scroll → See all → FAB). The sheet
  doesn't focus Amount, has no default account, and makes you open two dropdowns.
- **Change:**
  - Move `_TransactionSheet` out of `transactions_screen.dart` into its own widget file so
    Home and Transactions share one sheet.
  - Add an **Add** FAB on Home that opens it. Give the list enough bottom padding to clear
    the FAB (prior audit finding H2 was exactly this overlap).
  - In the sheet, Amount gets `autofocus` and a decimal keypad.
  - Show the account **last used** as the default, remembered locally on the device.
  - Show category as a row of the 6 most-used categories as chips, with "More…" opening
    the full list.
- **Files:** a new `lib/features/transactions/widgets/transaction_sheet.dart`,
  `transactions_screen.dart`, `dashboard_screen.dart`.
- **DESIGN.md:** a Home FAB is new, not forbidden. §3 lists Home's components and has no FAB,
  but Accounts already uses a persistent FAB (§4). Confirm you're happy with it (decision D2).
- **Tests:** the Home FAB opens the sheet; Amount has focus; the last-used account is
  pre-selected; tapping a chip then Save calls `create` with that category.
- **Done when:** a cash purchase is logged in 3 taps and under 10 seconds.

### 3. Categories that match your data (S)
- **Problem:** the add sheet uses the hard-coded 12-item `commonCategories`, which are
  expense-only. Your data says "Dining Out", "Salary", "Freelance", "Interest"; the sheet
  offers "Dining" and no income categories. Mismatched names split budgets and spending
  reports.
- **Change:** feed the sheet from the existing `transactionCategoriesProvider` (already in
  `transactions_provider.dart:156`, it collects the categories your transactions use),
  filtered by Expense, Income or Transfer and ordered by use. Keep `commonCategories` as
  the cold-start fallback it already is.
- **Files:** `transaction_sheet.dart` (from item 2), `transactions_provider.dart`.
- **Tests:** the Income tab shows only income categories; "Dining Out" from your data
  appears; an empty history falls back to `commonCategories`.
- **Done when:** you never type or pick a category name that differs from what your
  budgets use.

### 4. Budgets that open on now (S)
- **Problem:** `selectedBudgetMonthProvider` sets the month once, when the app first
  starts, so a long-running app showed **September** in October. The tab also reopens on
  the Goals segment, and Home's progress card shows a **completed** goal (the existing
  TODO in `_ProgressBlock`) instead of something you can act on.
- **Change:**
  - Reset the selected month to the current month when the app resumes in a new month.
  - Open Budgets on the Budgets segment by default.
  - On Home, pick the most at-risk budget for this month, or the first in-progress goal,
    and skip completed goals.
- **Files:** `lib/features/budgets/providers/budgets_provider.dart`,
  `lib/features/budgets/screens/budgets_home_screen.dart`, `dashboard_screen.dart`
  (`_ProgressBlock`).
- **Tests:** the month provider resets after a simulated month change; a completed goal
  is skipped in favour of an over-budget category.
- **Done when:** "am I on budget?" is answered on Home, or one tap away, for the current month.

### 5. Errors you can recover from (S)
- **Problem:** "Network error. Check your connection and try again." on Transactions and
  Budgets is a dead end, with no Retry. Transactions shows it in black text and Budgets in
  red. The add sheet **silently removes the Account field** when accounts fail to load, so
  you'd save transactions with no account and never know.
- **Change:**
  - Add an optional `onRetry` to the shared `InlineError` in `state_views.dart` and use it
    on Transactions, Budgets and Home. Use one consistent style.
  - In the sheet, replace the silently hidden field with "Couldn't load accounts · Retry".
- **Files:** `lib/shared/widgets/state_views.dart`, `transactions_screen.dart`,
  `budgets_home_screen.dart`, `transaction_sheet.dart`.
- **Tests:** tapping Retry re-calls the API; an accounts error shows the retry row, not
  nothing.
- **Done when:** a bad signal moment costs one tap, not leaving and coming back.

## Decisions for you (not scheduled, because each changes a locked rule)

- **D1. Should the Home hero stay Net Worth?** DESIGN.md §3 locks it ("same fixed vertical
  order"). For daily use, today's spend or this month's budget left would earn that slot
  better. Item 1 works without changing it.
- **D2. Home FAB (item 2):** an addition, not a violation. Just confirm it.
- **D3. A Transactions tab?** The 5-tab nav is locked (Home / Invest / Budgets /
  Assistant / Settings). Transactions, your most-used list, has no tab, while Assistant
  takes a slot. Swapping Assistant for Transactions (with Assistant reached from Home or
  the app bar) would shorten every "what did I spend?" trip. Not needed if items 1 and 2
  land, so revisit after the streak.

## Beta items (separate, Phase B of the goal doc, not part of this plan)

Public install link (not Tailscale); first-run onboarding without help, including empty
states for a brand-new account; capture for testers' banks; in-app feedback; Pro free for
everyone. Plan these after the streak, from `next-goal-friends-family-beta.md`.

## Patterns to follow

| Category | Source | Pattern |
|---|---|---|
| Providers | `transactions_provider.dart`, `summaries_provider.dart` | `FutureProvider.autoDispose` per data need, API via `*ApiProvider` |
| Errors | `lib/shared/widgets/state_views.dart:47` | `InlineError(message:)`; extend it, don't fork it |
| Sheets | `transactions_screen.dart:148` | `showModalBottomSheet(isScrollControlled: true)` |
| Tests | `test/features/detection/screens/pending_review_screen_test.dart` | mocktail API mocks + `pumpApp(..., overrides:)` |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Today's spend is computed client-side from a paged transactions list | Medium | Query with `date_from = today`. One day never exceeds a page. |
| The Home FAB hides the last recent row | High (it happened before, H2) | Bottom padding on the list. A test checks the last row is hittable. |
| Learned categories inherit old typos | Low | Order by use count; rarely used typos sink below "More…". |

## Validation (each PR)

```bash
flutter analyze
flutter test
```

Then install on the phone and re-count the taps in the table above.
