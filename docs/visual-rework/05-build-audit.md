# Visual rework 05: build audit (Step 9 close-out)

Branch `visual/09-close-out`, cut from `feat/visual-rework` @ `30dd5d2` (Steps 0–8
merged). This is the record the release PR into `master` rests on.

**Status:** Steps 1–5 and 7 of the close-out are done. Step 6, the on-device pass, needs
Tiaan signed in on his phone, because Claude can't enter passwords. The release waits on
it.

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 925 pass (922 at the end of Step 8, +3) |
| Motion rows M1–M42 | 38 fully built and tested; 4 styled by the theme on Flutter's built-in motion (M7, M10, M17, M38) |
| Literal `Duration(milliseconds:` in widgets | 0 (one search debounce remains, which isn't motion) |
| Raw colours outside the theme | 0 (only `models/comparison_entry.dart`, left by design, see the mutation log) |
| Light and dark goldens for every screen in spec §4.2 | 15 screens × 2 |
| AA contrast | `test/core/theme/contrast_test.dart`, every token pair in both themes |
| Critique, tab roots | **35/40** (baseline 27) |
| Release APK, arm64 | 24.1 MB, against 28.7 MB on `master` (−4.6 MB; the four `mascot_*.jpg` sources left the bundle in Step 2) |
| On-device pass | **Pending Tiaan** |

---

## 1. Motion audit (M1–M42)

✅ means built and proved by the named test. ◐ means styled to spec by the theme, with
the motion itself left to Flutter's built-in transition (see the note below the table).
Paths are under `lib/` and `test/`.

| Row | Built in | Proved by | |
|---|---|---|---|
| M1 Tab fade-through, nav pill | `core/router/app_shell.dart` | `core/router/app_shell_test.dart`, `core/router/app_shell_nav_test.dart` | ✅ |
| M2 Re-tap active tab | `shared/motion/tab_retap.dart`, `shared/widgets/tab_app_bar.dart` | `core/router/app_shell_nav_test.dart`, `shared/widgets/components_test.dart` (TabAppBar) | ✅ |
| M3 Avatar → Settings, shared axis Z | `core/router/app_router.dart` (`sharedAxisPage`) | `shared/widgets/step8_widgets_test.dart` (shared-axis pages) | ✅ |
| M4 Card press 0.97 | `shared/motion/press_scale.dart`, `shared/widgets/app_card.dart` | `shared/motion/motion_test.dart` (PressScale), `components_test.dart` (AppCard) | ✅ |
| M5 Row highlight in a group | `shared/widgets/group_card.dart` | `components_test.dart` (GroupCard) | ✅ |
| M6 Container transform | `shared/motion/container_transform.dart`, Home and Net worth rows | `shared/motion/motion_test.dart` (ContainerTransform) | ✅ |
| M7 Sheet | `core/theme/app_theme.dart` (`bottomSheetTheme`: radius 28, handle, scrim 40 %) | goldens `add_transaction_sheet_*` | ◐ |
| M8 Save in a sheet | `shared/motion/saved_highlight.dart`, `features/transactions/widgets/transaction_sheet.dart` | `features/transactions/widgets/transaction_sheet_test.dart`, `motion_test.dart` (SavedHighlight) | ✅ |
| M9 Submit a full-screen form | `shared/widgets/submit_button.dart` | `step8_widgets_test.dart` (SubmitButton) | ✅ |
| M10 Field error | `app_theme.dart` (`inputDecorationTheme`: danger outline and text) | goldens `login_*` | ◐ |
| M11 Initial load | `shared/widgets/app_skeleton.dart`, `shared/motion/stagger_in.dart` | `shared/widgets/state_views_test.dart`, `features/transactions/screens/transactions_screen_test.dart` | ✅ |
| M12 Pull to refresh | `shared/widgets/app_controls.dart` (`AppRefresh`, all 18 lists) | `shared/widgets/app_controls_test.dart` | ✅ |
| M13 Load more | `features/transactions/screens/transactions_screen.dart` | `transactions_screen_test.dart` | ✅ |
| M14 Load error + Retry | `shared/widgets/state_views.dart` (`InlineError`) | `state_views_test.dart` | ✅ |
| M15 Delete a row (Undo) | `shared/widgets/deferred_delete.dart` (`CollapseOut`) | `shared/widgets/deferred_delete_test.dart` | ✅ |
| M16 Undo a delete | `deferred_delete.dart` | `deferred_delete_test.dart`, `transactions_screen_test.dart` | ✅ |
| M17 Confirm-delete dialog | `shared/widgets/confirm_dialog.dart`, `dialogTheme` | `components_test.dart` (ConfirmDialog) | ◐ |
| M18 Swipe a detection | `shared/motion/spring_swipe.dart` | `features/detection/screens/pending_review_screen_test.dart` | ✅ |
| M19 Swipe a savings suggestion | `spring_swipe.dart`, `features/savings/screens/savings_plan_screen.dart` | `features/savings/savings_plan_screen_test.dart` | ✅ |
| M20 Clear the review queue | `features/detection/screens/pending_review_screen.dart`, `shared/widgets/mascot_moment.dart` | `pending_review_screen_test.dart` | ✅ |
| M21 Hero value ticker | `shared/motion/count_up_text.dart`, `shared/widgets/hero_metric_card.dart` | `motion_test.dart` (CountUpText), `components_test.dart` | ✅ |
| M22 Secondary figure crossfade | `count_up_text.dart` (`CrossfadeDigits`) | `components_test.dart` (CrossfadeDigits) | ✅ |
| M23 Progress bar | `shared/widgets/progress_card.dart` | `components_test.dart` (progress), `features/plan/plan_look_test.dart` | ✅ |
| M24 Chart draw | `features/portfolios/` charts | `features/portfolios/invest_look_test.dart` | ✅ |
| M25 Plan segment | `shared/widgets/sliding_segments.dart`, `features/plan/screens/plan_screen.dart` | `plan_look_test.dart` | ✅ |
| M26 Change month | `features/budgets/screens/budgets_screen.dart` | `plan_look_test.dart` | ✅ |
| M27 Filter chip | `shared/widgets/app_filter_chip.dart` | `components_test.dart` (AppFilterChip) | ✅ |
| M28 Switch | `app_controls.dart` (`AppSwitch`, all 3 switches), `switchTheme` | `app_controls_test.dart` | ✅ |
| M29 Expand / collapse | `shared/widgets/expand_section.dart` | `components_test.dart` (ExpandSection), `plan_look_test.dart` | ✅ |
| M30 Send to Penny | `features/chatbot/screens/chatbot_screen.dart` | `features/chatbot/screens/penny_look_test.dart` | ✅ |
| M31 Penny replies | `chatbot_screen.dart` (`_ThinkingSlot`), `mascot_moment.dart` (bob) | `penny_look_test.dart` | ✅ |
| M32 Suggested question | `chatbot_screen.dart` | `penny_look_test.dart` | ✅ |
| M33 Wrong PIN | `features/auth/screens/lock_screen.dart` | `features/auth/screens/lock_screen_test.dart` (Lock look) | ✅ |
| M34 Unlock success | `lock_screen.dart`, `app_router.dart` (shell page) | `lock_screen_test.dart`, `step8_widgets_test.dart` | ✅ |
| M35 Log in success | `features/auth/screens/login_screen.dart`, `app_router.dart` | `step8_widgets_test.dart` | ✅ |
| M36 Onboarding next / skip | `features/onboarding/screens/onboarding_screen.dart` | `features/onboarding/onboarding_screen_test.dart` | ✅ |
| M37 Copy / share / export | `shared/widgets/tick_icon_button.dart` | `step8_widgets_test.dart` (TickIconButton) | ✅ |
| M38 Snackbar | `app_theme.dart` (`snackBarTheme`: floating ink pill) | goldens `review_*` | ◐ |
| M39 Goal reached / target met | `mascot_moment.dart`, `shared/widgets/completed_goal_card.dart`, Home savings card | `shared/widgets/mascot_moment_test.dart`, `plan_look_test.dart` | ✅ |
| M40 Over budget enters | `progress_card.dart`, `budgets_screen.dart` | `plan_look_test.dart`, `components_test.dart` | ✅ |
| M41 Update banner | `shared/widgets/app_banner.dart`, used by Home's `_UpdateBanner` | `components_test.dart` (AppBanner) | ✅ |
| M42 Scroll a long list | `tab_app_bar.dart`, `shared/widgets/shrinking_fab.dart` | `components_test.dart` (TabAppBar, ShrinkingFab) | ✅ |

**The four ◐ rows.** Their look is to spec: sheet radius and handle, danger field
outline, dialog radius 24 with a danger text button, a floating ink snackbar pill. Their
motion is Flutter's own:
- **M7:** sheets slide up on Flutter's curve, inside the 300 ms limit, but without
  `springSettle`.
- **M10:** the error text fades in rather than growing in.
- **M17:** the dialog fades without the 0.96 → 1 scale.
- **M38:** the snackbar slides and fades on Flutter's timings.

Getting the exact spec motion means a custom route or animation style at about 60 call
sites (21 sheets, 13 dialogs, 28 snackbars), and none of them is a visible defect. They
are logged in the blueprint's mutation log as accepted. They're a candidate for a
follow-up if the on-device pass says they feel off.

### Durations moved onto tokens
Every literal animation duration added in this epic now reads an `AppMotion` token.
The new tokens are `pressIn`, `fadeThroughIn`, `rowExit`, `highlightFade`,
`dangerFlash`, `bobPeriod`, `pennyPatience`, `tickHold`, `shimmerPeriod` and `retryMin`.
The Savings policy screen's scroll-to-top (300 ms, `Curves.easeOut`, from before the
epic) now uses `pageTransition` and `AppMotion.easeOut`. The ticker search debounce
(350 ms) is input timing, not motion, so it stays literal.

