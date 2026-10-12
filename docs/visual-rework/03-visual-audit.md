# Visual rework 03: visual audit

Session 1 of the visual rework epic, written 2026-10-09 against `feat/visual-rework`, which
is the merged UX rework (`feat/ux-rework` @ 7e5959e). It's the "before" for every
visual decision, and its motion coverage table (§3) is the list the spec must answer
row by row.

**Evidence and method**
- **Screenshots:** 28 golden screenshots, light and dark, at 412 × 915 dp (a Pixel 7
  class phone, 2.625×). They use real Manrope and Material Icons on believable sample
  data.
  - They live in `test/goldens/tab_roots/` (the 5 tab roots) and `test/goldens/audit/`
    (9 more screens).
  - The harness is `test/goldens/screenshot_harness.dart`, which fakes the API at the
    HTTP layer so every repository, provider and model runs unchanged.
  - Tiaan asked to skip the signed-in emulator run, so these replace emulator captures.
    They are also the golden-test foundation the epic needs (light + dark).
- **Contrast:** measured with the WCAG relative-luminance formula against the actual
  tokens in `lib/core/theme/app_theme.dart`.
- **Motion inventory:** a grep of `lib/` for every motion, haptic and feedback API, plus
  `animation-plans/README.md` (plans 001–005 are done).
- **Principle IDs:** R, P, C, A, J and X refer to `01-visual-principles.md`; K, N, Y and
  T refer to `docs/ux-rework/01-principles.md`. "Baseline" is the 27/40 critique
  (`.impeccable/critique/2026-10-09T15-48-57Z__lib-core-router-app-shell-dart.md`).

**Known harness limits:**
- Standalone pushed screens (Net worth, Accounts, Settings) render without a back arrow,
  because they're the route root in the test.
- The onboarding tour is a coach-mark overlay, so standalone it shows its card on an
  empty background.
- Neither is judged as a defect below.

---

## 1. System-level findings (every screen)

These recur everywhere. Fixing them in tokens and atoms (A6) fixes most screens at once.

| # | Finding | Evidence | Principles |
|---|---|---|---|
| S1 | **Contrast fails on primary surfaces.** <br>• White on the hero gradient start `#6FBE8C`: **2.23:1** (label and pill). <br>• Dark mode, white on accent `#3FC876`: **2.16:1** (FAB, selected chip, selected segment, avatar, "Next"). <br>• Light mode, white on accent `#1F8A4C`: **4.38:1** (buttons). <br>• Danger `#D64545` on white: **4.38:1**. <br>• Accent text on the mint chip: **3.87:1** (every percent pill). | Measured; visible on `home_*`, `plan_*`, `onboarding_dark` | P3, P4, P13, J4 |
| S2 | **One colour does every job.** A single green per theme is the button, chip fill, chip text, progress fill, hero, link, income amount, positive P/L, avatar and icon tint. There are no ramps (one hex per role), and the neutrals are stock grey `#6B7280`. | `app_theme.dart` defines 1 accent + 1 chip bg per theme | R8, R9, Y11 |
| S3 | **Every group is a bordered card.** Roughly 9 outlined, equal-weight cards on Home, one card per Settings group, and cards inside Savings. Nothing is grouped by space or tint, and elevation isn't used. | `home_light`, `settings_light`, `plan_savings_light` | R7, P9, R11, X2 |
| S4 | **Flat type hierarchy.** App-bar titles are large but regular weight. Section headings are regular weight at about body size. Card titles and row titles are the same style. Money has weight but **no tabular figures**, so amounts in a column don't align digit-for-digit. | All screens | R1, R2, R14, P7, J3 |
| S5 | **No spacing scale.** Paddings and gaps are ad-hoc (16/24/32/48, with gaps between groups sometimes smaller than within them). On Home, the gap above "Recent transactions" is the largest on the page, so it reads like the end of the screen. | `home_light` | R5, R6, P1, P2 |
| S6 | **Icon chips are generic and identical.** Every row leads with the same 48 dp mint circle. Category identity isn't carried by colour, and the unknown-category fallback is an up-arrow, which reads as income on Subscriptions. | `transactions_*` | R13, J4, J11 |
| S7 | **Spinners everywhere.** `CircularProgressIndicator` is in **42** files, and there are no skeletons. | grep | J10, C4 |
| S8 | **Haptics are almost absent:** only 2 files (the review and savings swipes). | grep | X4 (behavioural), Android haptics guidance |
| S9 | **The dark theme is an inversion, not a design.** The hero keeps the light gradient, so it's the brightest thing on screen. The bright accent sits under white text. Surfaces don't step lighter with elevation. | `*_dark` | P13, R11 |
| S10 | **The mascot is absent at rest.** Penny's tab, Lock, Login and empty states use a Material icon or nothing. Mascot poses appear only in Step 7 moments. | `penny_*`, `lock_*` | R15, X4 |
| S11 | **The FAB covers content.** The extended FAB sits over the last visible row (Home, Transactions, Plan) and over the Savings empty-state text, and there's no bottom inset for it. | `plan_light`, `plan_savings_light`, `transactions_dark` | X1, Y3 |

