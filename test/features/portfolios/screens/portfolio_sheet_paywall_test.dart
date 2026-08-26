import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/portfolios/data/portfolios_api.dart';
import 'package:piggybank/features/portfolios/models/portfolio.dart';
import 'package:piggybank/features/portfolios/providers/portfolios_provider.dart';
import 'package:piggybank/features/portfolios/screens/portfolio_sheet.dart';

import '../../../test_helpers/pump_app.dart';

class MockPortfoliosApi extends Mock implements PortfoliosApi {}

/// Renders `showPortfolioSheet`'s "Create portfolio" form and taps Save —
/// per DESIGN.md's paywall precedent (also exercised for Portfolios in
/// `portfolio_sheet.dart`'s `_submit`), a 402 `ApiError` should pop the sheet
/// and show the generic "Upgrade to PRO" dialog, while any other status
/// keeps the sheet open with an inline error and never shows that dialog.
void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2026, 1, 1));
    registerFallbackValue(PortfolioType.general);
  });

  late MockPortfoliosApi mockApi;

  setUp(() => mockApi = MockPortfoliosApi());

  Future<void> pumpSheet(WidgetTester tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showPortfolioSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      overrides: [portfoliosApiProvider.overrideWithValue(mockApi)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Portfolio name'), 'Growth');
  }

  testWidgets('shows the Upgrade to PRO dialog on a 402 paywall error', (tester) async {
    when(() => mockApi.createPortfolio(
          name: any(named: 'name'),
          description: any(named: 'description'),
          currency: any(named: 'currency'),
          portfolioType: any(named: 'portfolioType'),
        )).thenThrow(const ApiError(statusCode: 402, message: "You've reached the Free plan's portfolio limit."));

    await pumpSheet(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to PRO'), findsOneWidget);
    expect(find.text("You've reached the Free plan's portfolio limit."), findsOneWidget);
    // The sheet itself is popped when a paywall error is hit.
    expect(find.text('Create portfolio'), findsNothing);
  });

  testWidgets('does not show the paywall dialog for a non-402 error, and keeps the sheet open', (tester) async {
    when(() => mockApi.createPortfolio(
          name: any(named: 'name'),
          description: any(named: 'description'),
          currency: any(named: 'currency'),
          portfolioType: any(named: 'portfolioType'),
        )).thenThrow(const ApiError(statusCode: 400, message: 'Name is required.'));

    await pumpSheet(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to PRO'), findsNothing);
    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.text('Create portfolio'), findsOneWidget);
  });

  testWidgets('does not show the paywall dialog on success', (tester) async {
    when(() => mockApi.createPortfolio(
          name: any(named: 'name'),
          description: any(named: 'description'),
          currency: any(named: 'currency'),
          portfolioType: any(named: 'portfolioType'),
        )).thenAnswer((_) async => Portfolio(
          id: 'p1',
          name: 'Growth',
          description: null,
          currency: 'ZAR',
          portfolioType: PortfolioType.general,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ));

    await pumpSheet(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to PRO'), findsNothing);
    expect(find.text('Create portfolio'), findsNothing);
  });
}
