/// API base URL config.
///
/// Default targets the piggybank-backend over its Tailscale MagicDNS domain
/// (`tiaanbossies-h81m-ds2.tail886b94.ts.net:8000`) rather than the raw
/// tailnet IP — the production host is locked down to Tailscale-only access
/// (see `plans/piggybank-full-suite-qa-v2.md` Step 0), and
/// `piggybank.fynboscreative.co.za` does not resolve to anything that serves
/// this app, so it cannot be the default. `:8000` is correct with the domain
/// too: `docker-compose.yml` maps `${BACKEND_BIND:-0.0.0.0}:${BACKEND_PORT:-8000}:8000`
/// and `.env.docker` binds to the same tailnet IP the domain resolves to, so
/// this hits the identical socket either way — Caddy (`:80`) is not in this
/// request path at all, only `/downloads/*` goes through it.
/// Override at build/run time with `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`
/// to point at a local Docker Desktop backend from the Android emulator instead.
abstract final class ApiConfig {
  static const _productionDomainDefault = 'http://tiaanbossies-h81m-ds2.tail886b94.ts.net:8000/api';

  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: _productionDomainDefault);

  /// Raw-tailnet-IP fallback for the production MagicDNS default, used by
  /// [ApiClient] only when a request to [baseUrl] fails at the connection
  /// level (no HTTP response at all — DNS failure, connect timeout, etc.),
  /// never for a real HTTP error response. Confirmed empirically, not
  /// theoretically: an Android emulator with no Tailscale client of its own
  /// running cannot resolve this MagicDNS name at all (`nslookup` against
  /// it fails outright) even though the same tailnet IP is reachable via
  /// routing — this is a genuine "MagicDNS resolution can fail" case the
  /// plan itself called out, not a hypothetical one, so shipping the domain
  /// with no fallback would be a real regression for some real devices.
  /// `null` when [baseUrl] has been overridden via `--dart-define` (local
  /// dev pointing at Docker Desktop, say) — a dev override must never
  /// silently fall back to hitting production.
  static const String? fallbackBaseUrl =
      baseUrl == _productionDomainDefault ? 'http://100.121.165.7:8000/api' : null;
}
