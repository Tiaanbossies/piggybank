import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/app/app_build.dart';
import '../data/updates_api.dart';
import '../models/latest_release.dart';

/// Raw fetch of the latest published release, or `null` if none has been
/// published yet. `autoDispose` since this only needs to run once per
/// Dashboard visit, matching this app's other one-shot Dashboard fetches
/// (see `summaries_provider.dart`).
final latestReleaseProvider = FutureProvider.autoDispose<LatestRelease?>((ref) {
  return ref.watch(updatesApiProvider).latest();
});

/// Compares the latest published build number against this install's own
/// (`PackageInfo.fromPlatform()`, the same source `about_screen.dart` uses
/// for its version display). Resolves to the [LatestRelease] when a
/// genuinely newer build exists, or `null` when there's nothing to show
/// (no release published yet, already current, or a malformed build
/// number on either side — never surface a banner off a comparison that
/// can't be trusted).
final updateAvailableProvider = FutureProvider.autoDispose<LatestRelease?>((ref) async {
  final latest = await ref.watch(latestReleaseProvider.future);
  if (latest == null) return null;

  final info = await PackageInfo.fromPlatform();
  // Through AppBuild so a split-per-ABI install (versionCode 2009) still
  // compares as build 9.
  final currentBuild = AppBuild.buildNumber(info.buildNumber);
  final latestBuild = AppBuild.buildNumber(latest.buildNumber);
  if (currentBuild == null || latestBuild == null) return null;

  return latestBuild > currentBuild ? latest : null;
});
