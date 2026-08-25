/// API base URL config.
///
/// Default targets the piggybank-backend deployment on the home Ubuntu box
/// reachable over Tailscale (`100.121.165.7`, port 8000, `/api` prefix).
/// Override at build/run time with `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`
/// to point at a local Docker Desktop backend from the Android emulator instead.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://100.121.165.7:8000/api',
  );
}
