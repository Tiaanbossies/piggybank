import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_banner.dart';
import '../models/detected_event.dart';
import '../providers/detection_provider.dart';
import '../screens/pending_review_screen.dart';
import '../services/detection_setup_service.dart';

/// How many detected transactions are waiting for review. UI-only, derived
/// from [pendingEventsProvider]: 0 while loading and on error, so callers
/// can hide themselves instead of surfacing a detection error.
///
/// Counts only `pending` events: `skipped_invalid` rows can merely be
/// discarded, and nagging about them would cry wolf.
final pendingReviewCountProvider = Provider.autoDispose<int>((ref) {
  final events = ref.watch(pendingEventsProvider).valueOrNull;
  return events?.where((e) => e.status == DetectionStatus.pending).length ?? 0;
});

/// Opens the review queue. Shared by the banner and the Transactions tab's
/// Review action.
void openPendingReview(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PendingReviewScreen()));

/// "N new to review": the daily loop's front door to one-tap review, shown
/// on Home and at the top of the Transactions tab (UX rework spec §2.1,
/// §2.2). Hidden at 0 — detection off, or consent not given, is a normal
/// state, not something to put on a daily screen.
class ReviewBanner extends ConsumerWidget {
  const ReviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingReviewCountProvider);
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
      child: AppBanner(
        key: const Key('review-banner'),
        icon: Icons.fact_check_outlined,
        message: count == 1 ? '1 new transaction to review' : '$count new transactions to review',
        onTap: () => openPendingReview(context),
      ),
    );
  }
}

/// "Capture is off": detection is set up but Android has notification
/// access turned off, so bank notifications go nowhere. A sideloaded
/// reinstall does this, and Android 13 then blocks the toggle as a
/// restricted setting, so the message names that unlock step too. Not
/// dismissible: a silent capture gap is what this exists to stop.
class NotificationAccessBanner extends ConsumerWidget {
  const NotificationAccessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(notificationAccessMissingProvider).valueOrNull != true) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
      child: AppBanner(
        key: const Key('notification-access-banner'),
        icon: Icons.notifications_off_outlined,
        message: "Bank notifications aren't being captured. Open App info > ⋮ > "
            'Allow restricted settings, then turn on notification access',
        onTap: () => ref.read(notificationListenerChannelProvider).openSystemSettings(),
      ),
    );
  }
}
