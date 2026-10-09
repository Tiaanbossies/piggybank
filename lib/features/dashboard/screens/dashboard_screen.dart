import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/motion/container_transform.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../../../shared/widgets/progress_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tab_app_bar.dart';
import '../../budgets/models/budget.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../detection/providers/detection_provider.dart';
import '../../detection/widgets/review_banner.dart';
import '../../goals/models/goal.dart';
import '../../goals/providers/goals_provider.dart';
import '../../networth/screens/net_worth_screen.dart';
import '../../plan/screens/plan_screen.dart';
import '../../savings/providers/savings_provider.dart';
import '../../summaries/providers/summaries_provider.dart';
import '../../transactions/category_icons.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/widgets/transaction_sheet.dart';
import '../../updates/models/latest_release.dart';
import '../../updates/providers/updates_provider.dart';
import '../widgets/left_to_spend_hero.dart';

/// Fixed v1 layout per DESIGN.md § Dashboard/Home: hero net-worth card,
/// compact stat strip, one progress card, recent-transactions preview.
/// Widget customization is explicitly deferred (parity matrix). Also hosts
/// the quick-links row to Accounts/Assets/Liabilities/Calculators, since
/// DESIGN.md's locked 5-tab nav has no dedicated slot for those domains.
/// Home (UX rework spec §2.1): "am I OK today and this month?" in one
/// glance. Fixed order, no customisation: update and review banners when
/// they apply, the Left to spend hero, the savings card, net worth, the one
/// thing that needs attention, and recent transactions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const TabAppBar(title: 'Piggybank'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(netWorthProvider);
            ref.invalidate(netWorthHistoryProvider);
            ref.invalidate(cashflowProvider);
            ref.invalidate(todaySpendProvider);
            ref.invalidate(goalsProvider);
            ref.invalidate(currentMonthBudgetProgressProvider);
            ref.invalidate(recentTransactionsProvider);
            ref.invalidate(pendingEventsProvider);
            ref.invalidate(savingsOverviewProvider);
          },
          child: ListView(
            // The bottom inset clears the Add button (56) plus its margin,
            // so it never sits over the last recent transaction — the
            // overlap the 2026-09-21 audit logged as H2 on other screens.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: const [
              _UpdateBanner(),
              ReviewBanner(),
              LeftToSpendHero(),
              SizedBox(height: 16),
              _SavingsCard(),
              _NetWorthCard(),
              SizedBox(height: 16),
              _NeedsAttention(),
              SizedBox(height: 24),
              _RecentTransactionsPreview(),
            ],
          ),
        ),
      ),
      // Quick add (UX plan item 2, decision D2): the cash coffee gets logged
      // from where the day starts, not three screens down Transactions.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

/// "A newer build exists" notice, shown only when [updateAvailableProvider]
/// resolves to a real [LatestRelease] (i.e. its build number is genuinely
/// greater than this install's own). Deliberately not persisted anywhere —
/// dismissing only hides it for the remainder of this app session; per
/// Step 8's own plan note, a fresh launch re-shows it if still out of date,
/// since this is a manual, low-frequency check, not a nagging prompt.
/// Notify + manual download only: tapping "Download" opens `downloadUrl` in
/// the platform browser via `url_launcher` — no in-app APK download or
/// install code exists anywhere in this app.
class _UpdateBanner extends ConsumerStatefulWidget {
  const _UpdateBanner();

