# UX rework 03: capability inventory (regression contract)

Session 1 of the Piggybank UX rework epic, built 2026-10-08 from `origin/master` @
`1d27263` (release 1.0.8+9).

**Purpose.** This is the complete list of what a user can do in the app today. The
rework may move, regroup or rename any of it. It may **not** lose any of it. The spec
(`04-spec.md`) must map every row ID below to its new location, and the final
integration session ticks every row on a device.

**Method.**
- Read `lib/core/router/app_router.dart`, `lib/core/router/app_shell.dart` and every
  `lib/features/*/screens/*` and `lib/features/*/widgets/*` file.
- Grepped `context.push|context.go|Navigator…push|MaterialPageRoute|showModalBottomSheet|showDialog|launchUrl`
  across `lib/`, plus every `show*Sheet` helper, then traced each helper to its callers.
- Recorded each button, chip, switch, swipe, long-press and pull-to-refresh as an
  action.

**Legend.**
- **Depth** is taps from Home with the app already unlocked. For example, "2" means
  Home → X → Y.
- **Entry** lists every way in.
- *Sheet* means a modal bottom sheet, and *dialog* means an `AlertDialog`.

---

## A. Gates and auth (go_router, top level)

| ID | Capability | Screen / route | Actions | Entry |
|---|---|---|---|---|
| A1 | Log in | `/login` `LoginScreen` | email + password, show/hide password, Log in, "Forgot password?", "Create account" | cold start when signed out; any redirect |
| A2 | Register | `/register` `RegisterScreen` | name/email/password, show/hide, Create account, back to login | A1 |
| A3 | Forgot password | `/forgot-password` | request code, continue to reset, back | A1 |
| A4 | Reset password | `/reset-password` (email passed via `extra`) | code + new password, show/hide, Reset, then go to `/login` | A3 |
| A5 | Unlock | `/lock` `LockScreen` | biometric prompt; PIN + Unlock; "Use biometrics instead" / "Use PIN instead"; Log out | redirect when `locked` |
| A6 | Accept consents | `/consent` `ConsentScreen` | read each document (dialog), tick, accept, Retry on load error | redirect when `consentsRequired`; **also** Settings → Privacy & consent (I3) |
| A7 | Onboarding tour | `/onboarding` | 6 pages (Penny intro, Home, Invest, Budgets, Assistant, Security), Skip, Next/Done | redirect when `onboardingRequired` |
| A8 | Redirect precedence | `computeRedirect()` | locked → consent → onboarding → shell | must keep its unit-tested behaviour |

## B. Shell

| ID | Capability | Where | Notes |
|---|---|---|---|
| B1 | 5-tab bottom nav | `AppShell` `NavigationBar` | Home `/`, Invest `/invest`, Budgets `/budgets`, Assistant `/assistant`, Settings `/settings` |
| B2 | Per-tab stack preserved | `StatefulShellRoute.indexedStack` | switching tabs keeps scroll and pushed screens |
| B3 | Re-tap the active tab to pop to its root | `goBranch(initialLocation: same index)` | |
| B4 | Tab-switch fade | `_AppShellState` | opacity 1 → 0 → 1, skipped when `reducedMotion` |

## C. Home (`/`, `DashboardScreen`): depth 0

Sections in their fixed order (DESIGN.md §3). The "fixed layout, no customisation"
decision is locked (`piggybank-production-completion.md`).

| ID | Capability | Actions | Leads to |
|---|---|---|---|
| C1 | Pull to refresh all Home data | pull | — |
| C2 | OTA update banner | "Update" opens the APK URL externally (`launchUrl`); Dismiss (×) | browser |
| C3 | "N new transactions to review" banner | tap | D10 Pending review |
| C4 | Net worth hero with trend pill | view only | — |
| C5 | Today / This month cashflow strip | view only | — |
| C6 | Savings card ("gap R Z" / "Set a savings target") | tap | F1 Savings plan |
| C7 | Progress block (most at-risk budget or first in-progress goal) | view only | — |
| C8 | Trends entry card | tap | D8 Trends |
| C9 | Quick links: Accounts / Assets / Liabilities / Calculators | tap each | D1, D5, D6, D9 |
| C10 | Recent transactions preview (dated rows) | "See all" | D3 Transactions |
| C11 | **Add** FAB → transaction sheet | tap | D4 |
| C12 | Notification bell (app bar) | **non-functional placeholder** (DESIGN.md: settled decision, no feature) | — |

