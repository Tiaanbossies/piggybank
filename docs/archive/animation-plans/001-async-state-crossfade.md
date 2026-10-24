# 001 — Crossfade loading/data/empty states instead of swapping instantly

- **Status**: TODO
- **Commit**: 8a264ab
- **Severity**: HIGH
- **Category**: Missed opportunities / Purpose & frequency (preventing a jarring change)
- **Estimated scope**: 3 files, ~6 `.when()` call sites, plus 1 new shared tokens file

## Problem

Every `AsyncValue.when(loading:, error:, data:)` branch in the app swaps its child instantly — no
crossfade between the loading spinner and the real content, and (where a screen also branches on
`isEmpty`) no crossfade between the empty-state message and the populated list either. This is most
visible on pull-to-refresh, where a screen's content can flash/replace abruptly.

This plan scopes the fix to the six call sites the audit actually cited with evidence — it does
**not** extend to the other ~33 `.when()` call sites found elsewhere in the app (Accounts,
Transactions, Portfolios, RA, TFSA, Liabilities, Settings, Imports, Insights, Expenses). Those were
not part of the audited finding; treat them as a separate, deliberately-scoped follow-up if wanted
later.

**Site 1 — `lib/features/dashboard/screens/dashboard_screen.dart:86-95`** (`_NetWorthHero`):

```dart
// current
return netWorthAsync.when(
  loading: () => const SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
  error: (err, _) => Text(err is ApiError ? err.message : 'Failed to load net worth'),
  data: (netWorth) => HeroMetricCard(
    label: 'Net worth',
    value: formatZAR(netWorth.netWorth),
    deltaText: _NetWorthTrend.of(ref),
  ),
);
```

**Site 2 — `lib/features/dashboard/screens/dashboard_screen.dart:134-172`** (`_CashflowStatStrip`):

```dart
// current
return cashflowAsync.when(
  loading: () => const SizedBox.shrink(),
  error: (_, _) => const SizedBox.shrink(),
  data: (cashflow) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ /* ... unchanged ... */ ],
      ),
    ),
  ),
);
```

**Site 3 — `lib/features/dashboard/screens/dashboard_screen.dart:184-199`** (`_ProgressBlock`):

```dart
// current
return goalsAsync.when(
  loading: () => const SizedBox.shrink(),
  error: (_, _) => const SizedBox.shrink(),
  data: (goals) {
    if (goals.isNotEmpty) {
      final goal = goals.first;
      return ProgressCard(
        title: goal.name,
        pct: goal.progressPct / 100,
        footnote: '${formatZAR(goal.currentAmount)} saved / ${formatZAR(goal.targetAmount)} goal',
      );
    }
    return const _BudgetProgressFallback();
  },
);
```

