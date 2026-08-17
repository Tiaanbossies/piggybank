import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/liability.dart';

class LiabilitiesApi {
  LiabilitiesApi(this._client);
  final ApiClient _client;

  Future<List<Liability>> list() async {
    try {
      final response = await _client.dio.get('/liabilities/', queryParameters: {'limit': 200});
      final data = response.data as Map<String, dynamic>;
      return (data['items'] as List).map((e) => Liability.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Either pass [outstandingAmount] directly, or the loan-params
  /// ([originalBalance], [interestRate], [startDate], and one of
  /// [termMonths]/[monthlyAmount]) for the backend to auto-compute it.
  Future<Liability> create({
    required LiabilityType liabilityType,
    required String name,
    String? outstandingAmount,
    String? originalBalance,
    String? interestRate,
    int? termMonths,
    String? monthlyAmount,
    DateTime? startDate,
  }) async {
    try {
      final response = await _client.dio.post('/liabilities/', data: {
        'liability_type': liabilityTypeToJson(liabilityType),
        'name': name,
        if (outstandingAmount != null) 'outstanding_amount': outstandingAmount,
        if (originalBalance != null) 'original_balance': originalBalance,
        if (interestRate != null) 'interest_rate': interestRate,
        if (termMonths != null) 'term_months': termMonths,
        if (monthlyAmount != null) 'monthly_amount': monthlyAmount,
        if (startDate != null) 'start_date': _dateOnly(startDate),
      });
      return Liability.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Liability> update(
    String liabilityId, {
    LiabilityType? liabilityType,
    String? name,
    String? outstandingAmount,
  }) async {
    try {
      final response = await _client.dio.patch('/liabilities/$liabilityId', data: {
        if (liabilityType != null) 'liability_type': liabilityTypeToJson(liabilityType),
        if (name != null) 'name': name,
        if (outstandingAmount != null) 'outstanding_amount': outstandingAmount,
      });
      return Liability.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> delete(String liabilityId) async {
    try {
      await _client.dio.delete('/liabilities/$liabilityId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
