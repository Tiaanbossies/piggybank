/// API base URL config.
///
/// Override at build/run time with `--dart-define=API_BASE_URL=https://...`
/// once Phase 7 settles on a real server. Default targets the Android
/// emulator's alias for the host machine's localhost (`10.0.2.2`), matching
/// finance-app.v3's local dev backend on port 8000 under the `/api` prefix.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
}