## 2. Screen by screen

The columns:
- **Empty/static/plain:** what makes it feel lifeless.
- **Hierarchy and spacing:** what competes or misgroups.
- **Missing feedback:** interactions with no response.
- **Contrast:** measured failures.

### Home (`tab_roots/home_*`)
- **Empty/static/plain:**
  - Nine equal outlined cards on one plane.
  - The only colour block is the hero.
  - No illustration at rest (Penny appears only for "quiet day" or a target met).

  (S3, S10, R12)
- **Hierarchy and spacing:**
  - The hero is correctly primary.
  - Then the review banner, savings, net worth and needs-attention cards all compete at
    equal weight (R1, J7).
  - The "75%" in the savings card has no label (R3, K1).
  - The gap above "Recent transactions" is bigger than any other (R6).
  - The FAB covers the second recent row (S11).
- **Missing feedback:**
  - Recent rows have no press state beyond the ink ripple (X1).
  - Pull to refresh works but isn't branded.
  - There's no entrance motion when data arrives, and cards pop in.
- **Contrast:** the hero label and the "Spent today" pill are 2.23:1 at the gradient
  start (S1).

### Transactions (`tab_roots/transactions_*`)
- **Empty/static/plain:**
  - Each day is its own outlined card, so a busy week becomes a tower of boxes (S3).
  - All rows lead with identical mint icon chips (S6).
- **Hierarchy and spacing:**
  - The app bar has **three unlabelled icons** (review badge, trends sparkle, overflow).
    That's against the spec's "at most two labelled" (§1.2), and the review badge
    repeats the review banner directly below it (P10, J9, X5).
  - Date headers are the same weight as row text (S4).
  - Amounts aren't tabular (J3).
  - The filter chip row is cut off at the right edge with no fade, so it reads as
    broken (X1).
- **Missing feedback:**
  - Chip selection has no haptic.
  - Rows have no press state (X1).
  - New rows from a refresh just appear; there's no insert animation.
  - Loading more at the bottom is a spinner (S7).
- **Contrast:**
  - Danger red amounts on white are 4.38:1, just below 4.5:1 (S1).
  - In dark mode, white on the selected "All" chip is 2.16:1 (S1).

### Plan › Budgets (`tab_roots/plan_*`)
- **Empty/static/plain:** five identical cards with full-width bars. The "Total spent"
  summary looks exactly like a category budget.
- **Hierarchy and spacing:**
  - Total spent should be the organism that leads, not a peer (R1, A3).
  - The month switcher, segmented control and cards are three separate bands with
    uneven gaps (R6).
  - The FAB hides the Utilities percent (S11).
- **Missing feedback:**
  - Month change has no slide or haptic. The content just replaces, which is the only
    Plan transition that isn't shared axis.
  - Segment change has a shared axis but no haptic (S8).
- **Contrast:**
  - Percent pills are 3.87:1 (S1).
  - The over-budget pill in dark mode needs a check after the palette change.

### Plan › Goals (`audit/plan_goals_*`)
- **Empty/static/plain:**
  - Only two cards, then about 45 % blank screen.
  - "Completed (1)" is a bare text row (R15).
- **Hierarchy and spacing:** footnotes read "R 6 200,00 saved / R 18 000,00 goal / by
  2027-03-01". That's three facts at one weight, joined by slashes, with an ISO date the
  user would never write (R3, Y17, K5).
- **Missing feedback:** expanding "Completed" snaps open with no size transition. Goal
  progress fills animate (Step 6), but there's no haptic on reaching 100 %.
- **Contrast:** percent pills are 3.87:1 (S1).

