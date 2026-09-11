# Batch 5 — Retries, Admin, Forgot/Reset Password, Grounded-by-Extension Screens

Piggybank Stitch project: `projects/4011413732038259168`
Design system asset: `assets/a4ebed3c029941c992bfc13f8f6565d9`

All 12 calls use:
- `projectId`: `4011413732038259168`
- `designSystem`: `assets/a4ebed3c029941c992bfc13f8f6565d9`
- `deviceType`: `MOBILE`

This batch covers 4 groups: (1) the two Batch 4 screens that never got a working generation,
retried here with fixes for content drift and the chatbot's persona rename; (2) the 3 Admin
panel screens, which have no Flutter implementation yet — grounded entirely in
`docs/admin-scope.md`, so their layout is speculative in a way the others aren't; (3) Forgot/
Reset Password, built in Flutter but never mocked; (4) 5 screens `DESIGN.md` calls
"grounded by extension" — built, but only ever inheriting a sibling screen's visual pattern
rather than getting their own mockup.

---

## Group 1 — Retries carried over from Batch 4

### Imports wizard

Amended from the Batch 4 prompt (that version undersold the real screen's scan-entry paths, its
CSV step structure, and its confidence-badge/result-card details — all patched in below).

```
Imports wizard screen for a personal finance app. Combines two import paths into one screen: (1) "Scan receipt" — OCR-based receipt scanning, and (2) "Import CSV" — bank/statement CSV upload, itself a 3-step wizard. Below both entry points, a "Past imports" history list.

Layout, top to bottom:
1. "Scan receipt" section: an icon-chip header, then three entry options — "Take photo" and "Pick image" as two side-by-side outlined pill buttons, plus an "or choose a PDF instead" text link beneath them. After a scan, show an OCR review state: a small confidence pill badge reading "HIGH CONFIDENCE", "MEDIUM CONFIDENCE", or "LOW CONFIDENCE" (not a percentage), with editable fields for type (Expense/Income), category, amount (R-prefixed, tabular figures), date, and description pre-filled from the OCR result, and Confirm/Retry actions.
2. "Import CSV" section: an icon-chip header, then a pill-segment step indicator showing 3 steps — "Configure", "Upload", "Review". Configure step: a bank-template dropdown and an account dropdown. Upload step: a file-picker card (drag/tap to upload a .csv) plus a themed preview table of the first few parsed rows once a file is chosen. Review step: a themed result card.
3. "Upload result" section: an icon-chip header, then a themed result/summary card — counts for imported, failed, and auto-categorized transactions, a duplicate-skipped count shown only when nonzero, a "Bank balance (last row)" money figure in tabular figures, and a secondary "Normalize with AI" button.
4. "Past imports" section: an icon-chip header, then a list of row-cards, each showing an import source icon (receipt or CSV), a filename/merchant label, an "imported/total" count, a failed count when nonzero, and a status badge.

Follow the Piggybank design system exactly: Manrope typography including tabular figures for all money amounts, #1F8A4C accent as the only accent color (no gradients except a hero card), 20px card radius, pill buttons, circular icon chips in the accent-wash (#E4F5EA) background, calm high-contrast charcoal-on-white base (#141815 ink, never pure black), danger-wash (#FCE8E8/#D64545) reserved only for error/low-confidence states, no emojis, ZAR with "R" prefix.
```

### Chatbot

Rewritten from the Batch 4 prompt to use the app's now-live "Penny" persona (the original prompt
predates that decision and still said generic "Financial Assistant").

```
Chatbot screen for a personal finance app — an AI financial assistant chat thread with a named persona, "Penny", tied to the app's piggy-bank mascot. Header: a simple top bar with a small circular savings/piggy-bank icon chip in the accent-wash background, title "Penny", and subtitle "Ask me anything about your money".

Message thread, top to bottom, mix of message types:
- Bot messages: left-aligned chat bubbles with the small round icon chip to the left, bubble background in the accent-wash (#E4F5EA) tint, dark charcoal text, asymmetric corner radii (sharper corner near the avatar, rounder elsewhere) giving a speech-bubble tail feel.
- User messages: right-aligned chat bubbles, solid #1F8A4C accent background, white text, asymmetric corners mirrored to the bot bubbles.
- A "typing" indicator bubble: same style as a bot bubble but containing 3 small animated-looking dots instead of text.
- One bot message should be a rich response containing a small embedded stat card reading "Your spending this month: R4,230 — 12% lower than last month" in tabular figures, with a small down-trending arrow — always rendered in Ledger Green (#1F8A4C), regardless of whether spending went up or down, never in a red/danger color.
- An error state example: a bot bubble with a muted-danger tint (#FCE8E8 wash) containing the text "Sorry, I'm having trouble with that." and a "Retry" link.

Below the thread: a message composer bar pinned to the bottom — a rounded pill-shaped multiline text input with placeholder "Ask about your finances..." and a circular filled send button (accent #1F8A4C background, white paper-plane icon) to its right.

Also design the empty state (shown before any messages exist): centered savings icon chip in accent-wash, headline "Hi, I'm Penny", muted supporting text "I can help you track spending, check your budgets, or analyze your investments.", and three suggested-question pill chips below: "How much did I spend on dining?", "Am I on track with my budget?", "Show my net worth trend".

Follow the Piggybank design system exactly: Manrope typography including tabular figures for all money amounts, #1F8A4C accent as the only accent color, 20px card radius, pill-shaped composer and buttons, calm high-contrast charcoal-on-white base (#141815 ink, never pure black), danger-wash (#FCE8E8/#D64545) reserved only for the error bubble, no emojis, ZAR with "R" prefix.
```

