# Piggybank — Mobile Design Direction

Phase 0 deliverable for the Flutter migration (see the approved migration plan at
`C:\Users\tiaan\.claude\plans\run-the-full-prompt-eager-nebula.md`). Originally a
**written spec, not generated mockups** — that changed on 2026-08-16 (see below).

> ## Revision — 2026-10: visual rework, "Ledger Pocket" (spec `docs/visual-rework/04-visual-spec.md`, pending approval)
>
> Tiaan picked the direction on 2026-10-10: B · Pocket's warmth and shape, A · Ledger's
> colours, a **light** hero panel, and Penny as a **transparent cutout** that is never at
> rest on Home. The sections below (Brand read, Colour, Typography, Spacing/shape/
> elevation, Iconography, Signature components, Motion and mascot) are rewritten to
> match. The spec has the full tokens, measured contrast and the M1–M42 motion table.
> - **Colour:** a warm paper and forest-green palette replaces white plus one green.
>   - The green gradient hero is gone.
>   - Every pair passes WCAG AA in both themes (65 pairs, 0 failures).
> - **Type:** Plus Jakarta Sans (display, titles, money) and Nunito Sans (body, labels) replace Manrope.
> - **Shape:**
>   - 24 dp cards, with pills for chips, buttons, segments and the FAB.
>   - Forest-tinted soft shadows in light mode; tonal surfaces in dark.
>   - One card per group, not per row.
> - **Penny:** the four Gemini poses (welcoming, sleeping, thinking, celebrating) are cut out to `assets/penny/*.png`. There's no circle clip and nothing new is generated. The old default pose `mascot.jpg` is retired, and welcoming is the default now.
> - **This supersedes:**
>   - the 2026-08-16 colour and type notes below;
>   - "every list row is its own card";
>   - the gradient hero;
>   - the circle-clipped mascot.
>
> ## Revision — 2026-10: UX rework (approved spec `docs/ux-rework/04-spec.md`)
>
> The UX rework (2026-10-09, approvals A1–A6) rewrites these locked rules; the sections
> below are updated to match, and the spec is the source for anything not repeated here:
> - **Navigation:** Home · Transactions · Plan · Invest · Penny. Settings leaves the tab
>   bar and opens from the avatar.
> - **Tab-root app bar:** avatar (→ Settings) · title · at most two labelled actions plus
>   an overflow. **The bell is removed** until a notification inbox exists (this
>   supersedes the "non-functional placeholder" decision below).
> - **Home:** the hero is **Left to spend this month**; Net worth becomes a card that
>   opens a Net worth hub. Fixed order, still no customisation.
> - **Motion is expressive** (spec §3) with mascot moments, using the existing mascot
>   poses. Still no confetti, streaks or badges.
> - **New screens:** the Plan host (Budgets · Goals · Savings) and the Net worth hub.
>
> ## Revision — 2026-08-16: superseded by delivered mockups
>
> The user delivered 9 concrete UI mockups (`assets/WhatsApp Image 2026-08-16 at
> 14.23.4x.jpeg` — Login, Create account, Home/Dashboard, Accounts, Transactions,
> Budgets, Goals, Invest, Settings). Everything below this note has been rewritten to
> match them, replacing the original Phase 0 written spec. This is a genuine identity
> **pivot**, not a refinement — two of the original spec's explicit rules are directly
> reversed by the mockups:
> - "No literal piggy-bank mascot or cartoon iconography anywhere" → the mockups use a
>   3D illustrated piggy-bank mascot repeatedly (Login, Create account, every hero card).
> - "Every ZAR amount and percentage renders in a distinct monospaced face" → the
>   mockups render money in the same UI sans as everything else, no mono face visible.
>
> **What this revision does NOT cover, flagged rather than guessed:**
> - **The mascot illustration and the photographic profile avatar are real image assets
>   this doc cannot supply.** Code built against this revision uses a plain Material
>   icon as a structural placeholder for both — swap in real assets when sourced (AI
>   generation, a purchased illustration, or a commissioned asset — the user previously
>   opted out of paid image generation for cost reasons, so this needs a fresh decision).
> - **Dark mode is inferred, not shown.** All 9 mockups are light-mode only. The dark
>   palette below keeps the same hue relationships (brightened accent, dark surface) as
>   the superseded spec did, but has not been confirmed against any delivered mockup.
> - **The avatar photo and notification bell (with unread dot) have no backing feature,
>   and that's now a settled decision, not an open question.** No avatar-upload endpoint
>   or `notifications` domain exists anywhere in the backend or the migration's parity
>   matrix, and per `docs/ui-ux-mockup-brief.md` §13 item 10 (2026-08-17), both stay
>   non-functional placeholders for now rather than getting built.
> - Only Login, Create account, Home/Dashboard, Accounts, Transactions, Budgets, Goals,
>   Invest, and Settings were mocked. Lock/biometric, Assets, Liabilities, Calculators,
>   and Expenses Summary inherit the new component language below by extension, not by a
>   direct mockup — reasonable given they already share the row/progress-card patterns
>   with screens that were mocked, but worth a follow-up mockup pass if precision matters.
> - The Invest tab mockup answers two previously-open questions from
>   `docs/ui-ux-mockup-brief.md` §13: Investments IA appears **collapsed** (Overview +
>   Portfolios list combined into one Invest-tab-root screen, not the web's 3-tier
>   structure), and **TFSA/RA appear as rows inside the regular portfolios list**, not
>   as separate dedicated screens. Flagged there as inferred, not confirmed by the user.

