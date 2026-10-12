import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/motion/count_up_text.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../accounts/screens/accounts_screen.dart';
import '../../assets/screens/assets_screen.dart';
import '../../calculators/screens/calculators_screen.dart';
import '../../liabilities/screens/liabilities_screen.dart';
import '../../summaries/providers/summaries_provider.dart';

/// "+2.4% this month"-style trend text, backed by the daily snapshot job
/// (`summaries/snapshot_job.py`), not a fabricated number. Null (no pill)
/// until about 25 days of snapshot history exist for the account, since
/// there's no meaningful "this month" comparison before then.
String? netWorthTrendText(WidgetRef ref) {
  const minDaysForComparison = 25;
  final snapshots = ref.watch(netWorthHistoryProvider).valueOrNull;
  if (snapshots == null || snapshots.length < 2) return null;

  final sorted = [...snapshots]..sort((a, b) => a.snapshotDate.compareTo(b.snapshotDate));
  final latest = sorted.last;
  final comparison = sorted.firstWhere(
    (s) => latest.snapshotDate.difference(s.snapshotDate).inDays >= minDaysForComparison,
    orElse: () => sorted.first,
  );
  final daysSpanned = latest.snapshotDate.difference(comparison.snapshotDate).inDays;
  if (daysSpanned < minDaysForComparison || comparison.netWorth == Decimal.zero) return null;

  final change = (latest.netWorth - comparison.netWorth).toDouble();
  final pct = change / comparison.netWorth.abs().toDouble() * 100;
  return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% this month';
}

/// Net worth and the screens that make it up (UX rework spec §2.1). A hub,
/// not a new feature: it gathers the four Home quick links (Accounts,
/// Assets, Liabilities, Calculators) under the number they explain, one tap
/// further from Home, which suits screens used weekly or less (Y15).
class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorthAsync = ref.watch(netWorthProvider);
    final summary = netWorthAsync.valueOrNull;

    final t = context.tokens;
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('Net worth')),
      body: SafeArea(
        child: AppRefresh(
          onRefresh: () async {
            ref.invalidate(netWorthHistoryProvider);
            return ref.refresh(netWorthProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.gutter),
            children: [
              AnimatedSwitcher(
                duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
                switchInCurve: AppMotion.easeOut,
                switchOutCurve: AppMotion.easeOut,
                child: netWorthAsync.when(
                  loading: () => const SkeletonHero(key: ValueKey('loading')),
                  error: (err, _) => InlineError(
                    key: const ValueKey('error'),
                    message: err is ApiError ? err.message : 'Failed to load net worth',
                    onRetry: () => ref.invalidate(netWorthProvider),
                  ),
                  data: (netWorth) => HeroMetricCard(
                    key: const ValueKey('data'),
                    label: 'Net worth',
                    value: formatZAR(netWorth.netWorth),
                    amount: netWorth.netWorth.toDouble(),
                    deltaText: netWorthTrendText(ref),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sectionGap),
              // What makes up the figure. Liabilities are a fact, not a
              // warning: their total is ink, never red (visual spec §4.1).
              GroupCard(
                children: [
                  GroupRow(
                    key: const Key('net-worth-accounts'),
                    leadingIcon: Icons.account_balance_wallet_outlined,
                    title: 'Accounts',
                    trailing: Icon(Icons.chevron_right, color: t.muted),
                    onTap: () => open(const AccountsScreen()),
                  ),
                  GroupRow(
                    key: const Key('net-worth-assets'),
                    leadingIcon: Icons.savings_outlined,
                    title: 'Assets',
                    trailing: _Total(summary?.totalAssets),
                    onTap: () => open(const AssetsScreen()),
                  ),
                  GroupRow(
                    key: const Key('net-worth-liabilities'),
                    leadingIcon: Icons.request_quote_outlined,
                    title: 'Liabilities',
                    trailing: _Total(summary?.liabilitiesTotal),
                    onTap: () => open(const LiabilitiesScreen()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sectionGap - AppSpace.rowGap),
              GroupCard(
                children: [
                  GroupRow(
                    key: const Key('net-worth-calculators'),
                    leadingIcon: Icons.calculate_outlined,
                    muted: true,
                    title: 'Loan calculators',
                    trailing: Icon(Icons.chevron_right, color: t.muted),
                    onTap: () => open(const CalculatorsScreen()),
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

/// A hub row's total, tabular in ink, then the chevron. Nothing while the
/// summary loads: the hero above carries the loading state.
class _Total extends StatelessWidget {
  const _Total(this.amount);

  final Decimal? amount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final value = amount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          CrossfadeDigits(
            text: formatZAR(value),
            amount: value.toDouble(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: t.ink),
          ),
        Icon(Icons.chevron_right, color: t.muted),
      ],
    );
  }
}
