import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/portfolios_api.dart';
import '../models/dividend.dart';
import '../models/holding.dart';
import '../models/investment_overview.dart';
import '../models/portfolio.dart';
import '../models/portfolio_value.dart';
import '../models/trade.dart';

final portfoliosApiProvider = Provider<PortfoliosApi>((ref) => PortfoliosApi(ref.watch(apiClientProvider)));

final portfoliosProvider = FutureProvider.autoDispose<List<Portfolio>>((ref) {
  return ref.watch(portfoliosApiProvider).listPortfolios();
});

final investmentOverviewProvider = FutureProvider.autoDispose<InvestmentOverview>((ref) {
  return ref.watch(portfoliosApiProvider).getInvestmentOverview();
});

/// Keyed by portfolioId — Portfolio Detail's holdings table.
final portfolioHoldingsProvider = FutureProvider.autoDispose.family<List<Holding>, String>((ref, portfolioId) {
  return ref.watch(portfoliosApiProvider).listHoldings(portfolioId);
});

/// Keyed by portfolioId — Portfolio Detail's value-summary tiles.
final portfolioValueProvider = FutureProvider.autoDispose.family<PortfolioValue, String>((ref, portfolioId) {
  return ref.watch(portfoliosApiProvider).getPortfolioValue(portfolioId);
});

typedef PortfolioDividendSummaryKey = ({String portfolioId, int year});

/// Keyed by portfolioId+year — Portfolio Detail's dividends section.
final portfolioDividendSummaryProvider =
    FutureProvider.autoDispose.family<DividendYearSummary, PortfolioDividendSummaryKey>((ref, key) {
  return ref.watch(portfoliosApiProvider).getPortfolioDividendSummary(key.portfolioId, key.year);
});

/// Keyed by holdingId — the holding detail sheet's trade ledger.
final holdingTradesProvider = FutureProvider.autoDispose.family<List<Trade>, String>((ref, holdingId) {
  return ref.watch(portfoliosApiProvider).listTrades(holdingId);
});

/// Keyed by holdingId — the holding detail sheet's dividend history.
final holdingDividendsProvider = FutureProvider.autoDispose.family<List<Dividend>, String>((ref, holdingId) {
  return ref.watch(portfoliosApiProvider).listDividends(holdingId);
});
