import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../../shared/widgets/progress_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../summaries/models/summaries.dart';
import '../../summaries/providers/summaries_provider.dart';
import '../../transactions/category_icons.dart';
import '../models/month_budget_usage.dart';
import '../providers/trends_provider.dart';

/// Trends — the app's analytics surface: net worth over time, budget
/// adherence across the trailing window, and spending-pattern callouts.
///
/// Reached by tapping the Trends card on the Dashboard
/// (`Navigator.push`, like Accounts/Assets/Liabilities), **not** a sixth
/// bottom-nav tab: DESIGN.md § Navigation locks the shell at five.
///
/// Deliberately named "trends", never "insights". The backend keeps a live,
/// unrelated `/insights` AI Q&A router, and asking questions about your
/// finances remains solely the Assistant tab's job — nothing on this screen
/// takes a question.
///
/// Composes only the established vocabulary — [HeroMetricCard] (once, at the
/// top), [ProgressCard] per month, the Dashboard's stat-strip card pattern,
/// and [GroupCard]/[GroupRow] rows — per `docs/stitch-design-brief.md` §8's
/// instruction not to invent a fourth visual language for this screen.
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(netWorthTrendHistoryProvider);
            for (final month in trailingMonthKeys()) {
              ref.invalidate(budgetUsageProvider(month));
            }
            ref.invalidate(budgetAdherenceTrendProvider);
            ref.invalidate(highCostExpensesProvider);
            ref.invalidate(recurringExpensesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _NetWorthTrendHero(),
              SizedBox(height: 24),
              _SectionHeading('Budget adherence', subtitle: 'Last $trendWindowMonths months'),
              SizedBox(height: 8),
              _BudgetAdherenceTrend(),
              SizedBox(height: 16),
              _SectionHeading('Spending patterns', subtitle: 'This month'),
              SizedBox(height: 8),
              _HighCostStatStrip(),
              SizedBox(height: 16),
              _RecurringExpensesList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null)
          Text(subtitle!, style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
      ],
    );
  }
}

/// Shared shell for a section's loading/error placeholder so every async
/// block on this screen reserves the same height and reads identically —
/// matching `BudgetsBody`'s `AnimatedSwitcher`-over-`AsyncValue.when`
/// structure rather than each section inventing its own.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: child));
  }
}

Widget _loadingCard() => const _SectionCard(
      key: ValueKey('loading'),
      child: SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
    );

Widget _errorCard(Object err, String fallback) => _SectionCard(
      key: const ValueKey('error'),
      child: InlineError(message: err is ApiError ? err.message : fallback),
    );

AnimatedSwitcher _asyncSection(BuildContext context, Widget child) => AnimatedSwitcher(
      duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      child: child,
    );

/// Net worth over time. The one hero card on this screen, per DESIGN.md
/// § Signature components ("used once per screen, at the top").
///
/// Snapshots are written daily by the backend job, so a brand-new account
/// legitimately has none — that's an empty state, not an error.
class _NetWorthTrendHero extends ConsumerWidget {
  const _NetWorthTrendHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(netWorthTrendHistoryProvider);

    return _asyncSection(
      context,
      historyAsync.when(
        loading: _loadingCard,
        error: (err, _) => _errorCard(err, 'Failed to load your net-worth history'),
        data: (snapshots) {
          if (snapshots.isEmpty) {
            return const EmptyState(
              key: ValueKey('empty'),
              icon: Icons.show_chart,
              title: 'No net-worth history yet.',
              hint: 'Your net worth is recorded once a day — check back in a few days.',
              topPadding: 24,
            );
          }
          final sorted = [...snapshots]..sort((a, b) => a.snapshotDate.compareTo(b.snapshotDate));
          return HeroMetricCard(
            key: const ValueKey('data'),
            label: 'Net worth · last $trendWindowMonths months',
            value: formatZAR(sorted.last.netWorth),
            deltaText: _deltaText(sorted),
          );
        },
      ),
    );
  }

  /// "+4.2% since Mar 2026"-style pill, or null when the window holds a
  /// single snapshot (nothing to compare against) or the earliest figure is
  /// zero (a percentage change from zero is meaningless, not infinite).
  static String? _deltaText(List<NetWorthSnapshot> sorted) {
    if (sorted.length < 2) return null;
    final first = sorted.first;
    final last = sorted.last;
    if (first.netWorth == Decimal.zero) return null;
    final pct = (last.netWorth - first.netWorth).toDouble() / first.netWorth.abs().toDouble() * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}% since ${monthLabel(first.snapshotDate)}';
  }
}

