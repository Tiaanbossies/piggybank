import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/portfolios/data/portfolios_api.dart';
import 'package:piggybank/features/portfolios/models/dividend.dart';
import 'package:piggybank/features/portfolios/models/holding.dart';
import 'package:piggybank/features/portfolios/models/investment_overview.dart';
import 'package:piggybank/features/portfolios/models/portfolio.dart';
import 'package:piggybank/features/portfolios/models/portfolio_value.dart';
import 'package:piggybank/features/portfolios/models/trade.dart';
import 'package:piggybank/features/portfolios/providers/portfolios_provider.dart';

class MockPortfoliosApi extends Mock implements PortfoliosApi {}

Portfolio _portfolio({String id = 'p1', PortfolioType type = PortfolioType.general}) => Portfolio(
      id: id,
      name: 'Growth',
      description: null,
      currency: 'ZAR',
      portfolioType: type,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Holding _holding({String id = 'h1', String portfolioId = 'p1'}) => Holding(
      id: id,
      portfolioId: portfolioId,
      ticker: 'AAPL',
      name: 'Apple Inc',
      quantity: Decimal.fromInt(10),
      costBasis: Decimal.fromInt(100),
      currentPrice: Decimal.fromInt(150),
      assetClass: AssetClass.stock,
      contributionYear: null,
      yfSymbol: 'AAPL',
      priceUpdatedAt: DateTime(2026, 1, 1),
      dividendYield: null,
      isClosed: false,
      realizedPl: null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Dividend _dividend({String id = 'd1', String holdingId = 'h1'}) => Dividend(
      id: id,
      holdingId: holdingId,
      payDate: DateTime(2026, 3, 1),
      amount: Decimal.fromInt(50),
      currency: 'ZAR',
      taxWithheld: Decimal.zero,
      note: null,
      createdAt: DateTime(2026, 3, 1),
    );

Trade _trade({String id = 't1', String holdingId = 'h1'}) => Trade(
      id: id,
      holdingId: holdingId,
      tradeType: HoldingTradeType.buy,
      quantity: Decimal.fromInt(5),
      pricePerUnit: Decimal.fromInt(100),
      tradeDate: DateTime(2026, 2, 1),
      fee: Decimal.zero,
      note: null,
      createdAt: DateTime(2026, 2, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(AssetClass.stock);
    registerFallbackValue(HoldingTradeType.buy);
    registerFallbackValue(PortfolioType.general);
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  late MockPortfoliosApi mockApi;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockPortfoliosApi();
    container = ProviderContainer(overrides: [portfoliosApiProvider.overrideWithValue(mockApi)]);
  });

  tearDown(() => container.dispose());

  group('portfoliosProvider', () {
    test('fetches the portfolio list from the api', () async {
      when(() => mockApi.listPortfolios()).thenAnswer((_) async => [_portfolio()]);
      final result = await container.read(portfoliosProvider.future);
      expect(result, hasLength(1));
      expect(result.single.id, 'p1');
      verify(() => mockApi.listPortfolios()).called(1);
    });
  });

  group('investmentOverviewProvider', () {
    test('fetches the aggregated overview', () async {
      when(() => mockApi.getInvestmentOverview()).thenAnswer((_) async => InvestmentOverview(
            totalValue: Decimal.fromInt(1000),
            totalCost: Decimal.fromInt(800),
            unrealizedPl: Decimal.fromInt(200),
            ytdDividends: Decimal.fromInt(30),
            portfolioCount: 1,
            holdingCount: 2,
            allocation: const [],
            topHoldings: const [],
          ));
      final result = await container.read(investmentOverviewProvider.future);
      expect(result.totalValue, Decimal.fromInt(1000));
      expect(result.portfolioCount, 1);
    });
  });

  group('portfolioHoldingsProvider (family keyed by portfolioId)', () {
    test('calls listHoldings with the requested portfolioId', () async {
      when(() => mockApi.listHoldings('p1')).thenAnswer((_) async => [_holding(portfolioId: 'p1')]);
      when(() => mockApi.listHoldings('p2')).thenAnswer((_) async => []);

      final resultP1 = await container.read(portfolioHoldingsProvider('p1').future);
      final resultP2 = await container.read(portfolioHoldingsProvider('p2').future);

      expect(resultP1, hasLength(1));
      expect(resultP2, isEmpty);
      verify(() => mockApi.listHoldings('p1')).called(1);
      verify(() => mockApi.listHoldings('p2')).called(1);
    });
  });

  group('portfolioValueProvider (family keyed by portfolioId)', () {
    test('fetches the value summary for the given portfolio', () async {
      when(() => mockApi.getPortfolioValue('p1')).thenAnswer((_) async => PortfolioValue(
            portfolioId: 'p1',
            totalCost: Decimal.fromInt(1000),
            totalValue: Decimal.fromInt(1500),
            unrealizedPl: Decimal.fromInt(500),
            realizedPl: Decimal.zero,
            currency: 'ZAR',
          ));
      final result = await container.read(portfolioValueProvider('p1').future);
      expect(result.portfolioId, 'p1');
      expect(result.unrealizedPl, Decimal.fromInt(500));
    });
  });

  group('portfolioDividendSummaryProvider (family keyed by portfolioId+year)', () {
    test('calls getPortfolioDividendSummary with both key fields', () async {
      when(() => mockApi.getPortfolioDividendSummary('p1', 2026)).thenAnswer((_) async => DividendYearSummary(
            year: 2026,
            totalReceived: Decimal.fromInt(120),
            totalTaxWithheld: Decimal.fromInt(10),
            byMonth: const [],
          ));
      final result =
          await container.read(portfolioDividendSummaryProvider((portfolioId: 'p1', year: 2026)).future);
      expect(result.year, 2026);
      verify(() => mockApi.getPortfolioDividendSummary('p1', 2026)).called(1);
    });

    test('a different year in the key triggers a separate api call', () async {
      when(() => mockApi.getPortfolioDividendSummary('p1', 2025)).thenAnswer((_) async => DividendYearSummary(
            year: 2025,
            totalReceived: Decimal.zero,
            totalTaxWithheld: Decimal.zero,
            byMonth: const [],
          ));
      when(() => mockApi.getPortfolioDividendSummary('p1', 2026)).thenAnswer((_) async => DividendYearSummary(
            year: 2026,
            totalReceived: Decimal.fromInt(50),
            totalTaxWithheld: Decimal.zero,
            byMonth: const [],
          ));

      final r2025 = await container.read(portfolioDividendSummaryProvider((portfolioId: 'p1', year: 2025)).future);
      final r2026 = await container.read(portfolioDividendSummaryProvider((portfolioId: 'p1', year: 2026)).future);

      expect(r2025.totalReceived, Decimal.zero);
      expect(r2026.totalReceived, Decimal.fromInt(50));
    });
  });

  group('holdingTradesProvider / holdingDividendsProvider (family keyed by holdingId)', () {
    test('holdingTradesProvider fetches trades for the holding', () async {
      when(() => mockApi.listTrades('h1')).thenAnswer((_) async => [_trade()]);
      final result = await container.read(holdingTradesProvider('h1').future);
      expect(result, hasLength(1));
      expect(result.single.tradeType, HoldingTradeType.buy);
    });

    test('holdingDividendsProvider fetches dividends for the holding', () async {
      when(() => mockApi.listDividends('h1')).thenAnswer((_) async => [_dividend()]);
      final result = await container.read(holdingDividendsProvider('h1').future);
      expect(result, hasLength(1));
      expect(result.single.amount, Decimal.fromInt(50));
    });
  });

  group('portfolio CRUD wiring (api calls invoked by the sheets, verified directly)', () {
    test('createPortfolio forwards name/description/currency/type', () async {
      when(() => mockApi.createPortfolio(
            name: any(named: 'name'),
            description: any(named: 'description'),
            currency: any(named: 'currency'),
            portfolioType: any(named: 'portfolioType'),
          )).thenAnswer((_) async => _portfolio());

      final api = container.read(portfoliosApiProvider);
      await api.createPortfolio(name: 'Growth', portfolioType: PortfolioType.tfsa);

      verify(() => mockApi.createPortfolio(
            name: 'Growth',
            description: any(named: 'description'),
            currency: any(named: 'currency'),
            portfolioType: PortfolioType.tfsa,
          )).called(1);
    });

    test('updatePortfolio forwards id and changed fields', () async {
      when(() => mockApi.updatePortfolio(any(),
          name: any(named: 'name'), description: any(named: 'description'))).thenAnswer((_) async => _portfolio());

      final api = container.read(portfoliosApiProvider);
      await api.updatePortfolio('p1', name: 'New name');

      verify(() => mockApi.updatePortfolio('p1', name: 'New name', description: any(named: 'description')))
          .called(1);
    });

    test('deletePortfolio forwards the id', () async {
      when(() => mockApi.deletePortfolio(any())).thenAnswer((_) async {});
      final api = container.read(portfoliosApiProvider);
      await api.deletePortfolio('p1');
      verify(() => mockApi.deletePortfolio('p1')).called(1);
    });
  });

  group('holding CRUD wiring', () {
    test('createHolding forwards all holding fields', () async {
      when(() => mockApi.createHolding(
            any(),
            ticker: any(named: 'ticker'),
            name: any(named: 'name'),
            quantity: any(named: 'quantity'),
            costBasis: any(named: 'costBasis'),
            assetClass: any(named: 'assetClass'),
            currentPrice: any(named: 'currentPrice'),
            contributionYear: any(named: 'contributionYear'),
          )).thenAnswer((_) async => _holding());

      final api = container.read(portfoliosApiProvider);
      await api.createHolding('p1',
          ticker: 'AAPL', name: 'Apple', quantity: '10', costBasis: '100', assetClass: AssetClass.stock);

      verify(() => mockApi.createHolding(
            'p1',
            ticker: 'AAPL',
            name: 'Apple',
            quantity: '10',
            costBasis: '100',
            assetClass: AssetClass.stock,
            currentPrice: any(named: 'currentPrice'),
            contributionYear: any(named: 'contributionYear'),
          )).called(1);
    });

    test('updateHolding forwards the holdingId and changed fields', () async {
      when(() => mockApi.updateHolding(
            any(),
            ticker: any(named: 'ticker'),
            name: any(named: 'name'),
            quantity: any(named: 'quantity'),
            costBasis: any(named: 'costBasis'),
            currentPrice: any(named: 'currentPrice'),
            assetClass: any(named: 'assetClass'),
            dividendYield: any(named: 'dividendYield'),
          )).thenAnswer((_) async => _holding());

      final api = container.read(portfoliosApiProvider);
      await api.updateHolding('h1', quantity: '15');

      verify(() => mockApi.updateHolding('h1', quantity: '15')).called(1);
    });

    test('deleteHolding forwards the holdingId', () async {
      when(() => mockApi.deleteHolding(any())).thenAnswer((_) async {});
      final api = container.read(portfoliosApiProvider);
      await api.deleteHolding('h1');
      verify(() => mockApi.deleteHolding('h1')).called(1);
    });
  });

  group('dividend CRUD wiring', () {
    test('createDividend forwards holdingId/date/amount', () async {
      when(() => mockApi.createDividend(
            any(),
            payDate: any(named: 'payDate'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            taxWithheld: any(named: 'taxWithheld'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => _dividend());

      final api = container.read(portfoliosApiProvider);
      await api.createDividend('h1', payDate: DateTime(2026, 3, 1), amount: '50');

      verify(() => mockApi.createDividend(
            'h1',
            payDate: DateTime(2026, 3, 1),
            amount: '50',
            currency: any(named: 'currency'),
            taxWithheld: any(named: 'taxWithheld'),
            note: any(named: 'note'),
          )).called(1);
    });

    test('deleteDividend forwards the dividendId', () async {
      when(() => mockApi.deleteDividend(any())).thenAnswer((_) async {});
      final api = container.read(portfoliosApiProvider);
      await api.deleteDividend('d1');
      verify(() => mockApi.deleteDividend('d1')).called(1);
    });
  });

  group('trade CRUD wiring', () {
    test('createTrade (sell) forwards tradeType/quantity/price/date', () async {
      when(() => mockApi.createTrade(
            any(),
            tradeType: any(named: 'tradeType'),
            quantity: any(named: 'quantity'),
            pricePerUnit: any(named: 'pricePerUnit'),
            tradeDate: any(named: 'tradeDate'),
            fee: any(named: 'fee'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => _trade());

      final api = container.read(portfoliosApiProvider);
      await api.createTrade(
        'h1',
        tradeType: HoldingTradeType.sell,
        quantity: '5',
        pricePerUnit: '150',
        tradeDate: DateTime(2026, 4, 1),
      );

      verify(() => mockApi.createTrade(
            'h1',
            tradeType: HoldingTradeType.sell,
            quantity: '5',
            pricePerUnit: '150',
            tradeDate: DateTime(2026, 4, 1),
            fee: any(named: 'fee'),
            note: any(named: 'note'),
          )).called(1);
    });

    test('deleteTrade forwards the tradeId', () async {
      when(() => mockApi.deleteTrade(any())).thenAnswer((_) async {});
      final api = container.read(portfoliosApiProvider);
      await api.deleteTrade('t1');
      verify(() => mockApi.deleteTrade('t1')).called(1);
    });
  });
}
