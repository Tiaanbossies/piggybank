import 'package:flutter/services.dart';

/// The app's haptic vocabulary (visual spec §1.8). Flutter's predefined
/// feedback constants honour the system haptics setting. Errors and
/// validation never buzz: they are visual and text only.
abstract final class AppHaptics {
  /// Selection change: tab, chip, segment, month, toggle.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// A swipe crossing its commit threshold, or a save that succeeded.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// A delete (row hidden, Undo shown), or a goal reached (once).
  static Future<void> medium() => HapticFeedback.mediumImpact();
}
