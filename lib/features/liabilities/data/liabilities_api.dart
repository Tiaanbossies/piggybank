import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/liability.dart';
import '../models/liability_payment.dart';

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
        if (outstandingAmount case String oa) 'outstanding_amount': oa,
        if (originalBalance case String ob) 'original_balance': ob,
        if (interestRate case String ir) 'interest_rate': ir,
        if (termMonths case int tm) 'term_months': tm,
        if (monthlyAmount case String ma) 'monthly_amount': ma,
        if (startDate case DateTime sd) 'start_date': _dateOnly(sd),
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
        if (liabilityType case LiabilityType lt) 'liability_type': liabilityTypeToJson(lt),
        if (name case String n) 'name': n,
        if (outstandingAmount case String oa) 'outstanding_amount': oa,
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

  Future<LiabilityProgress> getProgress(String liabilityId) async {
    try {
      final response = await _client.dio.get('/liabilities/$liabilityId/progress');
      return LiabilityProgress.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<List<LiabilityPayment>> listPayments(String liabilityId) async {
    try {
      final response = await _client.dio.get('/liabilities/$liabilityId/payments');
      return (response.data as List).map((e) => LiabilityPayment.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<LiabilityPayment> createPayment(
    String liabilityId, {
    required DateTime paymentDate,
    required String amount,
    required String principalPortion,
    required String interestPortion,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post('/liabilities/$liabilityId/payments', data: {
        'payment_date': _dateOnly(paymentDate),
        'amount': amount,
        'principal_portion': principalPortion,
        'interest_portion': interestPortion,
        if (notes case String n) 'notes': n,
      });
      return LiabilityPayment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> deletePayment(String liabilityId, String paymentId) async {
    try {
      await _client.dio.delete('/liabilities/$liabilityId/payments/$paymentId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
