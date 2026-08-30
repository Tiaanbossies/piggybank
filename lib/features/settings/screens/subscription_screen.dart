import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_theme.dart';
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
              Text(
                'CURRENT PLAN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).extension<AppSemanticColors>()?.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              GroupCard(
                children: [
                  GroupRow(
                    leadingIcon: Icons.workspace_premium_outlined,
                    title: _tierLabel(sub.tier),
                    subtitle: sub.currentPeriodEnd != null
                        ? '${_statusLabel(sub.status)} · renews ${sub.currentPeriodEnd!.toLocal().toString().split(' ').first}'
                        : _statusLabel(sub.status),
                    trailing: _TierBadge(tier: sub.tier),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('What Pro unlocks', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _FeatureComparisonCard(isPro: sub.tier == SubscriptionTier.pro),
              const SizedBox(height: 16),
              if (_actionError != null) ...[
                Text(_actionError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
              ],
              if (sub.tier == SubscriptionTier.free)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _upgrade,
                    icon: _submitting ? null : const Icon(Icons.arrow_forward, size: 18),
                    label: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Upgrade to Pro'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _cancel,
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Cancel subscription'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small trailing badge distinguishing Pro (hero-gradient fill, matching the
/// same gradient as [HeroMetricCard]) from Free (muted accent chip) — per
/// DESIGN.md, the hero gradient is otherwise reserved for full-width top-of-
/// screen cards, so this reuses it at badge scale rather than introducing a
/// third "premium" colour.
class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});
  final SubscriptionTier tier;

  @override
  Widget build(BuildContext context) {
    final isPro = tier == SubscriptionTier.pro;
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: isPro
            ? const LinearGradient(colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd])
            : null,
        color: isPro ? null : semantic?.accentChipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPro ? 'PRO' : 'FREE',
        style: TextStyle(
          color: isPro ? Colors.white : Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Per §5.10's free-tier limits (3 accounts, 1 portfolio, zero AI features)
/// vs. Pro (999 of each, AI unlocked). A muted checklist, not a full pricing
/// table — the brief calls for "a generic 'Upgrade to PRO' prompt", not a
/// categorized breakdown, so this stays illustrative rather than exhaustive.
class _FeatureComparisonCard extends StatelessWidget {
  const _FeatureComparisonCard({required this.isPro});
  final bool isPro;

  static const _features = [
    'Unlimited accounts & portfolios',
    'AI-powered Insights',
    'AI Chatbot',
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final feature in _features) ...[
            Row(
              children: [
                Icon(isPro ? Icons.check_circle : Icons.check_circle_outline, size: 18, color: primary),
                const SizedBox(width: 10),
                Expanded(child: Text(feature, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
            if (feature != _features.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
