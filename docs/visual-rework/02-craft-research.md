# Visual rework 02: craft research

What makes a finance app feel premium and alive, and which free tools get Piggybank
there in Flutter. Written 2026-10-09 from public sources (cited inline and at the end).
Principle IDs (R, P, C, A, J, X) refer to `01-visual-principles.md`; K, N, Y and T refer
to `docs/ux-rework/01-principles.md`.

**Starting point (measured in the code, 2026-10-09):**
- **Motion tokens:** `AppMotion` has two curves (`easeOut` 0.23,1,0.32,1 and `easeInOut`
  0.77,0,0.175,1) and four durations: `feedback` 150, `stateChange` 200, `pageTransition`
  250 and `valueTransition` 400 ms. `context.reducedMotion` reads the OS setting.
- **Packages:** `animations` 3.0.0 and `fl_chart` 0.69 are already in. Nothing for
  skeletons, Lottie or Rive.
- **Loading:** `CircularProgressIndicator` appears in **42** files under `lib/`, so
  spinners are the default loading state.
- **Haptics:** `HapticFeedback` is used in **2** files (the review and savings swipes).
- **Motion in use:** the UX rework's Step 6 added container transforms, fade-through,
  shared axis, count-up heroes, the saved-row highlight and the press scale.

---

## 1. Motion systems

