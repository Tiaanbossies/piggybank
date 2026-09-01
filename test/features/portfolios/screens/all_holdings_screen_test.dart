import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/portfolios/data/portfolios_api.dart';
import 'package:piggybank/features/portfolios/models/holding.dart';
import 'package:piggybank/features/portfolios/models/portfolio.dart';
import 'package:piggybank/features/portfolios/providers/portfolios_provider.dart';
import 'package:piggybank/features/portfolios/screens/all_holdings_screen.dart';

import '../../../test_helpers/pump_app.dart';

class _MockPortfoliosApi extends Mock implements PortfoliosApi {}

Portfolio _portfolio(String id, String name) => Portfolio(
      id: id,
      name: name,
      description: null,
      currency: 'ZAR',
      portfolioType: PortfolioType.general,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Holding _holding(String id, String portfolioId, String ticker, {Decimal? price}) => Holding(
      id: id,
      portfolioId: portfolioId,
      ticker: ticker,
      name: '$ticker Inc',
      quantity: Decimal.fromInt(10),
      costBasis: Decimal.fromInt(100),
      currentPrice: price ?? Decimal.fromInt(150),
      assetClass: AssetClass.stock,
      contributionYear: null,
      yfSymbol: null,
      priceUpdatedAt: null,
      dividendYield: null,
      isClosed: false,
      realizedPl: null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('AllHoldingsScreen', () {
    testWidgets('merges holdings from every portfolio, sorted by market value, with the portfolio name shown', (tester) async {
      final mockApi = _MockPortfoliosApi();
      final growth = _portfolio('p1', 'Growth');
      final tfsa = _portfolio('p2', 'TFSA');
      when(mockApi.listPortfolios).thenAnswer((_) async => [growth, tfsa]);
      when(() => mockApi.listHoldings('p1')).thenAnswer((_) async => [_holding('h1', 'p1', 'AAA', price: Decimal.fromInt(50))]);
      when(() => mockApi.listHoldings('p2')).thenAnswer((_) async => [_holding('h2', 'p2', 'BBB', price: Decimal.fromInt(500))]);

      await pumpApp(
        tester,
        const AllHoldingsScreen(),
        overrides: [portfoliosApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('AAA'), findsOneWidget);
      expect(find.text('BBB'), findsOneWidget);
      expect(find.textContaining('Growth'), findsOneWidget);
      expect(find.textContaining('TFSA'), findsOneWidget);

      // BBB (market value 5000) should render above AAA (market value 500).
      final bbbTop = tester.getTopLeft(find.text('BBB')).dy;
      final aaaTop = tester.getTopLeft(find.text('AAA')).dy;
      expect(bbbTop, lessThan(aaaTop));
    });

    testWidgets('shows an empty state when no portfolio has any holdings', (tester) async {
      final mockApi = _MockPortfoliosApi();
      when(mockApi.listPortfolios).thenAnswer((_) async => [_portfolio('p1', 'Growth')]);
      when(() => mockApi.listHoldings('p1')).thenAnswer((_) async => []);

      await pumpApp(
        tester,
        const AllHoldingsScreen(),
        overrides: [portfoliosApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('No holdings yet'), findsOneWidget);
    });
  });
}
