import 'package:clock/clock.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../../shared/widgets/mascot_moment.dart';
import '../../../shared/widgets/state_views.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../budgets/screens/budgets_screen.dart';
import '../../plan/screens/plan_screen.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../providers/left_to_spend_provider.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Home's hero (UX rework spec §2.1, decision D1): what's left to spend this
/// month, with today's spend under it. It answers "am I OK today and this
/// month?" without arithmetic, and it changes every day, which Net worth
/// didn't. Tapping it opens Plan › Budgets.
///
/// Red is used only in the over-budget state, its reserved meaning. The copy
/// states the number and never judges it.
class LeftToSpendHero extends ConsumerWidget {
  const LeftToSpendHero({this.now, super.key});

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = now ?? clock.now();
    final state = ref.watch(leftToSpendProvider);
    final month = _months[today.month - 1];

    final Widget child = state.when(
      loading: () => const SkeletonHero(key: ValueKey('loading'), progress: true),
      error: (err, _) => InlineError(
        key: const ValueKey('error'),
        message: err is ApiError ? err.message : "Couldn't load this month's budgets",
        onRetry: () => ref.invalidate(currentMonthBudgetProgressProvider),
      ),
      data: (value) => KeyedSubtree(
        key: const ValueKey('data'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(value: value, month: month, subline: _subline(ref, today)),
            // Never alongside over budget (spec §3.3).
            if (value is! OverBudget && ref.watch(todaySpendProvider).valueOrNull == Decimal.zero) const _QuietDay(),
          ],
        ),
      ),
    );

    return AnimatedSwitcher(
      duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      child: child,
    );
  }

  String _subline(WidgetRef ref, DateTime today) {
    final spent = ref.watch(todaySpendProvider).valueOrNull;
    final days = daysLeftInMonth(today);
    final daysText = switch (days) {
      0 => 'last day of the month',
      1 => '1 day left',
      _ => '$days days left',
    };
    return 'Spent today ${spent == null ? '—' : formatZAR(spent)} · $daysText';
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.value, required this.month, required this.subline});

  final LeftToSpend value;
  final String month;
  final String subline;

  void _openBudgets(BuildContext context, WidgetRef ref) {
    ref.read(planSegmentProvider.notifier).state = PlanSegment.budgets;
    context.go('/plan');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (value) {
      UnderBudget(:final amount, :final spentShare) => HeroMetricCard(
          key: const Key('left-to-spend-hero'),
          label: 'Left to spend · $month',
          value: formatZAR(amount),
          amount: amount.toDouble(),
          progress: spentShare,
          deltaText: subline,
          onTap: () => _openBudgets(context, ref),
        ),
      OverBudget(:final amount) => _OverBudgetCard(
          month: month,
          amount: amount,
          subline: subline,
          onTap: () => _openBudgets(context, ref),
        ),
      NoBudgets(:final spentThisMonth) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroMetricCard(
              label: 'Spent this month · $month',
              value: spentThisMonth == null ? '—' : formatZAR(spentThisMonth),
              amount: spentThisMonth?.toDouble(),
              deltaText: subline,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('hero-set-budget'),
                onPressed: () => showAddBudgetSheet(context),
                child: const Text('Set a monthly budget ›'),
              ),
            ),
          ],
        ),
    };
  }
}

/// The hero's over-budget form: the one place Home is red, as its reserved
/// meaning (spec §1.1). It keeps the hero's shape and type, on the danger
/// container, and states the number without judging it.
class _OverBudgetCard extends StatelessWidget {
  const _OverBudgetCard({required this.month, required this.amount, required this.subline, required this.onTap});

  final String month;
  final Decimal amount;
  final String subline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final figure = 'Over by ${HeroMetricCard.wholeRand(formatZAR(amount))}';
    return AppCard(
      key: const Key('hero-over-budget'),
      color: t.dangerContainer,
      onTap: onTap,
      semanticLabel: 'Budgets, $month, $figure',
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Budgets · $month', style: text.labelSmall?.copyWith(color: t.onDangerContainer)),
            const SizedBox(height: AppSpace.s8),
            Text(
              figure,
              style: text.displaySmall?.copyWith(
                color: t.onDangerContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(subline, style: text.bodySmall?.copyWith(color: t.onDangerContainer)),
          ],
        ),
      ),
    );
  }
}

/// "Quiet day so far" under Spent today, with Penny asleep (spec §3.3).
/// Static: it's a resting state, and nothing on a resting screen loops.
class _QuietDay extends StatelessWidget {
  const _QuietDay();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('hero-quiet-day'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const MascotMoment(asset: MascotMoment.sleeping, size: 28),
          const SizedBox(width: 8),
          Text('Quiet day so far', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