## 2. Token audit

```
grep -rn "Color(0x\|Colors\.\(red\|green\|grey\|white\|black\|orange\|amber\|blue\)" lib
```
This now finds only `lib/core/theme/` and `models/comparison_entry.dart`. A wider sweep
for any `Colors.<name>` outside the theme finds only `Colors.transparent`. There were 14
named-colour uses outside the theme when the epic started.

The last two were in the import screen's OCR confidence badge (`Colors.green` and
`Colors.red` fallbacks). That badge also drew "LOW CONFIDENCE" in danger red, which
broke invariant 7. It now uses the `StatusBadge` pattern:
- HIGH is primaryContainer.
- MEDIUM and LOW are on `sunk`, in ink and muted.

The AA contrast test (`test/core/theme/contrast_test.dart`) checks every text, UI and
chart pair in both themes. It is on the epic's acceptance list (spec §6).

## 3. OTA update banner (M41)

`lib/features/updates/` holds only data, models and providers, so it stays untouched.
The banner widget lives in `features/dashboard/screens/dashboard_screen.dart`
(`_UpdateBanner`) and has rendered through `AppBanner` since Step 5. Nothing to move.

## 4. Goldens

Every screen in spec §4.2 has light and dark goldens: Home, Transactions, Plan
(Budgets, Goals, Savings), Invest, Net worth, Penny, Review, Add transaction, Settings,
Log in and Onboarding. Lock and Accounts are covered too, so that's 15 screens and 30
files. This step regenerated `tab_roots/home_*` and `tab_roots/invest_*` for the copy
fixes below.

