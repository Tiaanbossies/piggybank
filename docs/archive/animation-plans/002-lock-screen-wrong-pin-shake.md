# 002 — Shake the PIN boxes on a wrong PIN

- **Status**: TODO
- **Commit**: 8a264ab
- **Severity**: HIGH
- **Category**: Missed opportunities (feedback)
- **Estimated scope**: 1 file

## Problem

`lib/features/auth/screens/lock_screen.dart:174-245` (`_PinBoxes`) already turns the six PIN boxes'
border red and shows "Incorrect PIN" text below them on a failed attempt, but gives zero motion
signal — the only feedback is a static colour change. A wrong-PIN shake is a well-established,
purposeful pattern (this is a security-adjacent, if infrequent, friction point) that current code
does nothing for.

Current widget in full:

```dart
class _PinBoxes extends StatefulWidget {
  const _PinBoxes({required this.controller, required this.hasError});
  final TextEditingController controller;
  final bool hasError;

  @override
  State<_PinBoxes> createState() => _PinBoxesState();
}

class _PinBoxesState extends State<_PinBoxes> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final border = Theme.of(context).colorScheme.outline;
    final danger = semantic?.danger ?? Theme.of(context).colorScheme.error;
    final value = widget.controller.text;
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i != 0) const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.hasError ? danger : border, width: widget.hasError ? 1.5 : 1),
                  ),
                  child: Text(
                    i < value.length ? '•' : '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ],
          ),
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              onSubmitted: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
```

## Target

A single non-repeating horizontal shake, triggered exactly once per `hasError` false→true
transition (never on mount, never repeating, never re-triggered by an unrelated rebuild such as the
listener-driven `_onChanged` firing while typing the next attempt).

```dart
// target
class _PinBoxesState extends State<_PinBoxes> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _shakeController = AnimationController(vsync: this, duration: AppMotion.feedback);
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_PinBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError && !MediaQuery.of(context).disableAnimations) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _shakeController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final border = Theme.of(context).colorScheme.outline;
    final danger = semantic?.danger ?? Theme.of(context).colorScheme.error;
    final value = widget.controller.text;
    return AnimatedBuilder(
      animation: _shakeOffset,
      builder: (context, child) => Transform.translate(offset: Offset(_shakeOffset.value, 0), child: child),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i != 0) const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.hasError ? danger : border, width: widget.hasError ? 1.5 : 1),
                    ),
                    child: Text(
                      i < value.length ? '•' : '',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ],
            ),
            Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                onSubmitted: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`AppMotion.feedback` is `Duration(milliseconds: 150)` — matches the AUDIT.md press-feedback budget
(100-160ms) this shake is a variant of. The five-point `TweenSequence` and its weights are pulled
verbatim from the recipe cited in the audit (`[0, -8, 8, -6, 6, 0]`), decaying in amplitude so it
reads as a bounded jolt, not a wobble.

## Repo conventions to follow

- Import `AppMotion` from `lib/core/theme/app_motion.dart` — created by plan 001, Step 1. If plan
  001 has not landed yet, STOP and land it first (this plan depends on `AppMotion.feedback`
  existing); do not inline `Duration(milliseconds: 150)` as a substitute.
- `MediaQuery.of(context).disableAnimations` is Flutter's reduced-motion signal (OS "Reduce Motion"
  setting) — this codebase has no prior reduced-motion handling to imitate, so this plan establishes
  the convention: skip the *movement*, keep the *colour/text* feedback (matches AUDIT.md §6 —
  reduced motion means fewer/gentler animations, not zero feedback).

## Steps

1. Confirm `lib/core/theme/app_motion.dart` exists (from plan 001) and exposes `AppMotion.feedback`.
   If missing, stop.
2. In `lib/features/auth/screens/lock_screen.dart`, add
   `import '../../../core/theme/app_motion.dart';` to the import block.
3. Replace the `_PinBoxesState` class (lines 183-245) with the "Target" version above: add
   `with SingleTickerProviderStateMixin`, the `_shakeController`/`_shakeOffset` fields, their
   `initState` setup, the `didUpdateWidget` trigger, `dispose` cleanup, and wrap the existing
   `SizedBox`/`Stack` tree in `AnimatedBuilder` + `Transform.translate` exactly as shown. Do not
   alter anything inside the `Stack` itself.

## Boundaries

- Do NOT change `_LockScreenState` (the parent) — only `_PinBoxes`/`_PinBoxesState`.
- Do NOT make the shake repeat, loop, or re-trigger while `hasError` stays `true` across
  rebuilds (e.g. the `_onChanged` listener firing while the user types a new attempt with the old
  error still showing) — the guard is `widget.hasError && !oldWidget.hasError`, not `widget.hasError`
  alone.
- Do NOT add haptic feedback, sound, or any dependency — pure `Transform.translate`, no new
  packages.
- If a step doesn't match the code you find (drift since commit `8a264ab`), STOP and report instead
  of improvising.

## Verification

- **Mechanical**: `flutter analyze` (0 issues), then
  `flutter test test/features/auth/screens/lock_screen_test.dart` — all six existing tests must
  still pass, including `'a wrong PIN shows an error and stays locked'`, which calls
  `await tester.pumpAndSettle();` after tapping Unlock — this must resolve cleanly since the shake
  is a bounded, non-repeating 150ms animation (a repeating or unbounded controller would make
  `pumpAndSettle()` time out/throw — if you see that, the trigger guard is wrong).
- **Feel check**: run the app, lock it, enter a deliberately wrong PIN, and confirm:
  - The six PIN boxes visibly shake left-right once, settling back to their resting position, in
    sync with the border turning red and "Incorrect PIN" appearing.
  - Entering another wrong PIN immediately after re-triggers the shake (the guard must catch the
    *next* false→true transition too, not just the first ever).
  - Entering a correct PIN after a wrong one does not shake.
  - In DevTools (Animations panel), set playback to 10% and confirm the shake is a single bounded
    pass, never looping.
  - Toggle `prefers-reduced-motion`/OS "Reduce Motion" (Rendering panel in DevTools, or device
    accessibility settings) and confirm the boxes no longer shake but the red border + error text
    still appear.
- **Done when**: `flutter analyze` is clean, `lock_screen_test.dart` passes unchanged, and the feel
  check above holds.
