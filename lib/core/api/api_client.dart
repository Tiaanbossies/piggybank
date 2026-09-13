import 'package:dio/dio.dart';

import 'api_error.dart';

/// Retries a connection-level failure (no HTTP response reached at all —
/// DNS failure, connect timeout, connection refused, etc.) against
/// [fallbackBaseUrl], resolving/advancing [handler] and returning `true` if
/// it took action, or returning `false` (leaving [handler] untouched) when
/// there's nothing to do — no fallback configured, this was a real HTTP
/// error response, or the fallback was already tried once for this request.
/// Shared by [ApiClient] and the raw-Dio `AuthApi` (see that class's own
/// doc comment for why it can't just route through [ApiClient] itself) so
/// both get identical MagicDNS-resolution-failure resilience — see
/// `ApiConfig.fallbackBaseUrl`'s doc comment for why this exists at all.
Future<bool> tryConnectionFallback(
  Dio dio,
  DioException err,
  ErrorInterceptorHandler handler,
  String? fallbackBaseUrl,
) async {
  if (fallbackBaseUrl == null || err.response != null || err.requestOptions.extra['_fallbackTried'] == true) {
    return false;
  }
  try {
    final retryOptions = err.requestOptions;
    retryOptions.baseUrl = fallbackBaseUrl;
    retryOptions.extra['_fallbackTried'] = true;
    final response = await dio.fetch(retryOptions);
    handler.resolve(response);
  } on DioException catch (fallbackError) {
    handler.next(fallbackError);
  }
  return true;
}

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
    required this._getAccessToken,
    required this._refreshAccessToken,
    required this._onSessionExpired,
    void Function()? onConsentsRequired,
    this.fallbackBaseUrl,
    Dio? dio,
    // ignore: prefer_initializing_formals
  })  : _onConsentsRequired = onConsentsRequired,
        // Short global defaults so a genuinely hung request fails fast; the
        // two AI-backed endpoints (chatbot, insights `ask`) that legitimately
        // take 10-26s+ override receiveTimeout per-request instead of raising
        // this default for every call (see fix-it plan Step 3 / QA H6).
        dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            )) {
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio dio;
  final String? Function() _getAccessToken;
  final Future<bool> Function() _refreshAccessToken;
  final void Function() _onSessionExpired;

  /// Raw-IP (or otherwise alternate) base URL to retry a request against
  /// when it fails at the connection level (no HTTP response reached at
  /// all) — see `ApiConfig.fallbackBaseUrl`'s doc comment for why this
  /// exists: a MagicDNS domain that fails to resolve on some devices/
  /// networks even though the underlying IP is reachable. `null` disables
  /// this entirely (the default for tests and any dev-override baseUrl).
  final String? fallbackBaseUrl;

  /// Optional notify-only hook: on a 403 consents-required response, calls
  /// this and lets the error still surface normally (no retry). Nullable so
  /// existing [ApiClient] constructions (tests, in particular) don't need
  /// to supply it.
  final void Function()? _onConsentsRequired;

  Future<bool>? _refreshInFlight;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    if (await tryConnectionFallback(dio, err, handler, fallbackBaseUrl)) return;

    if (err.response?.statusCode == 403) {
      final apiError = ApiError.fromResponse(403, err.response?.data);
      if (apiError.isConsentsRequired) _onConsentsRequired?.call();
      return handler.next(err);
    }

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