---

## Group 2 — Admin panel (no Flutter implementation yet)

These 3 screens are speculative layout, doc-grounded content — there is no shipped Flutter code
to mirror. All content below is derived from `docs/admin-scope.md`'s confirmed feature set, not
assumed. The build itself stays gated behind a future blueprint; these are design references
only.

### Admin dashboard / metrics

```
Admin dashboard screen for a personal finance app's internal admin panel (accessed only by admin-role accounts, not shown to regular users). This is an aggregate operational overview, not a full analytics/monitoring product.

Layout, top to bottom:
1. A simple top bar: title "Admin dashboard".
2. A grid of stat tiles (2 columns), each a small card with a label and a large tabular-figure number: "Total users", "New users (7 days)", "New users (30 days)", "Total accounts", "Total transactions". Avoid a generic "3 equal cards" layout — use a proper grid with clear label/value hierarchy per tile.
3. Below the grid, a single action card: "Trigger price refresh" with a short helper line "Refresh market prices for all tracked instruments" and a pill button "Refresh now". Show a secondary disabled/cooldown state of this same button reading "Available again in 4m" with a muted countdown caption, since this action is rate-limited.

Do not include error-rate graphs, uptime charts, or any real-time monitoring visuals — this screen shows aggregate counts only, nothing more.

Follow the Piggybank design system exactly: Manrope typography including tabular figures for all numbers, #1F8A4C accent as the only accent color, 20px card radius, pill buttons, circular icon chips in the accent-wash (#E4F5EA) background where icons are used, calm high-contrast charcoal-on-white base (#141815 ink, never pure black), no emojis, no purple/blue "AI" gradients.
```

### Admin user list / search

```
Admin user list/search screen for a personal finance app's internal admin panel. Lets an admin search and browse all registered users.

Layout, top to bottom:
1. A simple top bar: title "Users", with a back chevron to the admin dashboard.
2. A search bar below the top bar, placeholder "Search by name or email".
3. A paginated list of row-cards, each showing: user's name and email (two lines, name bold), a small subscription-tier pill badge ("Free" or "Pro", Pro styled in the accent color), an active/disabled status dot (green for active, muted grey for disabled), and a "Joined {date}" caption on the right. Example rows: "Thandiwe Mokoena — thandiwe.m@gmail.com — Pro — Active — Joined 12 Mar 2026", "Sipho Nkosi — sipho.nkosi@outlook.com — Free — Disabled — Joined 03 Jan 2026", "Amanda van der Merwe — amanda.vdm@gmail.com — Pro — Active — Joined 28 Jul 2026".
4. An empty/no-results state (shown when a search matches nothing): a muted icon and text "No users found for that search."

Each row is tappable, navigating to a user detail screen.

Follow the Piggybank design system exactly: Manrope typography, #1F8A4C accent as the only accent color, 20px card radius, circular status dots, calm high-contrast charcoal-on-white base (#141815 ink, never pure black), no emojis, no generic placeholder names — use plausible South African names/institutions.
```

### Admin user detail

