# Visual rework 02b: three directions

Session 2 of the visual rework epic, written 2026-10-10. **Status: waiting for Tiaan
to pick one direction, or to merge parts of them.** Session 3 turns the pick into
`04-visual-spec.md` and the full light/dark mockups.

**Inputs:**
- Principles: `01-visual-principles.md` (R, P, C, A, J, X).
- Research: `02-craft-research.md`.
- Audit findings: `03-visual-audit.md` (S1–S11, M1–M42).
- The locked IA: `docs/ux-rework/04-spec.md`.

Palettes and pairings were shortlisted with the `ui-ux-pro-max` design database
(fintech colour rows, sans/serif pairing rows), then tuned by hand and **measured**.

**Rules every direction keeps:**
- **Presentation layer only.** The IA, tab set, section order and copy rules of
  `04-spec.md` stay as they are.
- **Fonts:** Google Fonts only (OFL), so they run through `google_fonts` exactly as
  Manrope does today.
- **Semantic colour:**
  - Red is reserved for over-budget and destructive actions.
  - Ordinary spending stays neutral ink.
  - Income and positive P/L carry a sign as well as colour (P6).
- **Money:**
  - Every money figure uses tabular figures (S4, J3).
  - The hero number uses `valueTransition`.
- **Motion:**
  - Reduced motion everywhere.
  - Feedback in under 100 ms; transitions ≤ 300 ms, except value and hero.
  - No confetti, streaks or badges.
- **Mascot:** Penny only from the existing 5 assets. No sad piggy. No paid image
  generation.

---

## How the three differ at a glance

| | A · **Ledger** | B · **Pocket** | C · **Precision** |
|---|---|---|---|
| One line | Quiet, editorial, "a well-kept notebook" | Soft, tactile, Penny-forward, "a friendly pocket" | Crisp, data-forward, "an instrument panel" |
| Persona fit (C2) | Monthly planner who wants calm | Daily checker who wants reassurance and warmth | Investor-leaning checker who wants numbers fast |
| Primary hue | Forest green `#1E5B3E` | Plum `#6B2D5C` + blush hero | Deep teal `#0B6E5F` / mint on dark |
| Hero treatment | Solid deep-forest panel, serif figure | **Light** blush panel, dark ink, Penny overlaps the edge | Ink-black panel, mint data accents, sparkline |
| Type | Newsreader (display) + Hanken Grotesk | Plus Jakarta Sans 800 + Nunito Sans | Space Grotesk + Inter |
| Shape | 8 dp radius, squared, hairline-free | 24 dp / pills, chunky | 12 dp, precise, 1 dp hairlines |
| Depth | Tonal layers only, no shadows | Soft tinted shadows, overlap (R12) | Hairlines + surface steps, overlay shadow only |
| Motion personality | Measured: standard easing, no overshoot | Springy: gentle overshoot on press/settle | Snappy: short decelerate, crisp crossfades |
| Grouping (S3) | Space + section rules, almost no cards | Few big tinted cards, rows inside | Grouped lists in one surface, hairline rows |
| Risk | Can read "serious" or slow if overdone | Can tip into playful/kiddy if overdone | Can read cold or generic-fintech |

---

## A · Ledger

**Idea.** A personal ledger kept in good ink. It's calm, adult and warm. Paper-toned
neutrals replace stock grey (R9), and depth comes from tone, not shadow. The serif hero
figure is the one moment of personality. Everything else is quiet, so the number leads
(R1, R2).

### Palette (measured)

