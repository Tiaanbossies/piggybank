import 'package:dio/dio.dart';

import 'api_error.dart';

/// Thin Dio wrapper implementing the same auth contract as
/// `frontend/src/api/client.ts`: attach the in-memory bearer token to every
/// request, and on a 401 (other than the request already being a retry),
/// attempt a silent refresh — coalescing concurrent 401s into a single
/// refresh call — then retry the original request once. On unrecoverable
/// refresh failure, [onSessionExpired] fires so the app can clear session
/// state, mirroring `client.ts`'s `auth:logout` event.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required String? Function() getAccessToken,
    required Future<bool> Function() refreshAccessToken,
    required void Function() onSessionExpired,
    Dio? dio,
  })  : _getAccessToken = getAccessToken,
        _refreshAccessToken = refreshAccessToken,
        _onSessionExpired = onSessionExpired,
        dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl)) {
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio dio;
  final String? Function() _getAccessToken;
  final Future<bool> Function() _refreshAccessToken;
  final void Function() _onSessionExpired;

  Future<bool>? _refreshInFlight;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['_retried'] == true;

    if (!isUnauthorized || alreadyRetried) {
      return handler.next(err);
    }

    _refreshInFlight ??= _refreshAccessToken().whenComplete(() => _refreshInFlight = null);
    final refreshed = await _refreshInFlight!;

    if (!refreshed) {
      _onSessionExpired();
      return handler.next(err);
    }

    try {
      final retryOptions = err.requestOptions;
      retryOptions.extra['_retried'] = true;
      retryOptions.headers['Authorization'] = 'Bearer ${_getAccessToken()}';
      final response = await dio.fetch(retryOptions);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  /// Converts a caught [DioException] into an [ApiError]. Call sites should
  /// catch `DioException` around `dio.get/post/patch/delete` and rethrow
  /// `ApiError.fromDioException(e)` so feature code only ever deals with
  /// [ApiError].
  static ApiError errorFrom(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == null) {
      return const ApiError(statusCode: 0, message: 'Network error. Check your connection and try again.');
    }
    return ApiError.fromResponse(statusCode, e.response?.data);
  }
}
