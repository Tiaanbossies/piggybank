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
import 'package:piggybank/core/auth/secure_storage.dart';
import 'package:piggybank/core/auth/user.dart';
import 'package:piggybank/features/settings/data/notification_prefs_api.dart';
import 'package:piggybank/features/settings/screens/notifications_screen.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

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
  late AuthController authController;

  setUp(() async {
    mockAuthApi = MockAuthApi();
    mockSecureStorage = MockSecureStorage();
    mockLocalAuth = MockLocalAuthentication();
    when(() => mockSecureStorage.readRefreshToken()).thenAnswer((_) async => null);

    authController = AuthController(authApi: mockAuthApi, secureStorage: mockSecureStorage, localAuth: mockLocalAuth);
    await Future<void>.delayed(Duration.zero);
    authController.state = AuthState(status: AuthStatus.authenticated, accessToken: 'token', user: _user, locked: false);
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
        authControllerProvider.overrideWith((ref) => authController),
        notificationPrefsApiProvider.overrideWithValue(NotificationPrefsApi(client)),
      ],
      child: const MaterialApp(home: NotificationsScreen()),
    );
  }

  group('NotificationsScreen', () {
    testWidgets('both toggles default on when no preferences have ever been saved', (tester) async {
      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      expect(find.text('Budget alerts'), findsOneWidget);
      expect(find.text('Weekly summary'), findsOneWidget);
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(2));
      expect(switches.every((s) => s.value), isTrue);
    });

    testWidgets('reflects a previously saved preference', (tester) async {
      authController.state = authController.state.copyWith(
        user: const User(
          id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true,
          notificationPreferences: {'budget_alerts': false, 'weekly_summary': true},
        ),
      );
      await tester.pumpWidget(buildScreen(adapter: _FakeAdapter([])));
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, isFalse); // budget_alerts
      expect(switches[1].value, isTrue); // weekly_summary
    });

    testWidgets('toggling a switch PATCHes the full dict and refreshes the user', (tester) async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'id': 'u1', 'email': 'a@b.com', 'full_name': 'A B', 'role': 'user', 'is_active': true,
              'notification_preferences': {'budget_alerts': false, 'weekly_summary': true},
              'created_at': '2026-01-01T00:00:00Z', 'updated_at': '2026-01-01T00:00:00Z',
            }), // PATCH /auth/me
      ]);
      when(() => mockAuthApi.me('token')).thenAnswer((_) async => const User(
            id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true,
            notificationPreferences: {'budget_alerts': false, 'weekly_summary': true},
          ));

      await tester.pumpWidget(buildScreen(adapter: adapter));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(adapter.requestLog.single.path, '/auth/me');
      expect(adapter.requestLog.single.method, 'PATCH');
      expect(adapter.requestLog.single.data, {
        'notification_preferences': {'budget_alerts': false, 'weekly_summary': true},
      });
      expect(tester.widgetList<Switch>(find.byType(Switch)).first.value, isFalse);
    });
  });
}
