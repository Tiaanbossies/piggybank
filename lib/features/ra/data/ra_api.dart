import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/ra_contribution.dart';
import '../models/ra_summary.dart';

/// Covers `backend/app/ra/router.py`'s contribution-ledger CRUD + summary.
class RaApi {
  RaApi(this._client);
  final ApiClient _client;

  Future<List<RaContribution>> listContributions() async {
    try {
      final response = await _client.dio.get('/ra/contributions');
      return (response.data as List)
          .map((e) => RaContribution.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<RaContribution> createContribution({
    required int taxYear,
    required String amount,
    DateTime? contributionDate,
    String? notes,
    String? provider,
  }) async {
    try {
      final response = await _client.dio.post('/ra/contributions', data: {
        'tax_year': taxYear,
        'amount': amount,
        if (contributionDate case DateTime cd) 'contribution_date': _dateOnly(cd),
        if (notes case String n) 'notes': n,
        if (provider case String p) 'provider': p,
      });
      return RaContribution.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> deleteContribution(String contributionId) async {
    try {
      await _client.dio.delete('/ra/contributions/$contributionId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<RaSummary> getSummary() async {
    try {
      final response = await _client.dio.get('/ra/summary');
      return RaSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
