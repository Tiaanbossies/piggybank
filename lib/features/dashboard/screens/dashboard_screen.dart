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
import '../../../shared/widgets/completed_goal_card.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../../../shared/widgets/progress_card.dart';
import '../../../shared/widgets/quick_link_tile.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tab_app_bar.dart';
import '../../accounts/screens/accounts_screen.dart';
import '../../assets/screens/assets_screen.dart';
import '../../budgets/models/budget.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../calculators/screens/calculators_screen.dart';
import '../../detection/providers/detection_provider.dart';
import '../../detection/widgets/review_banner.dart';
import '../../goals/models/goal.dart';
import '../../goals/providers/goals_provider.dart';
import '../../liabilities/screens/liabilities_screen.dart';
import '../../plan/screens/plan_screen.dart';
import '../../savings/providers/savings_provider.dart';
import '../../summaries/providers/summaries_provider.dart';
import '../../transactions/category_icons.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/widgets/transaction_sheet.dart';
import '../../trends/screens/trends_screen.dart';
import '../../updates/models/latest_release.dart';
import '../../updates/providers/updates_provider.dart';

/// Fixed v1 layout per DESIGN.md § Dashboard/Home: hero net-worth card,
/// compact stat strip, one progress card, recent-transactions preview.
/// Widget customization is explicitly deferred (parity matrix). Also hosts
/// the quick-links row to Accounts/Assets/Liabilities/Calculators, since
/// DESIGN.md's locked 5-tab nav has no dedicated slot for those domains.
/// Tab-root app bar (avatar/title/bell placeholder) per DESIGN.md § Navigation
/// — avatar and bell are static placeholders, not backed by real features
/// (no profile-photo or notifications capability exists yet — see DESIGN.md's
/// revision note).
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
              _NetWorthHero(),
              SizedBox(height: 16),
              _CashflowStatStrip(),
              SizedBox(height: 16),
              _SavingsCard(),
              _ProgressBlock(),
              SizedBox(height: 8),
              _TrendsEntryCard(),
              SizedBox(height: 16),
              _QuickLinksRow(),
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

class _NetWorthHero extends ConsumerWidget {
  const _NetWorthHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorthAsync = ref.watch(netWorthProvider);
    return AnimatedSwitcher(
      duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      child: netWorthAsync.when(
        loading: () => const SizedBox(
          key: ValueKey('loading'),
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => InlineError(
          key: const ValueKey('error'),
          message: err is ApiError ? err.message : 'Failed to load net worth',
          onRetry: () => ref.invalidate(netWorthProvider),
        ),
        data: (netWorth) => HeroMetricCard(
          key: const ValueKey('data'),
          label: 'Net worth',
          value: formatZAR(netWorth.netWorth),
          deltaText: _NetWorthTrend.of(ref),
        ),
      ),
    );
  }
}

/// "+2.4% this month"-style trend pill per the Stitch Dashboard mockup —
/// backed by real data (the daily snapshot job, `summaries/snapshot_job.py`),
/// not a fabricated number. Omitted entirely (returns null, no pill shown)
/// until at least ~25 days of snapshot history exist for this account, since
/// there's no meaningful "this month" comparison before then.
class _NetWorthTrend {
  static const _minDaysForComparison = 25;

  static String? of(WidgetRef ref) {
    final historyAsync = ref.watch(netWorthHistoryProvider);
    final snapshots = historyAsync.valueOrNull;
    if (snapshots == null || snapshots.length < 2) return null;

    final sorted = [...snapshots]..sort((a, b) => a.snapshotDate.compareTo(b.snapshotDate));
    final latest = sorted.last;
    final comparison = sorted.firstWhere(
      (s) => latest.snapshotDate.difference(s.snapshotDate).inDays >= _minDaysForComparison,
      orElse: () => sorted.first,
    );
    final daysSpanned = latest.snapshotDate.difference(comparison.snapshotDate).inDays;
    if (daysSpanned < _minDaysForComparison || comparison.netWorth == Decimal.zero) return null;

    final change = (latest.netWorth - comparison.netWorth).toDouble();
    final pct = change / comparison.netWorth.abs().toDouble() * 100;
    final up = pct >= 0;
    return '${up ? '+' : ''}${pct.toStringAsFixed(1)}% this month';
  }
}

