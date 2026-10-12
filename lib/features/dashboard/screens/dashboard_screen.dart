import 'package:clock/clock.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/motion/container_transform.dart';
import '../../../shared/motion/count_up_text.dart';
import '../../../shared/motion/stagger_in.dart';
import '../../../shared/widgets/app_banner.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../../../shared/widgets/mascot_moment.dart';
import '../../../shared/widgets/progress_card.dart';
import '../../../shared/widgets/shrinking_fab.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tab_app_bar.dart';
import '../../budgets/models/budget.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../calculators/screens/calculators_screen.dart';
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
import '../../transactions/widgets/signed_amount.dart';
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
        child: AppRefresh(
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
          // Visual spec §4.1: a fixed order, with a 24 dp gap between
          // sections so Recent reads as its own section, not the end of the
          // page (S5). Cards carry a 12 dp bottom margin, so the gaps below
          // top that up to 24. The bottom inset clears the Add button (S11).
          child: ListView(
            key: const Key('home-list'),
            primary: true,
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s8, AppSpace.gutter, AppSpace.fabInset),
            children: const [
              _UpdateBanner(),
              ReviewBanner(),
              LeftToSpendHero(),
              SizedBox(height: AppSpace.sectionGap),
              _SavingsCard(),
              _NetWorthCard(),
              _NeedsAttention(),
              SizedBox(height: AppSpace.sectionGap - AppSpace.rowGap),
              _RecentTransactionsPreview(),
            ],
          ),
        ),
      ),
      // Quick add (UX plan item 2, decision D2): the cash coffee gets logged
      // from where the day starts, not three screens down Transactions. It
      // folds to its icon while Home scrolls down (M42).
      floatingActionButton: Builder(
        builder: (context) => ShrinkingFab(
          controller: PrimaryScrollController.of(context),
          icon: Icons.add,
          label: 'Add',
          onPressed: () => showTransactionSheet(context),
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
      padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
      child: AppBanner(
        key: const Key('home-update-banner'),
        icon: Icons.system_update_outlined,
        message: _opening ? 'Opening the download…' : 'Update available: version ${release.version}. Tap to download',
        onTap: () {
          if (!_opening) _openDownload(release.downloadUrl);
        },
        onDismiss: () => setState(() => _dismissed = true),
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

    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final target = overview.target;
    final String title;
    final String subtitle;
    if (target == null) {
      title = 'Set a savings target';
      subtitle = 'See what you have left over each month';
    } else if (overview.targetMet) {
      title = '${target.displayLabel}: target met this month';
      subtitle = '${formatZAR(overview.leftOver)} left over a month';
    } else {
      title = '${target.displayLabel}: gap ${formatZAR(overview.gap)}';
      subtitle = overview.savingsFound > Decimal.zero
          ? '${formatZAR(overview.savingsFound)} a month found so far'
          : 'Tap to find costs to cut';
    }
    final pct = (overview.progress * 100).round();

    return AppCard(
      key: const Key('home-savings'),
      margin: const EdgeInsets.only(bottom: AppSpace.rowGap),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.cardPad, vertical: AppSpace.s16),
      semanticLabel: '$title. $subtitle',
      onTap: () {
        ref.read(planSegmentProvider.notifier).state = PlanSegment.savings;
        context.go('/plan');
      },
      child: Row(
        children: [
          // Celebrating Penny only when the target is met (visual spec §2):
          // a pop and one medium tap, at most once a day (M39).
          if (overview.targetMet)
            const MascotMoment(
              asset: MascotMoment.celebrating,
              size: 40,
              motion: MascotMotion.pop,
              kind: 'savings-target-met',
            )
          else
            const IconChip(icon: Icons.savings_outlined, size: 40),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall?.copyWith(color: overview.targetMet ? t.positive : t.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodySmall?.copyWith(color: t.muted)),
              ],
            ),
          ),
          if (target != null && !overview.targetMet)
            // The percent says what it's of, stacked so the subtitle keeps
            // its width.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CrossfadeDigits(
                  key: const Key('home-savings-pct'),
                  text: '$pct%',
                  amount: overview.progress,
                  style: text.labelMedium?.copyWith(color: t.muted),
                ),
                Text('of target', style: text.labelSmall?.copyWith(color: t.muted)),
              ],
            ),
          Icon(Icons.chevron_right, color: t.muted),
        ],
      ),
    );
  }
}

