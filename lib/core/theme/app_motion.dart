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
