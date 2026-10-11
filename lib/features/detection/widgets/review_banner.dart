import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_banner.dart';
import '../models/detected_event.dart';
import '../providers/detection_provider.dart';
import '../screens/pending_review_screen.dart';

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