/// Today's spend over this month's cashflow — the one thing on Home that
/// changes every day, and so the reason to open it daily (UX plan item 1).
/// Net worth barely moves day to day; "what did I spend today?" does.
/// The two halves load and fail independently: a month the summaries
/// endpoint can't produce shouldn't hide a today figure that loaded fine.
class _CashflowStatStrip extends ConsumerWidget {
  const _CashflowStatStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashflowAsync = ref.watch(cashflowProvider);
    final todayAsync = ref.watch(todaySpendProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spent today', style: labelStyle),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
              switchInCurve: AppMotion.easeOut,
              switchOutCurve: AppMotion.easeOut,
              child: todayAsync.when(
                // A dash rather than a spinner: the figure's slot keeps its
                // height, so the month row below doesn't jump when it lands.
                loading: () => Text('—', key: const ValueKey('loading'), style: moneyTextStyle(context, fontSize: 28)),
                error: (_, _) => InlineError(
                  key: const ValueKey('error'),
                  message: "Couldn't load today's spending",
                  onRetry: () => ref.invalidate(todaySpendProvider),
                ),
                data: (spent) => Text(
                  formatZAR(spent),
                  key: const ValueKey('data'),
                  style: moneyTextStyle(context, fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('This month', style: labelStyle),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
              switchInCurve: AppMotion.easeOut,
              switchOutCurve: AppMotion.easeOut,
              child: cashflowAsync.when(
                loading: () => const SizedBox(
                  key: ValueKey('loading'),
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, _) => InlineError(
                  key: const ValueKey('error'),
                  message: 'Failed to load cashflow',
                  onRetry: () => ref.invalidate(cashflowProvider),
                ),
                data: (cashflow) => Row(
                  key: const ValueKey('data'),
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Income', style: labelStyle),
                          Text(formatZAR(cashflow.incomeTotal), style: moneyTextStyle(context, fontSize: 18, color: semantic?.success)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expenses', style: labelStyle),
                          Text(formatZAR(cashflow.expenseTotal), style: moneyTextStyle(context, fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The single most actionable progress card (UX plan item 4), in order:
/// 1. a category over budget this month — the thing to act on today;
/// 2. a goal still in progress;
/// 3. this month's busiest budget;
/// 4. a completed goal, only when there's nothing live to show.
/// It used to be `goals.first` regardless of status, so a finished laptop
/// fund sat here for weeks, and its budget fallback followed whichever
/// month the Budgets tab had last been browsed to.
class _ProgressBlock extends ConsumerWidget {
  const _ProgressBlock();

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

    final overBudget = busiest(budgets.where((b) => b.overBudget));
    if (overBudget != null) return _budgetCard(overBudget);

    final inProgress = goals.where((g) => g.status != GoalStatus.completed);
    if (inProgress.isNotEmpty) return _goalCard(inProgress.first);

    final busiestBudget = busiest(budgets);
    if (busiestBudget != null) return _budgetCard(busiestBudget);

    if (goals.isNotEmpty) return _goalCard(goals.first);
    return const SizedBox.shrink();
  }

  Widget _goalCard(Goal goal) {
    final footnote = '${formatZAR(goal.currentAmount)} saved / ${formatZAR(goal.targetAmount)} goal';
    if (goal.status == GoalStatus.completed) {
      return CompletedGoalCard(title: goal.name, footnote: footnote);
    }
    return ProgressCard(title: goal.name, pct: goal.progressPct / 100, footnote: footnote);
  }

  Widget _budgetCard(BudgetProgress budget) {
    return ProgressCard(
      title: budget.category ?? 'Total budget',
      pct: budget.pctUsed / 100,
      overBudget: budget.overBudget,
      footnote: budget.overBudget
          ? '${formatZAR(budget.remaining.abs())} over budget'
          : '${formatZAR(budget.spent)} / ${formatZAR(budget.budgetAmount)}',
    );
  }
}

/// Entry point to the Trends analytics screen. A pushed route
/// (`Navigator.push`, like Accounts/Assets/Liabilities below) rather than a
/// sixth bottom-nav tab — DESIGN.md § Navigation locks the shell at five
/// destinations. Given its own full-width row rather than a fifth quick-link
/// tile because it's a destination, not a domain shortcut.
class _TrendsEntryCard extends StatelessWidget {
  const _TrendsEntryCard();

  @override
  Widget build(BuildContext context) {
    return GroupCard(
      children: [
        GroupRow(
          leadingIcon: Icons.trending_up,
          title: 'Trends',
          // Kept short deliberately: GroupRow ellipsizes its subtitle at one
          // line, and the longer phrasing truncated mid-word on a 1080px
          // phone (verified live on the emulator).
          subtitle: 'Net worth, budgets and spending',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrendsScreen())),
        ),
      ],
    );
  }
}

class _QuickLinksRow extends StatelessWidget {
  const _QuickLinksRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickLinkTile(
            label: 'Accounts',
            icon: Icons.account_balance_wallet_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountsScreen())),
          ),
        ),
        Expanded(
          child: QuickLinkTile(
            label: 'Assets',
            icon: Icons.savings_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssetsScreen())),
          ),
        ),
        Expanded(
          child: QuickLinkTile(
            label: 'Liabilities',
            icon: Icons.request_quote_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiabilitiesScreen())),
          ),
        ),
        Expanded(
          child: QuickLinkTile(
            label: 'Calculators',
            icon: Icons.calculate_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalculatorsScreen())),
          ),
        ),
      ],
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
