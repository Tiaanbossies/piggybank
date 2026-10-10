# Blueprint: Piggybank visual rework ("Ledger Pocket")

Session 4 of the visual-rework epic, written 2026-10-10. It turns the approved visual spec
(`docs/visual-rework/04-visual-spec.md`; Tiaan approved its tokens and Penny choices on
2026-10-10 and retired the default pose) into one-PR steps that a fresh agent can run
cold.

## Read this first (every step)

- **Spec:** `docs/visual-rework/04-visual-spec.md` is the source of truth for *what*:
  tokens §1, Penny §2, components §3, screens §4, motion M1–M42 §5. This file is *how and
  in what order*. If they disagree, the spec wins. Record the conflict in the mutation log
  at the bottom.
- **Don't build the drift:** spec §4.3 lists what the Stitch mockups get wrong. The
  mockups illustrate the spec; they don't override it.
- **IA is locked:** `docs/ux-rework/04-spec.md` (tabs, sections, order, copy). Every row of
  `docs/ux-rework/03-capability-inventory.md` stays. This epic changes how things *look and
  move*, never what's there.
- **Findings being fixed:** S1–S11 and the M1–M42 baseline in
  `docs/visual-rework/03-visual-audit.md`.
- **Repo:**
  - Location: `C:\Fynbos Creative Master\02_Clients\Piggybank`, GitHub
    `Tiaanbossies/piggybank`.
  - Stack: Flutter, flutter_riverpod 2.6, go_router 14.
  - CI: the repo has **no CI**, so a step's own `flutter analyze` and `flutter test` are
    the gate.
- **Leave untracked:** `.impeccable/` and `assets/Gemini Mascot Images/`. Never
  `git add -A`. **Never run `dart format` on `lib/`.** The repo isn't format-clean, and
  formatting rewrites 100+ files. Edit only the files a step owns.

### Branch model

- **Integration branch:** `feat/visual-rework`. It already exists and already contains
  `master` through #49.
- **Each step:** branch `visual/<NN>-<slug>` from the latest `feat/visual-rework`, open a
  PR into `feat/visual-rework`, and squash-merge after Tiaan's OK.
- **Release:** testers keep running `master` builds until Step 9 merges
  `feat/visual-rework` into `master` as one release.
- **Rollback for any step:** revert its merge on `feat/visual-rework`. Nothing reaches
  `master` before Step 9.

### Invariants (checked at the end of every step)

1. **Tests are green.** `flutter analyze` reports no issues, and `flutter test` passes in
   full. The test count only grows. Record it in each PR body.
2. **Presentation only.** Don't edit any of these:
   - `lib/**/data/`, `lib/**/models/`
   - `lib/core/api/`, `lib/core/auth/`
   - the detection native-channel code, `lib/features/updates/`
   - `android/` or release config

   Existing providers keep their names and types. New *UI-only* providers are allowed.
   `computeRedirect` and its router tests stay unchanged and green.
3. **Tokens only.** No raw hex or `Colors.<named>` in widgets. Every colour comes from
   `Theme.of(context).colorScheme` or the `AppTokens` extension (Step 1), and every size
   from `AppSpace`/`AppRadius` (spec §6, R8). `Colors.transparent` is allowed.
4. **Dependencies.**
   - No new runtime dependency, except `skeletonizer` (MIT) in Step 4. Its adoption was
     decided in Session 1 (`02-craft-research.md` §8).
   - No new generated image. Penny comes only from `assets/penny/`.
5. **Motion rules.** Every new animation:
   - reads `context.reducedMotion` and does the spec's "RM" behaviour;
   - uses `AppMotion` tokens, not literal durations;
   - starts its feedback in under 100 ms;
   - finishes a transition in 300 ms or less.

   Value tickers (400 ms) and chart draws (≤ 600 ms) are the spec's only exceptions.
6. **Haptics** go through `AppHaptics` (Step 1) only, per spec §1.8. There are never
   haptics on errors.
7. **Red** means over budget or destructive only (J4). Expenses are ink; income is
   positive with "+".
8. **FAB inset.** Every scrollable under a FAB keeps at least 88 dp of bottom padding, and
   a test checks that its last row is hittable.
9. **Penny rules (spec §2):**
   - The cutouts sit straight on the surface: no `ClipOval` or `ClipRRect`, no white
     square, no ring.
   - Never at rest on Home.
   - Never on over-budget, missed-target or error states.
10. **Goldens.**
    - A step that changes a screen's look regenerates that screen's light and dark goldens
      in `test/goldens/` and attaches before/after crops to its PR.
    - Regenerate with `flutter test --update-goldens test/goldens/`, then re-run without
      the flag.

### Test helpers

- **Pump and mock helpers:** `test/test_helpers/pump_app.dart` (`pumpApp(..., overrides:)`)
  and `test/test_helpers/mocktail_setup.dart`.
- **Golden harness:** `test/goldens/screenshot_harness.dart` (`pumpShell`, `pumpScreen`,
  `loadRealFonts`). It renders real screens on sample data with real fonts, so it needs no
  sign-in.
- **Reduced-motion tests:** wrap the widget in
  `MediaQuery(data: MediaQueryData(disableAnimations: true), …)`, as the existing
  `mascot_moment` tests do.

---

## Dependency graph

```
0 ─▶ 1 ─┬─▶ 2 ─┐
        └─▶ 3 ─┴─▶ 4 ─┬─▶ 5 ─┐
                      ├─▶ 6 ─┤
                      ├─▶ 7 ─┼─▶ 9
                      └─▶ 8 ─┘
```

