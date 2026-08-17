import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/portfolios_api.dart';
import '../models/holding.dart';
import '../models/investment_overview.dart';
import '../models/portfolio.dart';

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
