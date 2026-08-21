import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/dividend.dart';
import '../models/holding.dart';
import '../models/investment_overview.dart';
import '../models/portfolio.dart';
import '../models/portfolio_value.dart';
import '../models/ticker_history.dart';
import '../models/ticker_lookup.dart';
import '../models/ticker_search_result.dart';
import '../models/trade.dart';

/// Covers `backend/app/portfolios/router.py`'s CRUD + aggregation surface,
/// plus ticker lookup/search/history for the Add/Edit Holding autocomplete
/// and sparkline/price-history charts. Market-data-batch/provider-health
/// aren't needed by any planned screen and remain unimplemented.
class PortfoliosApi {
  PortfoliosApi(this._client);
  final ApiClient _client;

  // ---- portfolios --------------------------------------------------------

  Future<List<Portfolio>> listPortfolios() async {
    try {
      final response = await _client.dio.get('/portfolios/', queryParameters: {'limit': 200});
      final data = response.data as Map<String, dynamic>;
      return (data['items'] as List).map((e) => Portfolio.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Portfolio> createPortfolio({
    required String name,
    String? description,
    String currency = 'ZAR',
    PortfolioType portfolioType = PortfolioType.general,
  }) async {
    try {
      final response = await _client.dio.post('/portfolios/', data: {
        'name': name,
        if (description case String desc) 'description': desc,
        'currency': currency,
        'portfolio_type': portfolioTypeToJson(portfolioType),
      });
      return Portfolio.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Portfolio> updatePortfolio(String portfolioId, {String? name, String? description}) async {
    try {
      final response = await _client.dio.patch('/portfolios/$portfolioId', data: {
        if (name case String n) 'name': n,
        if (description case String desc) 'description': desc,
      });
      return Portfolio.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> deletePortfolio(String portfolioId) async {
    try {
      await _client.dio.delete('/portfolios/$portfolioId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<PortfolioValue> getPortfolioValue(String portfolioId) async {
    try {
      final response = await _client.dio.get('/portfolios/$portfolioId/value');
      return PortfolioValue.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<DividendYearSummary> getPortfolioDividendSummary(String portfolioId, int year) async {
    try {
      final response =
          await _client.dio.get('/portfolios/$portfolioId/dividends/summary', queryParameters: {'year': year});
      return DividendYearSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Best-effort — a stale-price provider outage shouldn't block the screen,
  /// so callers may ignore [ApiError] here rather than surfacing it.
  Future<void> refreshPortfolioPrices(String portfolioId) async {
    try {
      await _client.dio.post('/portfolios/$portfolioId/refresh-prices');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  // ---- holdings ------------------------------------------------------------

  Future<List<Holding>> listHoldings(String portfolioId) async {
    try {
      final response = await _client.dio.get('/portfolios/$portfolioId/holdings');
      return (response.data as List).map((e) => Holding.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Holding> createHolding(
    String portfolioId, {
    required String ticker,
    required String name,
    required String quantity,
    required String costBasis,
    String? currentPrice,
    required AssetClass assetClass,
    int? contributionYear,
  }) async {
    try {
      final response = await _client.dio.post('/portfolios/$portfolioId/holdings', data: {
        'ticker': ticker,
        'name': name,
        'quantity': quantity,
        'cost_basis': costBasis,
        if (currentPrice case String cp) 'current_price': cp,
        'asset_class': assetClassToJson(assetClass),
        if (contributionYear case int cy) 'contribution_year': cy,
      });
      return Holding.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Holding> updateHolding(
    String holdingId, {
    String? ticker,
    String? name,
    String? quantity,
    String? costBasis,
    String? currentPrice,
    AssetClass? assetClass,
    String? dividendYield,
  }) async {
    try {
      final response = await _client.dio.patch('/holdings/$holdingId', data: {
        if (ticker case String t) 'ticker': t,
        if (name case String n) 'name': n,
        if (quantity case String q) 'quantity': q,
        if (costBasis case String cb) 'cost_basis': cb,
        if (currentPrice case String cp) 'current_price': cp,
        if (assetClass case AssetClass ac) 'asset_class': assetClassToJson(ac),
        if (dividendYield case String dy) 'dividend_yield': dy,
      });
      return Holding.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> deleteHolding(String holdingId) async {
    try {
      await _client.dio.delete('/holdings/$holdingId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  // ---- dividends -----------------------------------------------------------

  Future<List<Dividend>> listDividends(String holdingId) async {
    try {
      final response = await _client.dio.get('/holdings/$holdingId/dividends');
      return (response.data as List).map((e) => Dividend.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Dividend> createDividend(
    String holdingId, {
    required DateTime payDate,
    required String amount,
    String currency = 'ZAR',
    String taxWithheld = '0',
    String? note,
  }) async {
    try {
      final response = await _client.dio.post('/holdings/$holdingId/dividends', data: {
        'pay_date': _dateOnly(payDate),
        'amount': amount,
        'currency': currency,
        'tax_withheld': taxWithheld,
        if (note case String n) 'note': n,
      });
      return Dividend.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> deleteDividend(String dividendId) async {
    try {
      await _client.dio.delete('/dividends/$dividendId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  // ---- trades ----------------------------------------------------------------

  Future<List<Trade>> listTrades(String holdingId) async {
    try {
      final response = await _client.dio.get('/holdings/$holdingId/trades');
      return (response.data as List).map((e) => Trade.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// A sell trade is a recorded, auditable transaction — not a silent
  /// holding-quantity edit. See `ui-ux-mockup-brief.md` §7.
  Future<Trade> createTrade(
    String holdingId, {
    required HoldingTradeType tradeType,
    required String quantity,
    required String pricePerUnit,
    required DateTime tradeDate,
    String fee = '0',
    String? note,
  }) async {
    try {
      final response = await _client.dio.post('/holdings/$holdingId/trades', data: {
        'trade_type': holdingTradeTypeToJson(tradeType),
        'quantity': quantity,
        'price_per_unit': pricePerUnit,
        'trade_date': _dateOnly(tradeDate),
        'fee': fee,
        if (note case String n) 'note': n,
      });
      return Trade.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> deleteTrade(String tradeId) async {
    try {
      await _client.dio.delete('/trades/$tradeId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  // ---- investments overview -------------------------------------------------

  Future<InvestmentOverview> getInvestmentOverview() async {
    try {
      final response = await _client.dio.get('/investments/overview');
      return InvestmentOverview.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ---- ticker lookup/search/history ------------------------------------

  /// Returns `null` on a 404 (ticker not found) rather than throwing —
  /// callers treat "no match" as a normal, expected autocomplete outcome.
  Future<TickerLookup?> tickerLookup(String q) async {
    try {
      final response = await _client.dio.get('/portfolios/ticker-lookup', queryParameters: {'q': q});
      return TickerLookup.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiClient.errorFrom(e);
    }
  }

  /// Always 200 server-side (empty `items` on failure) — safe to call on
  /// every keystroke for an autocomplete dropdown.
  Future<List<TickerSearchResult>> tickerSearch(String q) async {
    try {
      final response = await _client.dio.get('/portfolios/ticker-search', queryParameters: {'q': q});
      final data = response.data as Map<String, dynamic>;
      return (data['items'] as List).map((e) => TickerSearchResult.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<TickerHistory> tickerHistory(String ticker, {String period = '3mo'}) async {
    try {
      final response = await _client.dio
          .get('/portfolios/ticker-history', queryParameters: {'ticker': ticker, 'period': period});
      return TickerHistory.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}