### Material 3 motion
- **Easing and duration are tokens.** M3 pairs *emphasized* easing (for most UI
  transitions) with *standard* easing (for small utility moves). Emphasized decelerate
  starts at peak velocity and settles gently, for things entering. Emphasized accelerate
  is for things leaving. ([m3 easing and duration](https://m3.material.io/styles/motion/easing-and-duration))
- **Four transition patterns** cover navigation ([Google Design: Implementing motion](https://medium.com/google-design/implementing-motion-9f2839002016),
  [MDC Android Motion.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)):
  - **Container transform:** an element grows into the screen it opens.
  - **Shared axis (X/Y/Z):** for spatial or hierarchical siblings.
  - **Fade through:** for unrelated destinations, such as tabs.
  - **Fade:** for things appearing in place, such as dialogs and menus.

  The Android reference defaults shared axis to about 300 ms.
- **Piggybank today:** all four already exist (Step 6). The gap is the *small* motion
  (entrances, list changes, state changes inside a card) and a **richer curve set**.
  We have one ease-out and one ease-in-out, with no accelerate curve for exits and no
  spring.

### Apple HIG and "fluid interfaces"
- **Supplement motion with haptics and audio, and keep it purposeful.** Direct touch can
  carry more emphasis than indirect input. ([HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion))
- **WWDC18 "Designing Fluid Interfaces":** interfaces should respond instantly, be
  **redirectable and interruptible** mid-animation, and use **springs** described by
  damping and response rather than duration. A spring "is always moving" toward its
  target, so an interrupted gesture hands off smoothly.
  ([WWDC18 session 803](https://developer.apple.com/videos/play/wwdc2018/803/))

### Springs vs curves: what to use where
| Use | Prefer | Why |
|---|---|---|
| Gesture-driven motion (swipe to confirm, drag sheet, pull to refresh) | **Spring** (critically damped or slightly under-damped) | It inherits the finger's velocity and survives interruption (WWDC18) |
| Press feedback (scale 0.97 and back) | **Spring**, or a very short ease-out | It must reverse instantly on release; a fixed-duration curve feels sticky |
| Navigation transitions | **Curves** (M3 emphasized) | Predictable length; coordinated with the route |
| Value changes (number ticker, progress fill, chart draw) | **Curve**, ease-out, 400–600 ms | Reading a number needs a predictable settle |
| Celebration (mascot pop) | **Spring with a small overshoot** | Personality, kept rare (no confetti rule) |

Flutter has `SpringSimulation` and `SpringDescription` in the framework (`physics`
library), so springs need no package.

### Motion budget (J10, C4, C6)
- **Feedback** must appear in under 100 ms. The press state starts on pointer-down, not
  on tap-up.
- **Transitions** take 300 ms or less, and never block input.
- **Value and hero animations** may run longer (`valueTransition` 400, up to ~600 for a
  chart draw), but the final value is readable throughout and correct on the last frame.
- **Reduced motion** (`MediaQuery.disableAnimations`): transitions become cuts or
  cross-fades, tickers show the final value, and loops stop. This is already the rule in
  `app_motion.dart`, and every new motion must keep it.

## 2. Micro-interactions and haptics

### Micro-interaction anatomy
Every micro-interaction has the same four parts:
1. **Trigger:** what starts it, either user or system.
2. **Rules:** what happens.
3. **Feedback:** what the user sees, feels or hears.
4. **Loops and modes:** what changes over time.

Premium apps get the *feedback* right on every tap, not only on big moments. The press
state, the selection change, the toggle snap and the copied tick each acknowledge the
user inside the 100 ms deadline (J10, N3).

### Haptics (Android guidance)
- **Less is more.** Too much vibration is annoying and gets haptics switched off.
  ([Android haptics principles](https://developer.android.com/develop/ui/views/haptics/haptics-principles))
- **Favour clear, crisp haptics** over buzzy ones, and **use the predefined
  constants**. Flutter's `HapticFeedback.selectionClick`, `lightImpact`, `mediumImpact`
  and `heavyImpact` map onto the platform's predefined effects.
- **Match strength to importance and frequency.** Frequent events get the lightest tap;
  rare, important ones get a stronger one.
- **Be consistent.** The same interaction gets the same haptic everywhere.
- **Respect the system setting** (`HAPTIC_FEEDBACK_ENABLED`). The platform's own haptic
  constants already honour it. ([Android haptics APIs](https://developer.android.com/develop/ui/views/haptics/haptics-apis))

**Proposed haptic vocabulary for Piggybank** (to be fixed in the spec):

| Event | Haptic | Frequency |
|---|---|---|
| Selection change (chip, segment, tab, month) | `selectionClick` | High |
| Swipe crosses its commit threshold | `lightImpact` (already used) | Medium |
| Save or confirm succeeded | `lightImpact` | Medium |
| Delete (row hidden, Undo shown) | `mediumImpact` | Low |
| Goal reached or savings target met | `mediumImpact`, once | Rare |
| Error or validation block | none (visual and text only); haptics can't explain an error | n/a |

## 3. Loading, latency and optimism

- **Skeletons over spinners for content.** Skeletons preview the structure and cut
  *perceived* wait for full-content loads. Spinners give no estimate and draw the eye to
  the wait itself. Use a spinner only for short, in-place actions (inside a button).
  ([NN/g Skeleton Screens 101](https://www.nngroup.com/articles/skeleton-screens/),
  [NN/g video: skeletons vs progress bars vs spinners](https://www.nngroup.com/videos/skeleton-screens-vs-progress-bars-vs-spinners/))
- **Don't flash.** Show the skeleton only if the data hasn't arrived after about 150–300
  ms. A fast response should go straight to content, and a skeleton that blinks for 80 ms
  is worse than none.
- **Optimistic UI.** For actions that almost always succeed (confirm a detection, toggle,
  save), update the UI immediately and reconcile when the server answers, rolling back
  with a clear message on failure. Piggybank already does this for deletes (Step 8 Undo)
  and review settling. Extending it is a *presentation* change, provided the provider
  contracts stay untouched.
- **Pull to refresh** should have a branded, calm indicator (the Material
  `RefreshIndicator` coloured from tokens) and a light haptic when it triggers.

## 4. Numbers, charts and data viz

- **Animated number tickers.** Money that changes should count or roll to its new value
  with tabular figures, so digits don't jitter, then land exactly on the formatted value.
  This exists for the hero (`CountUpText`, Step 6). It's missing on Invest's total and
  on secondary stats.
- **Chart entrances.** Draw lines left to right and sweep donuts from 12 o'clock over
  400–600 ms with ease-out, once per data change, never on every rebuild. A datatip on
  press with a selection haptic (X6). Copilot Money, an Apple Design Award finalist,
  invested in interactive charts, rebuilding its Cash Flow view on Swift Charts.
  ([Apple: Copilot Money and Swift Charts](https://developer.apple.com/articles/copilot-money/),
  [ADA 2024 finalists](https://developer.apple.com/design/awards/2024/))
- **Chart colour:** derive series colours from the palette ramps, ordered by value. No
  off-brand rainbow (the current donut is purple, cyan and teal).

## 5. Space, type, depth, colour

- **4/8-point grid:** spacing tokens on an 8-pt rhythm with 4-pt half-steps, growing
  non-linearly (P1, P2, R5).
- **Type scale:**
  - One family is fine. Manrope is a good, free choice and is already loaded through
    `google_fonts`; the Session 2 directions may propose alternatives.
  - Use two weights (P7) and tighter tracking on display sizes (P8, R14).
  - Use **tabular figures for all money**: `FontFeature.tabularFigures()` (J3).
- **Elevation and depth:**
  - Use a fixed set of levels (R11).
  - In light mode, shadows carry depth.
  - In dark mode, **higher surfaces get lighter** through an overlay of the
    on-surface colour. Material's levels run from 0 % at rest to 16 % at the top, and
    glows must never stand in for shadows.
    ([Material dark theme](https://m2.material.io/design/color/dark-theme.html),
    [Atmos: dark mode best practices](https://atmos.style/blog/dark-mode-ui-best-practices))
- **Dark mode colour:**
  - Saturated colours vibrate on dark surfaces and fail contrast, so **use desaturated,
    lighter tones** (around the 200 step) for accents.
  - Avoid pure black; Material uses `#121212`.
  - Each light token gets a deliberately chosen dark partner (P13).
  - [Material dark theme](https://m2.material.io/design/color/dark-theme.html),
    [FourZeroThree: scalable dark theme](https://www.fourzerothree.in/p/scalable-accessible-dark-mode)
  - Our baseline fails this exactly: white on the bright dark-mode green is 2.16:1.
- **Fintech colour:**
  - Green signals money and growth, but one green can't do every job (R8).
  - Keep red for "over"/loss only (Y11), add a warm secondary accent for good moments,
    and tint the neutrals (R9).
  - Pair every semantic colour with a word or sign (P6).

## 6. Empty states and illustration

- **Empty states are onboarding** (R15, Y16): an illustration, one sentence, one action.
- **Use the mascot, not stock art.** Piggybank owns its mascot poses (`assets/`
  welcoming, thinking, sleeping, celebrating, plus `assets/Gemini Mascot Images/`), and
  those are the illustration system.
- **Animated illustration** (Lottie/Rive) is optional and only for assets that are
  **free-licensed or made in-house**. Paid generation needs Tiaan's yes first.

## 7. Teardowns: apps known for craft

Sources are public write-ups, award pages and app listings. These are observations of
*patterns*; nothing here copies another app's assets or brand.

| App | What makes it feel premium | Lesson for Piggybank |
|---|---|---|
| **Monzo** | A single ownable brand colour (hot coral) used sparingly but unmistakably. Instant feedback on every transaction, with auto-categorised spending. The brand is consistent from card to app. ([Feely: fintech brand design](https://www.feelystudio.com/journal/the-evolution-of-fintech-design), [Product Powerhouse on Monzo](https://medium.com/product-powerhouse/monzos-product-playbook-how-the-hot-coral-card-disrupted-uk-digital-banking-14deee36e39f)) | One ownable accent, used *rarely*, beats one green used everywhere (Y11, R8). Feedback on each transaction is the habit engine, and we already have the review loop. |
| **Revolut** | Stated principles: speak the user's language, solve the real problem, **modular, scalable solutions** so features feel consistent, and constant validation. Known for dense but crisp motion between states. ([Revolut: our top 5 design principles](https://www.revolut.com/blog/post/our-top-5-design-principles-at-revolut/)) | Modularity *is* the visual system (A7): every new screen made from the same atoms. Motion explains state changes rather than decorating. |
| **Copilot Money** | ADA finalist (2024) and Editor's Choice. Native feel, interactive charts, a tidy dark-first aesthetic. ([Apple Developer article](https://developer.apple.com/articles/copilot-money/), [App Store](https://apps.apple.com/us/app/copilot-track-budget-money/id1447330651)) | Charts are a first-class surface: animate them, make them pressable, colour them from the system. Feeling native means using platform gestures and haptics, not custom imitations. |
| **Cleo** | A strong *personality* (witty, warm, a big-sister voice) carried consistently from chat to voice. In voice, they softened exclamations so cheer never sounds like shouting. ([Cleo: how we taught Cleo to talk back](https://web.meetcleo.com/blog/how-we-taught-cleo-to-talk-back)) | Penny's character has to be consistent across text, mascot pose and motion. Tone is tuned so warmth never reads as nagging (C8, no dark patterns). Personality without roasts: we stay kind. |
| **Things 3** | Apple Design Award winner. The "Magic Plus" button can be tapped *or dragged* to the exact spot to insert. Motion is restrained and physical, and every transition shows where an item went. ([Cultured Code: features](https://culturedcode.com/things/features/), [The Verge review](https://www.theverge.com/2017/5/19/15664348/things-3-review-ios-mac-productivity)) | Calm craft: few colours, generous space, and motion that explains placement. A primary action can carry a power-user accelerator without cluttering the novice path (C7). |
| **Apple Wallet** | Cards as physical objects: stacked depth, cards that lift and slide on selection, haptics on pass presentation. Spatial continuity: the card you tap *is* the detail. ([HIG Wallet](https://developer.apple.com/design/human-interface-guidelines/wallet)) | Depth and continuity sell "this is real money": container transforms from row to detail (already in), plus a real elevation model (R11). |

**Patterns across all six:**
- one ownable accent used sparingly
- an elevation model that means something
- motion that explains change rather than decorating
- personality carried by one consistent character
- charts treated as interactive surfaces
- feedback on every tap

## 8. Free, open-source Flutter packages (shortlist)

Data from the pub.dev API, 2026-10-09. APK size impact is an estimate until it's
measured in the visual-rework Step 1 release build. The blueprint records a measured
before/after size.

| Package | Version | Licence | Maintenance | Purpose | Size impact | Recommendation |
|---|---|---|---|---|---|---|
| [`animations`](https://pub.dev/packages/animations) | 3.0.0 (2026-08-19) | BSD-3-Clause | Flutter team, 160/160 points | Container transform, shared axis, fade through | Already in | **Keep** |
| [`skeletonizer`](https://pub.dev/packages/skeletonizer) | 3.0.0 (2026-09-11) | MIT | Active, 160/160 | Turns the *real* widget tree into a skeleton (no parallel skeleton layouts to maintain) | Small, pure Dart | **Adopt** for loading states (replaces most of the 42 spinners) |
| [`shimmer`](https://pub.dev/packages/shimmer) | 4.0.0 (2026-08-21) | BSD-3-Clause | Active, 160/160 | Shimmer gradient effect | Small, pure Dart | Not needed if `skeletonizer` is used (it has its own shimmer) |
| [`flutter_animate`](https://pub.dev/packages/flutter_animate) | 4.5.2 (2024-11-25) | BSD-3-Clause | Flutter Favorite, 150/160; **no release in ~11 months** | Declarative entrance, stagger and effect chains | Small, pure Dart | **Optional.** It's convenient for staggered list entrances, but implicit animations plus our own small helpers cover the need without a dependency. Decide in the spec. |
| [`lottie`](https://pub.dev/packages/lottie) | 3.6.1 (2026-09-18) | MIT | Active, 160/160 | Plays Lottie JSON animations | Small runtime, pure Dart; assets add size | **Only if** free-licensed or in-house mascot animations exist |
| [`rive`](https://pub.dev/packages/rive) | 0.14.11 (2026-08-03) | MIT runtime | Active, 140/160 | Interactive state-machine animations | **Larger**: native runtime per ABI | **Avoid for now.** Too heavy for a few mascot moments, and Rive's editor has paid tiers |

**Framework-only tools that need no package:**
- `AnimatedSwitcher`, `TweenAnimationBuilder` and `AnimatedSlide`/`AnimatedScale`
- `SpringSimulation` for springs
- `HapticFeedback`
- `FontFeature.tabularFigures()`
- `RefreshIndicator`
- `fl_chart`'s own animation duration and curve, for chart entrances (already a
  dependency)

## 9. What this means for the spec (carried into Session 2–3)

1. **Extend `AppMotion`.** Add emphasized decelerate/accelerate curves, a spring
   description for gestures and press, a `chartEntrance` duration (~600 ms), and a
   `skeletonDelay` (~200 ms). Keep every reduced-motion fallback.
2. **Swap content spinners for skeletons.** Use `skeletonizer` with the delay, and keep
   spinners only inside buttons.
3. **Adopt one haptic vocabulary** (§2), applied consistently.
4. **Build a palette with ramps** in light and dark, desaturated dark accents, and
   on-accent ink chosen per theme. Fixes the 2.16:1 and 2.23:1 failures.
5. **Use a three-level elevation model**: shadows in light, lighter surfaces in dark.
6. **Use tabular figures and tickers on every changing money figure**, Invest included.
7. **Give charts entrances, datatips and palette colours.**
8. **Make the mascot the illustration system**, using existing poses. Animated versions
   only if free or in-house.
