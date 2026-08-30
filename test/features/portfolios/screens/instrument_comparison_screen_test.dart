import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/portfolios/data/portfolios_api.dart';
import 'package:piggybank/features/portfolios/models/ticker_history.dart';
import 'package:piggybank/features/portfolios/providers/portfolios_provider.dart';
import 'package:piggybank/features/portfolios/screens/instrument_comparison_screen.dart';

import '../../../test_helpers/pump_app.dart';

class _MockPortfoliosApi extends Mock implements PortfoliosApi {}

TickerHistory _history(String ticker) => TickerHistory(ticker: ticker, name: '$ticker Inc', currency: 'ZAR', data: const []);

void main() {
  late _MockPortfoliosApi mockApi;

  setUp(() {
    mockApi = _MockPortfoliosApi();
    when(() => mockApi.tickerLookup(any())).thenAnswer((_) async => null);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      const InstrumentComparisonScreen(),
      overrides: [portfoliosApiProvider.overrideWithValue(mockApi)],
      useAppTheme: true,
    );
    await tester.pump();
  }

  group('Enter-to-submit', () {
    testWidgets('pressing Enter on a manually typed ticker adds it', (tester) async {
      when(() => mockApi.tickerHistory(any(), period: any(named: 'period'))).thenAnswer((_) async => _history('MSFT'));

      await pumpScreen(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Ticker'), 'msft');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('MSFT'), findsWidgets);
      verify(() => mockApi.tickerHistory('MSFT', period: any(named: 'period'))).called(1);
    });
  });

  group('Failed ticker lookup', () {
    testWidgets('shows the error via a SnackBar and marks the chip with a warning', (tester) async {
      when(() => mockApi.tickerHistory(any(), period: any(named: 'period')))
          .thenThrow(const ApiError(statusCode: 404, message: 'Ticker not found.'));

      await pumpScreen(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Ticker'), 'ZZZZ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('⚠'), findsOneWidget);
      expect(find.textContaining('Ticker not found.'), findsOneWidget);
    });
  });

  group('Max entries cap', () {
    testWidgets('the Add button disables once 5 tickers are added', (tester) async {
      when(() => mockApi.tickerHistory(any(), period: any(named: 'period')))
          .thenAnswer((invocation) async => _history(invocation.positionalArguments.first as String));

      await pumpScreen(tester);
      for (final ticker in ['AAA', 'BBB', 'CCC', 'DDD', 'EEE']) {
        await tester.enterText(find.widgetWithText(TextField, 'Ticker'), ticker);
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      final addButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'));
      expect(addButton.onPressed, isNull);
    });
  });
}
