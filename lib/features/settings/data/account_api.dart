import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';

/// POPIA self-service data-access/erasure rights: `GET /auth/me/export` and
/// `DELETE /auth/me`. `ApiClient`-based, mirrors [SecurityApi].
class AccountApi {
  AccountApi(this._client);
  final ApiClient _client;

  /// Everything the user owns, as a raw JSON map — no typed model on the
  /// client side either, mirroring the backend's deliberately-untyped export
  /// endpoint (see `backend/app/auth/data_export.py`).
  Future<Map<String, dynamic>> exportData() async {
    try {
      final response = await _client.dio.get('/auth/me/export');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Permanently deletes the account and all owned data. Throws [ApiError]
  /// with statusCode 401 on a wrong password.
  Future<void> deleteAccount(String currentPassword) async {
    try {
      await _client.dio.delete('/auth/me', data: {'current_password': currentPassword});
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final accountApiProvider = Provider<AccountApi>((ref) => AccountApi(ref.watch(apiClientProvider)));
