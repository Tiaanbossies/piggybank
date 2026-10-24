import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/group_card.dart';
import '../data/subscription_api.dart';
import '../models/subscription.dart';

final _subscriptionProvider = FutureProvider.autoDispose<Subscription>((ref) {
  return ref.watch(subscriptionApiProvider).fetch();
});

/// Per `stitch-design-brief.md` §8: "plan/tier display". Since
/// founder-review-fixes PR 1 there is nothing to buy or cancel in the app:
/// Pro is a free beta grant until the backend's `PRO_PROMO_UNTIL`, and paid
/// Pro will come through Google Play Billing. So this screen only says which
/// plan you're on and until when.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  static String planLine(Subscription sub) {
    if (sub.tier == SubscriptionTier.free) return 'Paid Pro is coming soon';
    final end = sub.currentPeriodEnd;
    if (sub.source == 'promo' || sub.source == null) {
      return end == null ? 'Free during the beta' : 'Free during the beta, until ${fullDate(end.toLocal())}';
    }
    return end == null ? 'Active' : 'Active until ${fullDate(end.toLocal())}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(_subscriptionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SafeArea(
        child: SkeletonSwitcher(child: subAsync.when(
          loading: () => const SkeletonPage(rows: 3),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(err is ApiError ? err.message : 'Something went wrong. Please try again.'),
            ),
          ),
          data: (sub) => LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            title: sub.tier == SubscriptionTier.pro ? 'Pro' : 'Free',
                            subtitle: planLine(sub),
                            trailing: _TierBadge(tier: sub.tier),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('What Pro unlocks', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 8),
                      _FeatureComparisonCard(isPro: sub.tier == SubscriptionTier.pro),
                    ],
                  ),
                ),
              );
            },
          ),
        )),
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
        color: isPro ? Theme.of(context).colorScheme.primary : semantic?.accentChipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPro ? 'PRO' : 'FREE',
        style: TextStyle(
          color: isPro ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
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
