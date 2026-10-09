import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/auth/auth_controller.dart';
import 'package:piggybank/core/auth/auth_state.dart';
import 'package:piggybank/core/auth/user.dart';
import 'package:piggybank/core/router/placeholder_screens.dart';

const _user = User(id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true);

/// Records log-out calls; everything else on [AuthController] is unused here.
class _FakeAuthController extends StateNotifier<AuthState> implements AuthController {
  _FakeAuthController()
      : super(const AuthState(status: AuthStatus.authenticated, accessToken: 'token', user: _user, locked: false));

  int logouts = 0;

  @override
  Future<void> logout() async => logouts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuthController auth;

  setUp(() => auth = _FakeAuthController());

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith((ref) => auth)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('groups rows under Account, Preferences and Data sources', (tester) async {
    await pumpSettings(tester);

    final labels = ['Account', 'Subscription', 'Security', 'Privacy & consent', 'Preferences', 'Appearance',
        'Notifications', 'Data sources', 'Bank notifications & email', 'About', 'Log out'];
    final tops = [for (final l in labels) tester.getTopLeft(find.text(l)).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: '${labels[i]} should sit below ${labels[i - 1]}');
    }
  });

  testWidgets('Savings plan and Import history have left Settings', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Savings plan'), findsNothing);
    expect(find.text('Import history'), findsNothing);
    expect(find.text('Notification & email detection'), findsNothing);
  });

  testWidgets('has a back-arrow app bar titled Settings', (tester) async {
    await pumpSettings(tester);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Settings')), findsOneWidget);
  });

  testWidgets('Log out asks first; Cancel keeps you signed in', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings-log-out')));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.logouts, 0);
  });

  testWidgets('Log out signs out once confirmed', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings-log-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Log out')));
    await tester.pumpAndSettle();
    expect(auth.logouts, 1);
  });
}
