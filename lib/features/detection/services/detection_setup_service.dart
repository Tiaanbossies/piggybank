import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../consent/consent_documents.dart';
import '../../consent/data/consents_api.dart';
import '../data/detection_api.dart';
import '../native/notification_listener_channel.dart';
import '../providers/detection_provider.dart';

/// Keeps notification capture from failing silently. A sideloaded
/// reinstall wipes the native allowlist and revokes notification access,
/// and nothing else notices: the listener just stops queuing.
class DetectionSetupService {
  DetectionSetupService(this._consents, this._api, this._channel);

  final ConsentsApi _consents;
  final DetectionApi _api;
  final NotificationListenerChannel _channel;

  Future<bool> _consentAccepted() async {
    final accepted = await _consents.listAccepted();
    return accepted.any(
      (c) =>
          c.documentType == notificationEmailDetectionConsentDocument.documentType &&
          c.documentVersion == notificationEmailDetectionConsentDocument.documentVersion,
    );
  }

  Future<List<String>> _activePackages() async {
    final sources = await _api.listNotificationSources();
    return sources.where((s) => s.isActive).map((s) => s.appPackageName).toList();
  }

  /// Re-pushes the backend's package allowlist to the native listener, so a
  /// reinstall recovers without the user opening the Detection settings
  /// screen. Called on launch and on every resume.
  Future<void> syncAllowlist() async {
    try {
      if (!await _consentAccepted()) return;
      await _channel.updateAllowlist(await _activePackages());
    } on ApiError {
      // Logged out or offline: the next resume tries again.
    }
  }

  /// True when detection is set up (consent given, at least one active
  /// source) but the system has notification access turned off, so
  /// nothing is being captured.
  Future<bool> needsNotificationAccess() async {
    if (!await _consentAccepted()) return false;
    if ((await _activePackages()).isEmpty) return false;
    return !await _channel.isEnabled();
  }
}

final detectionSetupServiceProvider = Provider<DetectionSetupService>(
  (ref) => DetectionSetupService(
    ref.watch(consentsApiProvider),
    ref.watch(detectionApiProvider),
    ref.watch(notificationListenerChannelProvider),
  ),
);

/// Drives Home's "capture is off" banner. Errors hide the banner, like the
/// review banner: a failed check shouldn't put an error on Home.
final notificationAccessMissingProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(detectionSetupServiceProvider).needsNotificationAccess(),
);
