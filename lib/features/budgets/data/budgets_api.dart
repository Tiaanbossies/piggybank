import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/budget.dart';

class BudgetsApi {
  BudgetsApi(this._client);
  final ApiClient _client;

  Future<List<BudgetProgress>> progress(DateTime month) async {
    try {
      final response = await _client.dio.get('/budgets/progress', queryParameters: {'month': _dateOnly(month)});
      return (response.data as List).map((e) => BudgetProgress.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<List<Budget>> list() async {
    try {
      final response = await _client.dio.get('/budgets/', queryParameters: {'limit': 200});
      final data = response.data as Map<String, dynamic>;
      return (data['items'] as List).map((e) => Budget.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Budget> create({
    required DateTime month,
    required String totalBudget,
    String? category,
    String? parentBudgetId,
  }) async {
    try {
      final response = await _client.dio.post('/budgets/', data: {
        'month': _dateOnly(month),
        'total_budget': totalBudget,
        if (category != null) 'category': category,
        if (parentBudgetId != null) 'parent_budget_id': parentBudgetId,
      });
      return Budget.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Budget> update(String budgetId, {DateTime? month, String? totalBudget, String? category}) async {
    try {
      final response = await _client.dio.patch('/budgets/$budgetId', data: {
        if (month != null) 'month': _dateOnly(month),
        if (totalBudget != null) 'total_budget': totalBudget,
        if (category != null) 'category': category,
      });
      return Budget.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> delete(String budgetId) async {
    try {
      await _client.dio.delete('/budgets/$budgetId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
