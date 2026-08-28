# Piggybank — Mobile Design Direction

Phase 0 deliverable for the Flutter migration (see the approved migration plan at
`C:\Users\tiaan\.claude\plans\run-the-full-prompt-eager-nebula.md`). Originally a
**written spec, not generated mockups** — that changed on 2026-08-16 (see below).

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

Clean, professional, approachable personal finance — mostly white and black, one
restrained green accent. Not a cold corporate bank app (FNB/Absa/Standard Bank
navy-and-blue), not a corporate-SaaS dashboard (navy sidebar, blue buttons), and not a
gamified trading app (no confetti, no streaks, no badges) — same underlying discipline as
before, new execution. Money and percentage figures render with confident, precise
typography. Dark mode is a first-class target in principle, though unconfirmed visually
(see revision note above).

## Colour

Mostly white/black, one confident green accent — eyeballed from the delivered JPEGs, not
sampled pixel-exact. Treat as a strong first pass; get real hex values from the user or a
design tool if pixel-perfect matching starts to matter.

| Role | Light | Dark (inferred, unconfirmed) |
|---|---|---|
| Background | `#FFFFFF` | `#0F1412` |
| Surface (cards) | `#FFFFFF` (differentiated from background by border + shadow, not colour) | `#181F1B` |
| Text — primary | `#111812` (near-black) | `#F2F5F1` |
| Text — muted | `#6B7280` | `#9AA69E` |
| Border / divider | `#EDEFEA` | `#28322C` |
| Accent (primary CTA, active nav, links, progress fill) | `#1F8A4C` | `#3FC876` (brightened for dark contrast) |
| Accent chip background (icon chips, positive pills) | `#E4F5EA` | `#17301F` |
| Hero-card gradient | `#6FBE8C` → `#227A4E`, top-left to bottom-right | same, unconfirmed in dark |
| Success (positive figures) | same as accent, `#1F8A4C` — the mockups reuse one green throughout rather than a separate success tone | `#3FC876` |
| Danger (negative/over-budget/destructive) | `#D64545` | `#E8685F` |
| Danger chip background | `#FCE8E8` | `#3A1F1F` |

The accent is still used sparingly — primary buttons, active nav, progress fills, links —
never as a dominant fill. Danger is reserved for over-budget states and destructive
actions (e.g. "Log out"); ordinary negative transaction amounts render in the primary
text colour, not danger — only budgets/goals that are actually over/at-risk get red.

## Typography

- **UI sans (headings, body, labels, AND money/percentage figures)**: **Manrope**,
  unchanged from the original spec — it reads compatibly with the mockups' rounded
  geometric letterforms, so no font swap was needed.
- **Money & percentage figures no longer use a distinct mono face.** The mockups render
  every amount in the same Manrope family as surrounding text (semibold/bold weight for
  emphasis). Tabular figures are kept via Manrope's tabular-figure font feature where
  available, for alignment in lists — the *discipline* of predictable-width numerals
  carries over, just not a separate typeface. `moneyTextStyle()` in `app_theme.dart` is
  the one place this is implemented; nothing else in the app should hardcode a font.
- Scale: 28/22/17/15/13sp for display/title/body-large/body/caption, unchanged — nothing
  in the mockups contradicts this.

## Spacing, shape, elevation

- 4px base unit; common steps 4/8/12/16/24/32/48.
- Card corner radius: 20px, unchanged — the mockups' cards read at roughly this radius.
- Buttons: pill-shaped, fully rounded — unchanged, confirmed by every CTA in the mockups.
- Shadows: soft, low-opacity, **neutral grey** now (not warm-tinted, since the base is no
  longer warm cream) — still barely-there elevation.
- **Every list row is now its own card** (white surface, border + soft shadow, 20px
  radius, ~16px internal padding) — a real structural change from the superseded spec's
  flat grouped-rows pattern. See Signature components below.

## Iconography

Simple filled/outlined icons sitting inside a circular colour-tinted "icon chip"
(accent-tinted by default, danger-tinted for warning/negative contexts) — this reads as
Material Symbols (rounded/outlined variant) in the mockups, not a bespoke custom line-icon
set. Relaxes the superseded spec's "custom 1.5px-stroke" requirement, since a bespoke icon
set isn't achievable from mockup images alone and isn't what the mockups actually show.
The "ledger-line grid" background texture on empty states/login is dropped — not visible
in any of the 9 mockups.

## Navigation

Material 3 `NavigationBar` (bottom, 5 tabs: Home, Invest, Budgets, Insights, Settings),
unchanged — confirmed directly by every mockup that shows the tab bar. Active tab renders
in the accent green (icon + label), inactive tabs in muted grey/outline.

**Top app bar now has two patterns, both seen directly in the mockups**:
- **Tab-root screens** (Home, Invest, Budgets): a circular avatar placeholder (top-left),
  centred title, and a static notification-bell icon with an unread dot (top-right).
