import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:local_auth/local_auth.dart';

import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/core/auth/auth_api.dart';
import 'package:piggybank/core/auth/auth_controller.dart';
import 'package:piggybank/core/auth/secure_storage.dart';
import 'package:piggybank/core/auth/user.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class FakeUser extends Fake implements User {
  @override
  final String id = 'user123';

  @override
  final String email = 'test@example.com';

  @override
  final String? fullName = 'Test User';
}

class FakeAuthenticationOptions extends Fake implements AuthenticationOptions {}

void main() {
  group('AuthController', () {
    late MockAuthApi mockAuthApi;
    late MockSecureStorage mockSecureStorage;
    late MockLocalAuthentication mockLocalAuth;
    late AuthController authController;

    setUpAll(() {
      registerFallbackValue(FakeAuthenticationOptions());
    });

    setUp(() {
      mockAuthApi = MockAuthApi();
      mockSecureStorage = MockSecureStorage();
      mockLocalAuth = MockLocalAuthentication();

      // Set default mock behavior for restoreSession to return null (no stored token)
      when(() => mockSecureStorage.readRefreshToken())
          .thenAnswer((_) async => null);

      authController = AuthController(
        authApi: mockAuthApi,
        secureStorage: mockSecureStorage,
        localAuth: mockLocalAuth,
      );
    });

    group('login', () {
      test('successful login stores refresh token and updates state', () async {
        const email = 'test@example.com';
        const password = 'password123';
        final tokenPair = TokenPair(
          accessToken: 'access_token_123',
          refreshToken: 'refresh_token_456',
        );
        final user = FakeUser();

        when(() => mockAuthApi.login(email: email, password: password))
            .thenAnswer((_) async => tokenPair);
        when(() => mockSecureStorage.writeRefreshToken('refresh_token_456'))
            .thenAnswer((_) async {});
        when(() => mockAuthApi.me('access_token_123'))
            .thenAnswer((_) async => user);

        await authController.login(email: email, password: password);

        verify(() => mockAuthApi.login(email: email, password: password)).called(1);
        verify(() => mockSecureStorage.writeRefreshToken('refresh_token_456')).called(1);
        verify(() => mockAuthApi.me('access_token_123')).called(1);
        expect(authController.state.isAuthenticated, true);
        expect(authController.state.locked, false);
        expect(authController.state.accessToken, 'access_token_123');
      });

      test('login with invalid credentials throws ApiError', () async {
        const email = 'bad@example.com';
        const password = 'wrong';

        when(() => mockAuthApi.login(email: email, password: password))
            .thenThrow(ApiError(statusCode: 401, message: 'Invalid credentials'));

        expect(
          () => authController.login(email: email, password: password),
          throwsA(isA<ApiError>()),
        );
        expect(authController.state.isAuthenticated, false);
      });
    });

    group('refresh token', () {
      test('successful refresh updates access token', () async {
        final newTokenPair = TokenPair(
          accessToken: 'new_access_token',
          refreshToken: 'new_refresh_token',
        );

        when(() => mockSecureStorage.readRefreshToken())
            .thenAnswer((_) async => 'old_refresh_token');
        when(() => mockAuthApi.refresh('old_refresh_token'))
            .thenAnswer((_) async => newTokenPair);
        when(() => mockSecureStorage.writeRefreshToken('new_refresh_token'))
            .thenAnswer((_) async {});

        final result = await authController.refreshAccessToken();

        expect(result, true);
        expect(authController.state.accessToken, 'new_access_token');
      });

      test('refresh with null response clears session', () async {
        when(() => mockSecureStorage.readRefreshToken())
            .thenAnswer((_) async => 'expired_token');
        when(() => mockAuthApi.refresh('expired_token'))
            .thenAnswer((_) async => null);
        when(() => mockSecureStorage.clearRefreshToken())
            .thenAnswer((_) async {});

        final result = await authController.refreshAccessToken();

        expect(result, false);
        expect(authController.state.isAuthenticated, false);
      });

      test('refresh with no refresh token returns false', () async {
        when(() => mockSecureStorage.readRefreshToken())
            .thenAnswer((_) async => null);

        final result = await authController.refreshAccessToken();

        expect(result, false);
      });
    });

    group('session restore', () {
      test('restoreSession with valid refresh token authenticates', () async {
        final tokenPair = TokenPair(
          accessToken: 'restored_access_token',
          refreshToken: 'restored_refresh_token',
        );
        final user = FakeUser();

        when(() => mockSecureStorage.readRefreshToken())
            .thenAnswer((_) async => 'valid_refresh_token');
        when(() => mockAuthApi.refresh('valid_refresh_token'))
            .thenAnswer((_) async => tokenPair);
        when(() => mockSecureStorage.writeRefreshToken('restored_refresh_token'))
            .thenAnswer((_) async {});
        when(() => mockAuthApi.me('restored_access_token'))
            .thenAnswer((_) async => user);

        final controller = AuthController(
          authApi: mockAuthApi,
          secureStorage: mockSecureStorage,
          localAuth: mockLocalAuth,
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(controller.state.isAuthenticated, true);
        expect(controller.state.locked, true);
      });

      test('restoreSession with no refresh token remains unauthenticated', () async {
        when(() => mockSecureStorage.readRefreshToken())
            .thenAnswer((_) async => null);

        final controller = AuthController(
          authApi: mockAuthApi,
          secureStorage: mockSecureStorage,
          localAuth: mockLocalAuth,
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(controller.state.isAuthenticated, false);
      });
    });

    group('biometric authentication', () {
      test('unlockWithBiometrics succeeds and clears lock flag', () async {
        authController.state = authController.state.copyWith(locked: true);
        expect(authController.state.locked, true);

        when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(() => mockLocalAuth.authenticate(
          localizedReason: 'Unlock Piggybank',
          options: any(named: 'options'),
        )).thenAnswer((_) async => true);

        final result = await authController.unlockWithBiometrics();

        expect(result, true);
        expect(authController.state.locked, false);
      });

      test('unlockWithBiometrics handles unavailable biometrics gracefully', () async {
        authController.state = authController.state.copyWith(locked: true);

        when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
        when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

        final result = await authController.unlockWithBiometrics();

        expect(result, true);
        expect(authController.state.locked, false);
      });
    });

    group('logout', () {
      test('logout clears refresh token and unauthenticates', () async {
        const email = 'test@example.com';
        const password = 'pass';
        final tokenPair = TokenPair(accessToken: 'token', refreshToken: 'refresh');
        final user = FakeUser();

        when(() => mockAuthApi.login(email: email, password: password))
            .thenAnswer((_) async => tokenPair);
        when(() => mockSecureStorage.writeRefreshToken('refresh'))
            .thenAnswer((_) async {});
        when(() => mockAuthApi.me('token'))
            .thenAnswer((_) async => user);
        when(() => mockSecureStorage.readRefreshToken())
            .thenAnswer((_) async => 'refresh');
        when(() => mockAuthApi.logout('refresh'))
            .thenAnswer((_) async {});
        when(() => mockSecureStorage.clearRefreshToken())
            .thenAnswer((_) async {});

        await authController.login(email: email, password: password);
        expect(authController.state.isAuthenticated, true);

        await authController.logout();

        verify(() => mockAuthApi.logout('refresh')).called(1);
        verify(() => mockSecureStorage.clearRefreshToken()).called(1);
        expect(authController.state.isAuthenticated, false);
      });
    });
  });
}
