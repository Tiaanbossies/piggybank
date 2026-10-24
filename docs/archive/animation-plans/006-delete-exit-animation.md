# 006 — Delete-row exit animation (RETIRED on closer inspection)

- **Status**: RETIRED — not pursued (see below)
- **Commit**: 8a264ab
- **Severity**: N/A (downgraded from the original LOW estimate)
- **Category**: Missed opportunities (preventing a jarring change)
- **Estimated scope**: N/A — no implementation

## Why this plan is retired instead of written

The originating `find-animation-opportunities` report flagged "a row vanishes instantly when the
list refetches after a delete" as a candidate, citing `confirmDestroy` (`confirm_dialog.dart`)
followed by a list rebuild in Transactions/Goals/Budgets. On closer inspection of the actual delete
call sites while writing this plan (e.g.
`lib/features/goals/screens/goals_screen.dart:158-174`, `_GoalSheet._delete()`), the real flow is:

```dart
// current — goals_screen.dart:158-174
Future<void> _delete() async {
  final existing = widget.existing;
  if (existing == null) return;
  setState(() {
    _deleting = true;
    _error = null;
  });
  try {
    await ref.read(goalsApiProvider).delete(existing.id);
    ref.invalidate(goalsProvider);
    if (mounted) Navigator.of(context).pop();
  } on ApiError catch (e) {
    setState(() => _error = e.message);
  } finally {
    if (mounted) setState(() => _deleting = false);
  }
}
```

Delete is triggered from inside a **modal bottom sheet** (`_GoalSheet`, opened via
`showEditGoalSheet`), not from a swipe/action directly on the visible list row. The sequence is:
provider invalidated → sheet pops closed (Flutter's own animated bottom-sheet dismissal, already
motion-correct) → by the time the sheet has slid away and the underlying list is visible again, it
has already re-rendered with the row gone. The row's disappearance is never visible mid-transition
— it's covered by the sheet's own exit animation the whole time. The "teleporting" the original
report was concerned about mostly doesn't exist in practice for this delete path; and the one part
that *is* real (the list flipping to its empty state when the last item is deleted) is already
fixed by plan 001 (`001-async-state-crossfade.md`), which crossfades the `data`-empty ↔ `data`-list
transition on the Goals and Budgets screens.

Budgets' delete flow (`showEditBudgetSheet` → `_BudgetSheet`) follows the same modal-sheet pattern,
so the same reasoning applies there without needing to re-verify each call site individually.

Per this skill's own standard — "the motion here is already right" is a valid audit result — this
finding does not clear the bar for a standalone plan once the actual architecture is accounted for.
Implementing a genuine optimistic-remove-with-exit-animation would require restructuring the delete
flow around local list state ahead of the provider refetch, which is a real architectural change for
a rare action whose current behavior is already adequately smoothed by plan 001. Not worth the
risk/effort tradeoff.

## If revisited later

Should a genuinely swipe-to-delete row action ever get added directly on a list (bypassing the
modal-sheet pattern), re-open this as a new finding at that point — a `Dismissible` with a
fade+height-collapse exit (`AnimatedSize` + `AnimatedOpacity`, ~200ms, `Curves.easeIn` for the exit
per AUDIT.md's entering/exiting rule) would be the correct recipe then, since the row itself would
be visibly present when removed.