| Step | Title | Depends on | Parallel with | Model tier |
|---|---|---|---|---|
| 0 | Approve, branch, optional Stitch pass | — | — | default |
| 1 | Tokens, theme, type, motion and haptic foundations | 0 | — | **strongest** |
| 2 | Penny cutouts and `mascot.jpg` retirement | 1 | 3 | default |
| 3 | Shared components restyle | 1 | 2 | **strongest** |
| 4 | Skeleton loading (`skeletonizer`) | 2, 3 | — | default |
| 5 | Home and Net worth | 4 | 6, 7, 8 | **strongest** |
| 6 | Transactions, Review and Add transaction | 4 | 5, 7, 8 | default |
| 7 | Plan (Budgets, Goals, Savings) and Invest | 4 | 5, 6, 8 | default |
| 8 | Penny chat, Settings, auth, lock and onboarding | 4 | 5, 6, 7 | default |
| 9 | Close-out, critique and release to master | 5–8 | — | **strongest** |

Steps 2 and 3, and steps 5–8, touch disjoint files, which are listed per step. One file is
shared on purpose: `lib/shared/widgets/state_views.dart`. Step 2 owns `EmptyState`'s
mascot, and Step 4 owns the loading view. That's why Step 4 waits for Step 2. If two
parallel PRs still collide, the second rebases on `feat/visual-rework` before it merges.

### Who owns each motion row (M1–M42)

| Step | Rows |
|---|---|
| 1 (theme level) | M7 sheet, M10 field error, M12 refresh, M17 dialog, M28 switch, M38 snackbar |
| 2 (Penny widget) | M31 bob, M39 pop (the widget; placed by 5 and 7) |
| 3 (components) | M1, M2, M4, M5, M21 ticker widget, M22, M23, M27, M29, M41, M42 |
| 4 (skeletons) | M11, M13, M14 |
| 5 | M6, M21 on the Home hero, M39 Home savings card |
| 6 | M8, M15, M16, M18, M20 |
| 7 | M19, M21 on the Invest summary, M24, M25, M26, M39 goal card, M40 |
| 8 | M3, M9, M30, M31 placement and the 10 s line, M32, M33, M34, M35, M36, M37 |

Every row has exactly one owner. Step 9 ticks all 42 against the build.

---

## Step 0: approve, branch, optional Stitch pass

**Tasks.**
1. On `visual/04-blueprint`:
   - set the spec's status line to "Approved by Tiaan 2026-10-10";
   - add this blueprint;
   - open the PR into `feat/visual-rework`. Tiaan merges it.
2. **Optional and non-blocking: the Stitch pass.** Re-run the 19 screens listed as
   unrendered in spec §4.2 in project `projects/2869264751174926029`, with the design
   systems from §4. How to run it:
   - Generate calls time out client-side but finish server-side. Poll `get_project` and
     don't fire duplicate requests.
   - Say "MOBILE ONLY 390px" in every prompt.
   - Composite the real cutouts into the Penny slots.
   - Add the screen IDs to §4.2 and the grids to `img/`.

   Steps 5–8 use these mockups if they exist. The spec text alone is enough to build from.

**Exit.** This blueprint is on `feat/visual-rework`.

---

## Step 1: tokens, theme, type, motion and haptic foundations (strongest)

**Context.**
- **Colour:** `lib/core/theme/app_theme.dart` (257 lines) defines the old identity, with
  white/black, one green accent and a hero gradient. `AppColors` has 3 callers outside the
  theme: `shared/widgets/hero_metric_card.dart`,
  `features/settings/screens/subscription_screen.dart` and
  `features/expenses/screens/expenses_summary_screen.dart`. `AppSemanticColors` is used
  widely.
- **Type:** Manrope everywhere, via `GoogleFonts.manropeTextTheme()` and
  `moneyTextStyle`.
- **Motion:** `lib/core/theme/app_motion.dart` holds the 4 durations and 2 curves.

