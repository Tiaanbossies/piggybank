import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piggybank/core/auth/auth_controller.dart';
import 'package:piggybank/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders email/password fields and a submit button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Piggybank'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email address'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
  });

  testWidgets('offers "Log in with fingerprint" only when a session was kept (QA A5)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [biometricLoginAvailableProvider.overrideWithValue(true)],
      child: const MaterialApp(home: LoginScreen()),
    ));
    expect(find.text('Log in with fingerprint'), findsOneWidget);
  });

  testWidgets('no kept session, no fingerprint button', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
    expect(find.byKey(const Key('login-biometric')), findsNothing);
  });
}