  @override
  ConsumerState<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<_UpdateBanner> {
  bool _dismissed = false;
  bool _opening = false;

  Future<void> _openDownload(String url) async {
    setState(() => _opening = true);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final release = ref.watch(updateAvailableProvider).valueOrNull;
    if (release == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconChip(icon: Icons.system_update_outlined, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Update available', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Version ${release.version} is ready to download.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _opening ? null : () => _openDownload(release.downloadUrl),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                        child: _opening
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Download'),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Dismiss',
                onPressed: () => setState(() => _dismissed = true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The savings target's gap, one tap from Home (cost-cutting plan, item 2).
/// Sits under the spend strip so the daily review-and-spend flow above it
/// is unchanged. Hidden while loading and on error, like the review
/// banner: a backend without the savings endpoints yet, or a bad-signal
/// moment, shouldn't put an error on Home. The Savings plan screen itself
/// shows the error with a Retry.
class _SavingsCard extends ConsumerWidget {
  const _SavingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(savingsOverviewProvider).valueOrNull;
    if (overview == null) return const SizedBox.shrink();

    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final target = overview.target;
    final String title;
    final String subtitle;
    if (target == null) {
      title = 'Set a savings target';
      subtitle = 'See what you have left over each month';
    } else if (overview.targetMet) {
      title = '${target.displayLabel}: target met';
      subtitle = '${formatZAR(overview.leftOver)} left over a month';
    } else {
      title = '${target.displayLabel}: gap ${formatZAR(overview.gap)}';
      subtitle = overview.savingsFound > Decimal.zero
          ? '${formatZAR(overview.savingsFound)} a month found so far'
          : 'Tap to find costs to cut';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            ref.read(planSegmentProvider.notifier).state = PlanSegment.savings;
            context.go('/plan');
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const IconChip(icon: Icons.savings_outlined, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: overview.targetMet ? semantic?.success : null,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (target != null && !overview.targetMet)
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(overview.progress * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(color: semantic?.textMuted, fontSize: 12),
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

/// Net worth, demoted from the hero to a card (decision D1): it barely moves
/// day to day, so it no longer takes the top slot. It opens the Net worth
/// screen, which now holds Accounts, Assets, Liabilities and Calculators.
class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorth = ref.watch(netWorthProvider);
    final trend = netWorthTrendText(ref);
    final value = netWorth.when(
      data: (n) => formatZAR(n.netWorth),
      loading: () => '—',
      error: (_, _) => "Couldn't load",
    );
    return GroupCard(
      children: [
        ContainerTransform(
          openBuilder: (_) => const NetWorthScreen(),
          closedBuilder: (context, open) => GroupRow(
            key: const Key('home-net-worth'),
            leadingIcon: Icons.account_balance_outlined,
            title: 'Net worth',
            subtitle: trend,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: moneyTextStyle(context, fontSize: 16)),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: open,
          ),
        ),
      ],
    );
  }
}

/// "Needs attention" (UX rework spec §2.1): the one thing worth a look,
/// in order:
/// 1. the category most over budget this month;
/// 2. a category at 80% or more of its budget;
/// 3. a goal still in progress.
/// Never a completed goal, and nothing at all when none of these exists.
/// The hero already carries the month's total, so a calm budget doesn't
/// need repeating here. Tapping opens the matching Plan segment.
class _NeedsAttention extends ConsumerWidget {
  const _NeedsAttention();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final budgetsAsync = ref.watch(currentMonthBudgetProgressProvider);

    final Widget child;
    if (goalsAsync.isLoading || budgetsAsync.isLoading) {
      child = const Card(
        key: ValueKey('loading'),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    } else if (goalsAsync.hasError && budgetsAsync.hasError) {
      child = Card(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: InlineError(
            message: 'Failed to load your progress',
            onRetry: () => ref
              ..invalidate(goalsProvider)
              ..invalidate(currentMonthBudgetProgressProvider),
          ),
        ),
      );
    } else {
      // One side failing still leaves the other worth showing.
      child = KeyedSubtree(
        key: const ValueKey('data'),
        child: _pick(goalsAsync.valueOrNull ?? const [], budgetsAsync.valueOrNull ?? const []),
      );
    }

    return AnimatedSwitcher(
      duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      child: child,
    );
  }

  Widget _pick(List<Goal> goals, List<BudgetProgress> budgets) {
    BudgetProgress? busiest(Iterable<BudgetProgress> candidates) =>
        candidates.isEmpty ? null : candidates.reduce((a, b) => b.pctUsed > a.pctUsed ? b : a);

    final atRisk = busiest(budgets.where((b) => b.overBudget)) ?? busiest(budgets.where((b) => b.pctUsed >= 80));
    if (atRisk != null) return _budgetCard(atRisk);

    final inProgress = goals.where((g) => g.status != GoalStatus.completed);
    if (inProgress.isNotEmpty) return _goalCard(inProgress.first);

    return const SizedBox.shrink();
  }

  Widget _goalCard(Goal goal) {
    return _OpensPlan(
      segment: PlanSegment.goals,
      child: ProgressCard(
        title: goal.name,
        pct: goal.progressPct / 100,
        footnote: '${formatZAR(goal.currentAmount)} saved / ${formatZAR(goal.targetAmount)} goal',
      ),
    );
  }

  Widget _budgetCard(BudgetProgress budget) {
    return _OpensPlan(
      segment: PlanSegment.budgets,
      child: ProgressCard(
        title: budget.category ?? 'Total budget',
        pct: budget.pctUsed / 100,
        overBudget: budget.overBudget,
        footnote: budget.overBudget
            ? '${formatZAR(budget.remaining.abs())} over budget'
            : '${formatZAR(budget.spent)} / ${formatZAR(budget.budgetAmount)}',
      ),
    );
  }
}

/// Makes a Needs attention card open its Plan segment.
class _OpensPlan extends ConsumerWidget {
  const _OpensPlan({required this.segment, required this.child});
  final PlanSegment segment;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      key: const Key('needs-attention'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(planSegmentProvider.notifier).state = segment;
        context.go('/plan');
      },
      child: child,
    );
  }
}

class _RecentTransactionsPreview extends ConsumerWidget {
  const _RecentTransactionsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentTransactionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () => context.go('/transactions'),
              child: const Text('See all'),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
          switchInCurve: AppMotion.easeOut,
          switchOutCurve: AppMotion.easeOut,
          child: recentAsync.when(
            loading: () => const Center(key: ValueKey('loading'), child: CircularProgressIndicator()),
            error: (err, _) => Center(
              key: const ValueKey('error'),
              child: InlineError(
                message: err is ApiError ? err.message : 'Failed to load transactions',
                onRetry: () => ref.invalidate(recentTransactionsProvider),
              ),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return const EmptyState(
                  key: ValueKey('empty'),
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet.',
                  topPadding: 24,
                );
              }
              final semantic = Theme.of(context).extension<AppSemanticColors>();
              return GroupCard(
                key: const ValueKey('list'),
                children: [
                  for (final t in page.items)
                    GroupRow(
                      leadingIcon: categoryIcon(
                        t.category,
                        isExpense: t.transactionType.name == 'expense',
                        isTransfer: t.transactionType.name == 'transfer',
                      ),
                      title: t.merchantName ?? t.description ?? t.category,
                      // Dated, so "did that coffee go in yet?" is answered
                      // here instead of on the full Transactions list.
                      subtitle: '${t.category} · ${dayLabel(
                        t.transactionDate,
                        withYear: t.transactionDate.year != DateTime.now().year,
                      )}',
                      trailing: Text(
                        formatZAR(t.transactionType.name == 'expense' ? -t.amount.toDouble() : t.amount.toDouble()),
                        style: moneyTextStyle(
                          context,
                          fontSize: 14,
                          color: t.transactionType.name == 'income'
                              ? semantic?.success
                              : (t.transactionType.name == 'expense' ? semantic?.danger : null),
                        ),
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
