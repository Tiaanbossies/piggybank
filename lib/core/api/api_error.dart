/// Typed representation of finance-app.v3's backend error envelope.
///
/// Mirrors `frontend/src/lib/parseApiError.ts` and `backend/app/errors.py`:
/// - 422 validation: `{"detail": [{"field": "...", "message": "..."}]}`
/// - consents-required: `{"detail": {"error": "consent required", "missing": [...]}}`
/// - everything else: `{"detail": "<string>"}`
/// - 402: subscription/tier gate (not a standard case Dio treats specially)
class ApiError implements Exception {
  const ApiError({
    required this.statusCode,
    required this.message,
    this.fieldErrors,
    this.consentsMissing,
  });

  final int statusCode;

  /// Flat, user-displayable message — the single 422 field message, the
  /// plain-string `detail`, or a generic fallback.
  final String message;

  /// Populated only for 422 responses whose `detail` is a `{field,message}[]`
  /// array — maps dotted field path to its message for inline form errors.
  final Map<String, String>? fieldErrors;

  /// Populated only for the consents-required 403 shape.
  final List<Map<String, dynamic>>? consentsMissing;

  bool get isValidation => statusCode == 422;
  bool get isConsentsRequired => consentsMissing != null;
  bool get isPaywall => statusCode == 402;
  bool get isUnauthorized => statusCode == 401;

  /// Parses a decoded JSON response body (already the `Map` from
  /// `response.data`) into an [ApiError]. Falls back to a generic message
  /// if the shape doesn't match any known case (e.g. a network-level error
  /// with no body at all — callers should pass an empty map in that case).
  factory ApiError.fromResponse(int statusCode, dynamic body) {
    final detail = body is Map ? body['detail'] : null;

    if (statusCode == 422 && detail is List) {
      final fieldErrors = <String, String>{};
      String? first;
      for (final entry in detail) {
        if (entry is Map && entry['field'] is String && entry['message'] is String) {
          final field = entry['field'] as String;
          final message = entry['message'] as String;
          fieldErrors[field] = message;
          first ??= '$field: $message';
        }
      }
      return ApiError(
        statusCode: statusCode,
        message: first ?? 'Validation error',
        fieldErrors: fieldErrors.isEmpty ? null : fieldErrors,
      );
    }

    if (detail is Map && detail['error'] == 'consent required') {
      final missing = detail['missing'];
      return ApiError(
        statusCode: statusCode,
        message: 'Consent required',
        consentsMissing: missing is List ? missing.cast<Map<String, dynamic>>() : const [],
      );
    }

    if (detail is String) {
      return ApiError(statusCode: statusCode, message: detail);
    }

    return ApiError(statusCode: statusCode, message: 'Something went wrong. Please try again.');
  }

  @override
  String toString() => 'ApiError($statusCode: $message)';
}
