import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/user_category.dart';

/// Wraps `backend/app/categories/router.py`. The list call also adds any
/// category already in use on a transaction, budget or goal, so it is
/// always the complete set.
class CategoriesApi {
  CategoriesApi(this._client);
  final ApiClient _client;

  Future<List<UserCategory>> list() async {
    try {
      final response = await _client.dio.get('/categories/');
      return [for (final c in response.data as List<dynamic>) UserCategory.fromJson(c as Map<String, dynamic>)];
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<UserCategory> create(String name, {CategoryKind kind = CategoryKind.expense}) async {
    try {
      final response = await _client.dio.post('/categories/', data: {'name': name, 'kind': kind.name});
      return UserCategory.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// A rename moves every transaction, budget and goal filed under the old
  /// name to the new one, server-side.
  Future<UserCategory> update(String id, {String? name, CategoryKind? kind}) async {
    try {
      final response = await _client.dio.patch('/categories/$id', data: {
        'name': ?name,
        if (kind != null) 'kind': kind.name,
      });
      return UserCategory.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Moves everything filed under the category to [reassignTo] first.
  Future<void> delete(String id, {required String reassignTo}) async {
    try {
      await _client.dio.delete('/categories/$id', queryParameters: {'reassign_to': reassignTo});
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}
