# Piggybank — UI/UX Context Brief for Mockup Design

**Purpose of this document**: a self-contained product/UX reference for designing Piggybank mockups, extracted from the live codebase (not aspirational docs alone). Hand this whole file to a design AI as context. It documents what exists today, what's planned but unbuilt, exact data available per screen, and open product questions — it does **not** prescribe a redesign.

---

## 1. App overview

**Piggybank** is a native Android (iOS later) personal-finance app being migrated from an existing React/FastAPI web app called **"The Clear Ledger."** It consolidates: bank accounts, CSV-imported and manually-entered transactions, budgets, goals, assets, liabilities, net worth, and (planned) investment portfolios, TFSA/RA retirement contributions, and CSV/OCR imports.

**Migration status**: Phase 1–3 of a 9-phase plan are built and live-verified:
- Phase 1: Auth, Accounts
- Phase 2: Transactions, Expenses, Budgets, Goals
- Phase 3: Assets, Liabilities, Calculators, Dashboard/Summaries
- **Not yet built**: Phase 4 (Portfolios/Investments — largest phase), Phase 5 (CSV/OCR Import), Phase 6 (Instrument Comparison, RA/TFSA), Phase 7+ (infra, final parity, iOS).

**Tech stack**: Flutter, Riverpod (state management), go_router (navigation), Dio (HTTP), `decimal` package for money (never `double` — precision matters, see §11), `flutter_secure_storage` (refresh token), `local_auth` (biometric lock), `google_fonts`, `fl_chart` (dependency present, currently **unused** — no chart renders anywhere in the app yet, reserved for Investments/Insights).

**Platform**: Android-first, phone-sized layouts only. No tablet or desktop breakpoints, no responsive/adaptive layout code exists anywhere. Design for a single phone form factor.

**Theming**: Light and dark mode are both first-class, fully implemented, not an afterthought — every screen must work in both.

**Backend**: FastAPI, ZAR currency only, South African context (SA bank names, SA tax year March–Feb, POPIA privacy framing). Money fields are Decimal-as-JSON-string server-side; the app never uses floating point for currency.

---

## 2. Visual direction

**Update, 2026-08-16 — this section is now resolved, not aspirational.** The 9 mockups
this brief originally anticipated have been delivered (`assets/WhatsApp Image
2026-08-16 at 14.23.4x.jpeg`) and `DESIGN.md` has been rewritten to match them in full
(see its "Revision — 2026-08-16" header). The rest of this section is kept as a record of
what was asked for vs. what `DESIGN.md`'s superseded spec said — read `DESIGN.md` directly
for the current, authoritative palette/typography/component values.

**User's stated target for this mockup round**: clean, professional, approachable personal finance — mostly white and black, one restrained accent colour such as green. Explicitly **not** a corporate-SaaS dashboard look. **Confirmed by the delivered mockups**: white background, near-black text, one green accent used for buttons/active-nav/progress/positive figures, red reserved for over-budget/destructive states only.

