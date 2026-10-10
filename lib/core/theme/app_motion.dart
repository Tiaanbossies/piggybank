import 'package:flutter/widgets.dart';

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

  /// Route push/pop transitions and bottom-nav tab switches.
  static const pageTransition = Duration(milliseconds: 250);

  /// Smooth value transitions (progress bars, numeric fills).
  static const valueTransition = Duration(milliseconds: 400);

  // Visual rework spec §1.7: B's "springy" personality inside the epic budget
  // (feedback < 100 ms, transitions ≤ 300 ms).

  /// Press scale 1 → 0.97 → 1; starts on pointer-down, reverses on release.
  static final springPress = SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.9);

  /// Swipe release, sheet settle, a selection pill sliding.
  static final springSettle = SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 0.85);

  /// Mascot moments only (rare by rule). Clamp its overshoot to
  /// [popOvershootCap].
  static final springPop = SpringDescription.withDampingRatio(mass: 1, stiffness: 300, ratio: 0.6);

  /// The most a [springPop] may overshoot its target (6 %).
  static const popOvershootCap = 0.06;

  /// First-load list stagger: per item, for the first [staggerMax] items.
  static const stagger = Duration(milliseconds: 30);
  static const staggerMax = 6;

  /// Every exit runs at this fraction of its entry duration.
  static const exitFactor = 0.65;

  static Duration exit(Duration entry) => entry * exitFactor;
}

/// Checks the OS-level reduced-motion request. Only the lock-screen PIN
/// shake honoured this before now — other implicit animations added since
/// (crossfades, entrance animations) skipped the check entirely.
extension ReducedMotion on BuildContext {
  bool get reducedMotion => MediaQuery.of(this).disableAnimations;
}
