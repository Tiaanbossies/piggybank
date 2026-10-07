import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/savings.dart';

/// Client for `/savings/*` (backend `app/savings/router.py`).
class SavingsApi {
  SavingsApi(this._client);
  final ApiClient _client;

  Future<SavingsOverview> overview() async {
    try {
      final response = await _client.dio.get('/savings/overview');
      return SavingsOverview.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Creates or replaces the target. A replace is a full replace on the
  /// server, so optional fields left null are cleared.
  Future<SavingsTarget> putTarget({
    required String monthlyAmount,
    String? label,
    DateTime? targetDate,
    String? incomeOverride,
  }) async {
    try {
      final response = await _client.dio.put('/savings/target', data: {
        'monthly_amount': monthlyAmount,
        'label': label,
        'target_date': targetDate == null ? null : _dateOnly(targetDate),
        'income_override': incomeOverride,
      });
      return SavingsTarget.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> deleteTarget() async {
    try {
      await _client.dio.delete('/savings/target');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<List<RecurringCost>> listRecurring() async {
    try {
      final response = await _client.dio.get('/savings/recurring');
      return (response.data as List).map((e) => RecurringCost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<RecurringCost> createRecurring({
    required String name,
    required String monthlyAmount,
    required RecurringCostKind kind,
    RecurringCostDecision decision = RecurringCostDecision.undecided,
    String? savedAmount,
  }) async {
    try {
      final response = await _client.dio.post('/savings/recurring', data: {
        'name': name,
        'monthly_amount': monthlyAmount,
        'kind': kind.wire,
        'decision': decision.wire,
        if (savedAmount case String saved) 'saved_amount': saved,
      });
      return RecurringCost.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<RecurringCost> updateRecurring(
    String costId, {
    String? name,
    String? monthlyAmount,
    RecurringCostKind? kind,
    RecurringCostStatus? status,
    RecurringCostDecision? decision,
    String? savedAmount,
  }) async {
    try {
      final response = await _client.dio.patch('/savings/recurring/$costId', data: {
        if (name case String n) 'name': n,
        if (monthlyAmount case String m) 'monthly_amount': m,
        if (kind case RecurringCostKind k) 'kind': k.wire,
        if (status case RecurringCostStatus s) 'status': s.wire,
        if (decision case RecurringCostDecision d) 'decision': d.wire,
        if (savedAmount case String saved) 'saved_amount': saved,
      });
      return RecurringCost.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> deleteRecurring(String costId) async {
    try {
      await _client.dio.delete('/savings/recurring/$costId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