**Files (this step owns them):**
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/app_motion.dart`
- new `lib/core/theme/app_tokens.dart`
- new `lib/core/theme/app_haptics.dart`
- the 3 `AppColors` callers above, for the hero gradient only
- `test/goldens/fonts/` and `test/goldens/screenshot_harness.dart`
- new tests

**Tasks.**
1. **`app_tokens.dart`.**
   - `class AppTokens extends ThemeExtension<AppTokens>`, with every role from spec §1.1
     and §1.2:
     - `bg`, `surface`, `surfaceRaised`, `sunk`
     - `ink`, `muted`, `outline`
     - `primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`
     - `positive`, `danger`, `dangerContainer`, `onDangerContainer`
     - `hero`, `heroInk`, `heroSecondary`, `heroBar`, `heroTrack`
   - Add `categoryTile(CategoryFamily)` and `categoryIcon(CategoryFamily)` (§1.3) and
     `chartSeries` (a list of 4).
   - Give it `light` and `dark` const instances, plus `copyWith` and `lerp`.
   - Add `context.tokens` as an extension getter.
   - Add `enum CategoryFamily { forest, ochre, clay, sage, neutral }`.
   - Add `AppSpace` (4, 8, 12, 16, 20, 24, 32, 40; `gutter` 16, `cardPad` 20,
     `rowGap` 12, `sectionGap` 24, `fabInset` 88).
   - Add `AppRadius` (`card` 24, `sheet` 28, `tile` 14, pill = `StadiumBorder`).
   - Add `AppShadows.level1` and `AppShadows.level2`: forest-tinted in light, empty in
     dark.
2. **`app_theme.dart`.**
   - Build `ColorScheme` from `AppTokens`: `primary`, `onPrimary`, `primaryContainer`,
     `onPrimaryContainer`, `surface`, `onSurface` = ink, `onSurfaceVariant` = muted,
     `outline`, `error` = danger, `errorContainer`, `surfaceContainerHighest` = sunk.
   - Keep `AppSemanticColors` and its five field names so nothing else has to change. Map
     them onto the new values: `success` → positive, `danger`, `textMuted` → muted,
     `accentChipBg` → primaryContainer, `dangerChipBg` → dangerContainer.
   - Delete `AppColors` once its 3 callers read tokens. Swap the hero gradient for the
     flat `hero` fill; the full hero layout comes in Steps 3 and 5.
   - **Type:**
     - Plus Jakarta Sans for display, headline and title roles.
     - Nunito Sans for body and label roles.
     - Map the spec §1.5 table onto Material roles: `displaySmall` = display 40/44/800,
       `headlineMedium` = headline 28, `titleLarge` = title 20,
       `titleMedium`/`titleSmall` = titleSmall 16, `bodyLarge` = body 16,
       `bodyMedium`/`bodySmall` = bodySmall 14, `labelLarge` = label 14/600,
       `labelSmall` = overline 12/700 +6 %.
     - `moneyTextStyle` becomes Plus Jakarta Sans with tabular figures, keeping the same
       signature.
   - **Component themes:**
     - **Card:** radius 24, `surface`, no border; elevation 0 with the level-1 shadow
       supplied by Step 3's `AppCard`; tonal in dark.
     - **Input:** pill, `sunk` fill, 2 dp primary focus ring. `errorMaxLines` 2, which
       makes M10's grow-in come from `InputDecorator`.
     - **Buttons:** filled, outlined and text, as pills at 52 dp.
     - **NavigationBar:** `surface`, `primaryContainer` pill indicator, `label` style.
     - **BottomSheet:** top radius 28, drag handle 4 × 32, scrim ink at 40 %. Gives M7.
     - **Dialog:** radius 24. Gives M17.
     - **SnackBar:** floating, pill, ink fill, 16 dp above the nav. Gives M38.
     - **Switch, Checkbox, Chip, SegmentedButton:** M28 and M27 colours.
     - **RefreshIndicator:** primary on `surface`. Gives M12.
   - Keep `_ReducedMotionAwarePageTransitionsBuilder` as it is.
3. **`app_motion.dart`.**
   - Add `springPress` (stiffness 700, ratio 0.9), `springSettle` (400, 0.85) and
     `springPop` (300, 0.6) as `SpringDescription.withDampingRatio`.
   - Add `stagger` (30 ms, `staggerMax` 6) and `exitFactor` (0.65).
   - Add `exit(Duration d)` and `popOvershootCap` (0.06).
   - Leave the existing tokens unchanged.
4. **`app_haptics.dart`.** Add `AppHaptics.selection()`, `.light()` and `.medium()`,
   wrapping `HapticFeedback.selectionClick`, `lightImpact` and `mediumImpact`. Move the 2
   existing `HapticFeedback` call sites onto it.
5. **Golden fonts.**
   - Add Plus Jakarta Sans (400, 700, 800) and Nunito Sans (400, 600, 700) TTFs (OFL,
     from Google Fonts) to `test/goldens/fonts/`, with licence notes in its `README.md`.
   - Extend `loadRealFonts()` and its google_fonts asset map the same way it handles
     Manrope today.
   - Drop the Manrope files once nothing asks for them.
6. **APK baseline.** Before changing anything, run `flutter build apk --release` on
   `feat/visual-rework` and record the `app-release.apk` size in the PR body. Step 4
   records the size after.

**Tests.**
- New `test/core/theme/contrast_test.dart`.
  - Port the WCAG luminance formula and assert every pair in spec §1.4 against the
    `AppTokens` instances: 65 pairs, with a 4.5 floor for text and 3.0 for UI parts.
  - This is the spec §6 "contrast script as a test".
- New `test/core/theme/app_tokens_test.dart`. It checks that light and dark differ, that
  `lerp` endpoints hold, and that `context.tokens` resolves under `pumpApp`.
- Update `test/core/theme/*` for the font and colour change.
- Regenerate **every** golden in `test/goldens/`. The font and colour change touches them
  all.

**Verify.** Run `flutter analyze`, then `flutter test`. Check
`grep -rn "Color(0x" lib --include=*.dart | grep -v core/theme`: only the two
`features/portfolios` palette files remain, and Step 7 owns them.

**Exit.**
- The app runs in the new palette and type everywhere.
- Contrast test green.
- Goldens regenerated.
- No screen's layout has changed yet.

**Risk.** The font change reflows text, and an overflow test may fail. Fix it with
`maxLines` or ellipsis in the failing widget, and say which in the PR. Don't shrink the
spec's sizes. If the step grows past about 700 changed lines (excluding PNGs), split it
into 1a (tokens, colour scheme, contrast test) and 1b (type, component themes, motion,
haptics, goldens), and record the split in the mutation log.

---

## Step 2: Penny cutouts and `mascot.jpg` retirement

**Context.**
- **Assets:** the cutouts are in `assets/penny/{welcoming,sleeping,thinking,celebrating}.png`
  but aren't in `pubspec.yaml`. The app bundles `assets/mascot.jpg` and the four
  `assets/mascot_*.jpg` poses.
- **Clipping:** every Penny is clipped.
  - `MascotMoment` (`lib/shared/widgets/mascot_moment.dart`) uses `ClipOval`.
  - `PennyAvatar` (`lib/features/onboarding/widgets/penny_avatar.dart:10`, default
    `assets/mascot.jpg`, with a looping bob) uses `ClipRRect(24)`.
  - Five auth screens clip a jpg inline: `login_screen.dart:96`,
    `register_screen.dart:77`, `lock_screen.dart:102`,
    `forgot_password_screen.dart:64` and `reset_password_screen.dart:73`.
- **Onboarding** picks the welcoming or default pose per page at
  `onboarding_screen.dart:130`.

**Files:**
- `pubspec.yaml` (assets block only)
- `mascot_moment.dart`, `penny_avatar.dart`
- `state_views.dart` (`EmptyState`'s mascot only)
- `completed_goal_card.dart` (pose path only)
- the 5 auth screens and `onboarding_screen.dart` (the `Image.asset` and clip lines
  only; their layout is Step 8's)
- `assets/mascot.jpg` (deleted)
- tests

**Tasks.**
1. In `pubspec.yaml`, add `- assets/penny/` and remove the five `assets/mascot*.jpg`
   lines.
2. Delete `assets/mascot.jpg`. Keep the four `mascot_*.jpg` files on disk unbundled: they
   are the sources the cutouts were made from (spec §2). Leave
   `assets/Piggybank mascot.jpeg` and `assets/icon/` alone, because the launcher icon is
   out of scope.
3. **`MascotMoment`.**
   - Point the constants at `assets/penny/*.png`.
   - Replace `ClipOval` with `Image.asset(..., fit: BoxFit.contain)` in a `SizedBox`.
   - `pop` uses `springPop` with the overshoot capped at 6 %, instead of `easeOutBack`.
   - Leave `bob` (2 dp, 1.2 s, M31) and `fadeIn` as they are.
4. **`PennyAvatar`.**
   - The default `assetPath` becomes `assets/penny/welcoming.png`.
   - Remove the clip.
   - Replace the looping bob with spec §2's "fade + `springPop` on the first page only".
     Add an `entrance` flag; onboarding passes `true` for page 0 only.
   - Under reduced motion it's static.
5. **Pose per place (spec §2 table):**
   - Login and register: welcoming.
   - **Lock: welcoming.** Today it's sleeping, and the spec wins.
   - Forgot and reset password: keep thinking. The spec doesn't list them, so log it in
     the mutation log.
   - Onboarding: welcoming on every page (`:130`).
   - `EmptyState` with `mascot: true`: welcoming.
   - `CompletedGoalCard`: celebrating.

   Sizes stay as they are here. Step 8 sets the spec sizes (140, 180) when it lays those
   screens out.

**Tests.**
- **`mascot_moment_test.dart`:**
  - no `ClipOval` in the tree;
  - the asset path is under `assets/penny/`;
  - the pop runs under the spring and doesn't run under reduced motion.
- **`penny_avatar_test.dart`:**
  - no clip;
  - no repeating animation (`tester.binding.hasScheduledFrame` is false after settle);
  - the entrance plays once.
- **Asset test:** a new test reads `pubspec.yaml` and asserts that no bundled path ends in
  `mascot.jpg`. Grep `lib/` and `test/` for `mascot.jpg` and `mascot_` and find zero
  references.
- Regenerate the goldens for login, lock and onboarding.

**Exit.**
- Every Penny is a cutout with no box.
- `mascot.jpg` is gone from the repo and the bundle.
- APK size recorded, since dropping four JPGs should shrink it.

---

## Step 3: shared components restyle (strongest)

**Context.** Spec §3 restyles the shared kit that every screen draws from. Doing it once
here means the screen steps mostly rearrange instead of restyling.

**Files:**
- `lib/core/router/app_shell.dart` (nav bar only)
- `lib/shared/widgets/`: `tab_app_bar.dart`, `group_card.dart`, `hero_metric_card.dart`,
  `progress_card.dart`, `percent_pill.dart`, `icon_chip.dart`, `status_badge.dart`,
  `quick_link_tile.dart`, `allocation_bar.dart`, `confirm_dialog.dart`,
  `swipe_background.dart`
- `lib/shared/motion/`: `press_scale.dart`, `count_up_text.dart`
- new `lib/shared/widgets/app_card.dart`, `category_tile.dart`, `expand_section.dart`,
  `app_banner.dart`
- `lib/features/transactions/category_icons.dart` (adds the family map)
- tests

**Tasks.**
1. **`AppCard`.** `surface`, radius 24, padding 20, level-1 shadow in light and tonal in
   dark, with an optional `onTap` that wraps `PressScale`. Use it inside `GroupCard`,
   `ProgressCard` and `HeroMetricCard`, so that their callers don't change.
2. **`PressScale`.** It drives 1 → 0.97 → 1 with `springPress`. It starts on
   pointer-down, reverses on release, and does a ripple only under reduced motion (M4).
3. **`GroupCard`.**
   - One card per group, rows at least 64 dp, `rowGap` 12 between rows.
   - Each row gets a press highlight of `sunk` at 60 %: 100 ms in, 150 ms out (M5).
4. **`CategoryTile` and the family map.**
   - Add `CategoryFamily categoryFamily(String? category)` next to `categoryIcon` in
     `category_icons.dart`, following spec §1.3. It's a presentation lookup over the
     existing `case` names, with no schema change.
     - **forest:** groceries, food, salary, freelance, interest
     - **ochre:** transport, gas, petrol
     - **clay:** dining, dining out, shopping, clothing, entertainment
     - **sage:** utilities, rent, insurance, gym, healthcare, medical
     - **neutral:** everything else
   - The unknown fallback icon becomes a neutral tag (`Icons.sell_outlined`), never an
     arrow (S6).
   - `CategoryTile` is 40 dp, radius 14, `tokens.categoryTile(f)` behind a
     `tokens.categoryIcon(f)` icon. `IconChip` takes an optional family and renders the
     tile.
5. **`TabAppBar`.**
   - `headline` title, the avatar at 40 dp in a 48 dp target, and at most 2 actions,
     each with a tooltip.
   - Flat on `bg`. It gains `surface` and a hairline once content scrolls under it
     (`scrolledUnderElevation` 0 plus a `NotificationListener`, 150 ms; M42).
   - No bell.
6. **Nav bar (`app_shell.dart`).**
   - The pill indicator slides with `springSettle`, and every tab change fires
     `AppHaptics.selection()` (M1).
   - Re-tap at the root scrolls to top and flashes a 6 dp shadow on the top bar (M2).
   - Leave the existing fade-through, re-tap-pops-to-root behaviour and its tests
     unchanged.
7. **`HeroMetricCard`.**
   - Light `hero` fill, `overline` label in `heroInk`, a `display` figure through
     `CountUpText` (400 ms, M21), and an 8 dp pill bar (`heroBar` on `heroTrack`).
   - The secondary line is in `heroSecondary`, and the whole card is tappable through
     `AppCard.onTap`.
   - The hero shows no cents.
8. **`CountUpText`.** It stays the M21 ticker and adds `CrossfadeDigits` for M22: 150 ms
   with a 4 dp slide in the direction of change. Under reduced motion it shows the final
   value.
9. **Progress (`ProgressCard`, `AllocationBar`).**
   - 8 dp pill on a `sunk` track. The fill animates over 400 ms ease-out (M23).
   - Danger only when the value is over 100 % of a *budget*.
   - At 100 % of a *goal*, add an `onReached` hook. The goal step plays a brightness pulse
     on it.
10. **`PercentPill` and `StatusBadge`.** Pills in `primaryContainer`/`onPrimaryContainer`,
    and `dangerContainer` only when the value is over.
11. **`ExpandSection`.** Size transition plus a 180° chevron rotation, 200 ms emphasized
    (M29).
12. **`AppBanner`.** Pill, `primaryContainer`, chevron, sliding down 8 dp and fading in
    (M41). The review and OTA banners adopt it in their own steps (5 and 9). This step
    only adds it.
13. **`ConfirmDialog`.** Radius 24 and a danger text button for destructive confirms; the
    motion comes from Step 1's theme (M17).
14. **`SwipeBackground`.** Token colours only; the behaviour is unchanged.
15. **Chips.** `FilterChip` and `ChoiceChip` styling comes from Step 1's theme. Add a
    150 ms check-icon grow-in and `AppHaptics.selection()` through a small
    `AppFilterChip` wrapper (M27).
16. **FAB.** Add `ShrinkingFab`, an extended pill that becomes an icon when its
    `ScrollController` scrolls down and grows back on scroll up (M42). The screen steps
    adopt it.

**Tests.**
- A widget test for every new or changed widget. Each one checks:
  - the token colours, read from the rendered `DecoratedBox` or `Material`;
  - the reduced-motion path;
  - for `PressScale`: the scale starts on pointer-down, before release;
  - for `GroupCard`: the press highlight;
  - `categoryFamily` for every `case` in `category_icons.dart`, with unknown → neutral and
    the icon not an arrow;
  - for `TabAppBar`: no bell, more than 2 actions asserts, and the hairline appears after
    a scroll;
  - for the nav bar: one selection haptic per tab change. Mock with
    `SystemChannels.platform` as the existing swipe tests do.
- Regenerate the goldens that use these widgets, which is every tab root.

**Exit.**
- The shared kit matches spec §3.
- Every row this step owns in the M table passes a test.
- Screens look restyled but keep their current layouts.

**Risk.** This step touches widgets with many callers. Keep every public constructor
source-compatible: add optional parameters, never rename. Then the callers don't change,
and the parallel screen steps don't collide with it.

---

## Step 4: skeleton loading (`skeletonizer`)

**Context.** `CircularProgressIndicator` appears in 42 files (S7). The spec replaces
*initial-load* spinners with skeletons of the real layout (M11), adds load-more skeleton
rows (M13), and gives Retry a press and a progress ring (M14). Spinners inside buttons
(the 16 dp ring of M8 and M9) stay.

**Files:**
- `pubspec.yaml` (adds `skeletonizer: ^3.0.0`)
- `lib/shared/widgets/state_views.dart` (the loading view and `InlineError`)
- new `lib/shared/motion/stagger_in.dart`
- the screens' `loading:` branches. These are one-line swaps to
  `AppSkeleton(child: <real body on placeholder data>)`; the screen steps own the rest of
  each screen.

**Tasks.**
1. Add `skeletonizer` (MIT; Session 1 shortlist). Run `flutter pub get` and commit
   `pubspec.lock`.
2. Add `AppSkeleton`. It wraps `Skeletonizer` with `sunk`-tinted bones and turns shimmer
   off under reduced motion. It crossfades to the content over 200 ms.
3. Add `StaggerIn`. The first 6 children fade in and rise 8 dp, 30 ms apart over 200 ms,
   and play once per first load. Under reduced motion it renders instantly.
4. Go through the 42 files:
   - Each **initial-load** `AsyncValue.loading` on a tab root, list or hub becomes
     `AppSkeleton` over the real widget fed placeholder data. Use a `fake` constructor
     next to the widget, never one in `models/`.
   - Leave button-, dialog- and sheet-save spinners, and spinners under 300 ms such as
     a refresh, as they are.
   - List each kept spinner, with a reason, in the PR body.
5. Load more: show 3 skeleton rows at the end of the list, replaced in place (M13).
6. `InlineError`: 200 ms fade-in; the Retry button uses `PressScale` and then a progress
   ring (M14).
7. Record the release APK size after this step, against Step 1's baseline. Flag it to
   Tiaan if it grows by more than 1 MB.

**Tests.**
- `state_views_test.dart`:
  - the skeleton renders and has no shimmer under reduced motion;
  - `StaggerIn` has no stagger under reduced motion;
  - the Retry button shows its ring.
- Any screen test that found a `CircularProgressIndicator` for loading now finds a
  `Skeletonizer`.

**Exit.**
- No full-screen loading spinner is left. `grep` lists only the kept spinners from the
  PR body.
- APK delta recorded.

---

## Step 5: Home and Net worth (strongest)

**Context.** Home is the screen Tiaan sees most. The spec's order is fixed:
1. review banner
2. light hero
3. Savings card **above** Net worth (both full width)
4. Needs attention
5. Recent (5 rows, one group card)
6. FAB

The 24 dp section gap makes Recent read as a section, not the end of the page (S5).
Penny is never at rest on Home; the two existing moments stay.

**Files:**
- `lib/features/dashboard/` (screens and widgets)
- `lib/features/networth/`, `lib/features/accounts/`, `lib/features/liabilities/`
- presentation files only, with their tests

**Tasks.**
1. **Order and spacing.**
   - Apply the order with `AppSpace.sectionGap` between sections and `gutter` 16.
   - Use `AppBanner` for the review banner.
   - Pad the list bottom by `fabInset`, and use `ShrinkingFab`.
2. **Hero.**
   - `LeftToSpendHero` is built on Step 3's `HeroMetricCard`: "LEFT TO SPEND · OCTOBER",
     the count-up figure (M21), the bar, and the secondary line.
   - Tapping it goes to Plan › Budgets, as it does today.
   - Remove any Penny overlap from the hero.
3. **Savings and Net worth cards** stacked, not side by side (spec §4.3 drift). Secondary
   figures use `CrossfadeDigits` (M22).
4. **Needs attention.**
   - The primary bar stays below 100 %. Danger shows only when a budget is exceeded
     ("Over by R 150").
   - Don't build the Stitch render's red 84 %.
5. **Recent.** One group card of 5 rows with `CategoryTile` leads. Amounts:
   `titleSmall` tabular, "−" in ink for expenses, "+" in positive for income.
6. **Kept moments:**
   - Sleeping Penny, 28 dp, static, beside "Quiet day so far".
   - Celebrating Penny, 40 dp on the savings card, `springPop` once a day,
     `AppHaptics.medium()` once (M39).
7. **Net worth hub.**
   - The summary card uses the hero palette.
   - Accounts, Assets and Liabilities rows follow, with Liabilities in ink, not red.
   - "Loan calculators ›" comes last.
   - Opening an account keeps its container transform (M6), restyled to radius 24.

**Tests.**
- `dashboard_screen_test.dart`:
  - The section order matches the spec.
  - The savings card sits above net worth: compare their `getTopLeft` y values.
  - No Penny image is present when neither moment applies.
  - A Needs-attention item at 84 % has no danger colour.
  - The last Recent row is hittable above the FAB.
- A test that the hero tap still routes to Plan › Budgets.
- Net worth tests: liabilities use the ink colour.
- Goldens: `home_*` and `net_worth_*`, light and dark.

**Exit.** Home and Net worth match spec §4.1, and the four rows this step owns (M6, M21,
M22, M39) pass.

---

## Step 6: Transactions, Review and Add transaction

**Files:**
- `lib/features/transactions/` (screens and widgets, except `category_icons.dart`, which
  is Step 3's)
- `lib/features/detection/screens/pending_review_screen.dart` and its widgets
- the add-transaction sheet
- `lib/shared/widgets/deferred_delete.dart`, `lib/shared/motion/saved_highlight.dart`
- tests

**Tasks.**
1. **Transactions.**
   - `TabAppBar` actions: Review (icon plus a count badge, hidden at 0) and Insights. Both
     have **tooltips and semantics labels**; the mockup's icon-only version is drift.
   - Then ⋮, the pill type chips (`AppFilterChip`) and Filter.
   - Day groups each get one group card. The header shows the date on the left and the
     day total on the right in `overline`, and day groups are separated by a 1 px
     `outline` at 30 %.
   - Rows show only what the data has: no invented times and no "Recurring" tag.
   - Load more is Step 4's skeleton rows. Add `fabInset` and `ShrinkingFab`.
2. **Delete with Undo.**
   - M15: the row slides 24 dp left and fades over 180 ms, the gap closes over 200 ms,
     and `AppHaptics.medium()` fires.
   - M16: on Undo the row grows back over 200 ms, with `AppHaptics.light()`.
   - The timer still lives with the snackbar, as before.
3. **Save in a sheet (M8).** The button shows a 16 dp ring, then the sheet closes over
   200 ms. `SavedHighlight` tints the row `primaryContainer` for 600 ms, and
   `AppHaptics.light()` fires on success.
4. **Add transaction sheet.** Pill segments, then a large display-weight amount field,
   then pill inputs, then Save.
5. **Review.**
   - Detected cards show a category pill with Confirm and Ignore.
   - The swipe works as it does today, with a `springSettle` release and the light haptic
     at the threshold (M18).
   - "Confirm all n" follows.
   - Clearing the queue on this visit shows "All caught up" with celebrating Penny at
     96 dp, `springPop` once a day, and `AppHaptics.medium()` once (M20).

**Tests.**
- **Transactions:** the day header shows the total; Review and Insights have tooltips; the
  Review badge is hidden at 0.
- **Delete:** the exit animation runs, the haptic fires once, and under reduced motion the
  row vanishes instantly.
- **Save:** the ring is visible, then the sheet closes and the highlight appears.
- **Review:** the swipe settles; "All caught up" pops only once a day. Reuse the
  `once_per_day` test pattern.
- **Goldens:** `transactions_*`, `add_transaction_sheet_*` and review, light and dark.

**Exit.** These screens match spec §4.1, and M8, M15, M16, M18 and M20 pass.

---

## Step 7: Plan (Budgets, Goals, Savings) and Invest

**Files:**
- `lib/features/plan/`, `budgets/`, `goals/`, `savings/`
- `lib/features/portfolios/` (screens, widgets and `asset_class_style.dart`)
- `lib/features/trends/`, `tfsa/`, `ra/`, `calculators/`, `summaries/`, `expenses/`
  (restyle only)
- `lib/shared/widgets/allocation_donut.dart`, `growth_projection_card.dart`,
  `completed_goal_card.dart` (layout only)
- tests

**Tasks.**
1. **Plan shell.**
   - The segmented control is a pill track in `sunk`, and its thumb slides with
     `springSettle`. Switching segments uses shared axis X over 250 ms with
     `AppHaptics.selection()` (M25).
   - The month switcher sits in the app bar's bottom area on Budgets. Changing month
     slides the content 24 dp in the direction of travel and fades it over 200 ms, with
     `AppHaptics.selection()`. Under reduced motion it's a 150 ms crossfade (M26).
2. **Budgets.**
   - The summary card sits above the budget cards.
   - Crossing into over budget gets one calm cue: the bar and amount crossfade to danger
     over 400 ms, and "Over by R …" fades in. No shake (M40).
3. **Goals.**
   - Each goal has a rounded progress bar. "Completed (n)" uses `ExpandSection` (M29).
   - When a goal is reached: celebrating Penny at 64 dp on the goal card, `springPop` the
     first time it's seen, one bar brightness pulse, and `AppHaptics.medium()` once (M39,
     M23).
4. **Savings.**
   - The target card uses the hero palette.
   - Suggestions have an Apply pill. The swipe settles with `springSettle` and fires the
     light haptic (M19).
   - Recurring costs form one group card, with "Policy check" text buttons.
   - The "Ask Penny" chip comes last.
5. **Invest.**
   - The summary card uses the hero palette, with the count-up (M21).
   - Compare becomes a labelled pill.
   - Charts use `tokens.chartSeries`:
     - Lines draw left to right, and bars and donut sweep, over at most 600 ms ease-out.
     - Touching shows a datatip with `AppHaptics.selection()`.
     - Under reduced motion the charts are static (M24).
6. **Chart colours, staying presentation-only.**
   - `asset_class_style.dart` maps asset classes onto `tokens.chartSeries` plus the
     neutral, instead of its 7 raw hex values.
   - `comparisonPalette` lives in `models/comparison_entry.dart` and is assigned by
     `providers/comparison_provider.dart`, so **leave both untouched**.
   - Instead, the comparison chart colours each line by its entry *index* from
     `tokens.chartSeries`, at render time, and ignores the stored colour.
   - Log this in the mutation log. A later data-layer change can remove the stored
     colour.

**Tests.**
- **Plan:** the segment switch fires one selection haptic; a month change slides in the
  direction of travel (check the offset sign at a mid-frame); under reduced motion it's a
  crossfade.
- **Budgets:** 84 % isn't danger, and 105 % is danger with "Over by".
- **Goals:** reaching a goal pops only once ever. Use `kind` with `daily: false`, as
  `completed_goal_card` does today.
- **Invest:** chart colours come from tokens, and there's no raw hex in
  `asset_class_style.dart`.
- **Goldens:** `plan_*`, `plan_goals_*`, `plan_savings_*` and `invest_*`, light and dark.

**Exit.**
- These screens match spec §4.1, and M19, M21 (Invest), M24, M25, M26, M39 (goal) and
  M40 pass.
- `grep -rn "Color(0x" lib | grep -v core/theme` finds only `models/comparison_entry.dart`.

---

## Step 8: Penny chat, Settings, auth, lock and onboarding

**Files:**
- `lib/features/chatbot/`, `lib/features/settings/`
- `lib/core/router/placeholder_screens.dart` (Settings body styling only)
- `lib/features/auth/screens/*` (layout; Step 2 already swapped the images)
- `lib/features/onboarding/`, `lib/features/consent/`
- tests

**Tasks.**
1. **Penny chat.**
   - A 40 dp welcoming cutout in the header.
   - Replies sit on `surface` and user bubbles in `primary`. Both use the speech-bubble
     shape: radius 24 with a 12 dp tail.
   - The input is a pill.
   - **Sending (M30):** the user bubble slides up 8 dp and fades in over 200 ms, the chips
     step aside, and `AppHaptics.light()` fires.
   - **Waiting for a reply (M31):** thinking Penny at 40 dp in the reply slot with a bob.
     After 10 s, "Still working on it…" fades in. The reply bubble then slides in over
     200 ms.
   - **Chips (M32):** the 3 data-aware chips are outlined pills. Tapping one starts the
     `PressScale` in under 100 ms, fires `AppHaptics.selection()`, then sends.
2. **Settings.**
   - A profile card, then the grouped cards from spec §2.6, showing real data only. The
     mockup's subtitles are drift.
   - Log out is a danger outline pill behind `ConfirmDialog`.
   - Settings opens from the avatar with shared axis Z, and back reverses it. Under
     reduced motion it's a 150 ms fade (M3).
   - **Copy, share and export (M37):** an inline tick replaces the icon for 1.5 s, the
     snackbar shows, and `AppHaptics.light()` fires.
3. **Login, register and lock.**
   - Welcoming Penny at 140 dp, the wordmark in `primary`, then the card. Forgot and
     reset password use the same layout with thinking Penny.
   - Submitting (M9): the button label becomes a ring with its width locked. On success:
     shared axis Y into the shell over 250 ms, plus `AppHaptics.light()` (M34, M35).
   - Wrong PIN (M33): keep the existing shake, and turn the dots danger for 600 ms. No
     haptic.
4. **Onboarding.**
   - Penny at 180 dp above a speech bubble. The page dots have an elongated active pill
     that stretches with `springSettle`, and there's a Next pill.
   - There's no "Step 1 of 6" text and no phone frame; those are drift.
   - Next and Skip (M36): the page slides, Penny's pose crossfades, and
     `AppHaptics.selection()` fires.
   - `PennyAvatar`'s entrance plays on page 0 only.

**Tests.**
- **Chat:** sending fires one light haptic. The 10 s "still working" line appears after
  `pump(Duration(seconds: 10))`. Under reduced motion, thinking Penny is static.
- **Settings:** Log out asks for confirmation; there are no invented subtitles. Assert the
  rows' subtitle texts against the provider data.
- **Auth:** the submit ring keeps the button width (equal `getSize` before and after);
  a wrong PIN turns the dots danger with no haptic.
- **Onboarding:** there's no "Step" text, the active dot is wider, and each page shows
  `welcoming.png`.
- **Goldens:** `penny_*`, `settings_*`, `login_*`, `lock_*` and `onboarding_*`, light and
  dark.

**Exit.** These screens match spec §4.1, and M3, M9, M30–M37 pass.

---

## Step 9: close-out, critique and release to master (strongest)

**Tasks.**
1. **Motion audit.**
   - Tick all 42 M rows against the build in a new `docs/visual-rework/05-build-audit.md`.
     For each row, give the file and the test that proves it.
   - Grep for every literal `Duration(milliseconds:` added in this epic, and move each
     one onto an `AppMotion` token.
2. **Token audit.**
   - Check that `grep -rn "Color(0x\|Colors\.\(red\|green\|grey\|white\|black\|orange\|amber\|blue\)" lib`
     finds only the theme, `models/comparison_entry.dart` and `Colors.transparent`. That
     takes the 14 named-colour uses outside the theme at the start of the epic, down to zero.
   - Put the AA contrast test in the epic's acceptance list.
3. **OTA banner.** `lib/features/updates/` is off-limits for logic. Move only its banner
   *widget* onto `AppBanner` (M41) if that widget sits outside the forbidden logic files.
   Otherwise, log it in the mutation log.
4. **Goldens.** Every screen in spec §4.2 has light and dark goldens.
5. **Critique.** Re-run the impeccable critique on the tab roots. The target is at least
   35/40 (the baseline was 27). Save it next to the Session 1 snapshot.
6. **On-device pass.** Tiaan signs in on his phone, because Claude can't enter passwords.
   Then:
   - tick every row of `docs/ux-rework/03-capability-inventory.md`, plus reduced motion
     on and off, plus dark mode;
   - record the ticks in `05-build-audit.md`.

   Any missing capability blocks the release.
7. **DESIGN.md.** Confirm that DESIGN.md matches what was built, and fix any drift in the
   doc, not the app.
8. **Release PR.** Open the PR `feat/visual-rework` → `master` with the audit, the score,
   the APK delta and before/after grids. Tiaan merges it and cuts the release through the
   usual process (version bump and OTA). This blueprint doesn't change release config.

**Exit.**
- The PR to master is merged, with all 42 M rows ticked, every inventory row ticked, and a
  critique score of at least 35.

**Out of scope, flagged for Tiaan:** the launcher icon (`assets/Piggybank mascot.jpeg`,
`assets/icon/app_icon.png`) still uses the old comp. Matching it to the welcoming pose
would be its own small step, after release.

---

## Review notes

The adversarial review ran in the same context, not in a sub-agent. It checked the
following.

**Coverage**
- Every spec section has an owner: §1 is Step 1, §2 is Step 2, §3 is Step 3, §4 is Steps
  5–8, §5 is the M ownership table above, and §6 is Steps 1 and 9.
- Every M row has exactly one owner.
- S1 and S2 are covered by Step 1, S3 by Steps 3 and 5, S4 by Step 1, S5 by Step 5, S6 by
  Step 3, S7 by Step 4, S8 by Steps 1 and 3–8, S9 by Step 1, S10 by Steps 2 and 8, and
  S11 by Steps 3 and 5–7.

**Data layer**
- The only raw colour in `models/` (`comparisonPalette`) is worked around at render time
  rather than edited, so invariant 2 holds.
- The category family map is a presentation lookup next to `categoryIcon`, so there's no
  schema change.

**Dependency order**
- Steps 2 and 3 need only Step 1's tokens.
- Step 4 needs Step 2's `EmptyState` and Step 3's `GroupCard`, because skeletons wrap the
  restyled layouts.
- Steps 5–8 need the whole shared kit.
- The parallel steps own disjoint feature folders.

**Anti-patterns avoided**
- No step depends on a previous step's chat.
- No "and also refactor X".
- Each step has its own tests and an exit criterion.
- Shared widgets keep source-compatible constructors (Step 3's risk note), so the screen
  steps don't collide with them.

**Risks**
- Step 1 (the font swap reflows every screen) and Step 3 (wide fan-out) are the biggest.
  Both have a split rule.
- The Stitch pass is optional, so a stalled Stitch can't block the build.

## Mutation log

| Date | Change | Why |
|---|---|---|
| 2026-10-10 | Created | Spec approved by Tiaan, default Penny retired |
| 2026-10-10 | Step 2: forgot and reset password keep the **thinking** pose | Spec §2's placement table doesn't list them; thinking fits "we're sorting it out" and is one of the four approved poses |
| 2026-10-10 | Step 2: the lock screen moves from sleeping to **welcoming** Penny | Spec §2 lists lock with login and register (welcoming); the spec wins over the current code |
| 2026-10-10 | Step 2: the four `mascot_*.jpg` sources stay in the repo but leave the bundle | Spec §2 keeps the originals; nothing in `lib/` loads them after the switch, and unbundling them shrinks the APK |
| 2026-10-10 | Step 7: comparison lines take their colour from `tokens.chartSeries` by index at render time; `comparisonPalette` in `models/` is left in place | Invariant 2 (no `models/` edits); removing the stored colour is a data-layer change outside this epic |
