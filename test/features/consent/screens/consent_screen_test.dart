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
import 'package:piggybank/core/consents/consent_models.dart';
import 'package:piggybank/core/theme/shared_preferences_provider.dart';
import 'package:piggybank/features/consent/consent_documents.dart';
import 'package:piggybank/features/consent/data/consents_api.dart';
import 'package:piggybank/features/consent/screens/consent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockConsentsApi extends Mock implements ConsentsApi {}

class _MockAuthApi extends Mock implements AuthApi {}

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockLocalAuthentication extends Mock implements LocalAuthentication {}

class _MockOnboardingStore extends Mock implements OnboardingStore {}

const _user = User(id: 'u1', email: 'a@b.com', fullName: 'A B', role: 'user', isActive: true);

void main() {
  late _MockConsentsApi mockConsentsApi;
  late _MockAuthApi mockAuthApi;
  late _MockSecureStorage mockSecureStorage;
  late _MockLocalAuthentication mockLocalAuth;
  late _MockOnboardingStore mockOnboardingStore;
  late AuthController authController;
  late SharedPreferences prefs;

  setUp(() async {
    mockConsentsApi = _MockConsentsApi();
    mockAuthApi = _MockAuthApi();
    mockSecureStorage = _MockSecureStorage();
    mockLocalAuth = _MockLocalAuthentication();
    mockOnboardingStore = _MockOnboardingStore();
    when(() => mockSecureStorage.readRefreshToken()).thenAnswer((_) async => null);
    when(() => mockOnboardingStore.isPending(any())).thenReturn(false);

    authController = AuthController(
      authApi: mockAuthApi,
      secureStorage: mockSecureStorage,
      localAuth: mockLocalAuth,
      onboardingStore: mockOnboardingStore,
    );
    await Future<void>.delayed(Duration.zero);
    authController.state =
        const AuthState(status: AuthStatus.authenticated, accessToken: 'token', user: _user, locked: false);

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildScreen() => ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith((ref) => authController),
          consentsApiProvider.overrideWithValue(mockConsentsApi),
        ],
        child: const MaterialApp(home: ConsentScreen()),
      );

  testWidgets('already-accepted view shows short subtitles instead of the full, truncation-prone summaries',
      (tester) async {
    when(() => mockConsentsApi.listRequired()).thenAnswer(
      (_) async => consentDocuments
          .map((doc) => RequiredDocument(documentType: doc.documentType, documentVersion: doc.documentVersion))
          .toList(),
    );
    when(() => mockConsentsApi.listAccepted()).thenAnswer(
      (_) async => consentDocuments
          .map((doc) => ConsentRecord(
                id: 'c-${doc.documentType}',
                documentType: doc.documentType,
                documentVersion: doc.documentVersion,
                acceptedAt: DateTime(2026, 9, 1),
              ))
          .toList(),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text("You're up to date"), findsOneWidget);
    expect(find.text('How we handle your data'), findsOneWidget);
    expect(find.text('Rules for using the app'), findsOneWidget);
    for (final doc in consentDocuments) {
      expect(find.text(doc.summary), findsNothing);
    }
  });
}