## D. Money: accounts, transactions, assets, liabilities, insights

| ID | Capability | Screen | Actions | Entry (depth) |
|---|---|---|---|---|
| D1 | Accounts list + "Total balance" hero; Inactive group | `AccountsScreen` | pull to refresh; tap row → D2; **long-press** row → context menu (Deactivate → confirm dialog); **+ Add account** FAB → sheet (name, type, institution, balance, currency) with paywall on the Pro limit; app-bar icon → D3 | Home quick link (1) |
| D2 | Account detail | `AccountDetailScreen` | pull to refresh; Edit (app bar) → D2a | D1 (2) |
| D2a | Edit account | `AccountEditScreen` | edit fields, **Save changes**, **Deactivate** (confirm dialog) | D2 (3) |
| D3 | Transactions list (grouped by day, paginated) | `TransactionsScreen` | type chips (All/Income/Expense/Transfer); **Filter** sheet (account, type, date from/to, Clear all, Done); **Expenses summary** → D7; **Import CSV / Scan receipt** → D11; "Load more"; pull to refresh; tap row → D4 edit; **Add transaction** FAB → D4 | Home "See all" (1); Accounts app-bar icon (2) |
| D4 | Add / edit transaction sheet | `transaction_sheet.dart` | amount (autofocus, decimal), type segment, top-category chips + full dropdown, account (last-used default; "Couldn't load accounts · Retry"), date picker, description, Save, **Delete** (edit only) | Home FAB (1); Transactions FAB/row (2) |
| D5 | Assets | `AssetsScreen` | pull to refresh; tap row → edit sheet (incl. delete); **+** FAB → add sheet (type, name, value) | Home quick link (1) |
| D6 | Liabilities | `LiabilitiesScreen` → `LiabilityDetailScreen` | list; tap → detail; FAB → add sheet; detail: Edit (app bar) → sheet, record payment (FAB sheet), delete liability (row icon) | Home quick link (1) / (2) |
| D7 | Expenses summary | `ExpensesSummaryScreen` | date-range picker, clear filter | D3 (2) |
| D8 | Trends ("Where the money went", budget vs actual, recurring expenses) | `TrendsScreen` | pull to refresh; view only | Home trends card (1) |
| D9 | Calculators: Loan Calculator / Loan Accelerator | `CalculatorsScreen` | switch segment, inputs, Calculate | Home quick link (1) |
| D10 | Pending review queue | `PendingReviewScreen` | pull to refresh; **swipe right = confirm, swipe left = discard** (`Dismissible`); Confirm button (one-tap when suggested); Edit → confirm sheet (account, category, type segment, Confirm); Discard; Undo snackbar (~4 s) | Home banner (1); Settings → Detection → "Review detected items" (3) |
| D11 | Import: CSV wizard (Configure → Upload → Review) + **Scan receipt** | `ImportsScreen` | template + account pickers, pick file, upload, review rows, confirm dialog, result; receipt photo → parsed result | D3 app-bar icon (2) |

## E. Budgets tab (`/budgets`): depth 1

| ID | Capability | Screen | Actions |
|---|---|---|---|
| E1 | Budgets / Goals segmented toggle | `BudgetsHomeScreen` | segment switch; FAB is context-aware (Add budget / Add goal) |
| E2 | Budgets for a month (grouped, sub-categories indented) | `BudgetsScreen` | previous/next month chevrons; pull to refresh; tap card → edit sheet (amount, category, delete); FAB → add-budget sheet (category dropdown incl. sub-category parent) |
| E3 | Goals | `GoalsScreen` | pull to refresh; tap → edit sheet (target, saved, date, delete); FAB → add-goal sheet |

## F. Savings plan (cost-cutting, 1.0.8)

