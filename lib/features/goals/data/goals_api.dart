import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/goal.dart';

class GoalsApi {
  GoalsApi(this._client);
  final ApiClient _client;

  Future<List<Goal>> list() async {
    try {
      final response = await _client.dio.get('/goals/');
      final data = response.data as Map<String, dynamic>;
      return (data['items'] as List).map((e) => Goal.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Goal> create({
    required String name,
    required String targetAmount,
    String? currentAmount,
    DateTime? targetDate,
    String? category,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post('/goals/', data: {
        'name': name,
        'target_amount': targetAmount,
        if (currentAmount != null) 'current_amount': currentAmount,
        if (targetDate != null) 'target_date': _dateOnly(targetDate),
        if (category != null) 'category': category,
        if (notes != null) 'notes': notes,
      });
      return Goal.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Goal> update(
    String goalId, {
    String? name,
    String? targetAmount,
    String? currentAmount,
    DateTime? targetDate,
    String? category,
    GoalStatus? status,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.patch('/goals/$goalId', data: {
        if (name != null) 'name': name,
        if (targetAmount != null) 'target_amount': targetAmount,
        if (currentAmount != null) 'current_amount': currentAmount,
        if (targetDate != null) 'target_date': _dateOnly(targetDate),
        if (category != null) 'category': category,
        if (status != null) 'status': status.name,
        if (notes != null) 'notes': notes,
      });
      return Goal.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<void> delete(String goalId) async {
    try {
      await _client.dio.delete('/goals/$goalId');
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
