import 'package:dio/dio.dart';

import '../api/api_config.dart';
import '../api/api_client.dart';
import 'user.dart';

/// Result of a successful login/refresh — mirrors
/// `backend/app/auth/schemas.py`'s `AccessTokenResponse`.
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

/// Raw (unauthenticated) client for `/api/auth/*`. Deliberately doesn't go
/// through [ApiClient]'s bearer/refresh interceptor — these endpoints either
/// don't need it (register/login) or are what the interceptor calls into
/// (refresh), which would otherwise be circular.
class AuthApi {
  AuthApi({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  final Dio _dio;

  Future<TokenPair> register({required String email, required String password, String? fullName}) async {
    await _post('/auth/register', {
      'email': email,
      'password': password,
      if (fullName != null) 'full_name': fullName,
    });
    return login(email: email, password: password);
  }

  Future<TokenPair> login({required String email, required String password}) async {
    final data = await _post('/auth/login', {'email': email, 'password': password});
    return TokenPair(accessToken: data['access_token'] as String, refreshToken: data['refresh_token'] as String);
  }

  /// Returns null (rather than throwing) on any failure — refresh failure is
  /// an expected, routine case (expired/revoked token), not exceptional.
  Future<TokenPair?> refresh(String refreshToken) async {
    try {
      final data = await _post('/auth/refresh', {'refresh_token': refreshToken});
      return TokenPair(accessToken: data['access_token'] as String, refreshToken: data['refresh_token'] as String);
    } on DioException {
      return null;
    }
  }

  Future<void> logout(String? refreshToken) async {
    try {
      await _post('/auth/logout', {if (refreshToken != null) 'refresh_token': refreshToken});
    } on DioException {
      // Best-effort — logging out locally still proceeds regardless.
    }
  }

  Future<User> me(String accessToken) async {
    try {
      final response = await _dio.get('/auth/me', options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(path, data: body);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiClient.errorFrom(e);
    }
  }
}
