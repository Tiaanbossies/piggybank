/// API base URL config.
///
/// The default is the host's public HTTPS address, published by Tailscale Funnel
/// (`docs/runbook.md` in piggybank-backend, "Public HTTPS via Tailscale Funnel").
/// Funnel serves the same MagicDNS name the tailnet already uses, on the standard
/// HTTPS port, so testers without Tailscale can reach the API. Do not ship a build
/// with this default until Funnel is on, or every request fails.
///
/// Override at build/run time with `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`
/// to point at a local Docker Desktop backend from the Android emulator instead.
abstract final class ApiConfig {
  static const _productionDomainDefault = 'https://tiaanbossies-h81m-ds2.tail886b94.ts.net/api';

  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: _productionDomainDefault);

  /// Raw-tailnet-IP fallback for the production default, used by
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