- **Pushed/detail screens** (Transactions, Create account) and **Settings** (a tab-root,
  but shown with no avatar/bell — likely because it already surfaces identity in its own
  first row): back-arrow + screen-name title, no avatar/bell.

## Signature components (used consistently across the app)

1. **Hero metric card** — full-width, rounded 24px, green gradient fill (see Colour),
   white text: a small label, a large bold figure (net worth, total balance, portfolio
   value), and an optional translucent-white delta pill below. Used once per screen, at
   the top, never repeated as a pattern for lesser numbers.
2. **Compact stat strip** — a horizontal row of 2-3 small stat blocks (e.g. "Income" /
   "Expenses" this month), each just a label + bold figure, no borders between them, just
   spacing.
3. **Row card** — the new base pattern for every list (Accounts, Transactions, Assets,
   Liabilities, Settings, recent-transactions previews): a white rounded-20px card per
   row, with a leading circular icon chip, title + muted subtitle, and a trailing
   value/chevron. Replaces the superseded spec's flat "grouped list cells."
4. **Progress card** — same row-card shell, holding: title + a small rounded percentage
   pill (accent-tinted, or danger-tinted when over-budget/at-risk) on one row, a linear
   progress bar beneath it (never a ring — the mockups consistently use linear, resolving
   `docs/ui-ux-mockup-brief.md` §13's open question in favour of the current code's
   existing linear treatment), then a muted footnote line ("R 1,240 / R 2,000" or "R 450
   over budget"). Used for Budgets, Goals, and the Dashboard's single progress block.
5. **Quick-link tile** — a small square tile (icon chip + label, stacked) for the
   Dashboard's Accounts/Assets/Liabilities/Calculators row — replaces the superseded
   spec's inline `ActionChip` row with something closer to the mockup's 4-up grid.

## Screen-by-screen direction

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
5-tab `NavigationBar` as specified above, unchanged. Tab-root screens get the
avatar+title+bell app bar (Settings excepted — see Navigation above); pushed screens get
back+title.

### 3. Dashboard / Home
Confirmed directly by mockup. Top: hero metric card for **Net Worth**, with a small
translucent trend-delta pill. Below: compact stat strip (Income / Expenses this month).
Below that: one progress card (linear, not a ring — see Signature components) for the
single most relevant budget or goal. Below that: a 4-up quick-link tile row (Accounts /
Assets / Liabilities / Calculators). Below: a row-card preview of the 3-5 most recent
transactions, with a "See all" text link to the Transactions tab. Same fixed vertical
order as the superseded spec, just re-skinned to the new card/hero components.

### 4. Accounts
Confirmed directly by mockup — and the mockup adds a hero metric card ("Total balance")
above the list that the superseded spec didn't have; added since the account balances are
already loaded client-side (a client-side sum, no new API call). Active accounts render
as row cards (institution as muted subtext, balance trailing). Soft-deleted (deactivated)
accounts render in a collapsed "Inactive" group beneath active ones, matching the
backend's soft-delete/restore semantics — never just hidden with no way back in. A pill
"+ Add account" CTA as a persistent FAB, per mockup.

### 5. Transactions — list + detail/edit
Confirmed directly by mockup. List: filter chip row (All/Income/Expense/Transfer — visual
only for now, matching the mockup; wiring it to the existing-but-unused filter provider is
a separate, already-tracked gap, not part of this visual pass) then row cards grouped by
date (day headers as muted small-caps labels), each row: merchant-icon chip + merchant/
description, category as muted subtext, amount trailing (plain text colour, not
success/danger-tinted — the mockup renders ordinary expense/income amounts in the same
ink colour, reserving green/red for goal/budget progress and destructive actions only).
Tapping a row opens the existing detail/edit bottom sheet, restyled to the new field
theme, fields unchanged. Reimbursement-linking and transfer-pair badges (small pill tags)
sit just below the amount row on both list and detail views, unchanged from the
superseded spec — not shown in the mockup's sample data but still the documented plan.

### 6. Budgets
Confirmed directly by mockup. Progress cards (see Signature components), one group per
top-level category, month selector above (chevron-left / "May 2025" / chevron-right).
Sub-categories render as indented progress cards within their parent's group (mirrors the
web app's recursive parent/sub-category tree, flattened to one level of visual indentation
for mobile clarity rather than infinite nesting). Over-budget rows use the danger colour
on the progress fill, the percentage pill, and the "R X over budget" footnote — not a
full-row red background. A segmented Budgets/Goals toggle sits above the list (unchanged
IA, restyled to a pill segmented control per the mockup).

### 7. Goals
Confirmed directly by mockup (second segment of the Budgets tab). Same progress-card
pattern as Budgets: title + percentage pill + linear bar + "R saved / R goal" footnote,
one card per goal, no sub-nesting.

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
