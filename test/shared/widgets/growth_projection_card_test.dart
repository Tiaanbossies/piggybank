import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/shared/widgets/growth_projection_card.dart';

void main() {
  group('GrowthProjectionCard', () {
    testWidgets('renders the disclaimer and a default 8% projection', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GrowthProjectionCard(startingBalance: 50000, label: 'TFSA')),
        ),
      );

      expect(find.textContaining('not a forecast'), findsOneWidget);
      // 50000 * 1.08^10 ≈ R 107 946.25 — default rate is 8%.
      expect(find.textContaining('107 946'), findsOneWidget);
    });

    testWidgets('updates projections when the rate input changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GrowthProjectionCard(startingBalance: 50000, label: 'TFSA')),
        ),
      );

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();

      // At 0% growth, every horizon's projected value equals the starting balance.
      expect(find.textContaining('50 000'), findsWidgets);
      expect(find.textContaining('107 946'), findsNothing);
    });
  });
}