## Brand read

Warm, calm, friendly personal finance: forest green ink on warm paper, with soft rounded
shapes. Think of a well-kept pocket notebook that's pleasant to open every day.
- It's not a cold corporate bank app (navy and blue).
- It's not a SaaS dashboard.
- It's not a gamified trading app (no confetti, streaks or badges).

Money figures are confident and tabular. Penny the piggy is the warmth: she shows up for
moments that reward finishing something, never to guilt. Dark mode is designed rather
than inverted (2026-10 visual rework).

## Colour

"Ledger Pocket" (2026-10). Every value is measured, with 0 failures against WCAG AA; see
`docs/visual-rework/04-visual-spec.md` §1 for the full table, including category tiles and
chart series.

| Role | Light | Dark |
|---|---|---|
| Background (paper) | `#F7F4EC` | `#121512` |
| Surface (cards, sheets) | `#FFFDF8` | `#1A1E1A` (raised `#222722`) |
| Sunk (inputs, tracks) | `#EFEADF` | `#0E110E` |
| Text: ink / muted | `#1A1F1A` / `#595E54` | `#ECEAE2` / `#A7ACA2` |
| Outline (lines only) | `#8C8A7C` | `#6E7469` |
| Primary (CTA, active nav, links, progress) | `#1E5B3E`, white text | `#8FCBA4`, **dark** text `#0E2A1C` |
| Primary container (chips, pills, banners, avatar) | `#DCEBDD` / `#123A27` | `#24402F` / `#C6E6CF` |
| **Hero panel** | **light** `#DCEBDD`, figure `#123A27`, secondary `#3D6150` | tonal `#1F3A2A`, figure `#ECEAE2`, secondary `#A9C9B4` |
| Positive (income, +P/L, always with "+") | `#1E6B44` | `#8FCBA4` |
| Danger (over budget, destructive only) / container | `#A8322D` / `#F6E1DC` | `#F2A49B` / `#4A2421` |

Primary is used for actions and progress, never as a large fill. The hero is the one
tinted panel per screen. Danger is reserved for over-budget states and destructive
actions. Ordinary spending renders in ink, and a budget at 84 % is not red.

## Typography

- **Plus Jakarta Sans** (google_fonts, OFL) is used for the display figure, titles and every money figure, at weights 700 and 800.
- **Nunito Sans** (OFL) is used for body text, labels, buttons and chips, at weights 400, 600 and 700.
- Both replace Manrope (2026-10).
- **Every money figure uses tabular figures.** `moneyTextStyle()` in `app_theme.dart` stays the one place this is implemented.
- **Hero money format:** no cents. Rows show "R 1 245,50". Income carries "+" in positive; spending carries "−" in ink.
- **Scale** (size/line/weight):
  - display 40/44/800, hero only
  - headline 28/34/800
  - title 20/26/700
  - titleSmall 16/22/700
  - body 16/24/400
  - bodySmall 14/20/400
  - label 14/20/600
  - overline 12/16/700, caps, +6 % tracking

## Spacing, shape, elevation

- **Spacing:** a 4 dp base, with steps 4/8/12/16/20/24/32/40.
  - Gutter 16, card padding 20, gap between rows 12.
  - Gap between sections 24, always larger than any gap inside a section.
- **Radius:**
  - Cards and hero: 24.
  - Sheet top corners: 28.
  - Category tiles: 14.
  - Chips, buttons, inputs, segmented controls, banners and the FAB: full pills.
