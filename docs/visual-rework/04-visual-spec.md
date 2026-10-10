# Visual rework 04: visual spec, "Ledger Pocket"

**Status:** draft for Tiaan's approval (Session 3). Nothing here is built yet; Session 4
turns it into the blueprint.

**The pick (2026-10-10):** B · Pocket's warmth and style, with A · Ledger's colour theme
and a **light** hero panel. Penny is shown as a **transparent cutout**, never a square,
and is **not at rest on Home**. Home keeps its two existing small moments (sleeping
Penny for "Quiet day so far", celebrating Penny when the savings target is met). See
`02b-directions.md` § Decision.

**What's locked and unchanged:**
- The IA in `docs/ux-rework/04-spec.md`: tabs, sections, order and copy rules.
- Every capability in `docs/ux-rework/03-capability-inventory.md`.
- The epic constraints: free OSS only, no dark patterns, no confetti, streaks or badges, reduced motion everywhere, feedback < 100 ms, transitions ≤ 300 ms.

Principle IDs (R, P, C, A, J, X) are from `01-visual-principles.md`, and S1–S11 and
M1–M42 are from `03-visual-audit.md`.

---

## 1. Tokens

### 1.1 Colour, light

| Role | Token | Hex | On it |
|---|---|---|---|
| Background (paper) | `bg` | `#F7F4EC` | ink |
| Surface (cards, sheets) | `surface` | `#FFFDF8` | ink |
| Sunk (inputs, tracks) | `sunk` | `#EFEADF` | ink, muted |
| Ink | `ink` | `#1A1F1A` | — |
| Muted text | `muted` | `#595E54` | — |
| Outline (lines only, never text) | `outline` | `#8C8A7C` | — |
| Primary | `primary` | `#1E5B3E` | `onPrimary #FFFFFF` |
| Primary container (chips, review banner, avatar) | `primaryContainer` | `#DCEBDD` | `#123A27` |
| Positive (income, +P/L, always with "+") | `positive` | `#1E6B44` | — |
| Danger (over budget, delete, log out only) | `danger` | `#A8322D` | — |
| Danger container | `dangerContainer` | `#F6E1DC` | `#7A1F1B` |
| **Hero panel** (light) | `hero` | `#DCEBDD` | figure and label `#123A27`, secondary `#3D6150` |
| Hero progress | `heroBar` / `heroTrack` | `#1E5B3E` / `#C4DCC8` | — |

Ordinary spending is shown in ink, never red: red means over budget, and only over
budget (guardrail, J4). "Needs attention" at 84 % keeps the primary bar; it turns danger
only once the budget is exceeded.

### 1.2 Colour, dark (designed, not inverted; fixes S9)