**What the (now-superseded) `DESIGN.md` used to lock**:
- Palette: warm cream background (`#FAF7F2`/dark `#1A1613`), warm charcoal-brown text (not pure black), terracotta-orange accent (`#D9703F`/dark `#E8875C`), sage-green success (`#5A8567`), crimson danger (`#B03A2E`).
- Typography: **Manrope** (UI/body), **IBM Plex Mono** with tabular figures (every money/percentage value, no exceptions).
- Shape: 20px card corner radius, fully pill-shaped buttons, soft low-opacity warm-tinted shadows, no box-in-box nesting.
- Iconography (spec'd but **not implemented in code** — app currently uses stock Material `Icons.*`): custom 1.5px-stroke line icons, plus a "ledger-line grid" background texture on empty states and login only.
- Brand tone: "warm and human... not a gamified trading app (no confetti, no streaks, no badges)... no literal piggy-bank mascot."

**What the mockups confirmed vs. reversed** (see `DESIGN.md` for the full rewrite): pill buttons, dark-mode-as-first-class-target (in principle — no dark mockup exists), and the no-gamification/5-tab-nav constraints all carried over unchanged. Two things reversed outright: the mockups *do* use a literal 3D piggy-bank mascot repeatedly, and money figures are *not* set in a distinct mono face — both flagged in `DESIGN.md`'s revision header as deliberate pivots, not oversights. Card shape shifted from "flat, no per-row border" to "every row is its own white bordered/shadowed card."

---

## 3. Navigation & information architecture

### Bottom navigation (locked, 5 tabs — Material 3 `NavigationBar`)
`Home` · `Invest` · `Budgets` · `Insights` · `Settings`

This is a **locked structure** — adding a 6th tab is a real design decision, not a given. Today: Home and Budgets are implemented; Invest and Insights are placeholder "coming soon" stubs; Settings is a minimal stub (view user + log out only).

### Auth state machine (drives top-level routing)
- `unknown` (session-restore in progress) → blank/splash, no redirect yet.
- `unauthenticated` → Login (or Register).
- `authenticated` + `locked: true` → Lock screen (biometric/PIN). **Every restored session lands on Lock first**, even if the device has no biometrics enrolled (in which case it silently unlocks without prompting). Fresh logins/registrations skip Lock entirely.
- `authenticated` + `locked: false` → the 5-tab shell.

### Reachability graph (push-based screens with no tab of their own)
Several domains have no bottom-nav slot and are reached only by pushing from Home:

```
Home (tab)
 ├─ quick-link → Accounts
 │                ├─ AppBar icon → Transactions
 │                │                 └─ AppBar icon → Expenses Summary
 ├─ quick-link → Assets
 ├─ quick-link → Liabilities
 ├─ quick-link → Calculators (2 tabs: Loan Calculator / Loan Accelerator)
 └─ "See all" (recent transactions) → Transactions
```
All of these are `Navigator.push` (modal-stack push, standard back button), not named routes — they have no deep-link URL today.

### Budgets tab internal structure
One tab, two views toggled by a segmented control: **Budgets** / **Goals**. Not two separate tabs — a single screen with an in-page switch. The FAB's label/action changes with the active segment ("Add budget" / "Add goal").

---

## 4. Screen inventory — implemented today

For each: purpose, key info shown, primary/secondary actions, how reached/left, states.

### 4.1 Login
- **Purpose**: authenticate returning users.
- **Shows**: "Piggybank" wordmark, email field, password field (obscured), inline flat error text.
- **Primary action**: "Log in" button (spinner while submitting).
- **Secondary**: text link "Don't have an account? Register" → Register screen.
- **Reached**: app cold-start when unauthenticated. **Left**: successful login → shell (or Lock, on restored sessions — not applicable here since fresh login skips lock).
- **Error state**: single flat error message under the fields, no field-level errors.

### 4.2 Register
- **Purpose**: create a new account.
- **Shows**: AppBar "Create account"; fields: Full name (optional), Email, Password (obscured).
- **Primary action**: "Register" button.
- **Errors**: this is the *only* screen with field-level 422 validation errors (shown as `errorText` under Email/Password) in addition to a flat error summary.
- **Reached**: from Login's text link. **Left**: success → shell directly (skips Lock).

### 4.3 Lock / biometric unlock
- **Purpose**: app-lock gate on session restore.
- **Shows**: lock icon, "Piggybank is locked" text, then either a spinner (auto-prompting) or an "Unlock" button (manual retry after a failed/dismissed prompt).
- **Primary action**: biometric prompt (auto-triggered), or tap "Unlock" to retry.
- **Reached**: automatically on authenticated+locked state. **Left**: successful unlock → shell. No PIN-code fallback UI exists (device biometric or nothing) — a known limitation worth a design decision.

### 4.4 Dashboard (Home tab root)
- **Purpose**: at-a-glance net worth, cashflow, one progress highlight, recent activity, and a jump-off point to domains without their own tab.
- **Shows**, top to bottom (fixed order, not customizable by user):
  1. **Net worth hero**: single large mono figure (`Net worth` label + ZAR total).
  2. **Cashflow stat strip**: Income (green) / Expenses (red) for the current month, no month picker.
  3. **Progress block**: the *first* active Goal's name + progress bar + percentage; if no goals exist, falls back to the *first* Budget's category + progress bar (danger-colored if over budget). Only ever shows one item — not a list.
  4. **Quick-links row**: chips for Accounts / Assets / Liabilities / Calculators.
  5. **Recent transactions preview**: up to 5 most recent transactions (merchant, category, signed colored amount) + "See all" link to the full Transactions screen.
- **Actions**: pull-to-refresh (reloads all sections); tapping any quick-link chip or "See all".
- **States**: each section fails/loads independently (partial-failure tolerant) — e.g. if net worth fails to load, the transactions preview can still render.
- **Note**: DESIGN.md specifies a *ring*-style progress indicator for this hero progress block; the current implementation uses the same flat linear bar as every list screen. Flag as a design decision (§13).

### 4.5 Accounts
- **Purpose**: list of bank/cash/savings accounts and their balances.
- **Shows**: "Accounts" heading, active accounts (name, muted institution subtext, right-aligned ZAR balance), then a collapsed "Inactive" group below if any exist. Empty state: "No accounts yet."
- **Primary action**: FAB "Add account" → bottom sheet (Account name, Type dropdown: Bank account / Savings account / Cash; currency fixed to ZAR).
- **Secondary**: AppBar icon → Transactions.
- **Reached**: Dashboard quick-link. **Left**: system back, or AppBar icon forward to Transactions.
- **Known gap**: **no edit or deactivate UI at all** — tapping a row does nothing. The backend supports soft-delete/deactivate (an account can be deactivated and later restored) and the Flutter API layer has the method, but no screen calls it. This is a strong candidate for a missing screen (§13).
- **Also missing from the Add sheet**: institution name and opening balance fields (backend supports both, UI collects neither).

### 4.6 Add/Edit Account *(edit does not currently exist — recommend for mockups)*
- Backend supports: name, account type (bank/savings/cash — free-form string on the model, but UI-constrained to 3 options), currency, institution name, opening balance, active/inactive state.
- A real edit flow would need: rename, change institution, deactivate (with restore path for inactive accounts), and ideally viewing that account's transactions filtered.

### 4.7 Transactions
- **Purpose**: full transaction ledger — the core daily-use screen.
- **Shows**: AppBar "Transactions"; list grouped by date (day headers "D Mon YYYY", newest first), each row: merchant/description title, category subtext, signed colored ZAR amount (green income, red expense). Empty state: "No transactions yet."
- **Primary action**: FAB "Add transaction" → bottom sheet.
- **Add/Edit sheet fields**: type (segmented: Expense / Income / Transfer), Amount, Category (free text), Merchant (optional), Account (optional dropdown, active accounts only, "No account" option), Date (date picker), Notes (optional). Edit mode adds a red "Delete" button.
- **Secondary**: AppBar icon → Expenses Summary.
- **Reached**: Dashboard "See all", or Accounts screen's AppBar icon.
- **Known gaps**:
  - **No filter UI exists**, despite the backend and app-layer state (account/type/date-range/category filters) being fully built — nothing on screen lets the user set them. A filter entry point (icon, bottom sheet, or search bar) is a clear missing-but-required piece.
  - **No pagination/infinite-scroll** — only the first 50 transactions ever load, with no "load more."
  - Category is currently a free-text field, not a picker from the fixed category list (§9) — worth a design decision on whether mockups should show a category *picker* instead.

### 4.8 Expenses Summary
- **Purpose**: read-only category breakdown of expenses over a date range.
- **Shows**: AppBar "Expenses"; "Total" hero figure; "By category" list (category name or "Uncategorised", transaction count, category total). Empty state: "No expenses in this period."
- **Actions**: filter icon → date-range picker; clear-filter icon (shown only when a filter is active).
- **Reached**: Transactions screen's AppBar icon. **Left**: back to Transactions.
- **Gap**: month-by-month breakdown data (`byMonth`) is fetched from the backend but never rendered — no chart despite `fl_chart` being available. A bar/line chart of spend-over-time is a natural mockup addition here.
- Purely read-only — no CRUD, no FAB.

### 4.9 Assets
- **Purpose**: track owned assets that feed net worth (not just bank cash).
- **Shows**: flat list — name, subtext (type label + institution if set), right-aligned ZAR current value. Empty state: "No assets yet."
- **Primary action**: FAB "Add asset" → bottom sheet (Type dropdown, Name, Current value, Institution optional). Row tap → same sheet pre-filled, plus red "Delete" button.
- **Reached**: Dashboard quick-link.
- **Asset types** (7): Cash, Savings account, Property, Vehicle, Investment, Retirement, Other.
- **Known gap**: `valuationDate` exists on the model but is never captured/shown in the UI. The backend also supports a much richer "savings account" sub-type (interest rate, bank/product presets, monthly fee, live interest-preview calculator) that is entirely unbuilt — flagged as out-of-scope-for-now in code comments, but worth knowing about if mockups want to gesture at it.

### 4.10 Liabilities
- **Purpose**: track debts that feed net worth.
- **Shows**: flat list — name, type-label subtext, right-aligned red ZAR outstanding amount. Empty state: "No liabilities yet."
- **Primary action**: FAB "Add liability" → bottom sheet with a **smart-form toggle** (create-mode only): "Amount owed" (single outstanding-amount field) vs. "Loan details" (Original loan amount, Annual interest rate %, Term in months, Start date — the backend auto-computes the current outstanding balance from these). Edit mode only exposes the plain outstanding-amount field (loan params aren't editable after creation via this UI).
- **Row tap**: opens the edit sheet + red "Delete" button.
- **Liability types** (6): Credit card, Personal loan, Vehicle loan, Mortgage, Tax, Other.
- **Reached**: Dashboard quick-link.
- **Known gap**: no payment-log or amortisation-progress UI — the backend supports logging individual payments against a liability and computing repayment progress (% paid, projected payoff date, total interest paid), none of which is surfaced. A "Liability detail" screen with a payment history + progress bar is a natural missing screen.

### 4.11 Budgets (Budgets tab, segment 1)
- **Purpose**: monthly spending budgets, optionally split into sub-categories.
- **Shows**: month selector (‹ Month YYYY ›, defaults to current month); grouped progress list — one row per top-level budget (category name or "Total" for the overall budget), each with spent/budgeted ZAR figures and a progress bar (accent color, or red + "over budget" caption when exceeded); sub-category budgets render indented one level under their parent. Empty state: "No budgets for this month."
- **Primary action**: FAB "Add budget" → sheet (Amount, Category optional — blank means the overall total budget, optional Parent-budget dropdown to nest under an existing top-level budget for that month).
- **Known gap**: **no edit or delete UI** — tapping a budget row does nothing, despite the backend/API layer fully supporting update and delete. This is a strong missing-screen candidate.
- **Reached**: Budgets tab, "Budgets" segment (default).

### 4.12 Goals (Budgets tab, segment 2)
- **Purpose**: savings goals with a target amount and progress.
- **Shows**: flat list — name, percentage, progress bar, current/target ZAR amounts. Empty state: "No goals yet."
- **Primary action**: FAB "Add goal" → sheet (Goal name, Target amount, Starting amount — defaults to 0).
- **Known gap**: **no edit/delete UI**, despite the backend supporting update (including a status field: Active / Completed / Paused), delete, and additional fields never surfaced anywhere — target date, category, notes. All of these exist on the data model and API but have zero UI presence.
- **Reached**: Budgets tab, toggle to "Goals" segment.

### 4.13 Calculators
- **Purpose**: pure client-side loan math, no backend/persistence involved at all.
- **Shows**: AppBar "Calculators" with 2 tabs:
  - **Loan Calculator**: inputs (Loan amount, Annual interest rate %, Term in months) → outputs monthly payment.
  - **Loan Accelerator**: inputs (Outstanding balance, Annual interest rate %, Remaining term, Extra monthly payment) → outputs months saved + interest saved.
- **Reached**: Dashboard quick-link. Fully self-contained, no external data dependency — good candidate for an unusually playful/visual mockup treatment since it's low-stakes.

### 4.14 Settings (Settings tab — currently a stub)
- **Shows**: "Settings" heading; if logged in, a row showing the user's name/email; a working "Log out" action.
- **This is the only functioning piece.** No profile editing, no password change, no theme toggle, no notification preferences, no consent/privacy management, no subscription/upgrade entry point — all absent from the current build. See §10 and §13 for what a complete Settings screen would need.

### 4.15 Invest tab & Insights tab
Both are pure "`{Title}` — coming soon" placeholder text, no data, no widgets, visually identical to each other. Invest is the intended home for the Investments/Portfolio work (§5); Insights is deferred (AI-generated financial summaries, gated behind a PRO subscription — see §5.10).

---

## 5. Screen inventory — planned but not yet built in Flutter

The backend for all of these already exists and is fully functional; the **web app** ("The Clear Ledger") has a working (if dense/desktop-oriented) UX for them that Flutter has not yet ported. Use this section as the source of truth for what these screens need to *do*, not how they should *look*.

### 5.1 Investments Overview
- **Purpose**: cross-portfolio landing dashboard — the natural destination for the "Invest" tab.
- **Key info** (from backend `InvestmentOverview`): total value, total cost, unrealized P&L, YTD dividends, portfolio count, holding count, an **allocation breakdown by asset class** (Stock/Equity/Bond/ETF/Crypto/Cash/Other, sorted by value), and a **top-5 holdings** list (ticker, name, value, unrealized P&L) aggregated across every portfolio the user owns.
- **On the web**: 4 KPI tiles, a stacked-bar allocation chart, a card grid of "my portfolios" (each showing type badge, name, total value, unrealized P&L), an "All Holdings" merged table with click-to-expand fund-factsheet rows, and a Quick Actions panel (Add holding → routes into Portfolios; View portfolios; Open TFSA; Open RA; View insights; Refresh prices — with a "prices last refreshed at" timestamp).
- **Empty state** (zero portfolios): full-page CTA "No investments yet / Create a portfolio to start tracking your investments" → Create Portfolio.

### 5.2 Portfolios (list)
- **Purpose**: CRUD list of the user's investment "buckets."
- **Key info per row**: name, type badge, currency badge, description, created date.
- **Create form fields**: Type (General / TFSA / RA / Day Trading — **TFSA and RA are singletons**, only one of each allowed per user, disabled in the dropdown once created), Name, Currency (default ZAR), Description (optional).
- **Actions**: open (→ Portfolio Detail), delete (with a "cannot be undone" confirmation).
- **Free-tier limit**: 1 portfolio max (see §5.10 paywall). Pro: unlimited.

### 5.3 Portfolio Detail — the largest, most complex screen in the whole product
- **Purpose**: everything about one portfolio — value, allocation, holdings, dividends, trades.
- **Header**: editable portfolio name, holding count + description subtitle, currency badge.
- **Value summary** (4 stat tiles): Total Value, Total Cost, Unrealized P&L (colored), **Realized P&L — only shown once non-zero** (i.e. hidden until the user has actually sold something; don't show a permanent "R0" tile).
- **Allocation**: donut/pie by asset class, legend with name + percent. Renders nothing at all if there are no valued holdings (no empty-state placeholder needed here — it just doesn't appear).
- **Dividends section**: year selector (last 5 years); a year-summary card (Received total, Tax withheld total) plus a simple month-by-month bar breakdown for that year. Empty: "No dividends recorded this year."
- **Holdings table** — columns: **Ticker, Name, Asset Class, Year, Quantity, Cost Basis, Current Price, Value, P&L, P&L %, Realized P&L** (shows "—" until a sale exists), **Last Updated** (a clock icon; turns warning-colored + tooltip if the price is ≥24h stale; muted "—" if never updated), **Actions**. Sortable by Ticker/Value/P&L/P&L%. Closed (fully-sold) holdings render dimmed with a static "Closed" pill instead of action buttons.
  - **Row actions**: Dividends (expand/collapse an inline sub-panel), Sell (hidden once closed), Edit, Delete.
  - **Current Price is inline-editable** directly in the table (manual price override).
  - **Ticker cell → sparkline**: tap/hover reveals a small 1-month price-trend chart popover (colored by direction), with last price + period lo/hi labels.
- **Add/Edit Holding**: Ticker, Name, Asset class, Quantity, Cost basis, optional Year, optional Current price. **Ticker-lookup autocomplete** is a signature interaction: typing/blurring the ticker field looks up the symbol and auto-fills Name/Price/inferred Asset class — but if the user already typed something different manually, the app **keeps the user's input** and shows a small conflict banner ("Lookup returned X. Kept your manual entry Y.") with a one-tap "Use suggested value" per field, rather than silently overwriting. This exact pattern is reused identically in 3 places on web (Add Holding, Edit Holding, Instrument Comparison's ticker search) — treat it as one canonical, reusable interaction, not three separate ones.
- **Sell modal**: Quantity to sell (validated ≤ current holding quantity), Price per unit, Trade date, optional Fee, optional Note. Submit button is intentionally styled as a **destructive/red action** even though it's a normal workflow step (selling records an audit-trail Trade, it does not just edit the holding). Shows "Available: {qty} units" for reference.
- **Dividend sub-panel** (expands under a holding row): table of Date/Amount/Currency/Tax Withheld/Note + delete, plus a compact inline add-row form.
- **Projected Income table** (bottom of screen, only shown if ≥1 priced holding): Ticker, Name, Market Value, **Dividend Yield % (inline-editable, live-recalculates Annual/Monthly Income as you type)**, Annual Income, Monthly Income, with a summed "Total" footer row — effectively a live what-if income-projection tool.
- **Deletes** (holding, dividend, portfolio) all go through an explicit "this cannot be undone" confirmation.

### 5.4 Add Holding (as a distinct mockup surface, since it's this dense)
See 5.3 — worth mocking as its own screen/sheet given the autocomplete+conflict-resolution complexity.

### 5.5 TFSA (Tax-Free Savings Account)
- **Purpose**: contribution ledger + South African TFSA limit tracking. Not investment performance — pure compliance/limit tracking.
- **Key info**: lifetime limit (R500,000), lifetime contributed, lifetime remaining, annual limit (R36,000), current tax year, current-year contributed/remaining, years-to-lifetime-limit, and a by-tax-year breakdown table each flagged if it exceeded the annual limit.
- **Add contribution**: tax year, amount, optional date, optional notes, optional ticker (if it's tied to a specific holding).
- **Cross-link**: adding a holding *inside* a TFSA-type portfolio (§5.2) automatically creates a matching contribution record here — the two are linked, not independent data entry.
- **Not built**: any "estimated performance"/backtest — confirmed genuinely out of scope, not just deferred-and-hidden.

### 5.6 Retirement Annuity (RA)
- Structurally identical to TFSA: annual limit (R36,000), total contributed, current-year contributed/remaining, by-year breakdown. Add contribution fields: tax year, amount, optional date, optional notes, optional **provider** (fund manager name, RA's equivalent of TFSA's ticker link). No lifetime cap (RA limits in SA law are annual/income-percentage based, not lifetime).

### 5.7 Instrument / Fund Comparison *(explicitly "if time allows" — lowest priority of this set)*
- Side-by-side comparison of up to 5 tickers: ticker search/autocomplete per slot, a time-period selector (1mo–5y), a multi-line price chart (toggle % change vs. absolute price), a summary table (Total Return, Annualised, Volatility, Max Drawdown, Sharpe, Dividend Yield — color-coded), a correlation heatmap between instruments, CSV export. A "benchmark overlay (CPI, STeFI)" feature exists as a backend stub but is explicitly not implemented — don't design for it.

### 5.8 CSV Import
- **Purpose**: bulk-import bank transactions from a downloaded statement CSV.
- **Backend reality**: this is a **single-shot upload** — the server parses, dedupes, auto-categorizes, and commits everything in one request. There is no server-side "preview before committing" step. A true 3-step wizard (Configure → Upload → Review) is a client-side UX layer *around* one endpoint, not three sequential backend calls — worth deciding explicitly whether mockups should present it as one screen (upload + immediate result) or a staged wizard feel (see §13).
- **Bank template selection** (choosing a template is the only "column mapping" mechanism — there's no manual column-mapping UI): 8 South African banks are supported — **FNB, Capitec, Standard Bank, ABSA, Nedbank, Investec, Discovery Bank, TymeBank** — plus a "None (Generic)" auto-detect option. Optionally also pick which existing Account the import applies to.
- **Upload**: drag-and-drop/file-picker, `.csv` only, 5MB max.
- **Result/review**: status (Completed / Partial / Failed / Pending, color-coded), metric tiles (Imported X/Y, Failed rows, Auto-categorized count, Filename, and — if detected — the bank's stated ending balance), a "Normalize with AI" action (runs an LLM pass to clean up auto-detected categories and learn rules for future imports), and per-row error detail for any failed rows (row number + error message).
- **Import history**: a simple table (date, filename, status badge, imported/failed/auto-categorized counts) — **read-only, no view/undo/delete action exists** even on the web app. Worth a deliberate decision on whether mockups add one.

### 5.9 Scan Receipt (OCR)
- **Purpose**: photograph or upload a receipt/slip and extract a transaction from it.
- **Flow**: capture/choose an image (or PDF) → server OCR extraction → a pre-filled review form (Type Expense/Income, Category, Amount, Date, Description) the user edits before saving → save as a normal transaction.
- **Key UX detail**: the extraction returns a **confidence score** (0–1) that should be shown as a badge — High (≥0.8, green) / Medium (≥0.5, amber) / Low (<0.5, red) — so the user knows how much to double-check the pre-fill. An "Enter manually" escape hatch discards the OCR result entirely.
- On mobile this should be a native camera-capture flow (not a file-picker like the web version) — no camera package is in `pubspec.yaml` yet, so this is fully greenfield for Flutter.

### 5.10 Subscription / Upgrade (PRO paywall)
- **Purpose**: surfaces when a free-tier user hits a limit.
- **Free tier limits**: 3 accounts max, 1 portfolio max, **zero AI features** (Insights, Chatbot both fully blocked). Pro tier: effectively unlimited accounts/portfolios (999) + AI features unlocked.
- **Error shape**: a 402 response with **only a plain message string** (e.g. "Portfolio limit reached for your subscription tier" or "Pro subscription required") — there's no structured "which limit" field, so the paywall UI should be a generic "Upgrade to PRO" prompt displaying that message, not a categorized reason. The `ApiError` model in Flutter already has an `isPaywall` getter ready for this.
- **Upgrade/cancel are currently mocked** (no real payment integration) — upgrading just flips the tier and sets a 30-day period end. A subscription-management screen showing current tier + an upgrade CTA is the missing piece.

### 5.11 Insights & Chatbot *(explicitly deferred beyond v1 — mention only, don't design in depth)*
Both are PRO-gated, self-hosted-AI-powered features: Insights is "ask a one-off question about your finances," Chatbot is an ongoing conversational assistant. Both currently render as the generic "coming soon" placeholder.

---

## 6. Data models (exact fields)

### Implemented in Flutter (source of truth for screens in §4)

**Account**: `id, name, accountType (string: bank/savings/cash), currency, balance (Decimal), isActive (bool), institutionName?`

**Transaction**: `id, accountId?, transactionType (income|expense|transfer), category (string), description?, amount (Decimal), transactionDate, merchantName?, notes?, accountName?`

**Budget**: `id, month, totalBudget (Decimal), category?, parentBudgetId?`
**BudgetProgress** (recursive): `id, month, category?, parentBudgetId?, budgetAmount, spent, remaining, pctUsed (double), overBudget (bool), children: [BudgetProgress]`

**Goal**: `id, name, targetAmount, currentAmount, targetDate?, category?, status (active|completed|paused), notes?, progressPct (double)`

**Asset**: `id, assetType (cash|savingsAccount|property|vehicle|investment|retirement|other), name, currentValue, valuationDate?, institutionName?, notes?`

**Liability**: `id, liabilityType (creditCard|personalLoan|vehicleLoan|mortgage|tax|other), name, outstandingAmount, originalBalance?, interestRate?, termMonths?, startDate?`

**NetWorthSummary**: `totalAssets, liabilitiesTotal, netWorth`
**CashflowSummary**: `incomeTotal, expenseTotal, netCashflow`
**ExpensesSummary**: `byCategory: [{category, total, count}], byMonth: [{month, total, count}], total`

**User**: `id, email, fullName?, role, isActive, salaryDay?` (salaryDay exists but has no UI anywhere)

### Backend-only (no Flutter model yet — needed for §5 screens)

**Portfolio**: `id, name, description?, currency (default ZAR), portfolioType (general|tfsa|ra|day_trading), createdAt, updatedAt`

**Holding**: `id, portfolioId, ticker, name, quantity (up to 6dp), costBasis, currentPrice?, assetClass (stock|equity|bond|etf|crypto|cash|other), contributionYear?, yfSymbol? (internal lookup key), priceUpdatedAt?, dividendYield? (0–100%), isClosed (bool), realizedPl? (computed, null until first sale)`

**Trade**: `id, holdingId, tradeType (buy|sell), quantity, pricePerUnit, tradeDate, fee, note?`

**Dividend**: `id, holdingId, payDate, amount, currency, taxWithheld, note?`

**ImportJob**: `id, filename, status (pending|completed|failed|partial), totalRows, importedRows, failedRows, errorMessage? (per-row error list), importedBalance? (detected ending balance), autoCategorizedRows, duplicateRows, createdAt`

**OcrResult** (not persisted, just extraction output): `date?, merchantName?, amount?, category?, description?, transactionType (income|expense), confidenceScore (0.0–1.0, always present), rawText?`

**TfsaContribution**: `id, taxYear, amount (≤R500,000/contribution), contributionDate?, notes?, ticker?, overAnnualLimitWarning (bool)`
**TfsaSummary**: `lifetimeLimit (R500,000), lifetimeContributed, lifetimeRemaining, annualLimit (R36,000), currentYear, currentYearContributed, currentYearRemaining, yearsToLifetimeLimit?, byYear: [{taxYear, contributed, limit, overLimit}]`

**RaContribution**: `id, taxYear, amount (≤R9,999,999.99), contributionDate?, notes?, provider?, overAnnualLimitWarning (bool)`
**RaSummary**: `annualLimit (R36,000), totalContributed, currentYear, currentYearContributed, currentYearRemaining, byYear: [...]`

**Subscription**: `id, tier (free|pro), status (active|cancelled|past_due), currentPeriodEnd?`

**InvestmentOverview**: `totalValue, totalCost, unrealizedPl, ytdDividends, portfolioCount, holdingCount, allocation: [{assetClass, value, percent}], topHoldings: [{holdingId, portfolioId, ticker, name, value, unrealizedPl}] (top 5)`

---

## 7. Key workflows worth designing carefully

1. **Bank account CRUD**: create is built; edit/deactivate is missing entirely (§4.5–4.6).
2. **Transaction CRUD + filtering**: CRUD is built and works well via bottom sheet; filtering (by account/type/date-range/category) has zero UI despite full backend+state support (§4.7).
3. **CSV import**: single backend call does upload→parse→dedupe→auto-categorize→commit in one shot; no true multi-step server gate. Design decision needed on wizard staging (§13).
4. **OCR receipt scan**: capture → confidence-scored extraction → editable review form → save. Needs native camera integration (greenfield in Flutter).
5. **Add-holding ticker autocomplete + conflict-preserving autofill**: the single most distinctive interaction pattern in the planned Investments domain — search-as-you-type, autofill on selection, but never silently overwrite a manually-typed value; offer it as an accept-or-keep choice instead. Reused identically in 3 places on web.
6. **Sell → Trade record**: selling a holding creates an auditable Trade row (not a silent quantity edit); UI should signal this is a "recorded transaction," styled with the same weight as other destructive/consequential actions.
7. **TFSA/RA contribution tracking**: simple add-a-contribution forms, but with a "running total crossed the annual limit" warning flag computed per contribution (not just per tax year) — the *specific* contribution that tips the year over the limit gets flagged, not every row in that year.

---

## 8. Established reusable patterns (from current code)

- **Grouped list cells**: flat `ListTile`-style rows with no per-row card/border, 16px outer padding, used for every list screen (Accounts, Transactions, Assets, Liabilities, Budget rows, Expense categories, Dashboard's recent-transactions preview). This is the dominant list pattern across the whole app.
- **Bottom-sheet add/edit forms**: every domain (Account, Transaction, Asset, Liability, Budget, Goal) uses an `isScrollControlled` modal bottom sheet with an identical shape: title → stacked fields (16px gaps) → inline error text → primary Save button (with inline spinner while submitting) → optional destructive-red "Delete" text button when editing. Full-page forms are never used for CRUD — this is a strong, consistent pattern to preserve or deliberately break from.
- **Segmented-button toggles**: used for transaction type (Expense/Income/Transfer), liability creation mode (Amount owed / Loan details), and the Budgets/Goals tab switch.
- **FAB "+ Add X"**: every list screen has an extended FAB as its primary creation entry point.
- **Money formatting**: every currency figure uses the same formatter (en-ZA grouping, comma decimals, `R` prefix, leading minus placed *outside* the R for negatives, `R —` for unparseable/missing values) in a monospace tabular-figures typeface — this rule has zero exceptions anywhere in the app.
- **Progress indicators**: exclusively flat linear bars (green/danger colored by over-limit state) — no ring/circular variant exists despite being spec'd for the Dashboard hero. A design opportunity.
- **Empty states**: plain centered text only, no illustration, no icon, no embedded CTA (e.g. "No accounts yet." with the FAB doing the work of "add one"). A clear area where the white/black/green direction could add polish without contradicting existing patterns.
- **Loading states**: plain circular spinners; some secondary sections instead silently collapse to nothing while loading to avoid layout jump.
- **Error states**: plain centered text of the raw error message, no retry button, no icon — duplicated inline per screen rather than a shared component.

---

## 9. Terminology & glossary

**Transaction categories** (fixed list used by the categorizer/OCR, though the Transactions form currently accepts free text): Groceries, Dining, Transport, Fuel, Shopping, Utilities, Housing, Healthcare, Entertainment, Personal, Salary, Transfer, Other.

**Account types**: Bank account, Savings account, Cash.

**Asset types**: Cash, Savings account, Property, Vehicle, Investment, Retirement, Other.

**Liability types**: Credit card, Personal loan, Vehicle loan, Mortgage, Tax, Other.

**Goal status**: Active, Completed, Paused (only Active is currently surfaced in any UI).

**Transaction types**: Expense, Income, Transfer.

**Portfolio types**: General, TFSA, RA, Day Trading (TFSA/RA are one-per-user singletons).

**Asset classes** (investment holdings): Stock, Equity, Bond, ETF, Crypto, Cash, Other.

**"TFSA"** = Tax-Free Savings Account (SA-specific, R36,000/year, R500,000 lifetime contribution limits). **"RA"** = Retirement Annuity (SA-specific, R36,000/year limit, no lifetime cap in this app).

**SA tax year**: 1 March – end of February (a contribution made in Jan 2027 belongs to tax year "2026").

**Currency**: ZAR only, always shown as `R` prefix.

---

## 10. Auth, onboarding, settings — what exists vs. what's missing

**Exists**: register, login, logout, silent session restore with automatic token refresh, biometric app-lock on restored sessions.

**Confirmed absent** (not just deferred — verified not present anywhere in code):
- **Consent/privacy acceptance UI.** The backend can return a "consent required" error (with a structured list of missing document types) and the Flutter app's error model fully parses this shape — but *nothing in any screen ever checks for it or reacts to it*. If a user needs to accept a privacy policy/terms update, there is currently no UI path for that at all. This needs a design (a blocking consent screen, most likely, similar in spirit to the Lock screen).
- Profile editing (name, email, salary day — despite `salaryDay` existing on the User model).
- Password change or password reset — not found anywhere in the backend either; genuinely unconfirmed whether this capability exists at all (§13).
- Theme switching UI (light/dark exists in code but there's no user-facing toggle — likely follows system setting only).
- Notification preferences.
- Subscription/billing management (see §5.10).

---

## 11. Technical constraints the mockups should respect

- **Money is always ZAR, always Decimal-precision** — mockups should show realistic 2-decimal-place figures (or up to 6dp for investment quantities), never show floating-point artifacts, and should generally use a monospace/tabular-figures treatment for numbers (an established, load-bearing convention, not just a style preference).
- **Phone-only** — no tablet/desktop layout consideration needed or evidenced in the codebase.
- **Material 3 base** — the app currently uses stock Material widgets (`NavigationBar`, `ListTile`, `SegmentedButton`, `FloatingActionButton`, bottom sheets, `TabBar`) throughout; mockups can lean into or deliberately move away from Material conventions, but should be aware this is the current foundation.
- **5-tab bottom nav is structurally locked** in the current build — proposing a 6th tab or restructuring the tabs is a real product/engineering decision, not a free redesign choice.
- **Dark mode must be designed in parity**, not as an afterthought — every screen exists in both today.
- **No custom icon set or texture currently implemented** despite being spec'd — stock Material icons are the honest current baseline; a custom icon system is greenfield work either way.

---

## 12. Recommended screen inventory for the mockup phase

### Tier 1 — Core, already built, refine visually
1. Login
2. Register
3. Lock / biometric unlock
4. Dashboard (Home)
5. Accounts list
6. Transactions list (grouped by date)
7. Add/Edit Transaction (bottom sheet)
8. Expenses Summary
9. Assets list
10. Add/Edit Asset (bottom sheet)
11. Liabilities list
12. Add/Edit Liability (bottom sheet, incl. loan-details smart form)
13. Budgets (progress view + month selector)
14. Add Budget (bottom sheet)
15. Goals list
16. Add Goal (bottom sheet)
17. Calculators (Loan Calculator / Loan Accelerator, 2 tabs)
18. Settings (as it exists: profile row + logout)

### Tier 2 — Missing pieces of existing domains (logically required, not yet built anywhere)
19. Edit Account (rename, institution, deactivate/restore)
20. Edit Budget / Delete Budget
21. Edit Goal / Delete Goal (incl. status change, target date, notes, category)
22. Transaction filter UI (account/type/date range/category)
23. Liability detail / payment history + amortisation progress
24. Consent / privacy-policy acceptance screen
25. Profile edit (name, email, salary day)
26. Password change (**pending confirmation this is even possible — see §13**)
27. Notifications preferences (**new — surfaced by the Settings mockup, §13 item 6**)
28. Appearance/theme picker (**new — surfaced by the Settings mockup, §13 item 6**)

### Tier 3 — Planned Investments domain (net new, backend-ready)
27. Investments Overview
28. Portfolios list
29. Portfolio Detail (holdings table + summary + allocation)
30. Add Holding (with ticker autocomplete/conflict-resolution)
31. Sell Holding
32. Edit Holding
33. Dividend log (per holding)
34. Projected Income table (likely part of #29, could stand alone)
35. TFSA (contributions + limit tracker)
36. Retirement Annuity (contributions + limit tracker)
37. Instrument/Fund Comparison *(stretch)*

### Tier 4 — Planned Import domain (net new, backend-ready)
38. CSV Import (upload + bank template select + result/review)
39. Import history
40. Scan Receipt (camera capture + confidence-scored review)

### Tier 5 — Monetization (net new, backend-ready but mocked)
41. Subscription / Upgrade (PRO paywall)

*(Insights and Chatbot are explicitly deferred beyond v1 — omit from this mockup round unless the user says otherwise.)*

---

## 13. Assumptions & open product questions

**Update, 2026-08-16**: questions 1, 2, 6, and 7 below are now resolved (or partially resolved) by the delivered mockups — kept here with a status note rather than deleted, since the resolution is *inferred from a mockup image*, not a direct product-owner answer, and is worth a quick confirm rather than treating as fully settled.

1. ~~**Investments IA depth**~~ — **Resolved by mockup (inferred).** The Invest tab mockup shows one combined tab-root screen (hero value + allocation donut + top holdings + portfolios list), not the web's 3-tier structure. Treat as collapsed IA: Invest tab = Overview + Portfolios combined, Portfolio Detail is still a separate pushed screen (unmocked). See `DESIGN.md` §8-9.
2. ~~**TFSA/RA placement**~~ — **Resolved by mockup (inferred).** The mockup shows TFSA, Retirement Annuity, and General Portfolio as plain rows within the same "Your portfolios" list, not separate dedicated screens.
3. **CSV import staging**: still open — no import screen was mocked. The backend does everything in one request — does the product want a *true* multi-step wizard feel (Configure → Upload → Review as distinct screens with back/forward), or a single screen (template picker + upload + inline result)?
4. **OCR capture UX**: still open — camera-only, or also allow picking an existing photo/PDF from the gallery/files?
5. **Is the consent-acceptance screen in scope for this mockup round?** Still open — not among the 9 delivered mockups.
6. ~~**Is Settings/profile-edit/subscription-upgrade in scope now?**~~ — **Resolved by mockup.** The Settings mockup shows a fully fleshed screen: profile row (name/email/avatar), Account section (Profile, Security, Notifications), App preferences (Appearance, Subscription — shown "Free"), Data & privacy (Privacy & consent, Import history), Log out. This surfaces items not previously listed in §12 Tier 2 at all: a dedicated **Notifications preferences** screen and an **Appearance/theme** screen. Added to §12 below. None of these sub-screens have their own mockup yet — only the Settings list row exists — so they're confirmed *in scope* but not yet designed in detail.
7. ~~**Dashboard progress block: ring or linear?**~~ — **Resolved by mockup.** Linear, confirmed directly (Emergency Fund progress bar on the Home mockup is a linear track). `DESIGN.md` updated accordingly.
8. **Password reset/change**: still open — no such capability was found anywhere in the backend during research, and no mockup screen addresses it either. Don't assume it's simply "unbuilt in Flutter"; it may not exist as a backend capability at all.
9. **Transaction category field**: still open — free text today — does the product want to constrain it to the fixed category list (§9) via a picker for consistency with OCR/import auto-categorization?
10. **New, from the mockups**: the Settings/Home/Invest/Budgets mockups all show a photographic profile avatar and a notification bell with an unread-count dot — neither has any backing feature today (no avatar upload anywhere in the API, no `notifications` domain in the parity matrix at all). Are these in scope to actually build, or purely decorative placeholders for now? `DESIGN.md` currently treats them as non-functional placeholders pending this answer.
10. **6th nav tab or restructure**: given how many domains (Assets, Liabilities, Calculators, and potentially Investments' 3 sub-areas) have no dedicated tab today and are reached only by pushing from Dashboard, is the 5-tab structure itself considered fixed, or open for revisiting as part of this design pass?
