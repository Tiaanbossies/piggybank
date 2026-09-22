import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_error.dart';
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
import '../../accounts/screens/accounts_screen.dart';
import '../../assets/screens/assets_screen.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../calculators/screens/calculators_screen.dart';
import '../../goals/models/goal.dart';
import '../../goals/providers/goals_provider.dart';
import '../../liabilities/screens/liabilities_screen.dart';
import '../../summaries/providers/summaries_provider.dart';
import '../../transactions/category_icons.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/screens/transactions_screen.dart';
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
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: CircleAvatar(child: Icon(Icons.person_outline, size: 18)),
        ),
        title: const Text('Piggybank'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(netWorthProvider);
            ref.invalidate(cashflowProvider);
            ref.invalidate(goalsProvider);
            ref.invalidate(budgetProgressProvider);
            ref.invalidate(recentTransactionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _UpdateBanner(),
              _NetWorthHero(),
              SizedBox(height: 16),
              _CashflowStatStrip(),
              SizedBox(height: 16),
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

class _CashflowStatStrip extends ConsumerWidget {
  const _CashflowStatStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashflowAsync = ref.watch(cashflowProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return AnimatedSwitcher(
      duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      child: cashflowAsync.when(
        loading: () => const Card(
          key: ValueKey('loading'),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ),
        error: (_, _) => const Card(
          key: ValueKey('error'),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: InlineError(message: 'Failed to load cashflow'),
          ),
        ),
        data: (cashflow) => Card(
          key: const ValueKey('data'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cashflow · This month', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Income', style: Theme.of(context).textTheme.labelMedium),
                          Text(formatZAR(cashflow.incomeTotal), style: moneyTextStyle(context, fontSize: 18, color: semantic?.success)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expenses', style: Theme.of(context).textTheme.labelMedium),
                          Text(formatZAR(cashflow.expenseTotal), style: moneyTextStyle(context, fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single most relevant progress card — an active goal takes priority,
/// falling back to the current month's top-level budget, per DESIGN.md.
class _ProgressBlock extends ConsumerWidget {
  const _ProgressBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return AnimatedSwitcher(
      duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      child: goalsAsync.when(
        loading: () => const Card(
          key: ValueKey('loading'),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ),
        error: (_, _) => const Card(
          key: ValueKey('error'),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: InlineError(message: 'Failed to load your progress'),
          ),
        ),
        data: (goals) {
          if (goals.isNotEmpty) {
            // TODO(follow-up): goals.first is not filtered to exclude
            // completed goals, so a fully-saved goal can keep occupying this
            // "most relevant" slot instead of the Dashboard falling through
            // to an actionable in-progress goal or budget. Out of scope for
            // this fix, which only makes the completed state render
            // correctly once shown — see the audit fix-it plan, Phase 3.
            final goal = goals.first;
            final footnote = '${formatZAR(goal.currentAmount)} saved / ${formatZAR(goal.targetAmount)} goal';
            if (goal.status == GoalStatus.completed) {
              return CompletedGoalCard(key: const ValueKey('data'), title: goal.name, footnote: footnote);
            }
            return ProgressCard(
              key: const ValueKey('data'),
              title: goal.name,
              pct: goal.progressPct / 100,
              footnote: footnote,
            );
          }
          return const _BudgetProgressFallback(key: ValueKey('data'));
        },
      ),
    );
  }
}

class _BudgetProgressFallback extends ConsumerWidget {
  const _BudgetProgressFallback({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(budgetProgressProvider);

    return progressAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ),
      error: (_, _) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: InlineError(message: 'Failed to load your budget progress'),
        ),
      ),
      data: (budgets) {
        if (budgets.isEmpty) return const SizedBox.shrink();
        final budget = budgets.first;
        return ProgressCard(
          title: budget.category ?? 'Total budget',
          pct: budget.pctUsed / 100,
          overBudget: budget.overBudget,
          footnote: budget.overBudget
              ? '${formatZAR(budget.remaining.abs())} over budget'
              : '${formatZAR(budget.spent)} / ${formatZAR(budget.budgetAmount)}',
        );
      },
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
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionsScreen())),
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
              child: InlineError(message: err is ApiError ? err.message : 'Failed to load transactions'),
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
                      subtitle: t.category,
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
