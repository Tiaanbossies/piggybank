import 'package:flutter/widgets.dart';

/// A single slide's content for the Penny onboarding tour (Step 3 assembles
/// these into the real `OnboardingScreen`). Deliberately minimal — icon +
/// title + body — so it maps cleanly onto `PennyAvatar` + `SpeechBubble`.
class TourPage {
  const TourPage({required this.title, required this.body, this.icon});

  /// The bottom-nav tab this slide mirrors, or null for the welcome/closing
  /// slides which frame the tour rather than a specific tab.
  final IconData? icon;
  final String title;
  final String body;
}
