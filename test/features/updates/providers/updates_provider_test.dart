import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/features/updates/data/updates_api.dart';
import 'package:piggybank/features/updates/models/latest_release.dart';
import 'package:piggybank/features/updates/providers/updates_provider.dart';

class _MockUpdatesApi extends Mock implements UpdatesApi {}

LatestRelease _release({required String buildNumber, String version = '1.4.0'}) => LatestRelease(
      version: version,
      buildNumber: buildNumber,
      filename: 'piggybank-$version.apk',
      publishedAt: '2026-09-13T12:00:00Z',
      downloadUrl: 'http://tiaanbossies-h81m-ds2.tail886b94.ts.net/downloads/piggybank-$version.apk',
    );

void main() {
  late _MockUpdatesApi api;
  late ProviderContainer container;

  setUp(() {
    api = _MockUpdatesApi();
    container = ProviderContainer(overrides: [updatesApiProvider.overrideWithValue(api)]);
    // This install's own build number, as `about_screen.dart` reads it via
    // the same `PackageInfo.fromPlatform()` call.
    PackageInfo.setMockInitialValues(
      appName: 'Piggybank',
      packageName: 'za.co.fynboscreative.piggybank',
      version: '1.3.0',
      buildNumber: '41',
      buildSignature: '',
    );
  });

  tearDown(() => container.dispose());

  group('updateAvailableProvider', () {
    test('resolves to the release when the remote build number is greater', () async {
      when(() => api.latest()).thenAnswer((_) async => _release(buildNumber: '42'));

      final result = await container.read(updateAvailableProvider.future);

      expect(result, isNotNull);
      expect(result!.buildNumber, '42');
    });

    test('resolves to null when the remote build number equals this install\'s own', () async {
      when(() => api.latest()).thenAnswer((_) async => _release(buildNumber: '41'));

      final result = await container.read(updateAvailableProvider.future);

      expect(result, isNull);
    });

    test('resolves to null when the remote build number is lower (already newer than published)', () async {
      when(() => api.latest()).thenAnswer((_) async => _release(buildNumber: '40'));

      final result = await container.read(updateAvailableProvider.future);

      expect(result, isNull);
    });

    test('resolves to null when no release has ever been published', () async {
      when(() => api.latest()).thenAnswer((_) async => null);

      final result = await container.read(updateAvailableProvider.future);

      expect(result, isNull);
    });

    test('resolves to null rather than throwing when a build number is not numeric', () async {
      when(() => api.latest()).thenAnswer((_) async => _release(buildNumber: 'not-a-number'));

      final result = await container.read(updateAvailableProvider.future);

      expect(result, isNull);
    });
  });
}