## 5. Critique (tab roots)

The full write-up is `.impeccable/critique/2026-10-11T17-30-00Z__visual-rework-close-out.md`,
next to the Session 1 baseline. It was scored in a single context against the same ten
heuristics, on the goldens.

| # | Heuristic | Baseline | Now | What moved it |
|---|---|---|---|---|
| 1 | Visibility of system status | 3 | 4 | Home's savings percent now says "of target"; skeletons and inline retry |
| 2 | Match system / real world | 3 | 4 | Invest says "Gain if sold today" and "Year's dividends", not "Unrealized P&L" and "YTD" |
| 3 | User control and freedom | 3 | 4 | Undo grows rows back, re-tap scrolls to top, every sheet cancels |
| 4 | Consistency and standards | 2 | 4 | One token system; chart colours from the ramp; one Penny in her header; no up-arrow fallback |
| 5 | Error prevention | 3 | 3 | Unchanged |
| 6 | Recognition rather than recall | 3 | 3 | Transactions still has three icon-only actions when reviews are waiting (tooltipped) |
| 7 | Flexibility and efficiency | 3 | 3 | Unchanged |
| 8 | Aesthetic and minimalist | 2 | 4 | Light hero, grouped cards, depth, real type scale, Penny as a cutout |
| 9 | Error recovery | 3 | 4 | InlineError with a retry ring, the PIN flash, Undo |
| 10 | Help and documentation | 2 | 2 | Still nothing in context for Invest beyond plainer labels |
| | **Total** | **27** | **35** | |

35 meets the target exactly. Points 6 and 10 are the honest headroom, and both are UX
work rather than visual work.

## 6. On-device pass (Tiaan)

On a release build signed in to the real account, tick each row of
`docs/ux-rework/03-capability-inventory.md` once with reduced motion **off**, then spot-check
with it **on** (Settings › Accessibility › Remove animations) and in **dark mode**. Any
capability that's missing blocks the release.

- [ ] A1 A2 A3 A4 A5 A6 A7 A8
- [ ] B1 B2 B3 B4
- [ ] C1 C2 C3 C4 C5 C6 C7 C8 C9 C10 C11 C12
- [ ] D1 D2 D2a D3 D4 D5 D6 D7 D8 D9 D10 D11
- [ ] E1 E2 E3
- [ ] F1 F2 F3 F4 F5 F6
- [ ] G1 G2 G2a G3 G4 G5 G6
- [ ] H1
- [ ] I1 I3 I4 I5 I6 I7 I8 I8a I9 I10 I11 I12
- [ ] J1 J2 J3 J4 J5 J6 J7 J8
- [ ] Reduced motion on: tab switch cuts, no bob, no stagger, the PIN flash without the shake
- [ ] Dark mode: every tab root and one sheet
- [ ] On device, the four ◐ rows above don't feel off

## 7. DESIGN.md

Checked against the build. Every palette hex matches `app_tokens.dart`. Four drifts were
fixed in the doc:
- the revision header said "pending approval";
- Login/Register described a placeholder icon and outlined fields;
- Invest used the old stat labels;
- Motion didn't say which four rows ride Flutter's built-in motion.
