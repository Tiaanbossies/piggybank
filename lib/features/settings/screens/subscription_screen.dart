import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/widgets/group_card.dart';
import '../data/subscription_api.dart';
import '../models/subscription.dart';

final _subscriptionProvider = FutureProvider.autoDispose<Subscription>((ref) {
  return ref.watch(subscriptionApiProvider).fetch();
});

/// Per `stitch-design-brief.md` §8: "plan/tier display, upgrade CTA". No real
/// payment flow exists yet — `upgrade`/`cancel` are backend-mocked (30-day
/// grant / instant revert), matching `paywall_dialog.dart`'s own
/// "currently mocked" note.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _submitting = false;
  String? _actionError;

  Future<void> _upgrade() => _runAction(() => ref.read(subscriptionApiProvider).upgrade());

  Future<void> _cancel() => _runAction(() => ref.read(subscriptionApiProvider).cancel());

  Future<void> _runAction(Future<Subscription> Function() action) async {
    setState(() {
      _submitting = true;
      _actionError = null;
    });
    try {
      await action();
      ref.invalidate(_subscriptionProvider);
    } on ApiError catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _tierLabel(SubscriptionTier tier) => switch (tier) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.pro => 'Pro',
      };

  String _statusLabel(SubscriptionStatus status) => switch (status) {
        SubscriptionStatus.active => 'Active',
        SubscriptionStatus.cancelled => 'Cancelled',
        SubscriptionStatus.pastDue => 'Past due',
      };

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(_subscriptionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SafeArea(
        child: subAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(err is ApiError ? err.message : 'Something went wrong. Please try again.'),
            ),
          ),
          data: (sub) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GroupCard(
                children: [
                  GroupRow(
                    leadingIcon: Icons.workspace_premium_outlined,
                    title: _tierLabel(sub.tier),
                    subtitle: sub.currentPeriodEnd != null
                        ? '${_statusLabel(sub.status)} · renews ${sub.currentPeriodEnd!.toLocal().toString().split(' ').first}'
                        : _statusLabel(sub.status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_actionError != null) ...[
                Text(_actionError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
              ],
              if (sub.tier == SubscriptionTier.free)
                ElevatedButton(
                  onPressed: _submitting ? null : _upgrade,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Upgrade to Pro'),
                )
              else
                OutlinedButton(
                  onPressed: _submitting ? null : _cancel,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Cancel subscription'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