### Plan › Savings (`audit/plan_savings_*`)
- **Empty/static/plain:** the recurring-costs empty state is text only, centred, and
  covered by the FAB (S10, S11, R15).
- **Hierarchy and spacing:**
  - "Gap R 1 240,00" is strong, which is good.
  - The breakdown table is aligned, but its figures aren't tabular (J3).
  - "Savings found so far" is green text on white at **4.38:1** (S1).
  - The "Ask Penny" button is outlined in near-black, unlike every other secondary
    action (J11).
- **Missing feedback:** none on editing the target (a pencil icon only). "Find costs"
  runs with a spinner (S7).
- **Contrast:** green text at 4.38:1 (S1).

### Add transaction sheet (`audit/add_transaction_sheet_*`)
- **Empty/static/plain:** a long column of identical outlined fields with no grouping.
  It's functional but plain (S3).
- **Hierarchy and spacing:**
  - **Save sits top-right** in the header, away from the thumb (T10 wants the finishing
    action at the bottom).
  - The category chips *and* the Category dropdown both pick the category, which is
    redundant (Y14).
  - The date shows as ISO "2026-10-09" (Y17).
  - The amount field has no large money style. The most important input looks like
    every other field (R1).
- **Missing feedback:**
  - No haptic on chip selection.
  - The Save button doesn't preview the amount ("Save R 642,35"), so there's no
    feedforward (X3).
  - Validation errors appear without motion.
- **Contrast:** in dark mode, white on the selected "Expense" segment is 2.16:1 (S1).

### Invest (`tab_roots/invest_*`)
- **Empty/static/plain:** the only chart in the app is a donut in **purple, cyan and
  teal**, outside the brand system (X6, R8). It doesn't animate in.
- **Hierarchy and spacing:**
  - Unrealized P/L appears twice, in the hero pill and in the stat strip (K5).
  - Top-holding P/L is green with no sign or label (P6, R3).
  - The "Your portfolios" add icon is a bare ⊕ with no label (J9).
- **Missing feedback:**
  - The total value doesn't count up. `HeroMetricCard` supports it, but the hero here
    doesn't pass `amount`.
  - The chart has no entrance and no datatip (X6).
- **Contrast:** the hero label at the gradient start is 2.23:1 (S1).

### Penny (`tab_roots/penny_*`)
- **Empty/static/plain:**
  - About 60 % of the screen is blank.
  - Penny is shown as a **Material piggy icon twice** (app-bar badge and greeting), not
    the mascot (S10).
  - The app bar holds the avatar *and* the Penny badge side by side (J11).
- **Hierarchy and spacing:**
  - The suggested questions are full-width outlined pills, centred, which is good for
    reach.
  - The input is a **square-cornered** outlined field next to a round send button,
    which doesn't match the pill language (J11).
- **Missing feedback:**
  - No haptic on send.
  - Suggested-question taps have only a ripple.
  - Bubbles do slide in (plan 004), and "thinking" bobs the mascot (Step 7).
- **Contrast:** in dark mode, the send button is white on 2.16:1 (S1).

### Net worth hub (`audit/net_worth_*`)
- **Empty/static/plain:**
  - The hero shows no trend (no sparkline, no delta) even though there's a 6-month
    history endpoint.
  - The rest of the screen is a single card of 4 rows, and the lower half is blank.
- **Hierarchy and spacing:**
  - Assets and Liabilities totals are tertiary grey under the label. They're the actual
    facts and deserve value styling (R3).
  - Icons are generic (piggy for Assets, a $ document for Liabilities) (S6).
- **Missing feedback:** the container transform in from Home exists (Step 6). Rows have
  only a ripple.
- **Contrast:** hero label 2.23:1 (S1).

### Accounts (`audit/accounts_*`)
- **Empty/static/plain:** there's a **~370 dp empty band above the hero** in both
  themes. It's a spacer or chart slot that renders nothing with this data, and it needs
  a check on device.
- **Hierarchy and spacing:**
  - In the "Accounts overview" card, "Largest: Savings" is a grey regular value next to
    bold numbers.
  - The three stat columns compete with the hero.
- **Missing feedback:** rows grow into the account detail (Step 6). There's no haptic
  and no balance ticker.
- **Contrast and semantics:** **the credit-card balance −R 4 210,00 renders in the
  positive green**. That's colour meaning the opposite of the sign (P6, J4). Green on
  dark is fine for contrast, but wrong for meaning.