- **Elevation, light:** shadows are forest-tinted, never grey.
  - Level 1: `0 4 16` at 8 %, for cards and the hero.
  - Level 2: `0 8 24` at 12 %, for the FAB, sheets and menus.
- **Elevation, dark:** no shadows. Depth comes from tonal steps: `surface`, then `surfaceRaised`.
- **One card per group, not per row** (2026-10; reverses 2026-08). Rows inside a group are separated by space, so Home and lists stop reading as a stack of identical boxes.
- **FAB:** scrollables under it get 88 dp of bottom padding.

## Iconography

Material Symbols Rounded sit inside a **40 dp rounded-square category tile** (radius 14).
- **Tile colour comes from the category family**, so rows carry identity without relying on colour alone:
  - forest: food, income
  - ochre: transport
  - clay: dining, shopping
  - sage: bills, health
  - neutral: other

  Spec §1.3 has the measured tile and icon hexes.
- **The unknown-category fallback** is a neutral tag icon, never an arrow (an arrow read as income).
- **No background textures.**

## Navigation

Material 3 `NavigationBar` (bottom, 5 tabs: **Home, Transactions, Plan, Invest, Penny**;
UX rework 2026-10). Active tab renders in the accent green (icon + label), inactive tabs
in muted grey/outline. Re-tapping the active tab pops it to its root; each tab keeps its
own stack and scroll position.

**Top app bar has two patterns**:
- **Tab-root screens** (all five tabs) use the shared `TabAppBar`: a circular avatar
  (top-left) that opens **Settings**, the title, then at most two labelled actions plus
  an optional overflow menu. **No notification bell**: it had no feature behind it, and
  a control that looks tappable and does nothing isn't allowed.
- **Pushed/detail screens**, including **Settings** (now above the tabs, not one of
  them): back-arrow + screen-name title.

## Signature components (used consistently across the app)

1. **Hero metric card:** full width, radius 24, level 1.
   - In light mode it's a **light** primary-container panel (`#DCEBDD`) with dark forest text. In dark mode it's the tonal `#1F3A2A`.
   - It holds an overline label, a display figure that counts up, an optional pill progress bar, and one line of context.
   - Used once per screen, at the top. No gradient.
2. **Compact stat strip** — a horizontal row of 2-3 small stat blocks (e.g. "Income" /
   "Expenses" this month), each just a label + bold figure, no borders between them, just
   spacing.
3. **Group card:** one `surface` card per group of rows, radius 24 (2026-10; replaces the per-row card).
   - Each row is at least 64 dp: a category tile, a title and muted subtitle, then a trailing tabular value or chevron.
   - Pressing a row highlights it in `sunk`.
