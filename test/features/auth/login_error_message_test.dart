import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/auth/screens/login_screen.dart';

void main() {
  group('loginErrorMessage', () {
    test('a wrong email or password reads plainly, not as "invalid credentials"', () {
      final error = ApiError.fromResponse(401, {'detail': 'invalid credentials'});
      expect(loginErrorMessage(error), 'Incorrect email or password.');
    });

    test("a password too short to be valid is just a wrong password, not the validator's words", () {
      final error = ApiError.fromResponse(422, {
        'detail': [
          {'field': 'password', 'message': 'String should have at least 8 characters'},
        ],
      });
      expect(loginErrorMessage(error), 'Incorrect email or password.');
    });

    test('a malformed email asks for a valid one', () {
      final error = ApiError.fromResponse(422, {
        'detail': [
          {'field': 'email', 'message': 'value is not a valid email address'},
        ],
      });
      expect(loginErrorMessage(error), 'Enter a valid email address.');
    });

    test('anything else keeps the server message', () {
      final error = ApiError.fromResponse(503, {'detail': 'Service unavailable'});
      expect(loginErrorMessage(error), 'Service unavailable');
    });
  });
}