```
Admin user detail screen for a personal finance app's internal admin panel — a single user's profile and admin controls.

Layout, top to bottom:
1. A simple top bar: title "User detail", back chevron to the user list.
2. A profile header card: user's name and email, subscription tier pill badge, "Joined {date}" caption.
3. A stats row: two small stat tiles, "Accounts" and "Transactions", each with a tabular-figure count for that user.
4. An "Account status" card: a label "Active" or "Disabled" with a toggle switch (not a destructive-styled control — this is a reversible action, use the standard accent-green toggle, not a red one).
5. A "Subscription override" card: current tier shown, and a pill button "Change subscription" that opens a form with a target-tier dropdown, an optional expiry-date field, and a required free-text "Reason" field (with helper text "Required — this bypasses normal payment flow"), plus a "Save" pill button.

Do not include any delete-user or remove-account control anywhere on this screen — user deletion is intentionally not an in-app action.

Follow the Piggybank design system exactly: Manrope typography including tabular figures, #1F8A4C accent as the only accent color, 20px card radius, pill buttons, calm high-contrast charcoal-on-white base (#141815 ink, never pure black), no emojis.
```

---

## Group 3 — Forgot / Reset Password (built in Flutter, never mocked)

### Forgot password

```
Forgot password screen for a personal finance app. Design both states of this single screen.

State 1 — request form:
1. A simple top bar: title "Forgot password".
2. Body copy: "Enter your account's email address and we'll send you a code to reset your password."
3. An email field (mail icon prefix, hint "you@example.com").
4. A primary pill button "Send reset code".
5. An inline error-text state below the field, shown in danger red, for an invalid/unrecognized email.
6. A "Back to log in" text link centered at the bottom.

State 2 — confirmation (shown after submitting, regardless of whether the email actually exists on an account — a deliberate anti-enumeration design, so it must look identical whether or not the account is real):
1. Same top bar.
2. A centered large mark-email-read icon in a circular accent-wash chip.
3. Headline copy: "If an account exists for that email, a reset code is on its way."
4. A primary pill button "I have my code".
5. A "Back to log in" text link below it.

Follow the Piggybank design system exactly: Manrope typography, #1F8A4C accent as the only accent color, 20px card radius, pill buttons, circular icon chips in the accent-wash (#E4F5EA) background, calm high-contrast charcoal-on-white base (#141815 ink, never pure black), danger-wash (#FCE8E8/#D64545) only for the error-text state, no emojis.
```

### Reset password

```
Reset password screen for a personal finance app — entered after requesting a reset code.

Layout, top to bottom:
1. A simple top bar: title "Reset password".
2. Body copy referencing a real-looking sample email: "Enter the 8-digit code sent to thandiwe.m@gmail.com and choose a new password."
3. An 8-digit reset-code field (pin/key icon prefix, numeric-styled input, max 8 characters).
4. A new-password field (lock icon prefix, obscured text, with a visibility-toggle eye icon on the right).
5. An inline error-text state below the fields, in danger red, reading "Invalid or expired code."
6. A primary pill button "Reset password", and show a secondary loading-spinner variant of this same button (spinner replacing the label).

No back-navigation link on this screen — do not add one.

Follow the Piggybank design system exactly: Manrope typography, #1F8A4C accent as the only accent color, 20px card radius, pill buttons, calm high-contrast charcoal-on-white base (#141815 ink, never pure black), danger-wash (#FCE8E8/#D64545) only for the error-text state, no emojis.
```

---

## Group 4 — Grounded-by-extension screens (built, never directly mocked)

Each of these 5 screens inherits its visual language from an already-mocked sibling rather than
having its own dedicated design pass. Each prompt names that sibling explicitly.

### Lock / biometric

Sibling: Login/Create account (same calm centered layout, smaller mascot since this is a
returning-user screen, not a first impression).

```
Lock screen for a personal finance app — shown to a returning user re-opening a previously-unlocked app. Design all 3 states.

Shared layout: centered composition, generous vertical whitespace, no ledger-line texture, a small centered piggy-bank mascot icon (smaller than a first-impression Login screen would use), headline "Piggybank is locked".

State 1 — biometric prompt: below the headline, a large circular icon chip in accent-wash with a fingerprint icon, muted caption "Tap to unlock with biometrics" beneath it, and a "Use PIN instead" text link below that (only relevant if the user also has a PIN set).

State 2 — loading/prompting: same layout, but the fingerprint chip is replaced by a centered circular loading spinner.

State 3 — PIN entry: below the headline, 6 individual bordered square boxes in a row (not one text field), each showing a filled dot once a digit is entered. Below the boxes, a primary pill button "Unlock" (show a loading-spinner variant of this button too), and a "Use biometrics instead" text link beneath it. Also show an error variant of this state: the 6 boxes bordered in danger red, with a caption "Incorrect PIN" in danger red above the Unlock button.

Follow the Piggybank design system exactly: Manrope typography, #1F8A4C accent as the only accent color, circular icon chips in accent-wash (#E4F5EA), calm high-contrast charcoal-on-white base (#141815 ink, never pure black), danger-wash (#FCE8E8/#D64545) only for the incorrect-PIN error state, no emojis.
```

