import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_error.dart';

void main() {
  group('ApiError.fromResponse', () {
    test('422 field-errors array maps to fieldErrors and a "field: message" summary', () {
      final error = ApiError.fromResponse(422, {
        'detail': [
          {'field': 'email', 'message': 'value is not a valid email address'},
        ],
      });

      expect(error.isValidation, isTrue);
      expect(error.fieldErrors, {'email': 'value is not a valid email address'});
      expect(error.message, 'email: value is not a valid email address');
    });

    test('consents-required 403 shape is recognised distinctly from a plain 403', () {
      final error = ApiError.fromResponse(403, {
        'detail': {
          'error': 'consent required',
          'missing': [
            {'document_type': 'privacy_policy', 'document_version': '1.0'},
          ],
        },
      });

      expect(error.isConsentsRequired, isTrue);
      expect(error.consentsMissing, hasLength(1));
      expect(error.consentsMissing!.first['document_type'], 'privacy_policy');
      expect(error.requiresAppConsents, isTrue);
    });

    test('a 403 naming only the opt-in detection consent does not require the app-wide consents', () {
      final error = ApiError.fromResponse(403, {
        'detail': {
          'error': 'consent required',
          'missing': [
            {'document_type': 'notification_email_detection', 'document_version': '1.0'},
          ],
        },
      });

      expect(error.isConsentsRequired, isTrue);
      expect(error.requiresAppConsents, isFalse);
    });

    test('a 403 naming the detection consent and an app-wide document still requires the app-wide consents', () {
      final error = ApiError.fromResponse(403, {
        'detail': {
          'error': 'consent required',
          'missing': [
            {'document_type': 'notification_email_detection', 'document_version': '1.0'},
            {'document_type': 'terms_of_service', 'document_version': '1.0'},
          ],
        },
      });

      expect(error.requiresAppConsents, isTrue);
    });

    test('a consents-required 403 with no missing list still requires the app-wide consents', () {
      final error = ApiError.fromResponse(403, {
        'detail': {'error': 'consent required'},
      });

      expect(error.requiresAppConsents, isTrue);
    });

    test('plain-string detail (e.g. 401 invalid credentials) becomes the message', () {
      final error = ApiError.fromResponse(401, {'detail': 'invalid credentials'});
      expect(error.isUnauthorized, isTrue);
      expect(error.message, 'invalid credentials');
      expect(error.fieldErrors, isNull);
      expect(error.isConsentsRequired, isFalse);
      expect(error.requiresAppConsents, isFalse);
    });

    test('402 is recognised as a paywall/tier-gate error', () {
      final error = ApiError.fromResponse(402, {'detail': 'Pro tier required'});
      expect(error.isPaywall, isTrue);
    });

    test('unrecognised body shape falls back to a generic message, not a crash', () {
      final error = ApiError.fromResponse(500, {'detail': 'Internal server error'});
      expect(error.message, 'Internal server error');
    });

    test('missing/malformed body falls back to a generic message', () {
      final error = ApiError.fromResponse(500, null);
      expect(error.message, isNotEmpty);
    });
  });
}
