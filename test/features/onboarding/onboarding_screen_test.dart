import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/auth/auth_api.dart';
import 'package:piggybank/core/auth/auth_controller.dart';
import 'package:piggybank/core/auth/auth_state.dart';
import 'package:piggybank/core/auth/onboarding_store.dart';
import 'package:piggybank/core/auth/secure_storage.dart';
import 'package:piggybank/core/auth/user.dart';
import 'package:piggybank/features/onboarding/screens/onboarding_screen.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class MockOnboardingStore extends Mock implements OnboardingStore {}

const _user = User(id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true);

const _pageTitles = [
  "Hi, I'm Penny!",
  'Your home base',
  'Grow what you have',
  'Stay on track',
  'Ask me anything',
  'Your data, secured',
  "You're all set",
];

void main() {
  late MockOnboardingStore mockOnboardingStore;
  late AuthController authController;

  setUp(() async {
    mockOnboardingStore = MockOnboardingStore();
    when(() => mockOnboardingStore.isPending(any())).thenReturn(false);
    when(() => mockOnboardingStore.clearPending(any())).thenAnswer((_) async {});
    final mockSecureStorage = MockSecureStorage();
    when(mockSecureStorage.readRefreshToken).thenAnswer((_) async => null);

    authController = AuthController(
      authApi: MockAuthApi(),
      secureStorage: mockSecureStorage,
      localAuth: MockLocalAuthentication(),
      onboardingStore: mockOnboardingStore,
    );
    await Future<void>.delayed(Duration.zero);
    authController.state = const AuthState(
      status: AuthStatus.authenticated,
      accessToken: 'token',
      user: _user,
      onboardingRequired: true,
    );
  });

  Widget buildScreen() {
    return ProviderScope(
      overrides: [authControllerProvider.overrideWith((ref) => authController)],
      child: const MaterialApp(home: OnboardingScreen()),
    );
  }

  /// Drives the PageView forward one slide. A single pump(duration) only
  /// establishes the driven-scroll animation's start timestamp; a leading
  /// empty pump() is needed before the elapsed-time pump actually moves it.
  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The active page-dot is rendered 20px wide, inactive dots 8px — count
  /// of active dots, read off each AnimatedContainer's target `width`.
  int activeDotCount(WidgetTester tester) {
    return tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((c) => c.constraints?.maxWidth == 20)
        .length;
  }

  testWidgets('all 7 pages are reachable via Next, in the documented order', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(milliseconds: 300));

    for (var i = 0; i < _pageTitles.length; i++) {
      expect(find.text(_pageTitles[i]), findsOneWidget, reason: 'page $i');
      if (i < _pageTitles.length - 1) await tapNext(tester);
    }
  });

  testWidgets('Skip is visible on every page except the last', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(milliseconds: 300));

    for (var i = 0; i < _pageTitles.length - 1; i++) {
      expect(find.text('Skip'), findsOneWidget, reason: 'page $i');
      await tapNext(tester);
    }
    expect(find.text('Skip'), findsNothing, reason: 'last page');
  });

  testWidgets('Skip calls completeOnboarding from any page', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(milliseconds: 300));
    await tapNext(tester);
    await tapNext(tester);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();

    verify(() => mockOnboardingStore.clearPending('u1')).called(1);
  });

  testWidgets('Get Started only appears on the final page and calls completeOnboarding', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(milliseconds: 300));

    for (var i = 0; i < _pageTitles.length - 1; i++) {
      expect(find.text('Get Started'), findsNothing, reason: 'page $i');
      await tapNext(tester);
    }
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pump();

    verify(() => mockOnboardingStore.clearPending('u1')).called(1);
  });

  testWidgets('page-dot indicator reflects the current page index', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(milliseconds: 300));

    expect(activeDotCount(tester), 1, reason: 'exactly one active dot on page 0');

    await tapNext(tester);
    expect(activeDotCount(tester), 1, reason: 'exactly one active dot on page 1');
  });
}
