import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_config.dart';

// These run without an API_BASE_URL dart-define, so they see the production
// defaults. An override build intentionally has no fallback (see ApiConfig).
void main() {
  group('ApiConfig defaults', () {
    test('the default base URL is HTTPS and ends in /api', () {
      expect(ApiConfig.baseUrl, startsWith('https://'));
      expect(ApiConfig.baseUrl, endsWith('/api'));
    });

    test('the default carries no explicit port, since Funnel serves on 443', () {
      expect(Uri.parse(ApiConfig.baseUrl).hasPort, isFalse);
    });

    test('the production default keeps the tailnet-IP fallback', () {
      expect(ApiConfig.fallbackBaseUrl, 'http://100.121.165.7:8000/api');
    });
  });
}
