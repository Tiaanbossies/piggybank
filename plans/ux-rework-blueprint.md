# Blueprint: Piggybank UX rework

Session 3 of the UX rework epic, written 2026-10-09. It turns the approved spec
(`docs/ux-rework/04-spec.md`, all approval items A1–A6 answered **yes** by Tiaan on
2026-10-09) into one-PR steps that a fresh agent can run cold.

## Read this first (every step)

- **Spec:** `docs/ux-rework/04-spec.md` is the source of truth for *what*. This file is
  *how and in what order*. If they disagree, the spec wins; record the conflict in the
  mutation log at the bottom.
- **Regression contract:** `docs/ux-rework/03-capability-inventory.md`. Every step lists
  the rows it moves. A row may move, never vanish.
- **Principles:** `docs/ux-rework/01-principles.md` (IDs K, N, Y, T, H, P cited in the spec).
- **Repo:** `C:\Fynbos Creative Master\02_Clients\Piggybank`, GitHub
  `Tiaanbossies/piggybank`, default branch `master`. Flutter, flutter_riverpod 2.6,
  go_router 14. `gh` is authenticated. The repo has **no CI**, so a step's own
  `flutter analyze` + `flutter test` run is the gate.
- **Leave untracked:** `.impeccable/` and `assets/Gemini Mascot Images/`. Never `git add -A`.

### Branch model (approval item A6: one release at the end)

- Integration branch **`feat/ux-rework`**, cut from `master` in Step 0.
- Each step: branch `ux/<NN>-<slug>` from the latest `feat/ux-rework`, PR **into
  `feat/ux-rework`**, squash-merge after Tiaan's OK.
- Testers keep running `master` builds until Step 9 merges `feat/ux-rework` → `master`.
- Rollback for any step: `git revert -m 1 <merge sha>` on `feat/ux-rework`. Nothing
  reaches `master` until Step 9.

### Invariants (checked at the end of every step)

1. `flutter analyze` reports no issues; `flutter test` is fully green (641 tests at the
   start; the count only grows).
2. **Presentation only.** No edits under `lib/**/data/`, `lib/**/models/`, `lib/core/api/`,
   `lib/core/auth/`, `lib/features/detection/` native channel code, `lib/features/updates/`,
   `android/`, or release config. Existing providers keep their names and types; new
   *UI-only* providers are allowed.
3. `computeRedirect` and `test/core/router/app_router_test.dart`'s redirect cases are
   unchanged and green (row A8).
4. No new dependency. (`animations: ^3.0.0` is **already** in `pubspec.yaml` and used by
   `app_theme.dart`'s `_ReducedMotionAwarePageTransitionsBuilder`, so approval A1 needs
   no pubspec change.)
5. Every new animation checks `context.reducedMotion` (`lib/core/theme/app_motion.dart`)
   and uses `AppMotion` tokens, not literal durations.
6. Every scrollable under a FAB keeps ≥ 88 dp bottom padding, with a test that the last
   row is hittable.
7. Copy is South African English and factual (no guilt copy, no fake urgency). Red is
   only for over-budget and destructive states.

### Test helpers

`test/test_helpers/pump_app.dart` (`pumpApp(..., overrides:)`) and
`test/test_helpers/mocktail_setup.dart`. Pattern to copy:
`test/features/detection/screens/pending_review_screen_test.dart`.

---

## Dependency graph

```
0 ─▶ 1 ─┬─▶ 2 ─┐
        ├─▶ 3 ─┤
        ├─▶ 4 ─┼─▶ 6 ─▶ 7 ─┐
        └─▶ 5 ─┘           ├─▶ 9
              (2–5) ─▶ 8 ──┘
```

| Step | Title | Depends on | Parallel with | Model tier |
|---|---|---|---|---|
| 0 | Integration branch + docs | — | — | default |
| 1 | Shell and IA switch | 0 | — | **strongest** |
| 2 | Settings + Transactions chrome | 1 | 3, 4, 5 | default |
| 3 | Home rework + Net worth hub | 1 | 2, 4, 5 | **strongest** |
| 4 | Plan polish + Invest fixes | 1 | 2, 3, 5 | default |
| 5 | Penny header + data-aware chips | 1 | 2, 3, 4 | default |
| 6 | Motion: transitions and feedback | 2, 3, 4, 5 | 8 | **strongest** |
| 7 | Mascot moments | 6 | 8 | default |
| 8 | Undo instead of confirm | 2, 3, 4, 5 | 6, 7 | default |
| 9 | Close-out and release to master | 7, 8 | — | **strongest** |