**Site 4 — `lib/features/dashboard/screens/dashboard_screen.dart:288-319`** (`_RecentTransactionsPreview`, inside the `Column`'s children):

```dart
// current
recentAsync.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (err, _) => Text(err is ApiError ? err.message : 'Failed to load transactions'),
  data: (page) {
    if (page.items.isEmpty) return const Text('No transactions yet.');
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return GroupCard(
      children: [ /* ... unchanged ... */ ],
    );
  },
),
```

**Site 5 — `lib/features/goals/screens/goals_screen.dart:31-47`** (`GoalsBody`):

```dart
// current
child: goalsAsync.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load goals')),
  data: (goals) {
    if (goals.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [Center(child: Padding(padding: EdgeInsets.only(top: 48), child: Text('No goals yet.')))],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final goal in goals) _GoalRow(goal: goal)],
    );
  },
),
```

**Site 6 — `lib/features/budgets/screens/budgets_screen.dart:61-106`** (inside `BudgetsBody`'s `RefreshIndicator`):

```dart
// current
child: progressAsync.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load budgets')),
  data: (budgets) {
    if (budgets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [ /* icon + "No budgets for this month." ... */ ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [ /* _TotalSpentSummary + _BudgetProgressRow list ... */ ],
    );
  },
),
```

## Target

A 200ms fade (`AppMotion.stateChange`, `Curves.easeOut`) between whichever branch is showing, keyed
by a short discriminator string so that:
- `loading` → `data` crossfades.
- `data` (empty) → `data` (populated) crossfades (and back).
- Updates *within* the same branch (net worth ticking up on refresh, a budget's spend changing) do
  **not** replay the fade — same key, so `AnimatedSwitcher` treats it as an in-place update, not a
  new child. This is deliberate: the audit explicitly rejected animating the financial figures
  themselves (see the "Rejected candidates" in the source report) — only the *branch switch* animates.

```dart
// target — Site 1
return AnimatedSwitcher(
  duration: AppMotion.stateChange,
  switchInCurve: Curves.easeOut,
  switchOutCurve: Curves.easeOut,
  child: netWorthAsync.when(
    loading: () => const SizedBox(
      key: ValueKey('loading'),
      height: 64,
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (err, _) => Text(
      key: const ValueKey('error'),
      err is ApiError ? err.message : 'Failed to load net worth',
    ),
    data: (netWorth) => HeroMetricCard(
      key: const ValueKey('data'),
      label: 'Net worth',
      value: formatZAR(netWorth.netWorth),
      deltaText: _NetWorthTrend.of(ref),
    ),
  ),
);
```

For the two sites with an empty/populated split inside `data` (Sites 5 and 6), the `data` branch's
returned widget needs its own key that differs between empty and populated so that swap crossfades
too:

```dart
// target — Site 5 (goals_screen.dart)
child: AnimatedSwitcher(
  duration: AppMotion.stateChange,
  switchInCurve: Curves.easeOut,
  switchOutCurve: Curves.easeOut,
  child: goalsAsync.when(
    loading: () => const Center(key: ValueKey('loading'), child: CircularProgressIndicator()),
    error: (err, _) => Center(
      key: const ValueKey('error'),
      child: Text(err is ApiError ? err.message : 'Failed to load goals'),
    ),
    data: (goals) {
      if (goals.isEmpty) {
        return ListView(
          key: const ValueKey('empty'),
          padding: const EdgeInsets.all(16),
          children: const [Center(child: Padding(padding: EdgeInsets.only(top: 48), child: Text('No goals yet.')))],
        );
      }
      return ListView(
        key: const ValueKey('list'),
        padding: const EdgeInsets.all(16),
        children: [for (final goal in goals) _GoalRow(goal: goal)],
      );
    },
  ),
),
```

Apply the identical `key: ValueKey('empty')` / `key: ValueKey('list')` split to Site 6
(`budgets_screen.dart`'s two `ListView`s).

## Repo conventions to follow

No shared motion-tokens file exists yet in this codebase (the only prior animation usage is a bare
`Duration(milliseconds: 200)` + `Curves.easeOut` inlined at
`lib/features/chatbot/screens/chatbot_screen.dart:58-59`, and the theme-mode crossfade in
`lib/core/theme/theme_mode_provider.dart`). This plan creates the first one, following the same
placement convention as other cross-cutting theme constants (`lib/core/theme/app_theme.dart`).

**Step 1 of this plan creates `lib/core/theme/app_motion.dart`:**

```dart
import 'package:flutter/animation.dart';

/// Shared motion tokens (durations + curves) so animated widgets across the
/// app pull from one vocabulary instead of hand-typing values per widget.
/// Values follow the design-engineering audit run 2026-09 (`animation-plans/`):
/// strong custom eases (Flutter's built-in `Curves.easeOut` etc. are weaker
/// than these), UI durations kept under 300ms except where noted.
abstract final class AppMotion {
  /// Strong ease-out — entering/exiting UI. cubic-bezier(0.23, 1, 0.32, 1).
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Strong ease-in-out — elements moving/morphing on screen.
  /// cubic-bezier(0.77, 0, 0.175, 1).
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Press/shake feedback — confirming the interface heard the user.
  static const feedback = Duration(milliseconds: 150);

  /// Branch/state swaps (loading→data, error text, crossfades).
  static const stateChange = Duration(milliseconds: 200);

  /// Smooth value transitions (progress bars, numeric fills).
  static const valueTransition = Duration(milliseconds: 400);
}
```

This plan's own crossfades use `Curves.easeOut` (Flutter's built-in curve is an acceptable, already
-used-in-repo choice for a plain fade per the chatbot exemplar at
`chatbot_screen.dart:58-59`) rather than `AppMotion.easeOut`, because `AnimatedSwitcher`'s
`switchInCurve`/`switchOutCurve` only take a `Curve`, and a bare opacity fade doesn't need the
stronger custom curve — reserve `AppMotion.easeOut` for transform-based motion (see plans 003, 004,
005). Do add the `AppMotion` class in full as specified above; later plans depend on it existing.

## Steps

1. Create `lib/core/theme/app_motion.dart` with the exact content under "Repo conventions to
   follow" above.
2. In `lib/features/dashboard/screens/dashboard_screen.dart`: wrap each of the four `.when()` call
   sites (lines 86, 134, 184, 288 — see "Problem" above for current code) in an `AnimatedSwitcher`
   as shown in "Target", adding `key: const ValueKey('loading'|'error'|'data')` to each branch's
   returned widget. `_CashflowStatStrip`'s three states already return distinct widget types
   (`SizedBox.shrink()`, `SizedBox.shrink()`, `Card`) — both `SizedBox.shrink()` returns still need
   their own distinct keys (`'loading'` and `'error'`) even though they render identically, so a
   loading→error transition (rare, but possible) doesn't silently skip the fade.
3. In `lib/features/goals/screens/goals_screen.dart`: wrap the `goalsAsync.when(...)` at line 31 in
   an `AnimatedSwitcher` as shown in "Target", with `'loading'`/`'error'`/`'empty'`/`'list'` keys on
   the four returned widgets.
4. In `lib/features/budgets/screens/budgets_screen.dart`: wrap the `progressAsync.when(...)` at
   line 61 the same way — `'loading'`/`'error'`/`'empty'`/`'list'` keys on the four returned
   widgets (the empty-state `ListView` at lines 66-92, the populated one at lines 94-104).
5. Add the import `import '../../../core/theme/app_motion.dart';` to `dashboard_screen.dart` only
   (goals/budgets screens don't need it for this plan since they use `Curves.easeOut` directly, not
   an `AppMotion` constant — see the note in "Repo conventions to follow").

## Boundaries

- Do NOT touch any `.when()` call site outside the six listed above (see "Problem" for the full
  list of 33 out-of-scope sites this audit did not cover).
- Do NOT add a key to `data:` branches that already crossfade correctly with an unchanging key
  across content updates (i.e. don't give `HeroMetricCard`'s key a value that changes when
  `netWorth` changes — it must stay `ValueKey('data')` regardless of the number shown).
- Do NOT animate the `Card` in `_CashflowStatStrip` (Site 2) internally — only the branch switch
  around it animates; its own content changes should not additionally re-trigger the switcher
  (same reasoning as the net-worth figure).
- Do NOT change any provider/data-fetching logic — this is presentation-only.
- If a step doesn't match the code you find (drift since commit `8a264ab`), STOP and report instead
  of improvising.

## Verification

- **Mechanical**: `flutter analyze` (0 issues), then
  `flutter test test/features/dashboard/dashboard_screen_test.dart test/features/budgets test/features/goals` —
  all existing tests must still pass unchanged (they all call `pumpAndSettle()`, which resolves the
  new 200ms `AnimatedSwitcher` transitions before assertions run).
- **Feel check**: run the app, open Dashboard on a slow/throttled connection (or add a temporary
  artificial delay while testing — then remove it), and confirm:
  - The net-worth card, cashflow strip, progress card, and recent-transactions list each fade in
    from their loading spinner rather than popping in.
  - Pull-to-refresh on Dashboard/Goals/Budgets does not show a jarring flash when fresh data
    replaces old data of the same kind (loading→data→loading→data should look like nothing
    happened if the values are identical).
  - Deleting the last goal/budget (so the screen flips to its empty state) crossfades to "No goals
    yet." / "No budgets for this month." rather than popping.
  - In DevTools' Flutter Inspector / Animations, confirm no transition exceeds ~200ms and none
    loops.
- **Done when**: all six sites are wrapped exactly as specified, `flutter analyze` is clean, and
  the cited test suites pass.
