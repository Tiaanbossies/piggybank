import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/settings/screens/subscription_screen.dart';
import 'package:piggybank/shared/widgets/paywall_dialog.dart';

void main() {
  Future<void> pumpTrigger(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPaywallPrompt(context, message: 'Limit reached'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('See Pro closes the dialog and opens the subscription screen', (tester) async {
    await pumpTrigger(tester);

    expect(find.text('Upgrade to PRO'), findsOneWidget);
    await tester.tap(find.text('See Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to PRO'), findsNothing);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
  });

  testWidgets('OK only closes the dialog', (tester) async {
    await pumpTrigger(tester);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to PRO'), findsNothing);
    expect(find.byType(SubscriptionScreen), findsNothing);
  });
}