Parallel steps 2–5 touch disjoint files (listed per step). If two parallel PRs collide
anyway, the second rebases on `feat/ux-rework` before merge.

---

## Step 0: integration branch + docs

**Context.** The spec is approved. This step only records that and creates the branch
every later step targets.

**Tasks.**
1. On `docs/ux-rework-spec` (PR #39): set the spec status line to "Approved by Tiaan
   2026-10-09 (A1–A6 yes)", note under A1 that `animations` is already a dependency,
   and add this blueprint. Mark #39 ready for review. Tiaan merges it.
2. After #39 merges: `git fetch && git switch -c feat/ux-rework origin/master && git push -u origin feat/ux-rework`.

**Verify.** `git ls-remote --heads origin feat/ux-rework` returns one line.
**Exit.** `feat/ux-rework` exists on GitHub at the merge commit of #39.

---

## Step 1: Shell and IA switch (strongest)

**Context.** Today the shell has 5 branches, Home `/`, Invest `/invest`, Budgets
`/budgets`, Assistant `/assistant` and Settings `/settings`, in
`lib/core/router/app_router.dart:45-53`, with the `NavigationBar` in
`lib/core/router/app_shell.dart:50-56`. The spec (§1.1) replaces them with **Home ·
Transactions · Plan · Invest · Penny**, moves Settings to a full-screen route opened by
the avatar, and introduces one tab-root header (§1.2).

**Files.**
- `lib/core/router/app_router.dart`: branches become `/`, `/transactions`
  (`TransactionsScreen`), `/plan` (`PlanScreen`), `/invest`, `/assistant`. Move
  `/settings` out of the shell as a top-level `GoRoute` with
  `parentNavigatorKey: rootNavigatorKey` (add a root key if there isn't one), and keep
  `/settings/data-export` as its child or sibling. **Do not touch `computeRedirect`.**
- `lib/core/router/app_shell.dart`: destinations Home (home), Transactions
  (receipt_long), Plan (pie_chart), Invest (trending_up), Penny (smart_toy). Keep B3
  (re-tap pops to root) and B4 (the current fade) as they are; Step 6 changes the fade.
- New `lib/shared/widgets/tab_app_bar.dart`: `TabAppBar({required title, actions (max 2), subtitle?, leadingAvatar = true})`.
  The avatar is an `IconButton`-sized (48 dp) `CircleAvatar` with tooltip "Settings"
  that calls `context.push('/settings')`. **No bell.**
- New `lib/features/plan/screens/plan_screen.dart`: a `ConsumerStatefulWidget` hosting
  `SegmentedButton` Budgets · Goals · Savings. It reads `GoRouterState.of(context).uri.queryParameters['s']`
  (`budgets|goals|savings`, default budgets) and keeps the last segment in a
  `StateProvider` for the session. It replaces `BudgetsHomeScreen`, absorbing its body:
  read `lib/features/budgets/screens/budgets_home_screen.dart` (84 lines) and move its
  context-aware FAB logic; the FAB for Savings is Add cost.
- `lib/features/savings/screens/savings_plan_screen.dart`: extract the `ListView` body
  into a public `SavingsPlanBody` (no `Scaffold`/`AppBar`) used by the Plan Savings
  segment. Keep `SavingsPlanScreen` as a thin wrapper only if something still pushes it
  (after this step nothing should; delete it if unused). The Add cost FAB moves to
  `PlanScreen`.
- Apply `TabAppBar` to the roots of Home (`dashboard_screen.dart:54-67`), Transactions,
  Plan, Invest (`invest_screen.dart` app bar) and Penny (`chatbot_screen.dart:135`, Penny
  avatar + subtitle as `subtitle`, inside the 16 dp gutter).
- Re-point navigation:
  - Home savings card (`dashboard_screen.dart:287`) → `context.go('/plan?s=savings')`
  - Home "See all" (`:655`) → `context.go('/transactions')`
  - Accounts app-bar Transactions icon → `context.go('/transactions')`
- `lib/core/router/placeholder_screens.dart` `SettingsScreen`: give it an `AppBar`
  (back arrow + "Settings"), remove the in-body title, and **remove the Savings plan
  row (I5)**. Leave the other rows for Step 2.
- Delete `budgets_home_screen.dart` once `PlanScreen` replaces it; move or rename its tests.

**Tests.**
- `test/core/router/app_shell_test.dart`: 5 new labels; re-tap pops to root.
- `test/core/router/app_router_test.dart`: `/transactions`, `/plan`, `/plan?s=savings`
  and `/settings` resolve. Redirect cases are untouched.
- New `test/features/plan/plan_screen_test.dart`: the query parameter selects the
  segment; the FAB label follows the segment; Savings shows `SavingsPlanBody`.
- New `test/shared/widgets/tab_app_bar_test.dart`: tapping the avatar pushes Settings;
  there's no bell icon; more than 2 actions asserts.
- Update `dashboard_screen_test.dart` / `savings_plan_screen_test.dart` for the new entry
  points.

**Inventory rows moved:** B1, C6, C10, C12 (removed), D3, E1–E3, F1–F4, H1 (header),
I1–I12 (Settings now pushed), I5 (removed as a row).

**Verify.**
```bash
flutter analyze
flutter test
```
Then on a device or emulator: every tab opens; the avatar opens Settings with a back
arrow; Home's savings card lands on Plan › Savings; "See all" switches to the
Transactions tab.

**Exit.** All invariants hold, and the bottom bar shows the 5 new tabs with no bell anywhere.

**Rollback.** Revert the merge on `feat/ux-rework`.

---

## Step 2: Settings + Transactions chrome

**Context.** Spec §2.2 and §2.6. Step 1 made Transactions a tab root and Settings a
pushed route. This step regroups Settings and gives Transactions its actions.

**Files (owned by this step only).** `lib/core/router/placeholder_screens.dart`,
`lib/features/transactions/screens/transactions_screen.dart`, and a new
`lib/shared/widgets/review_banner.dart` (extracted from `dashboard_screen.dart`
`_ReviewBanner` at line 205). **Coordinate with Step 3:** Step 2 creates the shared
widget and Step 3 switches Home to it. If Step 3 lands first, Step 2 does the switch
instead.

**Tasks.**
1. Settings groups: card (Profile I1); **Account**: Subscription I4, Security I8,
   Privacy & consent I3; **Preferences**: Appearance I7, Notifications I9; **Data
   sources**: "Bank notifications & email" (I10, renamed, approval A5); About I11;
   **Log out** I12 behind `confirm_dialog.dart` ("Log out?" / "Log out" / "Cancel").
   **Remove the Import history row (I6).**
2. Transactions `TabAppBar` actions:
   - **Review**: an `IconButton` with `Badge(label: count)`, shown only when
     `pendingEventsProvider` has items. Opens `PendingReviewScreen`.
   - **Insights**: an `IconButton` with tooltip "Insights" that opens `TrendsScreen`.
   - **Overflow ⋮** (`PopupMenuButton`): Expenses summary (D7), Import CSV / Scan receipt
     (D11), **Import history (I6)**.
3. Transactions body: the shared review banner at the top when pending > 0. Keep the
   FAB and its 88 dp clearance.

**Tests.** Settings: groups render in order, the renamed row, log out asks before
signing out (Cancel does nothing), no Savings plan or Import history row. Transactions:
the Review badge shows the count and hides at 0; Insights and every overflow item open
their screens.

**Rows:** D7, D8, D10, D11, I3, I4, I6, I7, I8, I9, I10, I11, I12.
**Verify / Exit / Rollback:** as Step 1.

---

## Step 3: Home rework + Net worth hub (strongest)

**Context.** Spec §2.1. `lib/features/dashboard/screens/dashboard_screen.dart` (719
lines). Its sections are private widgets: `_UpdateBanner` 124, `_ReviewBanner` 205,
`_SavingsCard` 257, `_NetWorthHero` 328, `_CashflowStatStrip` 394, `_ProgressBlock` 490,
`_TrendsEntryCard` 578, `_QuickLinksRow` 600, `_RecentTransactionsPreview` 640.

**Files (owned).** `dashboard_screen.dart`; new
`lib/features/dashboard/widgets/left_to_spend_hero.dart`; new
`lib/features/networth/screens/net_worth_screen.dart`; new UI-only
`lib/features/dashboard/providers/left_to_spend_provider.dart`.

**Tasks.**
1. **`leftToSpendProvider`** (UI-only, derived): from
   `currentMonthBudgetProgressProvider`, take top-level items (`parentBudgetId == null`)
   and sum `remaining`; from `cashflowProvider`, this month's expenses for the no-budget
   state; from `todaySpendProvider`, today's spend; compute days left in the month. It
   returns a sealed state: `under(amount)`, `over(amount)`, `noBudgets(spentThisMonth)`.
2. **`LeftToSpendHero`** replaces `_NetWorthHero` + `_CashflowStatStrip` in the hero slot,
   with the spec's states table (red only for `over`). Tap → `context.go('/plan?s=budgets')`.
   "Set a monthly budget ›" opens the existing add-budget sheet. Skeleton while loading,
   `InlineError(onRetry:)` on error.
3. **Net worth card**: compact value + the existing trend pill (reuse `_NetWorthTrend`);
   tap pushes `NetWorthScreen`.
4. **`NetWorthScreen`**: hero (the net worth gradient card moved here), then rows with
   totals, Accounts → `AccountsScreen`, Assets → `AssetsScreen`, Liabilities →
   `LiabilitiesScreen`, and "Loan calculators" → `CalculatorsScreen`. Use existing
   providers only; if a total isn't available without a new API call, show the row
   without a total.
5. **Needs attention** (rework `_ProgressBlock`): the most at-risk budget for the current
   month, else the first in-progress goal; never a completed goal; hidden if neither
   exists. Tap → that budget's edit sheet / `context.go('/plan?s=goals')`.
6. Delete `_TrendsEntryCard` and `_QuickLinksRow`. New order: update banner, review
   banner, hero, savings card, net worth card, needs attention, recent transactions, FAB.

**Tests.** The hero shows each state from mocked progress (under / over in red / no
budgets / error with Retry). The net worth card opens `NetWorthScreen`, and its four rows
open their screens. Needs attention skips completed goals. Home no longer contains
quick links or the Trends card. The last recent row is hittable above the FAB.

**Rows:** C4, C5, C7, C8, C9, D1, D2, D2a, D5, D6, D9.
**Verify / Exit / Rollback:** as Step 1.

---

## Step 4: Plan polish + Invest fixes

**Context.** Spec §2.3 and §2.4. Step 1 created `PlanScreen`.

**Files (owned).** `lib/features/plan/screens/plan_screen.dart`,
`lib/features/budgets/screens/budgets_screen.dart`,
`lib/features/goals/screens/goals_screen.dart`,
`lib/features/portfolios/screens/invest_screen.dart`,
`lib/features/budgets/providers/budgets_provider.dart` (only the month-reset behaviour
of `selectedBudgetMonthProvider`; its type and name stay).

**Tasks.**
1. The Budgets month chevrons move into `PlanScreen`'s app bar `bottom`, visible only on
   the Budgets segment. The selected month resets to the current month when Plan is
   entered in a new calendar month (UX plan item 4, if it isn't already done; check
   first).
2. Budgets: "See trends ›" text link after the list → `TrendsScreen`.
3. Goals: in-progress goals first, sorted by target date (no date last); completed goals
   in a collapsed "Completed (n)" `ExpansionTile`.
4. Invest: replace both error texts (`invest_screen.dart:57` and `:132`) with
   `InlineError(message:, onRetry: () => ref.invalidate(...))`; replace the full-screen
   spinner with a skeleton; Compare becomes a `TextButton.icon(label: 'Compare')` or
   gets a tooltip.

**Tests.** Month reset across a simulated month change; the "See trends" link; goal
order and the Completed group; Invest Retry re-calls the API; the skeleton shows while
loading.

**Rows:** E2, E3, G1, G6.
**Verify / Exit / Rollback:** as Step 1.

---

## Step 5: Penny header + data-aware chips

**Context.** Spec §2.5. `lib/features/chatbot/screens/chatbot_screen.dart` (467 lines);
Step 1 already gave it `TabAppBar`.

**Files (owned).** `chatbot_screen.dart`; new UI-only
`lib/features/chatbot/providers/suggested_questions_provider.dart`.

**Tasks.**
1. `suggestedQuestionsProvider`: up to 3 questions, in order:
   - an over-budget category from `currentMonthBudgetProgressProvider` → "Why is {category} over budget?"
   - a positive gap from `savingsOverviewProvider` → "Where should I cut to close my R {gap} gap?"
   - the largest expense category this week from existing transaction providers →
     "What did I spend on {category} this week?"

   It falls back to the current three generic chips. If any source errors, it skips
   that source and never fails the chip row.
2. The empty state uses the provider. Copy fix: "analyze" → "analyse".
3. Check the header gutter (16 dp) on a 360 dp-wide screen.

**Tests.** Each data case produces its chip; all sources failing gives the generic
chips; a chip tap sends that text.

**Rows:** H1.
**Verify / Exit / Rollback:** as Step 1.

---

## Step 6: Motion: transitions and feedback (strongest)

**Context.** Spec §3.1–§3.2 (approval M = expressive, A1 = `animations`). Existing:
`AppMotion` tokens; `app_theme.dart` already routes pushes through
`SharedAxisPageTransitionsBuilder` with a reduced-motion guard; `app_shell.dart` does a
1 → 0 → 1 fade (B4). Run this after Steps 2–5 so it animates the final layouts.

**Tasks.**
1. **Tab switch:** replace the shell fade with a fade-through (out 90 ms / in 160 ms,
   0.92 → 1 scale), driven by the existing `AnimationController`, total `pageTransition`.
   Instant under reduced motion.
2. **Container transform** (`OpenContainer` from `package:animations`) for list row →
   detail on: a Transactions row → edit sheet (if `OpenContainer` doesn't suit a modal
   sheet, keep the sheet and add the saved-row highlight from task 6 instead), a portfolio
   row → `PortfolioDetailScreen`, an account row → `AccountDetailScreen`, and the Net
   worth card → `NetWorthScreen`. Reduced motion → plain push.
3. **Plan segments:** `PageTransitionSwitcher` + `SharedAxisTransition(horizontal)`, with
   direction from segment order.
4. **Settings route:** `CustomTransitionPage` with `SharedAxisTransition(scaled)` on the
   `/settings` route.
5. **Value feedback:** the hero number counts to its new value (`TweenAnimationBuilder`,
   `valueTransition`, tabular figures); progress bars animate their fill (budgets, goals,
   savings).
6. **Interaction feedback:**
   - Review swipe backgrounds: ✓ Confirm green, Discard neutral grey; `HapticFeedback.lightImpact()` on commit.
   - Saved row highlight: tinted background fading out over 600 ms after a sheet save.
   - 0.97 press scale on cards (`feedback`).
7. Put the reusable pieces in `lib/shared/motion/` (for example `count_up_text.dart`,
   `press_scale.dart`, `saved_highlight.dart`), each checking `context.reducedMotion`.

**Tests.** For each animated widget: under `MediaQuery(disableAnimations: true)` it
reaches its final state in a single `pump()`. The count-up ends on the exact formatted
value. A tab switch still preserves the branch state (B2), and re-tap still pops (B3).

**Rows:** B4, J5 (extended).
**Verify / Exit / Rollback:** as Step 1, plus a manual check on a device that nothing
stutters (profile mode if anything feels slow).

---

## Step 7: Mascot moments

**Context.** Spec §3.3. Assets already exist: `assets/mascot_celebrating.jpg`,
`mascot_thinking.jpg`, `mascot_sleeping.jpg`, `mascot_welcoming.jpg`, `mascot.jpg`. They're
used today clipped to circles (`login_screen.dart:96`,
`shared/widgets/completed_goal_card.dart:27`). **No image generation.** New poses or
transparent PNGs need Tiaan's go-ahead.

**Tasks.**
1. `lib/shared/widgets/mascot_moment.dart`: a circle-clipped asset, scale 0.8 → 1 with
   a slight overshoot (300 ms), static under reduced motion.
2. `lib/shared/motion/once_per_day.dart`: a `SharedPreferences` key per moment kind +
   date, so each moment plays at most once a day. Local UI state only.
3. Moments:
   - Review queue cleared (`pending_review_screen.dart`): "All caught up", plus the
     investment line when real: "Piggybank suggested the category for {n} of {m} this
     week." Count only events confirmed this session, without a new API, if the data
     isn't available; otherwise omit the line.
   - A goal first seen at 100 % (the goal card).
   - Savings gap ≤ 0 for the month (the savings card): "Target met this month".
   - Penny waiting: `mascot_thinking` with a 2 px bob replaces the typing dots.
   - Spent today = 0: `mascot_sleeping` (static) + "Quiet day so far".
   - Empty Transactions / Goals / Savings: `mascot_welcoming` fade-in.
4. **Never** show a mascot on over-budget, missed-target or error states.

**Tests.** Each trigger shows its moment once; the second time the same day, it doesn't;
there's no mascot in the over-budget hero state; reduced motion is static.

**Rows:** none moved (additive).
**Verify / Exit / Rollback:** as Step 1.

---

## Step 8: Undo instead of confirm

**Context.** Spec §5 (approval A4). Pattern to copy: the review queue's deferred commit
with Undo in `pending_review_screen.dart` (about a 4 s window; a failed commit restores
the item).

**Tasks.**
1. `lib/shared/widgets/deferred_delete.dart`: hides the item locally, shows an Undo
   snackbar for 4 s, then calls the delete; on failure it restores the item and shows
   `InlineError` text in a snackbar. If the screen is disposed before the timer, it
   commits immediately (the user left: treat that as accepted). **Document that
   killing the app inside the window means nothing is deleted.**
2. Apply it to single-row deletes, replacing their confirm dialogs: transaction (sheet
   Delete), budget, goal, recurring cost, dividend (holding detail), TFSA/RA
   contribution.
3. **Keep the confirm dialogs** for: delete account, remove PIN, deactivate account,
   remove savings target, remove policy details, sell holding, log out.

**Tests.** Undo inside the window → no API call; let it expire → one API call; API
failure → the item comes back; a kept confirm still shows its dialog.

**Files:** the sheets and screens listed above. **Rebase hazard with Step 6**
(row widgets). Whichever lands second rebases.

**Rows:** D4, E2, E3, F3, G2a, G4, G5, J2, J4.
**Verify / Exit / Rollback:** as Step 1.

---

## Step 9: Close-out and release to master (strongest)

**Tasks.**
1. Onboarding copy (`lib/features/onboarding/screens/onboarding_screen.dart`): pages
   follow the new tabs (Penny intro, Home, Transactions, Plan, Invest + Penny,
   Security). Same 6 pages and flow (A7).
2. Update `DESIGN.md` with the spec's §8 changes (navigation, header, no bell, Home
   order and hero, motion and mascot moments, Plan and Net worth screens).
3. **On-device regression pass:** Tiaan signs in on his phone (Claude can't enter
   passwords). Tick every row of `03-capability-inventory.md` against the spec §9
   mapping, recording the ticks in a new `docs/ux-rework/06-regression-pass.md`. Any
   missing capability blocks the release.
4. Re-run the impeccable critique on all tabs. Target ≥ 32/40, saved next to the 21/40
   and 25/40 snapshots, with the re-measured tap-count table.
5. Open the PR `feat/ux-rework` → `master` with the regression pass and the score.
   Tiaan merges it, then cuts the release through the usual release process (version
   bump and OTA as in previous releases; this blueprint doesn't change release config).

**Exit.** The PR to master is merged, every inventory row is ticked, and the score is
recorded.

---

## Review notes

The adversarial review ran in the same context, not in a sub-agent (this session spawns
none unless asked). It checked:

- **Every inventory row is owned by a step:** A7 (9), A8 (invariant 3), B1 (1), B2/B3
  (1 tests, 6 tests), B4 (6), C* (1, 3), D* (1, 2, 3, 8), E* (1, 4, 8), F* (1, 8), G*
  (4, 8), H1 (1, 5), I* (1, 2), J* (6, 7, 8 + invariants). No orphans.
- **Dependency order:** Steps 2–5 need only Step 1's routes and `TabAppBar`; Step 6 needs
  the final layouts; Step 7 uses Step 6's motion helpers.
- **Anti-patterns avoided:**
  - No step depends on reading a previous step's chat.
  - No "and also refactor X".
  - Each step has its own tests and an exit criterion.
  - The parallel steps' file ownership is explicit, with the one shared widget
    (review banner) called out.
- **Risk:** Step 1 is the biggest change (router + 5 screens). It's kept whole because a
  half-switched shell isn't testable. If it grows past about 600 changed lines, split it
  as 1a (router, shell, `TabAppBar`, Settings route) and 1b (`PlanScreen` + the Savings
  body extraction), recorded in the mutation log.

## Mutation log

| Date | Change | Why |
|---|---|---|
| 2026-10-09 | Created | Spec approved (A1–A6 yes) |
| 2026-10-09 | Step 1: Plan's segment is a UI-only `planSegmentProvider` (Home sets it, then `go('/plan')`) instead of a `?s=` query parameter | The query parameter misbehaves on re-entry: once the user switches segment by hand, the old parameter no longer describes the screen |
| 2026-10-09 | Step 5: Penny's chips use two data sources (over-budget category, savings gap), not three. The largest-category-this-week chip is dropped | No existing provider gives this week's spending by category; adding one would mean a new query, which is more than a chip is worth. Generic questions fill the row |
| 2026-10-09 | Step 8: the delete timer lives with the Undo snackbar, not the screen, so leaving the screen inside the window still deletes after 4 s rather than immediately | Same outcome as "treat leaving as accepted" without a dispose hook in every sheet; matches the review queue's existing pattern. Killing the app inside the window still deletes nothing |
