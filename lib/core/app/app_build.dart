import '../format/dates.dart';

/// What this install was built from, for Settings → About and the update
/// check.
abstract final class AppBuild {
  /// The build's date, `YYYY-MM-DD`, passed by `scripts/build_release.sh`
  /// as `--dart-define=BUILD_DATE=...`. Empty in debug runs and tests.
  static const date = String.fromEnvironment('BUILD_DATE');

  /// The pubspec build number behind [raw], Android's versionCode.
  ///
  /// An APK built with `--split-per-abi` adds 1000 × the ABI number to the
  /// versionCode (arm64 build 9 reports 2009), so anything from 1000 up is
  /// reduced back to the build it came from. Without this, a split install
  /// showed "1.0.8 (2009)" in About and never saw an update banner, because
  /// a published build 10 is never greater than 2009 (QA pass 1).
  static int? buildNumber(String raw) {
    final n = int.tryParse(raw);
    if (n == null) return null;
    return n >= 1000 ? n % 1000 : n;
  }

  /// "built 12 Oct 2026" from [date], else from [installed] (when the APK
  /// was installed: close to the build for sideloaded releases), else null.
  static String? builtLabel({DateTime? installed}) {
    final parsed = DateTime.tryParse(date) ?? installed;
    if (parsed == null) return null;
    final prefix = date.isEmpty ? 'installed' : 'built';
    return '$prefix ${fullDate(parsed)}';
  }
}
