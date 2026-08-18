import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/tfsa_contribution.dart';
import '../models/tfsa_summary.dart';

/// Covers `backend/app/tfsa/router.py`'s contribution-ledger CRUD + summary.
class TfsaApi {
  TfsaApi(this._client);
  final ApiClient _client;

  Future<List<TfsaContribution>> listContributions() async {
    try {
      final response = await _client.dio.get('/tfsa/contributions');
      return (response.data as List)
          .map((e) => TfsaContribution.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<TfsaContribution> createContribution({
    required int taxYear,
    required String amount,
    DateTime? contributionDate,
    String? notes,
    String? ticker,
  }) async {
    try {
      final response = await _client.dio.post('/tfsa/contributions', data: {
        'tax_year': taxYear,
        'amount': amount,
        if (contributionDate != null) 'contribution_date': _dateOnly(contributionDate),
        if (notes != null) 'notes': notes,
        if (ticker != null) 'ticker': ticker,
      });
      return TfsaContribution.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> deleteContribution(String contributionId) async {
    try {
      await _client.dio.delete('/tfsa/contributions/$contributionId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<TfsaSummary> getSummary() async {
    try {
      final response = await _client.dio.get('/tfsa/summary');
      return TfsaSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
