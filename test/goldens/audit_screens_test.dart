// Golden screenshots beyond the tab roots, light and dark, for the visual
// audit (docs/visual-rework/03-visual-audit.md): Plan's other segments, the
// add-transaction sheet, pushed screens and the screens before the shell.
// Regenerate with: flutter test --update-goldens test/goldens/
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/router/placeholder_screens.dart';
import 'package:piggybank/features/accounts/screens/accounts_screen.dart';
import 'package:piggybank/features/auth/screens/lock_screen.dart';
import 'package:piggybank/features/auth/screens/login_screen.dart';
import 'package:piggybank/features/networth/screens/net_worth_screen.dart';
import 'package:piggybank/features/onboarding/screens/onboarding_screen.dart';

import 'screenshot_harness.dart';

void main() {
  setUpAll(loadRealFonts);

  /// Shell screens reached by a tap from a tab root.
  final viaTap = <String, (String, String)>{
    'plan_goals': ('/plan', 'Goals'),
    'plan_savings': ('/plan', 'Savings'),
    'add_transaction_sheet': ('/transactions', 'Add transaction'),
  };

  /// Screens pumped on their own.
  final standalone = <String, Widget>{
    'net_worth': const NetWorthScreen(),
    'accounts': const AccountsScreen(),
    'settings': const SettingsScreen(),
    'login': const LoginScreen(),
    'lock': const LockScreen(),
    'onboarding': const OnboardingScreen(),
  };

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final MapEntry(key: name, value: (location, label)) in viaTap.entries) {
      testWidgets('$name (${mode.name})', (tester) async {
        await pumpShell(tester, location, mode: mode);
        await tester.tap(find.text(label).first);
        await settle(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('audit/${name}_${mode.name}.png'));
        endShot();
      });
    }
    for (final MapEntry(key: name, value: screen) in standalone.entries) {
      testWidgets('$name (${mode.name})', (tester) async {
        await pumpScreen(tester, screen, mode: mode);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('audit/${name}_${mode.name}.png'));
        endShot();
      });
    }
  }
}