| Role | Hex | On it |
|---|---|---|
| `bg` | `#121512` | ink |
| `surface` | `#1A1E1A` | ink |
| `surfaceRaised` (sheets, menus, FAB container in place of a shadow) | `#222722` | ink, muted |
| `sunk` | `#0E110E` | muted |
| `ink` / `muted` / `outline` | `#ECEAE2` / `#A7ACA2` / `#6E7469` | — |
| `primary` | `#8FCBA4` | `onPrimary #0E2A1C` (dark text: fixes S1's 2.16:1) |
| `primaryContainer` | `#24402F` | `#C6E6CF` |
| `positive` | `#8FCBA4` | — |
| `danger` / container | `#F2A49B` / `#4A2421` | `#F8D5CF` |
| **Hero panel** (tonal) | `#1F3A2A` | figure `#ECEAE2`, secondary `#A9C9B4`; bar `#8FCBA4` on `#2C4A38` |

"Light hero" is a light-theme decision. In dark mode the hero is the tonal deep green,
so it's never the brightest thing on screen (S9).

### 1.3 Category tiles and chart ramp (fixes S6)

Each category family gets a tinted tile with a matching icon colour, so the row carries
identity without relying on colour alone (the icon and label still do the work). The
unknown-category fallback becomes a neutral tag icon, never an arrow.

| Family | Light tile / icon | Dark tile / icon | Chart series light / dark |
|---|---|---|---|
| Forest (food, groceries, income) | `#DCEBDD` / `#1E5B3E` | `#24402F` / `#8FCBA4` | `#1E5B3E` / `#8FCBA4` |
| Ochre (transport, fuel, travel) | `#F3E6CC` / `#8A5E14` | `#3D3220` / `#E3B866` | `#B9822E` / `#E3B866` |
| Clay (dining, entertainment, shopping) | `#F2DED3` / `#8A4A2E` | `#3E2A22` / `#E0A283` | `#9A5B3F` / `#E0A283` |
| Sage (bills, subscriptions, health) | `#E2ECE5` / `#3F6B4E` | `#26332B` / `#A9C9B4` | `#6E9579` / `#A9C9B4` |
| Neutral (other, unknown) | `#EFEADF` / `#595E54` | `#262A26` / `#A7ACA2` | — |

The exact category-to-family map lives with the category list in the build step; it's a
presentation lookup, with no schema change.

### 1.4 Contrast evidence

Measured with WCAG relative luminance (script: `contrast.py` with the merged theme). The
floor is **4.5:1** for text and **3:1** for UI parts and large figures. **65 pairs, 0
failures.**

| Pair (light) | Ratio | Pair (dark) | Ratio |
|---|---|---|---|
| ink on bg | 15.23 | ink on bg | 15.27 |
| ink on surface | 16.46 | ink on surface | 14.01 |
| muted on bg / surface / sunk | 6.06 / 6.55 / 5.55 | muted on bg / surface / sunk | 7.94 / 7.28 / 8.20 |
| white on primary | 8.01 | onPrimary on primary | 8.23 |
| primary on surface / bg | 7.88 / 7.29 | primary on surface / bg | 9.04 / 9.85 |
| on-container on primaryContainer | 10.22 | on-container on container | 8.45 |
| positive on surface | 6.37 | positive on surface | 9.04 |
| danger on surface / bg | 6.54 / 6.05 | danger on surface / bg | 8.48 / 9.25 |
| on-danger-container | 8.20 | on-danger-container | 9.84 |
| **hero figure on hero** | **10.22** | hero figure on hero | 10.27 |
| **hero secondary on hero** | **5.61** | hero secondary on hero | 6.90 |
| hero bar on track / on hero | 5.50 / 6.47 | hero bar on track / on hero | 5.25 / 6.63 |
| danger / positive on hero | 5.37 / 5.23 | danger / positive on hero | 6.22 / 6.63 |
| outline on surface (UI) | 3.42 | outline on surface (UI) | 3.51 |
| primary on primaryContainer (UI) | 6.47 | primary on container (UI) | 6.08 |
| category icons on tiles (UI) | 4.61–6.47 | category icons on tiles (UI) | 6.08–7.36 |
| chart series on surface (UI) | 3.28–7.88 | chart series on surface (UI) | 7.77–9.40 |
| focus ring on bg (UI) | 7.29 | focus ring on bg / raised muted | 9.85 / 6.56 |

**Session 1 failures, before → after:**
- Hero label: 2.23 → 10.22.
- Dark accent under text: 2.16 → 8.23 (the text is now dark).
- Light button: 4.38 → 8.01.
- Danger on white: 4.38 → 6.54.
- Percent pill text: 3.87 → 10.22.

One candidate failed and was replaced: light chart sage `#7FA38A` measured 2.75:1 and became `#6E9579` (3.31:1).

The hero panel against the paper background is 1.13:1. That's a surface boundary, not
an interactive part (WCAG 1.4.11 doesn't apply), and the hero is set apart by its
radius, its tint and a level-1 shadow.

### 1.5 Type (fixes S4)

Both fonts are on google_fonts (OFL). Every money figure uses
`FontFeature.tabularFigures()`.

| Role | Font | Size / line / weight | Use |
|---|---|---|---|
| `display` | Plus Jakarta Sans | 40 / 44 / 800, -1 % tracking | Hero figure only ("R 4 210") |
| `headline` | Plus Jakarta Sans | 28 / 34 / 800 | Tab-root titles |
| `title` | Plus Jakarta Sans | 20 / 26 / 700 | Section titles, sheet titles, pushed-screen titles |
| `titleSmall` | Plus Jakarta Sans | 16 / 22 / 700 | Card titles, row titles, money in rows |
| `body` | Nunito Sans | 16 / 24 / 400 | Body, Penny's replies |
| `bodySmall` | Nunito Sans | 14 / 20 / 400 | Row subtitles, helper text |
| `label` | Nunito Sans | 14 / 20 / 600 | Buttons, chips, tabs |
| `overline` | Nunito Sans | 12 / 16 / 700, +6 % tracking, caps | Section and hero labels ("LEFT TO SPEND · OCTOBER") |

Money rules:
- The hero shows no cents.
- Rows show cents with a comma ("R 1 245,50").
- The thousands separator is a narrow no-break space.
- Expenses carry "−" in ink; income carries "+" in positive.

### 1.6 Space, shape and depth (fixes S3, S5)

- **Spacing scale (4 pt):** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40.
  - Screen gutter: 16.
  - Card padding: 20.
  - Gap between rows in a group: 12.
  - Gap between sections: 24. It's always larger than any gap inside a section, so Home stops looking like it ends early (S5).
- **Radius:**
  - Cards and hero: 24.
  - Bottom sheets: 28 on the top corners.
  - Category tiles: 14 (40 dp tiles).
  - Inputs, chips, buttons, segmented controls, FAB, banners: full pill.
- **Grouping:** one card per *group*, not per row. Rows inside a group are separated by space (and by a 1 px `outline` at 30 % only between day groups in lists). Settings keeps one card per group because its groups are short.
- **Elevation, light:** shadows are tinted forest, never grey.
  - Level 0: flat, used for list groups on bg.
  - Level 1: `0 4 16 #1E5B3E @ 8 %`, used for cards and the hero.
  - Level 2: `0 8 24 #1E5B3E @ 12 %`, used for the FAB, sheets and menus.
- **Elevation, dark:** no shadows; level 1 = `surface`, level 2 = `surfaceRaised`.
- **Touch targets:** at least 48 dp, with at least 8 dp between them.
- **FAB inset:** every scrollable under a FAB gets 88 dp of bottom padding (S11, spec §1.2 rule 5).

### 1.7 Motion tokens (B's "springy", inside the epic budget)

The existing `AppMotion` curves and durations stay. They gain:

| Token | Value | Use |
|---|---|---|
| `springPress` | `SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.9)` | Press scale 1 → 0.97 → 1. Starts on pointer-down, reverses on release |
| `springSettle` | stiffness 400, ratio 0.85 | Swipe release, sheet settle, chip selection pill sliding |
| `springPop` | stiffness 300, ratio 0.6, overshoot capped at 6 % | Mascot moments only (rare by rule) |
| `stagger` | 30 ms per item, first 6 items only, 200 ms fade + 8 dp rise | First load of a list after the skeleton |
| `exit` | 0.65 × the entry duration | Every exit (sheets, snackbars, rows) |

**Budget:**
- Feedback starts in under 100 ms.
- Transitions are at most 300 ms.
- Value tickers run 400 ms and chart draws at most 600 ms. Their final value is correct on the last frame.

**Reduced motion** (`context.reducedMotion`):
- Springs, staggers and pops become a 150 ms fade or an instant change.
- Tickers show the final value.
- Nothing loops.

### 1.8 Haptic vocabulary (fixes S8)

Uses Flutter's predefined constants, which honour the system setting.

| Event | Haptic |
|---|---|
| Selection change (tab, chip, segment, month, toggle) | `selectionClick` |
| Swipe crosses its commit threshold | `lightImpact` |
| Save / confirm succeeded | `lightImpact` |
| Delete (row hidden, Undo shown) | `mediumImpact` |
| Goal reached / savings target met (once) | `mediumImpact` |
| Errors and validation | **none**: errors are visual and text only |

---

## 2. Penny

- **Assets:** `assets/penny/{welcoming,sleeping,thinking,celebrating}.png`.
  - These are transparent cutouts of the four Gemini-made poses. They're cut locally with rembg (MIT, u2net), trimmed with a 4 % margin, and at most 1024 px.
  - **The old default pose (`assets/mascot.jpg`) is retired** (Tiaan, 2026-10-10). It looked stale, generic and unlike the other four. **Welcoming is now the default pose.**
  - The original JPGs stay, so nothing new was generated.
  - Penny sits directly on the surface: **no circle clip, no white square, no ring.**
  - The 1024 px renders keep a 3 px band of baked-in shadow between one foot and the body. It vanishes at app sizes (28–180 dp).
- **Where she appears:**

| Place | Pose | Size | Motion |
|---|---|---|---|
| Penny tab header | welcoming | 40 dp | none |
| Penny replying | thinking | 40 dp, in the reply slot | 2 dp bob (M31); stops on reply |
| Onboarding (every page) | welcoming | 180 dp | fade + `springPop` on the first page only |
| Login, register, lock | welcoming | 140 dp | fade-in, once |
| Empty Transactions / Goals / Savings | welcoming | 120 dp | fade-in |
| Review queue cleared | celebrating | 96 dp | `springPop`, once a day (M20) |
| Goal reached | celebrating | 64 dp on the goal card | `springPop`, first view (M39) |
| **Home: savings target met** | celebrating | 40 dp on the savings card | `springPop`, once a day (kept) |
| **Home: nothing spent today** | sleeping | 28 dp beside "Quiet day so far" | static (kept) |

- **Never:**
  - Penny at rest on Home (no hero overlap, no greeting).
  - Penny on over-budget, missed-target or error states.
  - A "sad Penny".
  - Copy that uses Penny to guilt, such as "keep Penny happy".
- **Build note:** `MascotMoment` (`lib/shared/widgets/mascot_moment.dart`) and `PennyAvatar` (`lib/features/onboarding/widgets/penny_avatar.dart`) both swap their circle clip for the cutout. `pubspec.yaml` gains `assets/penny/`. That's a Session 4 blueprint step.
- **Retiring `mascot.jpg` (build step):**
  - `PennyAvatar`'s default `assetPath` (`penny_avatar.dart:10`) and onboarding's non-welcome pages (`onboarding_screen.dart:130`) switch to `assets/penny/welcoming.png`.
  - Then `assets/mascot.jpg` leaves `pubspec.yaml` and is deleted once nothing references it.
  - The launcher-icon comp (`assets/Piggybank mascot.jpeg`, `assets/icon/app_icon.png`) is out of scope here. Flag it if Tiaan wants the icon to match.

---

## 3. Components

| Component | Treatment |
|---|---|
| App bar (tab root) | Avatar (40 dp, primaryContainer, 48 dp target) · `headline` title · at most 2 labelled actions + ⋮. No bell. Flat on bg; it gains `surface` + a hairline only once content scrolls under it |
| Bottom nav | `surface`, 5 labelled tabs, pill indicator in primaryContainer that slides with `springSettle` (M1) |
| Hero | Light `hero` card, radius 24, level 1. `overline` label, `display` figure (count-up 400 ms, M21), pill progress bar, `bodySmall` line. The whole card is tappable (→ Plan › Budgets) with `springPress` |
| Card | `surface`, radius 24, padding 20, level 1 (light) / tonal (dark) |
| List group | One card; rows 64 dp min; category tile 40 dp radius 14; money right-aligned `titleSmall` tabular |
| Pill chip | 36 dp tall (48 dp target). Selected = primary fill + onPrimary; unselected = outline 1 px + ink |
| Segmented control | Pill track `sunk`, selected thumb `surface` + level 1 that slides (`springSettle`) |
| Buttons | Primary: pill, primary fill, 52 dp. Secondary: pill outline. Text: primary colour. Destructive: danger text or outline only |
| FAB | Extended pill, primary, level 2; shrinks to icon-only when the list scrolls down, grows back on scroll up |
| Review / OTA banner | Pill, primaryContainer, chevron; slides down 8 dp + fades in (M41) |
| Progress bar | 8 dp pill, track `sunk` (or `heroTrack` on hero); fill animates 400 ms ease-out (M23); danger only when over |
| Skeleton | `skeletonizer` (MIT) over the real layout, tinted `sunk`, shimmer off under reduced motion (S7, M11) |
| Bottom sheet | `surface` / `surfaceRaised`, top radius 28, 4 × 32 dp handle, level 2, scrim ink @ 40 % |
| Snackbar | Pill, ink fill, bg text, 16 dp above the nav; Undo in primaryContainer text |
| Input | Pill, `sunk` fill, label above, helper/error below; focus ring 2 dp primary |
| Speech bubble (onboarding, Penny) | `surface`, radius 24 with a 12 dp tail toward Penny |
| Empty state | Welcoming Penny 120 dp + `title` + `body` + one primary pill action |

---

## 4. Screens

Mockups are in the Stitch project **"Piggybank v2 Directions"**
(`projects/2869264751174926029`). The design systems are "v2 Merged · Ledger Pocket
(light)" `assets/12114533591739870141` and "(dark)" `assets/14338861856207029092`.
Screenshots with the real Penny cutouts composited into the reserved slots are in
`img/03-ledger-pocket-light.png` and `img/03-ledger-pocket-dark.png`. The screen IDs are
in §4.2.

### 4.1 Per-screen notes

- **Home:** Fixed order per spec §2.1.
  - Review banner, then the light hero, then the Savings card **stacked above** the Net worth card (both full width), then Needs attention, then Recent (5 rows, one group card), then the FAB.
  - No greeting and no Penny at rest. The two kept moments are as in §2.
  - Section gap 24, so "Recent transactions" reads as a section, not the end of the page.
- **Transactions:**
  - App bar: Review (icon + count badge, hidden at 0), Insights and ⋮.
  - Pill type chips, then Filter, then day groups. Each day header shows the date on the left and the day total on the right in `overline`.
  - Load more uses skeleton rows (M13).
- **Plan:**
  - The month switcher sits in the app bar bottom on Budgets.
  - The segmented control slides (M25).
  - The month change slides content left or right in the direction of travel, with `selectionClick` (M26).
  - The summary card sits above the budget cards.
  - "Over by R 150" appears in danger on its card only.
- **Goals:** Rounded progress per goal. "Completed (n)" expands with a size transition (M29).
- **Savings:**
  - The target card uses the hero palette (light container).
  - Suggestions have an Apply pill and swipe (M19).
  - Recurring costs are one group card, with "Policy check" text buttons.
  - The "Ask Penny" chip comes last.
- **Invest:**
  - The summary card uses the hero palette and gains the count-up (M21 gap closed).
  - Compare is a labelled pill.
  - The chart uses the ramp in §1.3 and draws in over 600 ms.
- **Net worth:** Hero palette card. Accounts, Assets and Liabilities rows, with Liabilities in ink (not red), then "Loan calculators ›".
- **Penny:**
  - 40 dp cutout in the header; replies on `surface`; user bubbles in primary.
  - The 3 data-aware chips are outlined pills that slide out of the way when a message sends (M30, M32 press state).
- **Settings:**
  - Profile card, then the grouped cards from spec §2.6.
  - Log out is a danger outline pill behind a confirm dialog.
  - Opens with shared axis Z (M3).
- **Login / register / lock:**
  - Welcoming Penny 140 dp, the wordmark in primary, then the card.
  - The submit button shows an inline progress state, then shared-axis Y into the shell on success (M9, M34, M35).
- **Onboarding:** Penny 180 dp above a speech bubble, with page dots (active = elongated pill) and a Next pill.
- **Review:** Detected cards with category pill, Confirm and Ignore; swipe as today with a `springSettle` release (M18); then "Confirm all n".
- **Add transaction sheet:** Pill segments, a large `display`-weight amount field, then pill inputs, then Save (M7, M8).

### 4.2 Stitch screen IDs

See `02b-directions.md` for the Session 2 IDs. All IDs below are under
`projects/2869264751174926029/screens/`.

| Screen | Light | Dark |
|---|---|---|
| Home | `9b20c998557041b1a102d535c021ea3d` | not rendered |
| Transactions | `f942232310e34f0b940068c01ed16dd3` | not rendered |
| Settings | `756332a12b024333b30fe00379d76c5c` | not rendered |
| Log in | `2de89987a84b4a348efbc183f06c59b5` | `0848808b7b5546d2ba48c0d6b7727284` |
| Onboarding 1/6 | `886f4f826e804d05af8558c8f8177773` | `72ca8efe54fe406b98488cbb47e5ac7b` |
| Plan › Budgets | `254f2f63…` discarded (desktop layout) | not rendered |

**Not rendered (Stitch stalled).** On 2026-10-10 the Stitch queue stopped returning
screens after 07:45. The 19 generation requests that timed out client-side never appeared
in the project:
- **Light:** Plan › Budgets (re-run), Goals, Savings, Invest, Net worth, Penny, Review, Add transaction.
- **Dark:** Home, Transactions, Plan › Budgets, Goals, Savings, Invest, Net worth, Penny, Settings, Review, Add transaction.

These screens are fully specified in §1–§4. They need one more Stitch pass, using the
prompts recorded in the session, before this spec can count as fully mocked up.

### 4.3 What the mockups get wrong (don't build these)

Stitch drifts from the prompts. These are known and must not be carried into the build:

- **Home:** Savings and Net worth rendered **side by side** in light; the spec stacks them.
- **Home:** "Needs attention" at 84 % rendered in red; red is reserved for over budget.
- **Settings:** some invented subtitles ("Plus Plan · Renews 1 Nov", "Capitec, FNB, Discovery", "Piggybank v2.4 (Build 384)", "Made with care in South Africa"). The real rows show real data only.
- **Onboarding:** "Step 1 of 6" text above the slot; the spec uses page dots only. The light render also draws a phone frame around the screen.
- **Transactions:** invented per-row times and a "Recurring" tag. Rows show what the data has.
- **Transactions:** the app bar's "Review" and "Insights" are icon-only. The spec needs a tooltip or label on each (spec §1.2 rule 1).
- **Dashed outlines:** the empty Penny slots are dashed outlines in Stitch. In the composites they're replaced by the real cutout, and the build has no outline.
- **Desktop canvases:** some screens rendered as a 390 px column on a desktop canvas. The grids crop the phone column.

---

## 5. Motion and feedback for every interaction (M1–M42)

Every row now has defined feedback. "RM" is the reduced-motion behaviour. Haptics follow
§1.8.

| # | Interaction | Visual feedback | Duration / easing | Haptic | RM |
|---|---|---|---|---|---|
| M1 | Tap a tab | Fade-through (out 90, in 160 with 0.92 → 1 scale); nav pill slides | 250 ms, emphasized; pill `springSettle` | `selectionClick` | Cut; pill jumps |
| M2 | Re-tap active tab | Pop to root; if already at root, scroll to top with a 6 dp top-bar shadow flash | 250 ms ease-out | `selectionClick` | Instant |
| M3 | Avatar → Settings | Shared axis Z (forward); back reverses | 250 ms | none | Fade 150 ms |
| M4 | Tap a card | Press scale 0.97 + ripple tinted primary @ 8 % | `springPress`, starts on pointer-down | none | Ripple only |
| M5 | Tap a row in a group | Row highlight `sunk` @ 60 % on press (fixes rows inside group cards) | 100 ms in, 150 ms out | none | Same (no motion) |
| M6 | Open a row's detail | Container transform | 250 ms emphasized | none | Fade 150 ms |
| M7 | Open a row's sheet | Sheet slides up with `springSettle`; scrim fades to 40 %; new radius 28 + handle | ≤ 300 ms | none | Fade 150 ms |
| M8 | Save in any sheet (all sheet types) | Button shows a 16 dp progress ring, then the sheet closes; the saved row tints primaryContainer and fades back | Close 200 ms; tint 600 ms | `lightImpact` on success | Instant close; tint without fade |
| M9 | Submit a full-screen form | Button label → progress ring (width locked); success = shared axis Y into the destination | 200 ms; 250 ms | `lightImpact` on success | Instant swap |
| M10 | Field validation error | Error text grows in below the field (size + fade); field outline → danger | 200 ms ease-out | none | Instant |
| M11 | Initial load | Skeleton (skeletonizer) of the real layout → content crossfade → first 6 rows stagger 30 ms | 200 ms + stagger | none | Skeleton → instant content, no stagger |
| M12 | Pull to refresh | Indicator in primary on `surface`; content settles with `springSettle` | Platform | `lightImpact` at the trigger point | Platform default |
| M13 | Load more | 3 skeleton rows at the end, replaced in place | 200 ms crossfade | none | Instant |
| M14 | Load error + Retry | `InlineError` fades in; Retry press = `springPress`, then button progress ring | 200 ms | none | Instant |
| M15 | Delete a row (Undo) | Row slides out left 24 dp + fades, list closes the gap; snackbar slides up | 180 ms exit; gap 200 ms | `mediumImpact` | Row vanishes; snackbar instant |
| M16 | Undo a delete | Row fades + grows back into its slot | 200 ms ease-out | `lightImpact` | Instant |
| M17 | Confirm-delete dialog | Dialog fades + scales 0.96 → 1; restyled to radius 24, danger text button | 200 ms in, 130 ms out | none | Fade |
| M18 | Swipe a detection | Background + label as today; release settles with `springSettle` | Gesture-driven | `lightImpact` at threshold (kept) | Same, no spring overshoot |
| M19 | Swipe a savings suggestion | Same as M18 | Gesture-driven | `lightImpact` (kept) | Same |
| M20 | Clear the review queue | "All caught up" + celebrating Penny 96 dp `springPop`, once a day | ≤ 300 ms | `mediumImpact`, once | Static pose |
| M21 | Hero value change (incl. Invest) | Count-up ticker | 400 ms ease-out | none | Final value |
| M22 | Secondary figure change | Digits crossfade 150 ms with a 4 dp vertical slide in the direction of change | 150 ms | none | Instant |
| M23 | Progress bar change | Fill animates; at 100 % of a *goal*, the bar does one soft brightness pulse | 400 ms ease-out | `mediumImpact` only for goal reached (M39) | Instant fill |
| M24 | Chart appears / changes | Line draws left → right; bars/donut sweep; touch datatip with `selectionClick` | ≤ 600 ms ease-out | `selectionClick` on datatip | Static chart |
| M25 | Switch Plan segment | Shared axis X; thumb slides with `springSettle` | 250 ms | `selectionClick` | Cut |
| M26 | Change month | Content slides 24 dp in the direction of travel + fades | 200 ms | `selectionClick` | Crossfade 150 ms |
| M27 | Select a filter chip | Fill + check icon grow in | 150 ms ease-out | `selectionClick` | Instant |
| M28 | Toggle a switch / checkbox | Thumb `springSettle`; track colour 150 ms | ≤ 200 ms | `selectionClick` | Instant |
| M29 | Expand / collapse | Size transition + chevron rotates 180° | 200 ms emphasized | none | Instant |
| M30 | Send to Penny | User bubble slides up 8 dp + fades; chips step aside | 200 ms | `lightImpact` | Instant |
| M31 | Penny replies | Thinking Penny bob 2 dp; after 10 s a line "Still working on it…" fades in; reply bubble slides in | Bob 1.2 s period; 200 ms | none | Static thinking pose, then instant reply |
| M32 | Tap a suggested question | `springPress` on the chip, then send (M30) | < 100 ms start | `selectionClick` | No scale |
| M33 | Wrong PIN | Shake (kept), dots → danger for 600 ms | 300 ms | none (errors are visual) | Dots colour only |
| M34 | Unlock success | Shared axis Y into the shell | 250 ms | `lightImpact` | Fade 150 ms |
| M35 | Log in success | Same as M34 | 250 ms | `lightImpact` | Fade 150 ms |
| M36 | Onboarding next / skip | Page slide + active dot stretches with `springSettle`; Penny pose crossfades | 250 ms | `selectionClick` | Cut; dot jumps |
| M37 | Copy / share / export | Inline tick replaces the icon for 1.5 s, plus the snackbar | 150 ms in | `lightImpact` | Tick without animation |
| M38 | Snackbar | Slides up 16 dp + fades; restyled pill | 200 ms in, 130 ms out | none | Fade |
| M39 | Goal reached / target met | Celebrating Penny `springPop` once (goal card 64 dp; Home savings card 40 dp) | ≤ 300 ms | `mediumImpact`, once | Static pose |
| M40 | Over budget enters | One calm cue: bar and amount crossfade to danger, the "Over by R …" text fades in. No shake, no alarm | 400 ms | none | Instant colour |
| M41 | Update banner | Slides down 8 dp + fades in | 200 ms ease-out | none | Instant |
| M42 | Scroll a long list | Platform overscroll; app bar gains `surface` + hairline once content passes under it; FAB shrinks / grows | 150 ms | none | Instant |

---

## 6. Checklist for the build (Session 5 onward)

- All colours come from tokens. No raw hex in widgets (R8).
- Goldens for every screen in light and dark (`test/goldens/`).
- The contrast script runs in CI, or as a test over the token table.
- Every motion reads `context.reducedMotion`.
- No new paid package and no new generated image. Penny comes only from `assets/penny/`.
- Critique ≥ 35/40 on the tab roots (baseline 27).
