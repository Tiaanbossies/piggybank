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
