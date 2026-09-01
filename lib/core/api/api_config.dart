/// API base URL config.
///
/// Default targets the piggybank-backend directly over Tailscale
/// (`100.121.165.7:8000`) — the production host is locked down to
/// Tailscale-only access (see `plans/piggybank-full-suite-qa-v2.md` Step 0),
/// and `piggybank.fynboscreative.co.za` does not resolve to anything that
/// serves this app, so it cannot be the default.
/// Override at build/run time with `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`
/// to point at a local Docker Desktop backend from the Android emulator instead.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://100.121.165.7:8000/api',
  );
}
