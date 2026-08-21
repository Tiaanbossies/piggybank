import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/accounts/models/account.dart';
import 'package:piggybank/features/accounts/screens/account_edit_screen.dart';

void main() {
  group('AccountEditScreen', () {
    late Account testAccount;

    setUp(() {
      testAccount = Account(
        id: 'acc-123',
        name: 'Test Account',
        accountType: 'bank',
        currency: 'ZAR',
        balance: Decimal.fromInt(5000),
        isActive: true,
        institutionName: 'Test Bank',
      );
    });

    testWidgets('displays account name in title field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountEditScreen(account: testAccount),
        ),
      );

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Test Account'), findsWidgets);
    });

    testWidgets('displays account type as read-only text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountEditScreen(account: testAccount),
        ),
      );

      expect(find.text('Account type: bank'), findsOneWidget);
    });

    testWidgets('displays currency as read-only text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountEditScreen(account: testAccount),
        ),
      );

      expect(find.text('Currency: ZAR'), findsOneWidget);
    });

    testWidgets('displays institution name in field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountEditScreen(account: testAccount),
        ),
      );

      expect(find.text('Test Bank'), findsWidgets);
    });

    testWidgets('shows deactivate button for active accounts', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountEditScreen(account: testAccount),
        ),
      );

      expect(find.text('Deactivate account'), findsOneWidget);
    });

    testWidgets('shows inactive message for inactive accounts', (WidgetTester tester) async {
      final inactiveAccount = Account(
        id: testAccount.id,
        name: testAccount.name,
        accountType: testAccount.accountType,
        currency: testAccount.currency,
        balance: testAccount.balance,
        isActive: false,
        institutionName: testAccount.institutionName,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AccountEditScreen(account: inactiveAccount),
        ),
      );

      expect(find.text('This account is inactive.'), findsOneWidget);
      expect(find.text('Deactivate account'), findsNothing);
    });

    testWidgets('AppBar displays Edit Account title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountEditScreen(account: testAccount),
        ),
      );

      expect(find.text('Edit Account'), findsOneWidget);
    });

    testWidgets('has Save changes button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountEditScreen(account: testAccount),
        ),
      );

      expect(find.text('Save changes'), findsOneWidget);
    });
  });
}
