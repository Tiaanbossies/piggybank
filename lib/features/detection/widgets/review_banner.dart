import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/icon_chip.dart';
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openPendingReview(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const IconChip(icon: Icons.fact_check_outlined, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 1 ? '1 new transaction to review' : '$count new transactions to review',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text('Tap to confirm or discard', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