### Settings (`audit/settings_*`)
- **Empty/static/plain:** six separate cards, each with mint icon circles. It's tidy but
  the most template-looking screen in the app (S3, S6).
- **Hierarchy and spacing:** group labels are small regular text with no weight
  contrast (S4). Single-row groups (Data sources, About) still get a full card each (P9).
- **Missing feedback:** none beyond the ripple. Switches inside sub-screens have no
  haptic.
- **Contrast:** passes. Muted email text is 4.83:1.

### Login (`audit/login_*`, and the on-device screenshot from Step 0)
- **Empty/static/plain:** the mascot is a static square image, and the rest is a
  standard form.
- **Hierarchy and spacing:** fine. "Forgot password?" and "Register" are green links,
  both 4.38:1 in light mode.
- **Missing feedback:** the error grows in (plan 005). The button has no loading state
  beyond its disabled look, and no success transition into the app.
- **Contrast:** in dark mode, the button's white text is 2.16:1 (S1).

### Lock (`audit/lock_*`)
- **Empty/static/plain:** the most empty screen in the app. There's a title, a mint
  fingerprint circle, and about 70 % blank space. Penny would make this the warmest
  "welcome back" moment (S10, X4).
- **Missing feedback:** the wrong-PIN shake exists (plan 002). A successful unlock just
  cuts to the app.
- **Contrast:** passes in light mode. Check dark mode after the palette change.

### Onboarding (`audit/onboarding_*`)
- **Empty/static/plain:** coach-mark cards with no mascot pose per page (the tour is
  *about* Penny).
- **Missing feedback:** the page dots animate. Advancing has no haptic.
- **Contrast:** in dark mode, "Next" is white on bright green at **2.16:1** (S1).

## 3. Motion and feedback coverage

Every user-visible interaction in the app, by family, with what happens today. "none"
means no feedback beyond what Flutter does by default (an ink ripple, where the widget
has one). The spec (`04-visual-spec.md`) must give **every row** a defined feedback:
trigger, animation, token, haptic and reduced-motion fallback. Acceptance: no "none"
left.