/// One [ProgressCard] per month of the trailing window. A month with no
/// budget set renders as a muted "not set" row rather than being dropped,
/// so gaps stay visible instead of quietly compressing the timeline.
class _BudgetAdherenceTrend extends ConsumerWidget {
  const _BudgetAdherenceTrend();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(budgetAdherenceTrendProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    return _asyncSection(
      context,
      trendAsync.when(
        loading: _loadingCard,
        error: (err, _) => _errorCard(err, 'Failed to load your budget history'),
        data: (months) {
          if (!months.any((m) => m.hasBudget)) {
            return const EmptyState(
              key: ValueKey('empty'),
              icon: Icons.account_balance_wallet_outlined,
              title: 'No budgets in the last $trendWindowMonths months.',
              hint: 'Set a budget on the Budgets tab to start tracking adherence.',
              topPadding: 24,
            );
          }
          return Column(
            key: const ValueKey('data'),
            children: [
              for (final month in months.reversed)
                if (month.hasBudget)
                  ProgressCard(
                    title: month.label,
                    pct: month.usage.percentUsed.toDouble() / 100,
                    overBudget: month.usage.percentUsed > Decimal.fromInt(100),
                    footnote: month.usage.percentUsed > Decimal.fromInt(100)
                        ? '${formatZAR(month.usage.remaining.abs())} over a ${formatZAR(month.usage.budgetTotal)} budget'
                        : '${formatZAR(month.usage.actualSpend)} of ${formatZAR(month.usage.budgetTotal)}',
                  )
                else
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(child: Text(month.label, style: Theme.of(context).textTheme.titleMedium)),
                          Text('No budget set', style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Spending-pattern callouts as a stat strip, following the Dashboard's
/// `_CashflowStatStrip` exactly: a labelled card, then a row of
/// label-over-figure columns.
class _HighCostStatStrip extends ConsumerWidget {
  const _HighCostStatStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highCostAsync = ref.watch(highCostExpensesProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    return _asyncSection(
      context,
      highCostAsync.when(
        loading: _loadingCard,
        error: (err, _) => _errorCard(err, 'Failed to load your spending patterns'),
        data: (categories) {
          if (categories.isEmpty) {
            return const EmptyState(
              key: ValueKey('empty'),
              icon: Icons.pie_chart_outline,
              title: 'No spending recorded this month.',
              hint: 'Add an expense and your patterns will appear here.',
              topPadding: 24,
            );
          }
          final top = categories.first;
          final biggestSingle = categories.map((c) => c.maxSingleAmount).reduce((a, b) => a > b ? a : b);
          return _SectionCard(
            key: const ValueKey('data'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Where the money went', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Top category',
                        value: top.category,
                        valueStyle: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Spent there',
                        value: formatZAR(top.totalAmount),
                        valueStyle: moneyTextStyle(context, fontSize: 18, color: semantic?.danger),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Categories',
                        value: '${categories.length}',
                        valueStyle: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Largest single',
                        value: formatZAR(biggestSingle),
                        valueStyle: moneyTextStyle(context, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Categories the backend saw spend in during at least 2 of the trailing 3
/// months — the "this keeps happening" half of the spending-pattern story.
class _RecurringExpensesList extends ConsumerWidget {
  const _RecurringExpensesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringExpensesProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading('Recurring spend', subtitle: 'Last 3 months'),
        const SizedBox(height: 8),
        _asyncSection(
          context,
          recurringAsync.when(
            loading: _loadingCard,
            error: (err, _) => _errorCard(err, 'Failed to load your recurring spend'),
            data: (recurring) {
              if (recurring.isEmpty) {
                return const EmptyState(
                  key: ValueKey('empty'),
                  icon: Icons.repeat,
                  title: 'Nothing recurring yet.',
                  hint: 'Categories you spend in month after month will show up here.',
                  topPadding: 24,
                );
              }
              return GroupCard(
                key: const ValueKey('data'),
                children: [
                  for (final item in recurring)
                    GroupRow(
                      leadingIcon: categoryIcon(item.category, isExpense: true),
                      title: item.category,
                      subtitle: '${item.occurrences} of the last 3 months · last ${monthLabel(item.lastDate)}',
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatZAR(item.totalAmount), style: moneyTextStyle(context, fontSize: 14)),
                          Text(
                            '${formatZAR(item.avgAmount)} avg',
                            style: TextStyle(color: semantic?.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
