# Design System: Piggybank (Stitch Exploration Brief)

> **Status: exploratory, not canonical.** This is a Google Stitch input brief for
> generating *new* visual reference designs across the full app. It is grounded in
> what's actually shipped today (`DESIGN.md`, the project's canonical design record)
> but deliberately invites new directions on top of it, per an explicit team decision
> to run a full-app redesign exploration rather than a locked-identity refresh.
> Stitch's output is meant to come back as real reference mockups for re-implementation
> in Flutter/Material 3 — treat every instruction below as something a screen must
> actually satisfy, not just mood-board language.

## 1. Visual Theme & Atmosphere

Piggybank is a calm, confident personal-finance app — the anti-bank-app, anti-SaaS-
dashboard, anti-gamified-trading-app. No navy-and-blue corporate finance look, no
navy-sidebar enterprise dashboard, no confetti/streaks/badges. The feeling is closer to
a well-organized personal ledger kept by someone who actually enjoys money being in
order: quiet trust, not urgency; clarity, not cleverness.

**Density:** 5 — "Daily App Balanced," leaning toward the denser end because financial
list data (transactions, holdings, budget rows) needs to be scannable without endless
scrolling, but never cockpit-dense — always room to breathe around hero numbers.

**Variance:** 5 — moderate, confident asymmetry. Not a rigid corporate grid, but a
finance app also isn't the place for artsy chaos; asymmetry should show up as
considered whitespace and offset card rhythm, not unpredictable layout.

**Motion:** 4 — fluid, restrained. Financial data earns trust through steadiness, not
spectacle; motion should feel like weight settling into place, never flashy.

This atmosphere carries over from what's shipped today. The exploration space is in
*execution*, not *mood* — push the typography, iconography, and layout rhythm further
than the current build's safe Material-default edges, without turning the app into
something that reads as a different product.

## 2. Color Palette & Roles

Grounded in the shipped palette's DNA (near-white canvas, near-black ink, one
restrained green accent) but refined toward more distinctive, less default-Material
values — open to Stitch proposing adjacent hues within this same structure.