| ID | Capability | Screen | Actions | Entry (depth) |
|---|---|---|---|---|
| F1 | Savings plan: target card (target, left over, gap, progress), "based on N months" note | `SavingsPlanScreen` | pull to refresh; **Set target** / Edit target → target sheet (amount, label, optional date with clear, income override, Save, Remove target) | Home savings card (1); Settings → Savings plan (2) |
| F2 | Detected recurring-cost suggestions | same | **swipe** or **Confirm / Dismiss** per suggestion, with undo; **Find costs** (run detection) | F1 |
| F3 | Recurring costs list (cut candidates first, "still charged" warning) | same | tap → cost sheet (name, kind, monthly amount, **Keep / Cut candidate / Cut** segment, amount saved, Delete); **Add cost** FAB | F1 |
| F4 | "Where should I cut?" chip | same | opens H1 (Assistant tab) with the question prefilled (`whereToCutQuestion` → chatbot provider → `go('/assistant')`) | F1 (2 → tab switch) |
| F5 | Policy details + data check | `PolicyScreen` | type-specific form (policy type, insurer, province, car make/model/year/value/cover/excess, insured value, cover amount, plan name), link vehicle/property asset, Save, Remove policy details; Policy check card (facts) | F3 insurance row → "Policy" button (3) |
| F6 | Ask Penny about this premium | same | Ask / Ask again; Sources list (each opens the browser via `launchUrl`); paywall on 402; "research paused" state; fixed footnote | F5 (3) |

## G. Invest tab (`/invest`): depth 1

| ID | Capability | Screen | Actions | Entry (depth) |
|---|---|---|---|---|
| G1 | Invest overview: total value hero, allocation donut, top holdings, portfolio list | `InvestScreen` | pull to refresh; **Compare instruments** (app bar) → G6; **+** Add portfolio → sheet (name, type incl. TFSA/RA, paywall on limit); "Create portfolio" (empty state); "See all" → G3; tap portfolio → G2 | tab (1) |
| G2 | Portfolio detail | `PortfolioDetailScreen` | pull to refresh; Edit portfolio (app bar) → sheet (incl. delete); **TFSA ledger** icon → G4 (TFSA portfolios); **RA ledger** icon → G5 (RA portfolios); **Add holding** FAB → holding sheet (ticker autocomplete, quantity, price, asset class, conflict "Use suggested"); tap holding → G2a | G1 (2) |
| G2a | Holding detail sheet | `holding_detail_sheet.dart` | price history, dividends list (add dividend, delete dividend), **Sell** → sell sheet, Edit → holding sheet, Delete | G2 / G3 (3) |
| G3 | All holdings | `AllHoldingsScreen` | pull to refresh; tap → G2a | G1 "See all" (2) |
| G4 | TFSA contribution ledger | `TfsaLedgerScreen` | lifetime/annual caps; add contribution (FAB sheet), delete contribution | G2 (3) |
| G5 | RA ledger + growth projection | `RaLedgerScreen` | add contribution (FAB sheet), delete contribution | G2 (3) |
| G6 | Instrument comparison | `InstrumentComparisonScreen` | pick instruments, period dropdown, switch, compare, "How to read this" dialog | G1 (2) |

## H. Assistant tab (`/assistant`): depth 1

| ID | Capability | Screen | Actions |
|---|---|---|---|
| H1 | Penny chat | `ChatbotScreen` | suggested-question chips; type + send (keyboard submit or send button); message list; Retry on a failed reply; paywall on 402; accepts a prefilled question from F4 |

## I. Settings tab (`/settings`, `placeholder_screens.dart` `SettingsScreen`): depth 1

Row order as shipped:

| ID | Row → screen | Actions inside | Depth |
|---|---|---|---|
| I1 | Profile (name/email row) → `ProfileScreen` | view email, edit name, Save | 2 |
| I3 | Privacy & consent → `ConsentScreen` | same as A6 (read/accept documents) | 2 |
| I4 | Subscription → `SubscriptionScreen` | "What Pro unlocks", Refresh status, **Upgrade to Pro** (external checkout via `launchUrl`), Cancel subscription | 2 |
| I5 | Savings plan → F1 | (second entry to F1) | 2 |
| I6 | Import history → `ImportHistoryScreen` | view past imports | 2 |
| I7 | Appearance → `AppearanceScreen` | System / Light / Dark | 2 |
| I8 | Security → `SecurityScreen` | biometric switch (with never-zero-unlock rule), Set/Change PIN (dialog), Remove PIN, **Export my data** → `/settings/data-export` (I8a), **Delete my account** (password dialog + destructive confirm) | 2 |
| I8a | Data export → `/settings/data-export` `DataExportScreen` | load, Retry, Copy to clipboard | 3 |
| I9 | Notifications → `NotificationsScreen` | per-type switches (backend preferences) | 2 |
| I10 | Notification & email detection → `DetectionSettingsScreen` | feature consent ("Review & enable"), Grant notification access, allowlisted apps (Add dialog, choose senders dialog, remove), Gmail Connect/Disconnect (external OAuth via `launchUrl`), allowlisted email senders (Add dialog, remove), **Review detected items** → D10 | 2 |
| I11 | About → `AboutScreen` | version/build info | 2 |
| I12 | Log out | signs out → A1 | 1 tap |