| Role | Light | Dark |
|---|---|---|
| Background | `#F7F4EC` (paper) | `#121512` |
| Surface (raised group) | `#FFFDF8` | `#1A1E1A` |
| Surface sunk (inputs, tracks) | `#EFEADF` | `#0E110E` |
| Ink | `#1A1F1A` | `#ECEAE2` |
| Ink muted | `#595E54` | `#A7ACA2` |
| Primary / on-primary | `#1E5B3E` / `#FFFFFF` | `#8FCBA4` / `#0E2A1C` |
| Primary container / on | `#DCEBDD` / `#123A27` | `#24402F` / `#C6E6CF` |
| Positive (income, +P/L) | `#1E6B44` | `#8FCBA4` |
| Danger (over budget, delete) | `#A8322D` | `#F2A49B` |
| Danger container / on | `#F6E1DC` / `#7A1F1B` | `#4A2421` / `#F8D5CF` |
| Hero / on-hero / hero muted | `#16402C` / `#F7F4EC` / `#B9D3C1` | `#1F3A2A` / `#ECEAE2` / `#A9C9B4` |
| Outline (UI parts) | `#8C8A7C` | `#6E7469` |
| Chart ramp (X6) | forest `#1E5B3E` · ochre `#B9822E` · clay `#9A5B3F` · sage `#7FA38A` · ink `#595E54` | lightened steps of the same hues |

### Type

- **Display:** Newsreader 600 (hero money 40/44, −1 % tracking; screen titles 28/34).
- **UI:** Hanken Grotesk 400/600 (title 20/26, body 16/24, label 13/18 +1 %).
- **Money:** in rows, Hanken Grotesk 600 with `tnum`. The hero uses Newsreader with
  `tnum lnum`.

### Shape, space, depth

- **Radius:**
  - 8 dp for groups and sheets.
  - 6 dp for chips and inputs.
  - Buttons are 8 dp rectangles, not pills.
- **Spacing:** 4 · 8 · 12 · 16 · 24 · 32 · 48. Sections are separated by 32 dp plus a
  label in small caps (Hanken 600, 12 sp, +6 %).
- **Depth:** three tonal steps (sunk, base, raised), no shadows. The bottom sheet gets
  the only shadow (overlay level). Borders are removed. Rows separate by space, and
  groups by surface tone (R7, P9).

### Motion

Measured. Standard easing (`Curves.easeInOutCubicEmphasized` on entry, `easeIn` on
exit):
- Press: 0.98 scale, 120 ms.
- Skeletons fade to content at 200 ms.
- The hero figure counts up over 400 ms with no overshoot.
- Feedback haptics: `selectionClick` only.

### Penny

Shown as a small framed portrait: a circle with a 2 dp paper ring.
- On Penny's tab, the greeting holds a 72 dp portrait.
- On Lock, a 96 dp welcoming portrait above the PIN.
- Empty states use a 120 dp portrait with one sentence and one action (R15).

### S1 fixes

- The hero becomes solid `#16402C` with paper text at **10.59:1** (was 2.23:1).
- Dark mode's primary becomes a light sage with *dark* text, at **8.23:1** (was 2.16:1).
- Light buttons are white on forest at **8.01:1** (was 4.38:1).
- Danger on paper is **6.05:1** (was 4.38:1).
- Pill text is on-container on container at **10.22:1** (was 3.87:1).

---

## B · Pocket

**Idea.** The app as a soft, well-made pocket: tactile, rounded, and unmistakably
Piggybank. It's the only direction that gives Penny a resting place on Home. The hero
is **light**, a blush panel with dark ink, which fixes S1 by inverting the problem
instead of darkening it. Plum is the action colour, so red and green stay free for
meaning.

### Palette (measured)

| Role | Light | Dark |
|---|---|---|
| Background | `#FFF8F5` | `#1C1418` |
| Surface | `#FFFFFF` | `#261C21` |
| Surface sunk | `#FBEDEA` | `#160F13` |
| Ink | `#2A1B22` | `#F6EAEE` |
| Ink muted | `#6A5660` | `#C2ACB5` |
| Primary / on-primary | `#6B2D5C` / `#FFFFFF` | `#F2A7C8` / `#3D0F2A` |
| Primary container / on | `#F6DDEB` / `#4E1A42` | `#4A2340` / `#FBD9EA` |
| Positive | `#0F7A5C` | `#6FD6AE` |
| Danger (burnt orange-red, distinct from plum) | `#B4380C` | `#FFA37A` |
| Danger container / on | `#FDE3D6` / `#7C2508` | `#4A2214` / `#FFD6C4` |
| Hero / on-hero / hero muted | `#FFD9E2` / `#2A1B22` / `#6A3A4C` | `#3A2430` / `#F6EAEE` / `#D9B3C4` |
| Outline | `#9C8790` | `#7C6670` |
| Chart ramp | plum `#6B2D5C` · teal `#0F7A5C` · peach `#E08A5A` · blush `#D97A9B` · ink `#6A5660` | lightened steps |

