import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/summaries.dart';

class SummariesApi {
  SummariesApi(this._client);
  final ApiClient _client;

  Future<NetWorthSummary> netWorth() async {
    try {
      final response = await _client.dio.get('/summaries/net-worth');
      return NetWorthSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Defaults to the current calendar month when [month] is omitted (backend
  /// convention, per `get_cashflow` in `summaries/router.py`).
  Future<CashflowSummary> cashflow() async {
    try {
      final response = await _client.dio.get('/summaries/cashflow');
      return CashflowSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// One month's budget-vs-actual figures. [month] is `YYYY-MM` and is
  /// **required by the backend** (`get_budget_usage` in `summaries/router.py`
  /// has no default) — unlike [cashflow], there is no "current month"
  /// fallback server-side.
  ///
  /// A month with no budget row simply comes back with zeros; it is not an
  /// error. There is no multi-month endpoint, so a trend view fans this out
  /// one call per month (see `budgetUsageProvider`).
  Future<BudgetUsageSummary> budgetUsage({required String month}) async {
    try {
      final response = await _client.dio.get('/summaries/budget-usage', queryParameters: {'month': month});
      return BudgetUsageSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Categories with spend in at least 2 of the 3 calendar months ending
  /// with [month] (`YYYY-MM`, defaults to the current month). The 3-month
  /// window is the backend's, not the client's — see `get_recurring_expenses`.
  Future<List<RecurringExpenseSummary>> recurringExpenses({String? month}) async {
    try {
      final response = await _client.dio.get(
        '/summaries/recurring-expenses',
        queryParameters: {'month': month ?? currentMonthKey()},
      );
      return (response.data as List).map((e) => RecurringExpenseSummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// The [topN] highest-total expense categories for [month] (`YYYY-MM`,
  /// defaults to the current month), already sorted server-side.
  Future<List<HighCostExpenseSummary>> highCostExpenses({String? month, int topN = 5}) async {
    try {
      final response = await _client.dio.get(
        '/summaries/high-cost-expenses',
        queryParameters: {'month': month ?? currentMonthKey(), 'top_n': topN},
      );
      return (response.data as List).map((e) => HighCostExpenseSummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Snapshots are written by the backend's daily scheduled job
  /// (`summaries/snapshot_job.py`) — the client only ever reads history,
  /// it never triggers `POST /net-worth-snapshot` itself.
  Future<List<NetWorthSnapshot>> netWorthHistory({int months = 2}) async {
    try {
      final response = await _client.dio.get('/summaries/net-worth-history', queryParameters: {'months': months});
      final data = response.data as Map<String, dynamic>;
      return (data['snapshots'] as List).map((e) => NetWorthSnapshot.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}
