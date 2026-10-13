import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] for the refresh token only.
///
/// The access token is deliberately never persisted here — it lives in
/// memory only, in [AuthController] (see DESIGN.md's note on this being the
/// one deliberate, platform-appropriate difference from the web app: the
/// refresh token needs client-side persistence on a native app, backed by
/// Keychain/Keystore rather than an httpOnly cookie).
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _refreshTokenKey = 'refresh_token';

  /// The session kept for "Log in with fingerprint" after a log out (QA A5).
  /// Separate from [_refreshTokenKey] so a cold start with only this one
  /// lands on the login screen, never straight into the app; it's only read
  /// after the device's biometric check passes.
  static const _biometricRefreshTokenKey = 'biometric_refresh_token';

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> writeRefreshToken(String token) => _storage.write(key: _refreshTokenKey, value: token);

  Future<void> clearRefreshToken() => _storage.delete(key: _refreshTokenKey);

  Future<String?> readBiometricRefreshToken() => _storage.read(key: _biometricRefreshTokenKey);

  Future<void> writeBiometricRefreshToken(String token) => _storage.write(key: _biometricRefreshTokenKey, value: token);

  Future<void> clearBiometricRefreshToken() => _storage.delete(key: _biometricRefreshTokenKey);
}