| # | Interaction | Where | Current feedback | Gap |
|---|---|---|---|---|
| M1 | Tap a tab | Bottom nav | Fade-through (fade + 0.92→1 scale, 160 ms), with an indicator pill | No haptic |
| M2 | Re-tap the active tab | Bottom nav | Pops to root | No scroll-to-top animation cue; **none** for the haptic |
| M3 | Tap the avatar → Settings | All tab roots | Shared axis Z | No haptic (fine). Back is a reverse axis |
| M4 | Tap a tappable card (hero, goal, budget) | Home, Plan | PressScale 0.97 + ripple | Done; keep it, and move it onto the spring token |
| M5 | Tap a list row (transaction, account, holding, setting) | Everywhere | Ripple only | **none** for the press state on rows inside group cards |
| M6 | Open a row's detail | Account, portfolio, Net worth | Container transform | Done |
| M7 | Open a row's sheet | Transaction, goal, budget, recurring | Modal sheet slides up (Material default) | No haptic; sheet radius and handle off-system |
| M8 | Submit a sheet (save) | Transaction, goal, budget sheets | Sheet closes and the saved row tints, then fades (600 ms) | **none** for haptic; **none** for the other sheets (recurring cost, account, asset, liability, holding, dividend, RA/TFSA, target) |
| M9 | Submit a full-screen form | Login, register, account edit | Button disables; errors grow in (login only) | **none** for the button's loading-state motion; **none** for the success transition |
| M10 | Validation error on a field | All forms | Text appears instantly (Material) | **none** for motion (a size/fade-in, like login's) |
| M11 | Initial screen load | All data screens | **Spinner** (42 files); AsyncValue crossfade on some (plan 001) | **none**: no skeleton, no staggered entrance |
| M12 | Pull to refresh | 18 screens | Material `RefreshIndicator` | No haptic; default colour |
| M13 | Load more (paging) | Transactions | Spinner row | **none**: skeleton rows |
| M14 | Load error and retry | All data screens | Error state + Retry button, crossfaded in | **none** for retry press/progress feedback |
| M15 | Delete a row (Undo) | 7 row types (Step 8) | The row disappears instantly; 4 s snackbar with Undo | **none** for the exit animation (plan 006 retired it while delete used a dialog; Undo changes the case); **none** for haptic |
| M16 | Undo a delete | Same | The row reappears instantly | **none** for the re-entry animation |
| M17 | Confirm-delete dialog | Holding, portfolio, liability payment, log out | Material dialog fade/scale | Fine; dialog styling off-system |
| M18 | Swipe to confirm/discard a detection | Review queue | Coloured background + label + `lightImpact` at threshold | Done; add a spring settle on release |
| M19 | Swipe to act on a savings suggestion | Savings | Background + `lightImpact` | Done |
| M20 | Clear the review queue | Review | "All caught up" + celebrating mascot pop (once a day) | Done |
| M21 | Value change on a hero | Home, Accounts, Net worth | CountUpText 400 ms | Done. **Invest hero: none** (no `amount` passed) |
| M22 | Value change on a secondary figure | Stat strips, breakdowns, row amounts | Instant | **none** |
| M23 | Progress bar value change | Budgets, goals, savings | Animated fill (plan 003) | Done; no haptic at 100 % |
| M24 | Chart appears or changes | Invest donut, Trends, Net worth history | Instant (fl_chart default) | **none**: no entrance, no datatip haptic |
| M25 | Switch Plan segment | Plan | Shared axis X | No haptic |
| M26 | Change month | Plan › Budgets, Trends | Content replaces | **none**: no directional slide, no haptic |
| M27 | Select a filter chip | Transactions, add sheet | Material chip check animation | No haptic |
| M28 | Toggle a switch or checkbox | Settings sub-screens, consents | Material thumb animation | No haptic |
| M29 | Expand/collapse a section | Goals "Completed", Settings groups | Snaps open | **none**: size transition |
| M30 | Send a message to Penny | Penny | The user bubble slides in (plan 004) | No haptic on send |
| M31 | Penny replies | Penny | Thinking bob, then the bubble slides in | Done; long waits have no progress copy past ~10 s |
| M32 | Tap a suggested question | Penny | Ripple, then sends | No press state |
| M33 | Wrong PIN | Lock | Shake (plan 002) | No haptic (error: keep it visual, see 02 §2) |
| M34 | Unlock success | Lock → app | Cut | **none**: a transition into the shell |
| M35 | Log in success | Login → app | Cut | **none** |
| M36 | Onboarding next/skip | Tour | Page change + dots | No haptic |
| M37 | Copy, share or export | Data export, settings | Snackbar | **none** for an inline confirmation tick |
| M38 | Snackbar appears | Everywhere | Material slide-up | Fine; style off-system |
| M39 | Goal reached / savings target met | Goals, Home | Mascot pop once (Step 7) | No haptic |
| M40 | Over budget enters | Home, Plan | Colour change only | **none**: a single, calm attention cue (no alarm, no shake; no dark patterns) |
| M41 | App update banner | Home | Appears instantly | **none**: an entrance |
| M42 | Scroll a long list | Transactions, Settings | Platform overscroll | Fine |

**Count:** 42 interactions.
- **Done:** 11 (M4, M6, M18–M21, M23, M25, M30, M31, M39).
- **Partial**, with a gap noted: 14.
- **"none" on at least one part:** 17 (M2, M5, M8, M9, M10, M11, M13, M14, M15, M16,
  M22, M24, M26, M29, M34, M35, M37). M40 and M41 are also none-gaps.

All 42 need an answer in the spec.

## 4. What the spec has to fix first (ranked)

1. **S1 contrast** in both themes. This is an accessibility failure, and the acceptance
   criteria need it fixed (WCAG AA).
2. **S2 palette ramps and S9 the dark theme as a real design.** They unlock S1, the
   chart colours (Invest) and the semantic fix on Accounts.
3. **S4 type scale with tabular money and S5 spacing tokens.** Every screen benefits
   through tokens.
4. **S3 card discipline, plus an elevation model.** This is the biggest "template look"
   change.
5. **S7 skeletons and the §3 "none" rows.** This is the "static" complaint, answered row
   by row.
6. **S10 the mascot at rest** on Penny, Lock, Login and empty states, using existing
   poses only.
7. **Screen fixes found on the way:** the Transactions app bar, the FAB inset, ISO dates,
   the credit-card sign colour, the Invest donut, the Invest ticker, and Accounts' empty
   band.
