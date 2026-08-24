import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/api_error.dart';
import 'auth_api.dart';
import 'auth_state.dart';
import 'secure_storage.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController({required this._authApi, required this._secureStorage, required this._localAuth})
      : super(AuthState.initial) {
    restoreSession();
  }

  final AuthApi _authApi;
  final SecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  /// Called once at app startup: if a refresh token is already stored,
  /// silently re-authenticate and require an app-lock unlock before the UI
  /// unblurs. Otherwise the user lands on the login screen.
  Future<void> restoreSession() async {
    final refreshToken = await _secureStorage.readRefreshToken();
    if (refreshToken == null) {
      state = AuthState.unauthenticated();
      return;
    }
    final pair = await _authApi.refresh(refreshToken);
    if (pair == null) {
      await _secureStorage.clearRefreshToken();
      state = AuthState.unauthenticated();
      return;
    }
    await _secureStorage.writeRefreshToken(pair.refreshToken);
    final user = await _authApi.me(pair.accessToken);
    final consentsRequired = await _checkConsentsRequired(pair.accessToken);
    state = AuthState(
      status: AuthStatus.authenticated,
      accessToken: pair.accessToken,
      user: user,
      locked: true,
      consentsRequired: consentsRequired,
    );
  }

  Future<void> login({required String email, required String password}) async {
    final pair = await _authApi.login(email: email, password: password);
    await _secureStorage.writeRefreshToken(pair.refreshToken);
    final user = await _authApi.me(pair.accessToken);
    final consentsRequired = await _checkConsentsRequired(pair.accessToken);
    state = AuthState(
      status: AuthStatus.authenticated,
      accessToken: pair.accessToken,
      user: user,
      locked: false,
      consentsRequired: consentsRequired,
    );
  }

  Future<void> register({required String email, required String password, String? fullName}) async {
    final pair = await _authApi.register(email: email, password: password, fullName: fullName);
    await _secureStorage.writeRefreshToken(pair.refreshToken);
    final user = await _authApi.me(pair.accessToken);
    final consentsRequired = await _checkConsentsRequired(pair.accessToken);
    state = AuthState(
      status: AuthStatus.authenticated,
      accessToken: pair.accessToken,
      user: user,
      locked: false,
      consentsRequired: consentsRequired,
    );
  }

  /// Diffs `/consents/required` against `/consents/` to decide whether the
  /// `/consent` gate should show. Fails open (returns `false`) on a
  /// transient failure rather than blocking login entirely — the server
  /// still enforces consents on every gated call regardless, and
  /// [ApiClient]'s `onConsentsRequired` fallback catches it if the app
  /// proceeds without knowing.
  Future<bool> _checkConsentsRequired(String accessToken) async {
    try {
      final required = await _authApi.requiredConsents(accessToken);
      final accepted = await _authApi.acceptedConsents(accessToken);
      final acceptedPairs = accepted.map((c) => (c.documentType, c.documentVersion)).toSet();
      return required.any((doc) => !acceptedPairs.contains((doc.documentType, doc.documentVersion)));
    } catch (_) {
      return false;
    }
  }

  /// Re-runs the consents check and updates state — called after the
  /// consent screen submits its acceptances. The router's redirect listener
  /// clears the `/consent` gate automatically once this resolves to `false`.
  Future<void> refreshConsentStatus() async {
    final token = state.accessToken;
    if (token == null) return;
    final consentsRequired = await _checkConsentsRequired(token);
    state = state.copyWith(consentsRequired: consentsRequired);
  }

  /// Passed into [ApiClient] as its `onConsentsRequired` fallback: fires
  /// when any gated call surfaces a 403 consents-required response, even if
  /// [_checkConsentsRequired] missed it at login (e.g. the fail-open path,
  /// or a consent version bumped mid-session).
  void markConsentsRequired() {
    if (state.isAuthenticated) state = state.copyWith(consentsRequired: true);
  }

  Future<void> logout() async {
    final refreshToken = await _secureStorage.readRefreshToken();
    await _authApi.logout(refreshToken);
    await _secureStorage.clearRefreshToken();
    state = AuthState.unauthenticated();
  }

  /// Passed into [ApiClient] as its refresh callback — same rotation flow as
  /// [restoreSession], but returns success/failure instead of throwing, and
  /// only clears session on unrecoverable failure (matches
  /// `client.ts`'s `_silentRefresh`).
  Future<bool> refreshAccessToken() async {
    final refreshToken = await _secureStorage.readRefreshToken();
    if (refreshToken == null) return false;
    final pair = await _authApi.refresh(refreshToken);
    if (pair == null) {
      await handleSessionExpired();
      return false;
    }
    await _secureStorage.writeRefreshToken(pair.refreshToken);
    state = state.copyWith(accessToken: pair.accessToken);
    return true;
  }

  /// Re-fetches `/auth/me` and replaces [AuthState.user] — used after an
  /// action that changes server-side user state the client needs to see
  /// immediately (e.g. Security screen's set/remove PIN, which flips
  /// `User.hasPin`). No-op when not authenticated.
  Future<void> refreshUser() async {
    final token = state.accessToken;
    if (token == null) return;
    final user = await _authApi.me(token);
    state = state.copyWith(user: user);
  }

  Future<void> handleSessionExpired() async {
    await _secureStorage.clearRefreshToken();
    state = AuthState.unauthenticated();
  }

  /// No-hardware is deliberately NOT an auto-unlock path (regression fix,
  /// blueprint Step 5a) — a device with no biometric/device-credential
  /// capability must fall back to PIN entry (see [unlockWithPin]), never be
  /// silently unlocked.
  Future<bool> unlockWithBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canCheck) return false;
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock Piggybank',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (ok) state = state.copyWith(locked: false);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Verifies [pin] via [verifyPin] (typically `SecurityApi.verifyPin`,
  /// passed in rather than imported directly to avoid a circular import
  /// between core auth and the settings feature layer) and clears the lock
  /// flag on success. Returns `false` on a wrong PIN (401) without mutating
  /// state, matching [unlockWithBiometrics]'s failure contract.
  Future<bool> unlockWithPin(String pin, {required Future<void> Function(String pin) verifyPin}) async {
    try {
      await verifyPin(pin);
      state = state.copyWith(locked: false);
      return true;
    } on ApiError {
      return false;
    }
  }

  void lockApp() {
    if (state.isAuthenticated) state = state.copyWith(locked: true);
  }
}

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());
final authApiProvider = Provider<AuthApi>((ref) => AuthApi());
final localAuthProvider = Provider<LocalAuthentication>((ref) => LocalAuthentication());

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    authApi: ref.read(authApiProvider),
    secureStorage: ref.read(secureStorageProvider),
    localAuth: ref.read(localAuthProvider),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final controller = ref.read(authControllerProvider.notifier);
  return ApiClient(
    baseUrl: ApiConfig.baseUrl,
    getAccessToken: () => ref.read(authControllerProvider).accessToken,
    refreshAccessToken: controller.refreshAccessToken,
    onSessionExpired: controller.handleSessionExpired,
    onConsentsRequired: controller.markConsentsRequired,
  );
});
