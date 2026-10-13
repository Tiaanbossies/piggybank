import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/app/app_build.dart';

void main() {
  group('AppBuild.buildNumber', () {
    test('reads a plain build number as-is', () {
      expect(AppBuild.buildNumber('9'), 9);
      expect(AppBuild.buildNumber('10'), 10);
    });

    test('strips the split-per-ABI offset (arm64 build 9 reports 2009)', () {
      expect(AppBuild.buildNumber('2009'), 9);
      expect(AppBuild.buildNumber('1010'), 10);
      expect(AppBuild.buildNumber('3012'), 12);
    });

    test('a malformed number is null, never a guess', () {
      expect(AppBuild.buildNumber(''), isNull);
      expect(AppBuild.buildNumber('abc'), isNull);
    });
  });

  group('AppBuild.builtLabel', () {
    test('falls back to the install date when no BUILD_DATE was passed', () {
      // Tests run without --dart-define, so AppBuild.date is empty.
      expect(AppBuild.builtLabel(installed: DateTime(2026, 10, 12)), 'installed 12 Oct 2026');
    });

    test('is null when there is no date at all', () {
      expect(AppBuild.builtLabel(), isNull);
    });
  });
}
