import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/auth/auth_api.dart';
import 'package:piggybank/core/auth/auth_controller.dart';
import 'package:piggybank/core/auth/auth_state.dart';
import 'package:piggybank/core/auth/onboarding_store.dart';
import 'package:piggybank/core/auth/secure_storage.dart';
import 'package:piggybank/core/auth/user.dart';
import 'package:piggybank/core/theme/shared_preferences_provider.dart';
import 'package:piggybank/features/settings/data/security_api.dart';
import 'package:piggybank/features/settings/screens/security_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class MockOnboardingStore extends Mock implements OnboardingStore {}

const _user = User(id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);
  final List<ResponseBody Function()> responses;
  int callCount = 0;
  final requestLog = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requestLog.add(options);
    final index = callCount < responses.length ? callCount : responses.length - 1;
    callCount++;
    return responses[index]();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _empty(int status) => ResponseBody.fromString('', status);
ResponseBody _json(int status, dynamic data) => ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late MockAuthApi mockAuthApi;
  late MockSecureStorage mockSecureStorage;
  late MockLocalAuthentication mockLocalAuth;
  late MockOnboardingStore mockOnboardingStore;
  late AuthController authController;
  late SharedPreferences prefs;

  setUp(() async {
    mockAuthApi = MockAuthApi();
    mockSecureStorage = MockSecureStorage();
    mockLocalAuth = MockLocalAuthentication();
    mockOnboardingStore = MockOnboardingStore();
    when(() => mockSecureStorage.readRefreshToken()).thenAnswer((_) async => null);
    when(() => mockOnboardingStore.isPending(any())).thenReturn(false);

    authController = AuthController(
      authApi: mockAuthApi,
      secureStorage: mockSecureStorage,
      localAuth: mockLocalAuth,
      onboardingStore: mockOnboardingStore,
    );
    await Future<void>.delayed(Duration.zero);
    authController.state = const AuthState(status: AuthStatus.authenticated, accessToken: 'token', user: _user, locked: false);

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildScreen({required _FakeAdapter adapter}) {
    final client = ApiClient(
      baseUrl: 'https://api.test',
      getAccessToken: () => 'token',
      refreshAccessToken: () async => false,
      onSessionExpired: () {},
    );
    client.dio.httpClientAdapter = adapter;

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith((ref) => authController),
        securityApiProvider.overrideWithValue(SecurityApi(client)),
        localAuthProvider.overrideWithValue(mockLocalAuth),
      ],
      child: const MaterialApp(home: SecurityScreen()),
    );
  }

  group('SecurityScreen', () {
    testWidgets('shows "Set PIN" and no "Remove PIN" row when no PIN is set', (tester) async {
      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      expect(find.text('Set PIN'), findsOneWidget);
      expect(find.text('Change PIN'), findsNothing);
      expect(find.text('Remove PIN'), findsNothing);
    });

    testWidgets('shows "Change PIN" and "Remove PIN" once a PIN is set', (tester) async {
      authController.state = authController.state.copyWith(user: const User(
        id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true, hasPin: true,
      ));
      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      expect(find.text('Change PIN'), findsOneWidget);
      expect(find.text('Remove PIN'), findsOneWidget);
    });

    testWidgets('turning biometric off with no PIN set is blocked with an error, switch stays on', (tester) async {
      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.textContaining('Set a PIN before turning off'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, true);
    });

    testWidgets('turning biometric off succeeds when a PIN is set', (tester) async {
      authController.state = authController.state.copyWith(user: const User(
        id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true, hasPin: true,
      ));
      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.textContaining('Set a PIN before turning off'), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
    });

    testWidgets('removing PIN while biometric is off is blocked with an error', (tester) async {
      authController.state = authController.state.copyWith(user: const User(
        id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true, hasPin: true,
      ));
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      // Turn biometric off first (allowed, since a PIN is set).
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove PIN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Turn on biometric unlock before removing'), findsOneWidget);
      // No password dialog should have appeared.
      expect(find.text('Current password'), findsNothing);
    });

    testWidgets('removing PIN with biometric on prompts for password and calls the API', (tester) async {
      authController.state = authController.state.copyWith(user: const User(
        id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true, hasPin: true,
      ));
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
      final adapter = _FakeAdapter([
        () => _empty(204), // DELETE /auth/pin
        () => _json(200, {
              'id': 'u1', 'email': 'a@b.com', 'full_name': 'A B', 'role': 'user', 'is_active': true,
              'has_pin': false,
              'created_at': '2026-01-01T00:00:00Z', 'updated_at': '2026-01-01T00:00:00Z',
            }), // /auth/me refresh
      ]);
      when(() => mockAuthApi.me('token')).thenAnswer((_) async => const User(
            id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true, hasPin: false,
          ));

      await tester.pumpWidget(buildScreen(adapter: adapter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Current password'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'password123');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(adapter.requestLog.single.path, '/auth/pin');
      expect(adapter.requestLog.single.method, 'DELETE');
      expect(find.text('Remove PIN'), findsNothing);
      expect(find.text('Set PIN'), findsOneWidget);
    });
  });
}