Category icon chips get one tint each from the chart ramp (R13, S6), so
category identity is carried by colour *and* icon.

### Type

- **Display:** Plus Jakarta Sans 800 (hero money 44/48, −2 %; titles 26/32 700).
- **UI:** Nunito Sans 400/700 (body 16/24, label 13/18).
- **Money:** Plus Jakarta Sans 700 with `tnum`.

### Shape, space, depth

- **Radius:**
  - 24 dp for cards and sheets.
  - Pills for buttons, chips and the segmented control.
  - 16 dp for inputs.
- **Spacing:** the same 4/8 scale, with larger section gaps (40 dp) so the few cards
  breathe.
- **Depth:** a soft plum-tinted shadow, two levels:
  - raised: `0 4 16 rgba(107,45,92,0.08)`
  - overlay: `0 12 32 rgba(107,45,92,0.14)`
- Penny overlaps the hero's top-right edge, which gives the screen a third plane (R12).
- Rows sit *inside* one card per section, not a card per row (S3).

### Motion

Springy and tactile:
- Press: 0.96 scale on a spring (`SpringDescription(mass 1, stiffness 400, damping 28)`,
  about a 4 % overshoot).
- Sheets: rise on a spring.
- List inserts: slide 8 dp and fade.
- The hero counts up with a tiny settle.
- Haptics: `selectionClick` on chips and segments, `lightImpact` on save.

### Penny

The most present of the three, at rest:
- Home: a 96 dp Penny (`mascot_welcoming`) sits on the hero's edge.
- Penny's tab: the greeting holds a 120 dp Penny.
- Lock: a large welcome.
- Empty states use the full pose.
- Celebrations are the existing once-a-day moments only.

### S1 fixes

- The hero is dark ink on blush at **12.73:1** (it was white on green).
- Dark mode's primary is light pink with dark text at **8.57:1**.
- Light buttons are white on plum at **9.74:1**.
- Danger is **5.69:1** on the background.
- Pill text is **10.62:1**.

---

## C · Precision

**Idea.** An instrument panel for your money: crisp, fast and exact. Ink-black hero,
mint data accents, hairline rows and the densest layout of the three. It suits Plan
and Invest's sovereign posture (C3) and stays glanceable on Home through size, not
colour. Dark mode is the natural home, and light mode keeps the black hero as its
anchor.

### Palette (measured)

| Role | Light | Dark |
|---|---|---|
| Background | `#F4F6F5` | `#0A0F0E` |
| Surface | `#FFFFFF` | `#121917` |
| Surface sunk | `#E9EEEC` | `#070B0A` |
| Ink | `#0E1513` | `#E8EFEC` |
| Ink muted | `#525D59` | `#97A6A0` |
| Primary / on-primary | `#0B6E5F` / `#FFFFFF` | `#5EE6C1` / `#00382F` |
| Primary container / on | `#CFEDE6` / `#053D34` | `#0F3B33` / `#B5F5E2` |
| Positive | `#0B7550` | `#5EE6C1` |
| Danger | `#B3261E` | `#FF8A80` |
| Danger container / on | `#FBE2DF` / `#7F1A14` | `#47201D` / `#FFD3CE` |
| Hero / on-hero / hero muted | `#0E1513` / `#FFFFFF` / `#9FB2AB` | `#13201D` / `#E8EFEC` / `#8FB5A9` |
| Hero data accent | `#5EE6C1` (sparkline, progress) | same |
| Outline | `#7D8884` | `#5C6965` |
| Chart ramp | teal `#0B6E5F` · mint `#5EE6C1` · slate `#5B7A8C` · amber `#C99A2E` · ink `#525D59` | lightened steps |

### Type

- **Display and money:** Space Grotesk 600 (hero 40/44, −2 %; titles 22/28).
  Space Grotesk's figures are the precision cue, always `tnum`.
- **UI:** Inter 400/600 (body 15/22, label 12/16 +2 %).

### Shape, space, depth

