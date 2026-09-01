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
import 'package:piggybank/core/auth/secure_storage.dart';
import 'package:piggybank/core/auth/user.dart';
import 'package:piggybank/core/theme/shared_preferences_provider.dart';
import 'package:piggybank/features/auth/screens/lock_screen.dart';
import 'package:piggybank/features/settings/data/security_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class FakeAuthenticationOptions extends Fake implements AuthenticationOptions {}

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

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthenticationOptions());
  });

  late MockAuthApi mockAuthApi;
  late MockSecureStorage mockSecureStorage;
  late MockLocalAuthentication mockLocalAuth;
  late AuthController authController;
  late SharedPreferences prefs;

  setUp(() async {
    mockAuthApi = MockAuthApi();
    mockSecureStorage = MockSecureStorage();
    mockLocalAuth = MockLocalAuthentication();
    when(() => mockSecureStorage.readRefreshToken()).thenAnswer((_) async => null);

    authController = AuthController(authApi: mockAuthApi, secureStorage: mockSecureStorage, localAuth: mockLocalAuth);
    await Future<void>.delayed(Duration.zero);

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
      ],
      child: const MaterialApp(home: LockScreen()),
    );
  }

  group('LockScreen', () {
    testWidgets('biometric enabled + PIN set: auto-prompts biometric, offers "Use PIN instead"', (tester) async {
      authController.state = const AuthState(
        status: AuthStatus.authenticated,
        accessToken: 'token',
        locked: true,
        user: User(id: 'u1', email: 'a@b.com', fullName: null, role: 'user', isActive: true, hasPin: true),
      );
      when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => false); // user cancels

      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      expect(find.text('Use PIN instead'), findsOneWidget);
      expect(authController.state.locked, true);
    });

    testWidgets('biometric disabled preference: goes straight to PIN entry, no biometric prompt', (tester) async {
      authController.state = const AuthState(
        status: AuthStatus.authenticated,
        accessToken: 'token',
        locked: true,
        user: User(id: 'u1', email: 'a@b.com', fullName: null, role: 'user', isActive: true, hasPin: true),
      );
      await prefs.setBool('biometric_enabled', false);

      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      verifyNever(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          ));
    });

    testWidgets('entering the correct PIN unlocks the app', (tester) async {
      authController.state = const AuthState(
        status: AuthStatus.authenticated,
        accessToken: 'token',
        locked: true,
        user: User(id: 'u1', email: 'a@b.com', fullName: null, role: 'user', isActive: true, hasPin: true),
      );
      await prefs.setBool('biometric_enabled', false);
      final adapter = _FakeAdapter([() => _empty(204)]);

      await tester.pumpWidget(buildScreen(adapter: adapter));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(authController.state.locked, false);
      expect(adapter.requestLog.single.path, '/auth/pin/verify');
    });

    testWidgets('a wrong PIN shows an error and stays locked', (tester) async {
      authController.state = const AuthState(
        status: AuthStatus.authenticated,
        accessToken: 'token',
        locked: true,
        user: User(id: 'u1', email: 'a@b.com', fullName: null, role: 'user', isActive: true, hasPin: true),
      );
      await prefs.setBool('biometric_enabled', false);
      final adapter = _FakeAdapter([() => _empty(401)]);

      await tester.pumpWidget(buildScreen(adapter: adapter));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect PIN'), findsOneWidget);
      expect(authController.state.locked, true);
    });

    testWidgets('no biometric hardware and no PIN set: never silently unlocks', (tester) async {
      authController.state = const AuthState(
        status: AuthStatus.authenticated,
        accessToken: 'token',
        locked: true,
        user: User(id: 'u1', email: 'a@b.com', fullName: null, role: 'user', isActive: true, hasPin: false),
      );
      when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      expect(authController.state.locked, true);
      expect(find.text('Use PIN instead'), findsNothing); // no PIN to fall back to
      expect(find.byType(TextField), findsNothing); // and no PIN entry shown either
    });
  });
}
