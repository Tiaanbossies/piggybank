# 003 — Animate ProgressCard's bar value instead of jumping

- **Status**: TODO
- **Commit**: 8a264ab
- **Severity**: MEDIUM
- **Category**: Purpose & frequency (state indication) / Interruptibility
- **Estimated scope**: 1 file

## Problem

`lib/shared/widgets/progress_card.dart` (used by Budgets, Goals, and the Dashboard progress block)
renders its bar with a raw `value:`, so any change to `pct` (e.g. after adding a transaction that
moves a budget from 40% to 55% spent) jumps instantly on the next rebuild instead of visibly
filling.

Current (lines 1-74, the whole file):

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'icon_chip.dart';
import 'percent_pill.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    required this.title,
    required this.pct,
    required this.footnote,
    this.overBudget = false,
    this.indented = false,
    this.icon,
    super.key,
  });

  final String title;
  final double pct;
  final String footnote;
  final bool overBudget;
  final bool indented;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final barColor = overBudget ? semantic?.danger : Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.only(left: indented ? 24 : 0, bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[IconChip(icon: icon!, danger: overBudget), const SizedBox(width: 12)],
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                PercentPill(pct: (pct * 100).round(), danger: overBudget),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 8,
                color: barColor,
                backgroundColor: semantic?.accentChipBg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              footnote,
              style: TextStyle(color: overBudget ? semantic?.danger : semantic?.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
```

`test/features/budgets/widgets/progress_card_color_test.dart` calls `tester.pumpWidget(...)` and
immediately reads `LinearProgressIndicator.value` with **no** extra `pump()`/`pumpAndSettle()` call
afterward — e.g. `expect(indicator.value, 1.0)` right after the first pump. This means the fix must
render at the target `pct` **on first mount with no animation**, and only animate when `pct`
*changes* on an already-mounted card (a real CSS-transition-style retarget, not an entrance
animation). Getting this backwards will break the existing test suite.

## Target

Convert to a `StatefulWidget` that tracks the previously-rendered `pct` and animates only between
consecutive values, using `AppMotion.valueTransition` (400ms).

```dart
// target
import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import 'icon_chip.dart';
import 'percent_pill.dart';

class ProgressCard extends StatefulWidget {
  const ProgressCard({
    required this.title,
    required this.pct,
    required this.footnote,
    this.overBudget = false,
    this.indented = false,
    this.icon,
    super.key,
  });

  final String title;
  final double pct;
  final String footnote;
  final bool overBudget;
  final bool indented;
  final IconData? icon;

  @override
  State<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<ProgressCard> {
  late double _displayedPct = widget.pct;

  @override
  void didUpdateWidget(ProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pct != widget.pct) _displayedPct = oldWidget.pct;
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final barColor = widget.overBudget ? semantic?.danger : Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.only(left: widget.indented ? 24 : 0, bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[
                  IconChip(icon: widget.icon!, danger: widget.overBudget),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium)),
                PercentPill(pct: (widget.pct * 100).round(), danger: widget.overBudget),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: _displayedPct, end: widget.pct),
                duration: AppMotion.valueTransition,
                curve: Curves.easeOut,
                onEnd: () => _displayedPct = widget.pct,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 8,
                  color: barColor,
                  backgroundColor: semantic?.accentChipBg,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.footnote,
              style: TextStyle(color: widget.overBudget ? semantic?.danger : semantic?.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
```

On first mount, `_displayedPct` initializes to `widget.pct`, so the `TweenAnimationBuilder`'s
`begin == end` and it renders the target value immediately with no animation — satisfying the
existing test's no-extra-pump assumption. Only a *later* `didUpdateWidget` where `pct` actually
changed sets `_displayedPct` back to the *old* value, giving the tween something to animate from.

`Curves.easeOut` (the built-in curve, not `AppMotion.easeOut`) is used here deliberately — this is
a constant-fill value transition, closer to AUDIT.md's "moving/morphing" case than a discrete
enter/exit, and the milder built-in curve reads better for a fill. If the feel-check below shows it
looking too linear, swap to `AppMotion.easeOut` and re-check.

## Repo conventions to follow

- Import `AppMotion` from `lib/core/theme/app_motion.dart` (created by plan 001). If plan 001 has
  not landed, STOP and land it first — this plan depends on `AppMotion.valueTransition`.
- Keep every existing field/constructor signature identical (`title`, `pct`, `footnote`,
  `overBudget`, `indented`, `icon`, `key`) — only the class becomes `StatefulWidget`; callers
  (`dashboard_screen.dart`, `budgets_screen.dart`, `goals_screen.dart`) are unaffected and need no
  changes.

## Steps

1. Confirm `lib/core/theme/app_motion.dart` exists (plan 001). If missing, stop.
2. Replace the full contents of `lib/shared/widgets/progress_card.dart` with the "Target" code
   above verbatim.

## Boundaries

- Do NOT change `PercentPill`, `IconChip`, or any caller of `ProgressCard`.
- Do NOT animate `PercentPill`'s numeric label — only the bar fill. (The audit's original finding
  was specifically about the bar; the pill jumping in sync with the bar's *final* value is fine and
  matches how the footnote text also updates instantly.)
- Do NOT give `TweenAnimationBuilder` a `key` that changes with `pct` — that would force a fresh
  animation from zero on every value, which is exactly the "teleporting" problem being fixed.
- If a step doesn't match the code you find (drift since commit `8a264ab`), STOP and report instead
  of improvising.

## Verification

- **Mechanical**: `flutter analyze` (0 issues), then
  `flutter test test/features/budgets/widgets/progress_card_color_test.dart` — all six existing
  tests must pass **unchanged**, including the ones that read `LinearProgressIndicator.value`
  immediately after `pumpWidget` with no extra pump (this is the test that catches a
  first-mount-animates-from-zero regression).
- **Feel check**: run the app, open Budgets, add a transaction against a category that has an
  existing `ProgressCard` visible, and confirm:
  - The bar visibly fills from its old value to the new one over ~400ms rather than snapping.
  - Opening the Budgets/Goals screen fresh (first paint) shows bars already at their correct value
    with no fill-in-from-zero animation.
  - In DevTools (Animations panel), set playback to 10% and confirm the fill eases out (fast start,
    slow settle), not linear or `ease-in`.
- **Done when**: `flutter analyze` is clean, `progress_card_color_test.dart` passes unchanged, and
  the feel check above holds.