- **Radius:**
  - 12 dp for groups.
  - 8 dp for chips and buttons.
  - 10 dp for inputs.
- **Spacing:** the 4/8 scale at its tightest. Rows are 56 dp, and sections 24 dp.
- **Depth:**
  - One surface per section, with 1 dp hairline row dividers in the outline token at
    40 %.
  - No shadows except the overlay level.
  - The hero is the only dark block on light screens.

### Motion

Snappy:
- Press: 0.98 scale plus a state layer, 90 ms.
- Decelerate easing (`Curves.easeOutQuart`), 180–220 ms.
- Charts draw in left to right over 300 ms.
- The hero ticks over digit by digit.
- Haptics: `selectionClick` on chips, segments and month change.

### Penny

Restrained:
- A 40 dp monochrome-ringed avatar in the Penny header and chat.
- Lock shows a 72 dp Penny.
- Empty states use a 96 dp Penny.
- Penny never sits on Home at rest.

### S1 fixes

- The hero is white on ink at **18.50:1**.
- Dark mode's primary is mint with dark text at **8.44:1**.
- Light buttons are white on teal at **6.16:1**.
- Danger is **6.02:1** on the background.
- Pill text is **9.81:1**.

---

## Contrast evidence

Measured with the WCAG 2.x relative-luminance formula (a scratch script, same method
as the audit). The floors were 4.5:1 for text pairs and 3:1 for UI parts. **102 pairs
measured, 0 failures.**

| Pair (floor) | A light | A dark | B light | B dark | C light | C dark |
|---|---|---|---|---|---|---|
| Ink on background (4.5) | 15.23 | 15.27 | 15.64 | 15.42 | 17.04 | 16.54 |
| Muted on background (4.5) | 6.06 | 7.94 | 6.42 | 8.48 | 6.30 | 7.61 |
| Muted on sunk (4.5) | 5.55 | 8.20 | 5.91 | 8.87 | 5.83 | 7.80 |
| On-primary on primary (4.5) | 8.01 | 8.23 | 9.74 | 8.57 | 6.16 | 8.44 |
| Primary as text on surface (4.5) | 7.88 | 9.04 | 9.74 | 8.77 | 6.16 | 11.52 |
| On-container on container (4.5) | 10.22 | 8.45 | 10.62 | 10.10 | 9.81 | 10.11 |
| Positive on surface (4.5) | 6.37 | 9.04 | 5.30 | 9.37 | 5.71 | 11.52 |
| Danger on background (4.5) | 6.05 | 9.25 | 5.69 | 9.27 | 6.02 | 8.46 |
| On-danger-container (4.5) | 8.20 | 9.84 | 8.06 | 10.24 | 8.27 | 10.36 |
| On-hero on hero (4.5) | 10.59 | 10.27 | 12.73 | 12.15 | 18.50 | 14.37 |
| Hero muted on hero (4.5) | 7.29 | 6.90 | 7.01 | 7.59 | 8.31 | 7.47 |
| Outline on surface (3.0) | 3.42 | 3.51 | 3.34 | 3.14 | 3.67 | 3.11 |
| Primary on container (3.0) | 6.47 | 6.08 | 7.64 | 6.94 | 4.96 | 8.01 |

Against the audit's S1 failures: hero 2.23 → ≥ 10.27, dark accent 2.16 → ≥ 8.23,
light buttons 4.38 → ≥ 6.16, danger 4.38 → ≥ 5.69, pills 3.87 → ≥ 9.81.

---

## Stitch screens

Project **Piggybank v2 Directions** (`projects/2869264751174926029`, private).

**Why it's a new project:** the plan said to use the existing project, "Piggybank Design
System" (`projects/4011413732038259168`). The connected Stitch key only has READER
access to it, so it can't create design systems or screens there. Tiaan chose a new
project on 2026-10-10. The old project is untouched.

There is one design system per direction, labelled "v2". Every direction has the same
five screens, built from `04-spec.md`'s locked IA with the same sample data:
- Home: OTA and review banners, hero "Left to spend · October", savings, net worth,
  needs attention, 5 recent rows, FAB.