(I2 is unused: no row.)

## J. Shared cross-cutting behaviour

| ID | Capability | Where |
|---|---|---|
| J1 | Pro paywall prompt | `shared/widgets/paywall_dialog.dart`, raised on 402 from accounts, portfolios, chat, policy research |
| J2 | Destructive confirm dialog | `shared/widgets/confirm_dialog.dart` |
| J3 | Inline error with Retry | `shared/widgets/state_views.dart` `InlineError(onRetry:)` |
| J4 | Undo snackbars | review queue (D10), savings suggestions (F2) |
| J5 | Reduced-motion respect | `context.reducedMotion` (shell fade, motion tokens in `app_motion.dart`) |
| J6 | Light / dark theme | I7 + `app_theme.dart` |
| J7 | Auto-capture (SMS/notification listener → pending events) | native channel + `detection/` providers. **Not a screen**, but its entry points (D10, I10) must survive |
| J8 | OTA update check | `updates/` feature, surfaced as C2 |

---

## Reconciliation against the grep

Every navigation, sheet, dialog and external-link site found by the grep maps to a row:

| Site type | Sites | Maps to |
|---|---|---|
| `Navigator.push(MaterialPageRoute…)` | **31** | Settings rows I1, I3–I11 (10) · Home C3, C6, C8, C9 ×4, C10 (8) · D1→D3, D1→D2, D2→D2a, D3→D7, D3→D11, D6 list→detail, I10→D10 (7) · G1→G6, G1→G3, G1→G2, G2→G4, G2→G5 (5) · F3→F5 (1) |
| `context.push` / `go` (go_router) | **6** | A1→A2, A1→A3, A3→A4, A4 `go('/login')`, I8→I8a, F4 `go('/assistant')` |
| `showModalBottomSheet` call sites | **21** | D1 add + long-press menu (2), D5 add + edit (2), E2 add + edit (2), E3 add + edit (2), D6 liability sheet + payment (2), G2 holding, G2a detail + sell (3), G1/G2 portfolio sheet (1), G5 add (1), F1 target (1), F3 cost (1), G4 add (1), D3 filter (1), D4 (1), D10 confirm (1) |
| `showDialog` | **13** | D1 deactivate, D2a deactivate, A6 document viewer, I10 ×3 (choose senders, add app, add sender), D11 import confirm, G6 "how to read", I8 ×3 (PIN, password, delete account), J1 paywall, J2 confirm |
| `launchUrl` (external) | **4** | C2 APK download, I10 Gmail OAuth, F6 source links, I4 checkout |

**Intentional exclusions:** none. Comment-only matches (`app_theme.dart` doc comments,
the `chatbot_screen.dart` and `trends_screen.dart` doc comments) are not navigation.

## Observations for the audit (facts, not fixes)

These are structural facts about the inventory. The audit (`02-audit.md`) scores them
against the principles.

1. **Three features have two entry points each:** Savings plan (Home card + Settings
   row), Pending review (Home banner + Settings → Detection), and Consent (the gate +
   Settings).
2. **Transactions has no tab.** It is reached through Home "See all" or the Accounts
   app-bar icon, even though it is the most-used list (UX plan D3).
3. **Settings is mixed:** account (Profile, Subscription, Security), app preferences
   (Appearance, Notifications), data plumbing (Detection, Import history), and one
   *feature* (Savings plan).
4. **Home carries 11 sections plus a FAB,** including 4 quick links to rarely used
   screens (Liabilities, Calculators).
5. **Account deactivation on the list is long-press only (D1).** It is also a visible
   button in D2a, so it is discoverable, but two taps deeper.
6. **Depth-3 features:** Policy check / Ask Penny (F5/F6), TFSA/RA ledgers (G4/G5),
   holding detail (G2a), data export (I8a), edit account (D2a), and review via Settings
   (I10 → D10).
7. **Import (D11) is an icon on Transactions.** Its history (I6) is in Settings.
8. **The bell icon (C12) is a dead affordance** on the daily screen.

## Row count

- **Capability rows:** 73 (A1–A8, B1–B4, C1–C12, D1–D11 + D2a, E1–E3, F1–F6,
  G1–G6 + G2a, H1, I1, I3–I12 + I8a, J1–J8).
- Every row has to appear in the spec's old → new mapping table.
