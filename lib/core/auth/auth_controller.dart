import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import 'auth_api.dart';
import 'auth_state.dart';
import 'secure_storage.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController({required AuthApi authApi, required SecureStorage secureStorage, required LocalAuthentication localAuth})
      : _authApi = authApi,
        _secureStorage = secureStorage,
        _localAuth = localAuth,
        super(AuthState.initial) {
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
    state = AuthState(status: AuthStatus.authenticated, accessToken: pair.accessToken, user: user, locked: true);
  }

  Future<void> login({required String email, required String password}) async {
    final pair = await _authApi.login(email: email, password: password);
    await _secureStorage.writeRefreshToken(pair.refreshToken);
    final user = await _authApi.me(pair.accessToken);
    state = AuthState(status: AuthStatus.authenticated, accessToken: pair.accessToken, user: user, locked: false);
  }

  Future<void> register({required String email, required String password, String? fullName}) async {
    final pair = await _authApi.register(email: email, password: password, fullName: fullName);
    await _secureStorage.writeRefreshToken(pair.refreshToken);
    final user = await _authApi.me(pair.accessToken);
    state = AuthState(status: AuthStatus.authenticated, accessToken: pair.accessToken, user: user, locked: false);
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

  Future<void> handleSessionExpired() async {
    await _secureStorage.clearRefreshToken();
    state = AuthState.unauthenticated();
  }

  Future<bool> unlockWithBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canCheck) {
        state = state.copyWith(locked: false);
        return true;
      }
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
    onSessionExpired: () => controller.handleSessionExpired(),
  );
});
