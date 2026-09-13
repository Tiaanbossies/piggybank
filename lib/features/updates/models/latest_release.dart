/// Mirrors `piggybank-backend/backend/app/updates/schemas.py`'s
/// `LatestReleaseOut` — the response shape for `GET /updates/latest`.
/// `buildNumber` is what update comparisons key off (a simple monotonic
/// integer set by `scripts/publish_release.sh`), not [version], which can
/// repeat across builds during testing.
class LatestRelease {
  const LatestRelease({
    required this.version,
    required this.buildNumber,
    required this.filename,
    required this.publishedAt,
    required this.downloadUrl,
  });

  final String version;
  final String buildNumber;
  final String filename;
  final String publishedAt;
  final String downloadUrl;

  factory LatestRelease.fromJson(Map<String, dynamic> json) => LatestRelease(
        version: json['version'] as String,
        buildNumber: json['buildNumber'] as String,
        filename: json['filename'] as String,
        publishedAt: json['publishedAt'] as String,
        downloadUrl: json['downloadUrl'] as String,
      );
}
