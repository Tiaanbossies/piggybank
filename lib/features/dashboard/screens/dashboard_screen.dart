import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../../shared/widgets/progress_card.dart';
import '../../../shared/widgets/quick_link_tile.dart';
import '../../accounts/screens/accounts_screen.dart';
import '../../assets/screens/assets_screen.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../calculators/screens/calculators_screen.dart';
import '../../goals/providers/goals_provider.dart';
import '../../liabilities/screens/liabilities_screen.dart';
import '../../summaries/providers/summaries_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/screens/transactions_screen.dart';

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
            children: [
              const _NetWorthHero(),
              const SizedBox(height: 16),
              const _CashflowStatStrip(),
              const SizedBox(height: 16),
              const _ProgressBlock(),
              const SizedBox(height: 24),
              const _QuickLinksRow(),
              const SizedBox(height: 24),
              const _RecentTransactionsPreview(),
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
    return netWorthAsync.when(
      loading: () => const SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
      error: (err, _) => Text(err is ApiError ? err.message : 'Failed to load net worth'),
      data: (netWorth) => HeroMetricCard(label: 'Net worth', value: formatZAR(netWorth.netWorth)),
    );
  }
}

class _CashflowStatStrip extends ConsumerWidget {
  const _CashflowStatStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashflowAsync = ref.watch(cashflowProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return cashflowAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (cashflow) => Card(
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

    return goalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (goals) {
        if (goals.isNotEmpty) {
          final goal = goals.first;
          return ProgressCard(
            title: goal.name,
            pct: goal.progressPct / 100,
            footnote: '${formatZAR(goal.currentAmount)} saved / ${formatZAR(goal.targetAmount)} goal',
          );
        }
        return const _BudgetProgressFallback();
      },
    );
  }
}

class _BudgetProgressFallback extends ConsumerWidget {
  const _BudgetProgressFallback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(budgetProgressProvider);

    return progressAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
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
        recentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text(err is ApiError ? err.message : 'Failed to load transactions'),
          data: (page) {
            if (page.items.isEmpty) return const Text('No transactions yet.');
            final semantic = Theme.of(context).extension<AppSemanticColors>();
            return GroupCard(
              children: [
                for (final t in page.items)
                  GroupRow(
                    leadingIcon: t.transactionType.name == 'expense' ? Icons.arrow_upward : Icons.arrow_downward,
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
      ],
    );
  }
}