4. **Progress card** — same row-card shell, holding: title + a small rounded percentage
   pill (accent-tinted, or danger-tinted when over-budget/at-risk) on one row, a linear
   progress bar beneath it (never a ring — the mockups consistently use linear, resolving
   `docs/ui-ux-mockup-brief.md` §13's open question in favour of the current code's
   existing linear treatment), then a muted footnote line ("R 1,240 / R 2,000" or "R 450
   over budget"). Used for Budgets, Goals, and the Dashboard's single progress block.
5. **Quick-link tile** — a small square tile (icon chip + label, stacked) for the
   Dashboard's Accounts/Assets/Liabilities/Calculators row — replaces the superseded
   spec's inline `ActionChip` row with something closer to the mockup's 4-up grid.

## Motion and mascot moments

UX rework spec §3, all built from `AppMotion` tokens and **instant or static under the
OS reduced-motion setting**. Reusable pieces live in `lib/shared/motion/`.
- **Transitions:** tab switch fade-through (incoming half: fade + 0.92 → 1 scale, 160
  ms); container transform from account, portfolio and Net worth rows into their
  screens; shared axis X between Plan segments; shared axis Z for Settings.
- **Feedback:** hero figures count to a new value (400 ms, tabular figures); progress
  bars animate their fill; the row a sheet just saved tints and fades (600 ms after the
  sheet closes); standalone cards press to 0.97; review swipes reveal Confirm (green) or
  Discard (neutral grey, not red), with a light haptic.
- **Deletes:** single-row deletes hide the row behind a 4 s Undo snackbar instead of a
  confirm dialog. Holdings, portfolios, liability payments and log out keep their
  confirms.
- **Mascot moments.** As of 2026-10, these use the **transparent cutouts** in `assets/penny/` and have no circle clip.
  - **Celebrating:** when the review queue is cleared, a goal is first seen complete, or the savings target is met.
  - **Thinking:** a 2 px bob while Penny replies.
  - **Sleeping:** beside "Quiet day so far".
  - **Welcoming:** on the empty Transactions, Goals and Savings screens, and on login, lock and onboarding.
  - A pop plays at most once a day per kind.
  - **Penny is never at rest on Home.** Only the sleeping and savings-target moments appear there.
  - **Never on over-budget, missed-target or error states.**
- **2026-10 additions** (spec §1.7, §1.8, §5):
  - Springs for press, settle and pop. Pop is mascot-only, with overshoot capped at 6 %.
  - A 30 ms stagger on first list load, after skeletons (`skeletonizer`).
  - A haptic vocabulary: `selectionClick` for selection; `lightImpact` for save, confirm and threshold; `mediumImpact` for delete and goal reached; none on errors.
  - Every one of M1–M42 has defined feedback.

## Screen-by-screen direction

> The structure below still holds. The 2026-10 visual treatment of each screen
> (palette, grouping, Penny placement, motion) is in `docs/visual-rework/04-visual-spec.md`
> §4, with Stitch mockups in light and dark. Where this section says "green gradient" or
> "circle-clipped mascot", the spec wins.

### 1. Login / Register
Confirmed directly by mockups. Piggy-bank mascot illustration (placeholder icon in code
until a real asset exists) centred top-third, "Piggybank" wordmark + tagline beneath it,
generous whitespace. Below: email + password fields (soft outlined fields, rounded), one
primary pill CTA in accent green ("Log in" / "Create account"), a plain-text link to
toggle between them, a small reassurance line at the bottom ("Your data is secure and
private..."). No ledger-line texture — dropped, not in the mockups. Biometric/PIN unlock
reuses this same calm layout on subsequent app opens, fingerprint/face icon replacing the
password field.

### 2. Bottom-nav shell
5-tab `NavigationBar` as specified above. Tab-root screens get `TabAppBar` (avatar ·
title · labelled actions); pushed screens get back+title. A tab switch fades the new tab
in from 0.92 scale (see Motion).

### 3. Dashboard / Home
Rewritten by the UX rework (spec §2.1). Fixed order, no customisation:
1. The update banner and the review banner, only when there's something to act on.
2. **Hero: Left to spend · {Month}**, the sum of what's left across top-level budgets,
   with "Spent today R … · N days left" in the delta pill. Tapping it opens Plan ›
   Budgets. Over budget, it becomes an error-container card ("Over by R …"); red is
   reserved for that state. With no budgets, it shows "Spent this month" and a "Set a
   monthly budget ›" link. "Quiet day so far" (Penny asleep) sits under it when nothing
   has been spent today, never alongside over budget.
3. The savings card (target, gap or "target met this month").
4. A **Net worth** card that opens the Net worth hub.
5. **Needs attention:** one card, in priority order: the most over-budget category, a
   budget at 80 % or more, a goal in progress. Never a completed goal; nothing when
   none applies.
6. A row-card preview of recent transactions, with "See all".

The quick-link tiles, the cashflow strip and the Trends card left Home; their
destinations live in the Net worth hub, Transactions and Plan.

### 4. Accounts
Confirmed directly by mockup — and the mockup adds a hero metric card ("Total balance")
above the list that the superseded spec didn't have; added since the account balances are
already loaded client-side (a client-side sum, no new API call). Active accounts render
as rows in a group card (institution as muted subtext, balance trailing). Soft-deleted (deactivated)
accounts render in a collapsed "Inactive" group beneath active ones, matching the
backend's soft-delete/restore semantics — never just hidden with no way back in. A pill
"+ Add account" CTA as a persistent FAB, per mockup.

### 5. Transactions — list + detail/edit
Confirmed directly by mockup. List: filter chip row (All/Income/Expense/Transfer — visual
only for now, matching the mockup; wiring it to the existing-but-unused filter provider is
a separate, already-tracked gap, not part of this visual pass) then rows in group cards, grouped by
date (day headers as muted small-caps labels), each row: merchant-icon chip + merchant/
description, category as muted subtext, amount trailing (success/danger-tinted by
direction — income green, expense red — matching the Dashboard's recent-transactions
preview; superseded 2026-09-01, the mockup's plain-ink rendering was the outlier, not the
intended convention).
Tapping a row opens the existing detail/edit bottom sheet, restyled to the new field
theme, fields unchanged. Reimbursement-linking and transfer-pair badges (small pill tags)
sit just below the amount row on both list and detail views, unchanged from the
superseded spec — not shown in the mockup's sample data but still the documented plan.

### 6. Plan: Budgets
Plan (UX rework) hosts three segments, Budgets · Goals · Savings, which slide in segment
order. The month switcher sits under the Plan app bar while Budgets is showing, and a
"See trends ›" link follows the list. Confirmed directly by mockup: Progress cards (see Signature components), one group per
top-level category, month selector above (chevron-left / "May 2025" / chevron-right).
Sub-categories render as indented progress cards within their parent's group (mirrors the
web app's recursive parent/sub-category tree, flattened to one level of visual indentation
for mobile clarity rather than infinite nesting). Over-budget rows use the danger colour
on the progress fill, the percentage pill, and the "R X over budget" footnote — not a
full-row red background.

### 7. Plan: Goals and Savings
Goals: same progress-card pattern as Budgets (title + percentage pill + linear bar + "R
saved / R goal" footnote), in-progress goals first by target date, completed goals folded
into "Completed (n)". The Savings segment holds the savings plan (target, gap, recurring
costs and their suggestions), which used to be a pushed screen from Settings.

### 7a. Net worth hub
Pushed from Home's Net worth card (it grows into the screen). A Net worth hero with its
trend, then rows for Accounts, Assets (total), Liabilities (total) and Loan calculators:
the destinations that used to be Home's quick-link tiles.

### 8. Invest tab-root (confirmed by mockup — built; verified live 2026-08-28)
Hero metric card for **Total value**, delta chip + unrealized P&L / YTD dividends stat
strip beneath it. Below: an **allocation donut** with a legend (colour swatch + asset
class + percentage) — the mockup uses a donut here, not the stacked bar the superseded
spec called for; kept the stacked-bar recommendation below for the pushed Portfolio
Detail screen specifically, since that's a different, denser layout the mockup doesn't
show. Below: a "Top holdings" row-card preview (3 rows, "See all"). Below: a "Your
portfolios" row-card list — **TFSA, Retirement Annuity, and General Portfolio all appear
as plain rows in this one list**, not as separate dedicated screens (see the IA note in
the revision header above). This whole tab-root screen is net-new relative to the
superseded spec, which only ever described the pushed Portfolio Detail screen below.

### 9. Portfolio detail (highest complexity — most design attention warranted, not mocked)
No mockup exists for this pushed detail screen — the Invest mockup only shows the
tab-root list above. Direction below is carried over from the superseded spec unchanged,
restyled to the new palette/components when Phase 4 builds it:
Top: hero metric card for total portfolio value, delta chip for today's/period change.
Below: a simple allocation block (horizontal stacked bar, not a donut, for mobile-width
legibility) with a compact legend beneath it (colour swatch + asset class + percentage).
Below: row-card list of holdings, each row: ticker + name, a small inline sparkline
(accent-coloured, minimal axis chrome) replacing a full chart per row, current value
trailing, day-change as a small percentage beneath it (green if up, red if down — the one
place a red/green duality on ordinary figures is appropriate, since it's price movement,
not a budget/goal state). Tapping a holding opens a detail sheet: price history as a
single clean line chart (accent-coloured line, muted grid), then dividend history as a
row-card list beneath it, then a "Sell" pill action. Ticker autocomplete/add-holding flow
reuses the same search-field pattern as any other search in the app — no bespoke
component, to keep this already-complex screen from introducing new patterns nobody else
uses.

## What's still not covered

Full component-by-component Figma/pixel specs (the 9 delivered mockups cover 9 screens at
JPEG fidelity, not a full design-tool source file), a formal design-token handoff with
exact confirmed hex values (this doc's palette is eyeballed from the JPEGs), and mockups
for the screens listed as "not directly mocked" in the revision header above. Real mascot
and avatar image assets are also outstanding — see the revision header's asset note.

The consent-acceptance screen is confirmed in scope (`docs/ui-ux-mockup-brief.md` §13 item
5, 2026-08-17) but has no mockup and no design direction here yet — build it in the app's
existing plain-screen style, matching the unmocked Portfolio Detail precedent, when it's
picked up. The CSV import wizard (Configure → Upload → Review, per §13 item 3) and the
password-reset scope-out (§13 item 8) are similarly resolved-but-undesigned.
