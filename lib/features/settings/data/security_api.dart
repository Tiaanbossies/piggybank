import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';

/// `ApiClient`-based, mirrors `SubscriptionApi`/`ConsentsApi`. Wraps
/// Step 4a's three `/auth/pin*` endpoints on `finance-app.v3-main`'s
/// backend, all of which return 204 with no body.
class SecurityApi {
  SecurityApi(this._client);
  final ApiClient _client;

  /// Sets or changes the PIN (same endpoint covers both — the backend has
  /// no separate "change" path). Requires the current password as re-auth.
  Future<void> setPin({required String currentPassword, required String pin}) async {
    try {
      await _client.dio.post('/auth/pin', data: {'current_password': currentPassword, 'pin': pin});
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Throws [ApiError] with statusCode 401 on a wrong PIN.
  Future<void> verifyPin(String pin) async {
    try {
      await _client.dio.post('/auth/pin/verify', data: {'pin': pin});
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  /// Requires the current password as re-auth.
  Future<void> removePin(String currentPassword) async {
    try {
      await _client.dio.delete('/auth/pin', data: {'current_password': currentPassword});
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}

final securityApiProvider = Provider<SecurityApi>((ref) => SecurityApi(ref.watch(apiClientProvider)));