- **Canvas** (#FAFAF9) — primary background. Off-white, not pure `#FFFFFF` — warmer,
  less clinical than a stock white canvas.
- **Surface** (#FFFFFF) — card/row-card fill, differentiated from canvas by a hairline
  border + soft shadow, not by a separate fill colour.
- **Charcoal Ink** (#141815) — primary text. Off-black, never pure `#000000`.
- **Muted Slate** (#6B7280) — secondary text, subtext, metadata, timestamps.
- **Whisper Border** (rgba(20,24,21,0.08)) — card borders, hairline dividers.
- **Ledger Green** (#1F8A4C) — the single accent. Primary CTAs, active nav state,
  progress fills, links, focus rings. Saturation kept moderate — confident, not neon.
  This is the one color allowed to carry weight; everywhere else stays neutral.
- **Accent Wash** (#E4F5EA) — accent-tinted icon-chip backgrounds, positive pills.
- **Alert Red** (#D64545) — reserved *only* for over-budget/at-risk states and
  destructive actions (e.g. "Log out," "Delete account"). Ordinary negative transaction
  amounts stay in Charcoal Ink, never red — red means "needs attention," not "this
  number happens to be negative."
- **Alert Wash** (#FCE8E8) — danger-tinted chip backgrounds.

**Dark mode** (first-class, not an afterthought — propose this explicitly, since it's
currently unconfirmed against any real mockup):
- Canvas → `#0F1412`, Surface → `#181F1B`, Charcoal Ink inverts to `#F2F5F1`,
  Muted Slate → `#9AA69E`, Border → `#28322C`, Ledger Green brightens to `#3FC876` for
  contrast, Alert Red brightens to `#E8685F`.

**Mandatory constraint:** exactly one accent hue (Ledger Green) across the entire app.
No purple, no neon glow, no gradient-heavy CTAs. The hero metric card is the one place
a gradient is allowed (green-toned, `#6FBE8C → #227A4E`, top-left to bottom-right) —
everywhere else, flat fills only.

## 3. Typography Rules

Open-direction proposal: move off a purely safe geometric grotesk toward something with
more character, while keeping numerals disciplined and highly legible — money is the
product, typography for money is not a place to be clever at the expense of clarity.

- **Display / headings:** `Cabinet Grotesk` (or `Satoshi` as a close alternate) — a
  distinctive geometric sans with more personality than the current build's Manrope,
  track-tight, weight-driven hierarchy rather than scale-driven. Semibold/Bold only.
- **Body / labels:** `Satoshi` (or the same family as display, one weight down) —
  relaxed leading, comfortable at small sizes for dense list rows.
- **Money & percentage figures:** stay in the body/display family (continuity with
  what's shipped — the current build deliberately dropped a separate mono face here),
  but with tabular-figure alignment enforced in every list/table context. **Flagged as
  worth testing as an explicit alternate:** a distinct monospace face (`JetBrains Mono`
  or `Geist Mono`) for money figures specifically was the *original* pre-mockup design
  direction before it was dropped — if Stitch's output makes a strong case for bringing
  it back, treat that as a legitimate finding to bring back to the team, not a rule to
  follow by default here.
- **Scale:** headline/title/body-large/body/caption roughly 28/22/17/15/13 — inherited
  from the shipped scale, don't reinvent proportions, refine letterforms instead.
- **Banned:** `Inter` (too default/safe for this exploration), generic serif faces
  entirely (`Times New Roman`, `Georgia`, `Garamond` — this is a sans-only dashboard
  product, no serif anywhere, not even for editorial moments).

## 4. Component Stylings

- **Buttons:** pill-shaped, fully rounded (inherited, confirmed by every shipped CTA).
  Flat Ledger Green fill for primary, ghost/outline for secondary. Tactile −1px
  translate on press. No outer glow, no custom cursors.
- **Hero metric card:** full-width, 24px radius, green gradient fill (see Colour),
  white text — small label, one large bold figure, optional translucent-white delta
  pill beneath. Used once per screen, at the top, never repeated for lesser numbers.
  This is Piggybank's signature component — protect its rarity, don't let Stitch turn
  every stat into a hero card.
- **Row card:** the base pattern for every list — Accounts, Transactions, Assets,
  Liabilities, Settings rows, holdings: white surface, 20px radius, hairline border +
  soft neutral-grey shadow (never warm-tinted), ~16px internal padding, leading circular
  icon chip (accent-tinted by default, danger-tinted for warnings), title + muted
  subtitle, trailing value/chevron.
- **Progress card:** same row-card shell — title + rounded percentage pill (accent or
  danger-tinted) on one row, a **linear** progress bar beneath (never a ring — settled
  decision, don't propose rings), then a muted footnote line ("R 1,240 / R 2,000").
- **Compact stat strip:** a horizontal row of 2–3 small stat blocks (label + bold
  figure), no borders between entries, spacing only.
- **Quick-link tile:** small square tile, icon chip + stacked label, used in a 4-up grid
  on the Dashboard.
- **Inputs:** label above field, soft outlined rounded fields, helper text optional,
  error text below in Alert Red. No floating labels.
- **Loaders:** skeletal shimmer matching the exact layout it's replacing — no generic
  circular spinners anywhere.
- **Empty states:** composed, illustrated — never a bare "No data" line.
- **Icon chips:** circular, accent-tinted (or danger-tinted), Material-Symbols-style
  filled/outlined icons — not a bespoke custom line-icon set (unachievable at this
  fidelity, and not what reads as premium here — the icon *chip treatment* is the
  distinctive part, not the icon glyphs themselves).

## 5. Layout Principles

This is a mobile phone app, not a responsive website — every screen is single-column by
definition, so the usual "collapse below 768px" rule is implicit everywhere, not a
breakpoint concern. Within that constraint:

- No overlapping elements — every element in its own clear vertical zone.
- Contain content within comfortable side padding (16–24px), never edge-to-edge except
  the hero metric card and full-bleed images.
- The bottom-nav shell (5 tabs: Home, Invest, Budgets, Insights, Settings) is fixed and
  non-negotiable — Material 3 `NavigationBar`, active tab in Ledger Green.
- Tab-root screens carry an avatar-placeholder + centred title + notification-bell top
  bar; pushed/detail screens carry a back-arrow + title bar. Settings is a tab-root but
  omits the avatar/bell (it already surfaces identity in its own first row).
- Vertical rhythm on data-dense screens (Transactions, Budgets, holdings lists): group
  by logical unit (date, category, account) with a muted small-caps section label, not
  a hard divider line.

## 6. Motion & Interaction

- Spring physics for all interactive transitions (`stiffness: 100, damping: 20`) — no
  linear easing anywhere.
- Staggered cascade reveals for list rows on first load (Accounts, Transactions,
  holdings) — never mount a list instantly.
- Restrained perpetual micro-interaction: a subtle pulse or shimmer on the hero metric
  card's number when it updates from a refresh, nothing else animates on a loop — this
  is a finance app, not a marketing site; motion should be occasional and meaningful.
- Animate only `transform`/`opacity` — never `top`/`left`/`width`/`height`.

## 7. Anti-Patterns (Banned)

- No emojis anywhere in the UI.
- No `Inter`, no generic serif fonts.
- No pure black (`#000000`) or pure white (`#FFFFFF`) as a *text* color (surfaces may
  use `#FFFFFF` as fill, per §2).
- No neon/outer-glow shadows, no oversaturated accents, no purple/blue "AI" gradient.
- No ring-style progress indicators (linear only, settled decision).
- No red/green duality on ordinary transaction amounts — red is reserved for
  over-budget/at-risk/destructive states only (portfolio price-movement figures are the
  one documented exception, since that's genuinely directional data).
- No generic "3 equal cards horizontally" feature-row layout.
- No centered hero/marketing-style composition on the Login screen — it should read as
  a calm product entry point, not a landing-page hero.
- No AI copywriting clichés ("Elevate your finances," "Seamless money management,"
  "Unleash your savings potential").
- No filler UI text ("Scroll to explore," bouncing chevrons — irrelevant to an app
  context but flagged for consistency with the source guardrails).
- No generic placeholder names in sample data ("John Doe," "Acme Bank") — use plausible
  South African names/institutions (e.g. "Thandiwe M.," "Standard Bank," "Capitec") to
  keep generated screens grounded in the app's actual context.
- No broken image links — use `picsum.photos` or SVG placeholders for any imagery.

## 8. Screen-by-Screen Direction

Every screen below should be generated. Screens marked **(grounded)** have a confirmed
shipped precedent to evolve from; screens marked **(new — no precedent)** have zero
existing visual direction and need genuine design thinking, not a restyle.

### Login / Register **(grounded)**
Piggy-bank mascot illustration (3D-illustrated style, warm and approachable, not
cartoonish/childish) centred top-third, "Piggybank" wordmark + tagline, generous
whitespace, soft outlined email/password fields, one primary pill CTA, plain-text
toggle link, small reassurance line at the bottom about data privacy. No landing-page
hero energy — this should feel like opening a trusted personal tool.

### Lock / biometric unlock **(grounded, extended)**
Same calm layout as Login, fingerprint/face icon replacing the password field. Reuses
the entry-point mood exactly — this is a returning-user moment, not a first impression.

### Dashboard / Home **(grounded)**
Hero metric card for Net Worth with a translucent trend-delta pill → compact stat strip
(Income/Expenses this month) → one progress card for the most relevant budget or goal →
4-up quick-link tile row (Accounts/Assets/Liabilities/Calculators) → row-card preview of
3–5 recent transactions with a "See all" link. Fixed vertical order — explore new
component *styling*, not a new information order.

### Accounts **(grounded)**
Hero metric card ("Total balance") above a row-card list. Active accounts show
institution as muted subtext, balance trailing. Soft-deleted accounts collapse into a
separate "Inactive" group beneath — never just hidden. Persistent pill "+ Add account"
FAB.

### Transactions — list + detail **(grounded)**
Filter chip row (All/Income/Expense/Transfer) → row cards grouped by date (muted
small-caps day headers) → merchant icon chip + description, category as muted subtext,
amount trailing in ordinary ink (not red/green). Tapping opens a detail/edit sheet in
the same field theme. Reimbursement-linking and transfer-pair badges as small pill tags
beneath the amount.

### Budgets **(grounded)**
Progress cards grouped by top-level category, month selector above (chevron / month
label / chevron). Sub-categories render as indented progress cards within their
parent's group. Over-budget rows use Alert Red on the fill, pill, and footnote only —
never a full-row red background. Segmented Budgets/Goals pill control above the list.

### Goals **(grounded)**
Same progress-card pattern as Budgets — title, percentage pill, linear bar, "R saved /
R goal" footnote, one card per goal, no sub-nesting.

### Invest tab-root **(grounded, unbuilt precedent)**
Hero metric card for Total portfolio value, delta chip + unrealized P&L/YTD dividends
stat strip → allocation donut with a colour-swatch legend → "Top holdings" row-card
preview (3 rows, "See all") → "Your portfolios" row-card list (TFSA, Retirement
Annuity, and General Portfolio appear as plain rows in one list, not separate screens).

### Portfolio detail **(grounded, highest complexity — most design attention warranted)**
Hero metric card for portfolio value + delta chip → horizontal stacked allocation bar
with compact legend (not a donut, for mobile-width legibility) → row-card holdings list,
each with ticker/name, an inline accent-coloured sparkline, current value trailing,
day-change as a small percentage beneath (green if up, red if down — the one place
red/green duality on ordinary figures is correct, since it's price direction, not a
budget state). Tapping opens a detail sheet: single clean price-history line chart →
dividend history as a row-card list → a "Sell" pill action.

### Assets / Liabilities **(grounded by extension)**
Inherit the Accounts row-card pattern and hero-metric-card treatment (Total assets /
Total liabilities). Liabilities additionally show a small amortisation/payoff progress
indicator per row where relevant.

### Expenses summary **(grounded by extension)**
Hero metric card for the period total, then a category breakdown — propose whether a
donut (matching Invest's allocation treatment) or a horizontal bar list reads better for
expense categories specifically; this is a genuine open design question to resolve
through the generated output, not a foregone conclusion either way.

### Calculators (loan calculator, loan accelerator) **(grounded by extension)**
Simple form-first layout: labeled inputs above, a hero-metric-card-style result block
below showing the calculated figure prominently, using the same card language as
everywhere else in the app rather than a separate "tool" visual identity.

### CSV Import wizard **(new — no precedent)**
A 3-step wizard (Configure → Upload → Review). Needs real design thinking: a clear step
indicator (not a generic progress dots pattern — propose something that fits the app's
row-card/pill language), a file-upload zone that doesn't read as a generic drag-and-drop
web component, and a review step that reuses the Transactions row-card pattern with a
confidence-score pill per imported row (accent-tinted for high confidence, danger-tinted
for low, per the existing backend contract).

### Consent acceptance screen **(new — just built in-app, no visual precedent)**
A screen listing the required documents (Privacy Policy, Terms of Service) as
checkable row items, each with a "Read" affordance opening the full document text, and
a primary CTA that's disabled until every item is checked. Should read as a calm,
un-alarming administrative moment — not a scary legal wall. Also needs a secondary,
read-only "already accepted" state for when it's reached from Settings for review
rather than as a gate.

### Insights tab **(new — currently a bare placeholder, no precedent at all)**
Currently unbuilt beyond a stub. This is the highest-value new-design target in the
whole brief: propose a genuinely considered layout for trend insights — net-worth-
over-time, spending pattern callouts, budget-adherence trends. Should use the hero
metric card + progress card + stat strip vocabulary already established elsewhere
rather than inventing a fourth visual language, but the actual information architecture
here is wide open.

### Settings + sub-screens **(mixed — root grounded, sub-screens new)**
Settings root: row-card list, no avatar/bell top bar (see Navigation), profile summary
row at top, then grouped settings rows, "Log out" as a destructive-styled row at the
bottom (Alert Red). The following sub-screens have **zero existing visual precedent**
and need real design work: **Security** (biometric toggle, PIN change), **Notifications**
(preference toggles), **Appearance** (theme selection — light/dark/system, tying
directly into the dark-mode palette in §2), **Subscription** (plan/tier display,
upgrade CTA), **Import history** (a row-card list of past CSV imports with status
pills). "Privacy & consent" (just shipped) reuses the Consent acceptance screen above.

## 9. Notes for Using This Brief With Stitch

- Upload this file as the design-system input for every screen generation request —
  don't regenerate the palette/typography/component rules per screen, keep them fixed
  across the whole batch so the output reads as one coherent app.
- Where a screen is marked **(new — no precedent)**, give Stitch explicit permission to
  generate multiple variations rather than accepting the first output — these are the
  screens where genuine design decisions are still open.
- Treat this brief as intentionally more opinionated than the currently-shipped
  `DESIGN.md` in typography and micro-interaction — that gap is the point of this
  exploration. If the generated output doesn't feel meaningfully more distinctive than
  what's already built, the brief hasn't done its job.