### Assets

Sibling: Accounts/Transactions (row-card list pattern) and Liabilities/Portfolio (hero-card
totals pattern).

```
Assets list screen for a personal finance app.

Layout, top to bottom:
1. A simple top bar: title "Assets".
2. A hero metric card: label "Total assets", large tabular-figure ZAR amount (e.g. "R842,300"), styled with the same accent-green gradient hero-card treatment used on Portfolio/Liabilities totals.
3. A row-card list, one row per asset, spanning 7 possible types with distinct leading icon chips (Cash, Savings account, Property, Vehicle, Investment, Retirement, Other): each row shows the asset name, a subtitle "{type} · {institution}" (institution omitted when not set), and a right-aligned tabular-figure ZAR value. Example rows: "Emergency fund — Savings account · Capitec — R45,200", "Sandton apartment — Property — R1,850,000", "Toyota Corolla — Vehicle — R210,000".
4. An empty state: centered muted text "No assets yet."
5. A circular floating action button (bottom right, accent-green, plus icon) labeled "Add asset" that opens a bottom sheet: a type dropdown, an asset-name field, a current-value field (R-prefixed), an optional institution field, and a primary "Save" pill button. Show the same sheet's edit-mode variant (tapping an existing row) with fields pre-filled and an additional red "Delete" text button at the bottom.

Follow the Piggybank design system exactly: Manrope typography including tabular figures for all money, #1F8A4C accent as the only accent color, 20px card radius, pill buttons, circular icon chips in accent-wash (#E4F5EA), calm high-contrast charcoal-on-white base (#141815 ink, never pure black), no emojis, ZAR with "R" prefix.
```

### Liabilities

Sibling: Accounts/Transactions (row-card list pattern), Budgets/Goals (linear progress-bar
language).

```
Liabilities list screen for a personal finance app.

Layout, top to bottom:
1. A simple top bar: title "Liabilities".
2. A hero metric card: label "Total liabilities", large tabular-figure ZAR amount, kept in neutral charcoal (not a red/danger-toned card) — only individual row amounts use danger red, the total itself stays neutral.
3. A row-card list, one row per liability, spanning 6 possible types (Credit card, Personal loan, Vehicle loan, Mortgage, Tax, Other), each row using a danger-tinted icon chip (red-wash background, not the usual accent-wash), the liability name, a type-label subtitle, and a right-aligned tabular-figure ZAR outstanding amount in danger red. Example rows: "Standard Bank credit card — Credit card — R12,450", "SARS provisional tax — Tax — R8,200". One row (a mortgage, e.g. "Home loan — Mortgage — R980,000") should additionally show a thin linear progress bar beneath it with a small percent pill reading "34% paid off".
4. An empty state: centered muted text "No liabilities yet."
5. A circular floating action button (bottom right, accent-green, plus icon) labeled "Add liability" that opens a bottom sheet with a segmented toggle at the top: "Amount owed" vs. "Loan details". "Amount owed" mode shows just a type dropdown, name field, and a single outstanding-amount field. "Loan details" mode instead shows: original loan amount, annual interest rate (%), term (months), and a start-date picker. Both modes end in a primary "Save" pill button.

Follow the Piggybank design system exactly: Manrope typography including tabular figures for all money, #1F8A4C accent as the only accent color, 20px card radius, pill buttons, danger-wash (#FCE8E8/#D64545) used deliberately here for liability icon chips and amounts (this screen is the documented exception to "danger only for error states" — debt amounts are inherently danger-toned), calm high-contrast charcoal-on-white base (#141815 ink, never pure black), no emojis, ZAR with "R" prefix.
```

### Calculators

Sibling: Portfolio/Assets/Liabilities/Expenses (shared `HeroMetricCard` result treatment —
deliberately not given a separate "tool" visual identity).

