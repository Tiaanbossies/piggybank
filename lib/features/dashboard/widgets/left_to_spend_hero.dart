import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_motion.dart';
import '../../../shared/widgets/hero_metric_card.dart';
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
    final today = now ?? DateTime.now();
    final state = ref.watch(leftToSpendProvider);
    final month = _months[today.month - 1];

    final Widget child = state.when(
      loading: () => const SizedBox(
        key: ValueKey('loading'),
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => InlineError(
        key: const ValueKey('error'),
        message: err is ApiError ? err.message : "Couldn't load this month's budgets",
        onRetry: () => ref.invalidate(currentMonthBudgetProgressProvider),
      ),
      data: (value) => KeyedSubtree(
        key: const ValueKey('data'),
        child: _Hero(value: value, month: month, subline: _subline(ref, today)),
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
      UnderBudget(:final amount) => _Tappable(
          onTap: () => _openBudgets(context, ref),
          child: HeroMetricCard(label: 'Left to spend · $month', value: formatZAR(amount), deltaText: subline),
        ),
      OverBudget(:final amount) => _Tappable(
          onTap: () => _openBudgets(context, ref),
          child: _OverBudgetCard(month: month, amount: amount, subline: subline),
        ),
      NoBudgets(:final spentThisMonth) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroMetricCard(
              label: 'Spent this month · $month',
              value: spentThisMonth == null ? '—' : formatZAR(spentThisMonth),
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

/// The hero's over-budget form. The green gradient can't carry red text, so
/// the card itself takes the error container colours.
class _OverBudgetCard extends StatelessWidget {
  const _OverBudgetCard({required this.month, required this.amount, required this.subline});

  final String month;
  final Decimal amount;
  final String subline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('hero-over-budget'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Budgets · $month', style: text.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
          const SizedBox(height: 6),
          Text(
            'Over by ${formatZAR(amount)}',
            style: text.headlineLarge?.copyWith(color: scheme.onErrorContainer, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(subline, style: text.labelMedium?.copyWith(color: scheme.onErrorContainer)),
        ],
      ),
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(key: const Key('left-to-spend-hero'), onTap: onTap, child: child),
    );
  }
}
