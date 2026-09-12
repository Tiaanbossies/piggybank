import 'package:flutter/material.dart';

/// Placeholder for the Penny onboarding tour (Step 1 of
/// `plans/piggybank-penny-onboarding-tour.md`) — exists only so the
/// `/onboarding` route and `computeRedirect`'s gate compile and are
/// independently testable before Step 3 replaces this with the real
/// multi-slide tour.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Onboarding placeholder')));
  }
}