- Transactions: header with Review and Insights, type chips, grouped days.
- Plan › Budgets: month in the app bar, Budgets · Goals · Savings, total spent leading.
- Penny: header, greeting, 3 data-aware chips, input.
- Home in dark.

The side-by-side grid is `img/02b-directions-grid.png`. Its columns are Home (light),
Transactions, Plan › Budgets, Penny and Home (dark). Each screen is cropped to its
first ~850 dp.

Screen IDs are under `projects/2869264751174926029/screens/`.

| Direction | Design system | Home (light) | Transactions | Plan › Budgets | Penny | Home (dark) |
|---|---|---|---|---|---|---|
| A · Ledger | `assets/2433414728080549754` | `1f790d284b6b44d393f8a1279bc59097` | `e9e9f6a2ff2b4f53bd35961b4b55462b` | `ec7674bdf56e4bf0a8c5cdb6dff6a25f` | `31862907cc4244b4871476eea7d77a10` | `4ed89f98c1984eadb31373b4b379fc83` |
| B · Pocket | `assets/3207442370290268890` | `d19437d9605d4b17b4afe1e0e8fd0c5e` | `6eaf848e0ca34400b8d4e220b2b0af98` | `5191b28fcc884cf6aecc3bf8ee3cb286` | `15528ddbab314757a1ecd693fa39b4a4` | `3de17c5bda9b40d296178f1e30182a97` |
| C · Precision | `assets/18139356660418287905` | `55565b4eb05c415c93a04ca964c78639` | `7d64bdceee6b489883519a4a6fd6bef0` | `1d339a3e0a8342ed95f8264f7c7cd28d` | `36d08645e8c244c6ad6e81f7bbb37d32` | `f17d32b4233749fd97ea690396ae7fba` |

**Discarded renders** (they stay in the project and aren't part of the comparison):
- `e2f277cf…`: A Transactions came out as a desktop layout.
- `457c2384…`: B Plan came out as a desktop layout.
- `424ac9b2…`: a duplicate B Transactions, with an unexplained photo avatar.
- `8196c4e6…`: a blank C dark render.
- `7a6daca1…`: a stray C Home re-run.

### What the mockups get wrong (don't carry these into Session 3)

Stitch drifted from the brief in places. These are mockup artefacts, not proposals:

1. **Penny's image is not one of ours.** Stitch generated its own piggy render (screen
   `25bc96d7…`) and used it on B Home, B Penny, A Penny and C Penny. The build uses
   **only the 5 existing assets**. No new poses without Tiaan's yes.
   - On B Home, the "overlap" is a white square pasted on the hero. The real treatment
     needs a transparent pose, and that is image work, so it also waits for Tiaan's yes.
2. **A bell appears on Plan** in all three directions. §1.2 removed the bell, so Plan's
   header is avatar · title · month only.
3. **Invented copy:**
   - "Synced to Capitec & Investec", "Penny analyzes connected accounts" (that's US
     spelling, and it makes a false claim).
   - "Categorise to keep Penny happy". This is **guilt copy, a dark pattern, and is
     rejected.**
   - "Ledger inquiries", "SYNCED" and "Action".
   - A's greeting "Hi Julian" is a made-up name. The brief said "Hi there".
   - The Penny screens add extra summary lines and context strips that the spec
     doesn't define.
4. **B's net worth and savings sit side by side** on dark Home. The spec order is
   stacked (§2.1).
5. **C shows cents on Home's hero** ("R 4 210,00"). The spec hero rounds to rand.

What each one shows faithfully, and what the pick is really between:
- The palette and contrast.
- The hero treatment.
- Type, shape and depth.
- Grouping: A by space, B in big cards, C in hairline surfaces.
- Overall density.

## What Tiaan decides

1. **Pick A, B or C**, or name a merge, such as "B's hero and Penny with A's type and
   depth".
2. **Hero colour:** dark panel (A, C) or light panel (B)? It's the biggest single
   visual change on Home.
3. **Penny at rest on Home:** yes (B) or no (A, C)? The spec allows either, using
   existing assets only.

Session 3 then produces every screen in light and dark, `04-visual-spec.md` (all
M1–M42 rows answered) and the DESIGN.md rewrite.