/// Net worth, demoted from the hero to a card (decision D1): it barely moves
/// day to day, so it no longer takes the top slot. It opens the Net worth
/// screen, which holds Accounts, Assets, Liabilities and Calculators; the
/// calculators also get their own row here.
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
    final t = context.tokens;
    return GroupCard(
      children: [
        // Opens the hub by growing out of the row (M6).
        ContainerTransform(
          radius: AppRadius.card,
          openBuilder: (_) => const NetWorthScreen(),
          closedBuilder: (context, open) => GroupRow(
            key: const Key('home-net-worth'),
            leadingIcon: Icons.account_balance_outlined,
            title: 'Net worth',
            subtitle: trend,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The figure crossfades when it changes (M22).
                CrossfadeDigits(
                  text: value,
                  amount: netWorth.valueOrNull?.netWorth.toDouble() ?? 0,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: t.ink),
                ),
                Icon(Icons.chevron_right, color: t.muted),
              ],
            ),
            onTap: open,
          ),
        ),
        // One tap from Home, not two via Net worth: the calculators were
        // hard to find there (QA D9).
        GroupRow(
          key: const Key('home-calculators'),
          leadingIcon: Icons.calculate_outlined,
          title: 'Loan calculators',
          trailing: Icon(Icons.chevron_right, color: t.muted),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CalculatorsScreen()),
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
      child = const Padding(
        key: ValueKey('loading'),
        padding: EdgeInsets.only(top: AppSpace.sectionGap - AppSpace.rowGap),
        child: SkeletonProgressCards(count: 1),
      );
    } else if (goalsAsync.hasError && budgetsAsync.hasError) {
      child = Padding(
        key: const ValueKey('error'),
        padding: const EdgeInsets.only(top: AppSpace.sectionGap - AppSpace.rowGap),
        child: AppCard(
          margin: const EdgeInsets.only(bottom: AppSpace.rowGap),
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
    if (atRisk != null) return _section(_budgetCard(atRisk));

    final inProgress = goals.where((g) => g.status != GoalStatus.completed);
    if (inProgress.isNotEmpty) return _section(_goalCard(inProgress.first));

    return const SizedBox.shrink();
  }

  /// Its own section: the 24 dp gap above it only when there's a card.
  Widget _section(Widget card) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sectionGap - AppSpace.rowGap),
      child: card,
    );
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
            ? 'Over by ${formatZAR(budget.remaining.abs())}'
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
    final text = Theme.of(context).textTheme;

    return Column(
      key: const Key('home-recent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent transactions', style: text.titleMedium),
            TextButton(
              onPressed: () => context.go('/transactions'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        AnimatedSwitcher(
          duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
          switchInCurve: AppMotion.easeOut,
          switchOutCurve: AppMotion.easeOut,
          child: recentAsync.when(
            loading: () => const SkeletonRows(key: ValueKey('loading'), count: 5),
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
              return GroupCard(
                key: const ValueKey('list'),
                children: [
                  for (final (i, tx) in page.items.indexed)
                    StaggerIn(
                      index: i,
                      child: GroupRow(
                        key: ValueKey('home-recent-${tx.id}'),
                        leadingIcon: categoryIcon(
                          tx.category,
                          isExpense: tx.transactionType.name == 'expense',
                          isTransfer: tx.transactionType.name == 'transfer',
                        ),
                        family: categoryFamily(tx.category),
                        title: tx.merchantName ?? tx.description ?? tx.category,
                        // Dated, so "did that coffee go in yet?" is answered
                        // here instead of on the full Transactions list.
                        subtitle: '${tx.category} · ${dayLabel(
                          tx.transactionDate,
                          withYear: tx.transactionDate.year != clock.now().year,
                        )}',
                        trailing: SignedAmount.of(tx),
                        // Same sheet a Transactions row opens: the details,
                        // editable, with Delete (QA Home 1).
                        onTap: () => showTransactionSheet(context, existing: tx),
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
