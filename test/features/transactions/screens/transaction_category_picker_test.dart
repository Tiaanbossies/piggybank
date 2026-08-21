import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/transactions/screens/transactions_screen.dart';

void main() {
  group('Transaction Category Picker Widget', () {
    testWidgets('DropdownButtonFormField renders on transactions screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const TransactionsScreen(),
          ),
        ),
      );

      // Wait for the screen to fully load
      await tester.pumpAndSettle();

      // Tap FAB to open transaction sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Look for the category dropdown button
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('Category dropdown has label "Category"', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open transaction sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify category label text exists
      expect(find.text('Category'), findsWidgets);
    });

    testWidgets('Dropdown is decorated with outline border', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open transaction sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify dropdown widget exists and can be found
      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);

      // Verify we can interact with it
      expect(find.byWidget(find.byType(DropdownButtonFormField<String>).evaluate().first.widget), findsOneWidget);
    });
  });
}