```
Calculators screen for a personal finance app.

Layout, top to bottom:
1. A simple top bar: title "Calculators".
2. A pill-segment toggle at the top with 2 options: "Loan Calculator" and "Loan Accelerator" (same segmented-control style as the app's Budgets/Goals switch).
3. "Loan Calculator" tab: an icon chip plus helper line "Work out the monthly payment for a loan", then 3 input fields — loan amount (R-prefixed), annual interest rate (%), term (months) — a primary pill button "Calculate", and an inline validation-error state beneath the fields reading "Enter a loan amount greater than zero." Below the button, the result renders as the same hero-metric-card treatment used elsewhere in the app (accent-green gradient card): label "Monthly payment", large tabular-figure ZAR amount (e.g. "R4,850").
4. "Loan Accelerator" tab: an icon chip plus helper line "See how much extra monthly payments save", then 4 input fields — outstanding balance, annual interest rate (%), remaining term (months), extra monthly payment (all R-prefixed where relevant) — a "Calculate" button, and a hero-metric-card result: label "Interest saved", large tabular-figure ZAR amount, with a small delta caption beneath it like "18 months saved".

This screen deliberately reuses the same hero-card result language as Assets/Liabilities/Expenses totals — do not give it a distinct "calculator tool" visual identity, no gauge/dial imagery, no separate accent color.

Follow the Piggybank design system exactly: Manrope typography including tabular figures for all money, #1F8A4C accent as the only accent color, 20px card radius, pill buttons and segmented control, circular icon chips in accent-wash (#E4F5EA), calm high-contrast charcoal-on-white base (#141815 ink, never pure black), danger-wash (#FCE8E8/#D64545) only for the validation-error state, no emojis, ZAR with "R" prefix.
```

### Expenses Summary

Sibling: Portfolio detail (horizontal stacked allocation-bar treatment, explicitly not a donut
chart).

```
Expenses summary screen for a personal finance app — a read-only breakdown of spending by category.

Layout, top to bottom:
1. A top bar: title "Expenses", with a filter icon (opens a date-range picker) on the right, and a small clear-filter "x" icon shown only when a date filter is currently active.
2. A hero metric card: label "Total", large tabular-figure ZAR amount (e.g. "R18,640").
3. A horizontal stacked allocation bar — a single rounded bar, about 12px tall, split into colored segments proportional to each category's share of the total. Explicitly not a donut/pie chart. Use an in-hue palette of Ledger Green (#1F8A4C) lightness variations for the segments, not a rainbow of unrelated colors — matching the same allocation-bar treatment used on the Portfolio detail screen.
4. A "By category" section below: a row-card list, each row showing a small colored dot (matching its segment's color in the bar above), the category name, a "{count} transactions" subtitle, and a right-aligned tabular-figure ZAR total. Example rows: "Groceries — 14 transactions — R4,230", "Dining out — 9 transactions — R2,180", "Transport — 6 transactions — R1,540", "Uncategorised — 3 transactions — R620" (use a muted grey dot for "Uncategorised").
5. An empty state: centered muted text "No expenses in this period."

This screen is purely read-only — no floating action button, no add/edit controls anywhere.

Follow the Piggybank design system exactly: Manrope typography including tabular figures for all money, #1F8A4C accent as the only accent color, 20px card radius, calm high-contrast charcoal-on-white base (#141815 ink, never pure black), no emojis, ZAR with "R" prefix.
```

---

## Status as of this export

**Scope note:** Before running any of these, `list_screens` on the live project revealed that
Group 3 (Forgot/Reset Password) and Group 4 (Lock/biometric, Assets, Liabilities, Calculators,
Expenses Summary) already have working Stitch mockups — some duplicated up to 5x — despite the
research that produced this doc concluding they were unmocked (that research only read the
Flutter/docs repos, not the live Stitch project state). Per user decision, only Group 1
(retries) and Group 2 (Admin) were actually run; Groups 3 and 4's prompts above are kept in this
doc as a record but were **not submitted**.

**Group 1 — retries:**
- **Imports wizard** — confirmed generated (`projects/4011413732038259168/screens/ee27b2f8cc6d49da956c7fdb169c5df0`, titled "Imports Wizard"). The tool call itself reported a client-side timeout, but the screen landed anyway — same pattern as the original Batch 4 failure was presumed to be a genuine outage; this time it wasn't.
- **Chatbot (Penny)** — submitted, tool reported a timeout. Not yet visible in `list_screens` after 3 follow-up checks (a few minutes). Plausibly still processing, per the same pattern as Imports wizard. Needs a fresh `list_screens` check later to confirm.

**Group 2 — Admin panel:**
- **Admin dashboard/metrics** — submitted, timed out client-side. Not yet visible after 3 checks — needs a later re-check.
- **Admin user list/search** — submitted, timed out client-side. Not yet visible after 3 checks — needs a later re-check.
- **Admin user detail** — submitted, got a distinct `"The service is currently unavailable"` error (not a timeout) — a different failure class, less likely to have silently succeeded. Needs re-submission once confirmed absent.

**Next step:** re-run `mcp__stitch__list_screens` on project `4011413732038259168` after a few
more minutes and check for screens titled "Penny" / "Chatbot", "Admin dashboard", "Users" /
"User list", "User detail". Anything still missing should be resubmitted (Admin user detail
first, since it hit a different, more clearly-failed error).
