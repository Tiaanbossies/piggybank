import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/motion/container_transform.dart';
import '../../../shared/widgets/allocation_donut.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tab_app_bar.dart';
import '../asset_class_style.dart';
import '../models/investment_overview.dart';
import '../models/portfolio.dart';
import '../providers/portfolios_provider.dart';
import 'all_holdings_screen.dart';
import 'holding_detail_sheet.dart';
import 'instrument_comparison_screen.dart';
import 'portfolio_detail_screen.dart';
import 'portfolio_sheet.dart';

/// Invest tab-root — confirmed by the delivered mockup as one combined
/// screen (Overview + Portfolios list), not the web's separate 3-tier IA.
/// See DESIGN.md §8 and `ui-ux-mockup-brief.md` §13 item 1.
class InvestScreen extends ConsumerWidget {
  const InvestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfoliosAsync = ref.watch(portfoliosProvider);

    return Scaffold(
      appBar: TabAppBar(
        title: 'Invest',
        actions: [
          // A labelled pill, not a bare icon (spec §4.1).
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s8),
            child: OutlinedButton.icon(
              key: const Key('invest-compare'),
              // App-bar size; the 48 dp tap target stays.
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              ),
              icon: const Icon(Icons.stacked_line_chart, size: 18),
              label: const Text('Compare'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InstrumentComparisonScreen()),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AppRefresh(
          onRefresh: () async {
            ref.invalidate(investmentOverviewProvider);
            ref.invalidate(portfoliosProvider);
          },
          child: SkeletonSwitcher(child: portfoliosAsync.when(
            loading: () => const SkeletonPage(key: Key('invest-skeleton'), hero: true, rows: 3),
            // Scrollable so pull-to-refresh still works on the error state.
            error: (err, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 96),
                InlineError(
                  message: err is ApiError ? err.message : 'Failed to load portfolios',
                  onRetry: () => ref
                    ..invalidate(investmentOverviewProvider)
                    ..invalidate(portfoliosProvider),
                ),
              ],
            ),
            data: (portfolios) {
              if (portfolios.isEmpty) return const _EmptyState();
              return ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s8, AppSpace.gutter, AppSpace.sectionGap),
                children: [
                  const _OverviewSection(),
                  const SizedBox(height: AppSpace.sectionGap),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your portfolios', style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Add portfolio',
                        onPressed: () => showPortfolioSheet(context),
                      ),
                    ],
                  ),
                  GroupCard(
                    children: [for (final portfolio in portfolios) _PortfolioRow(portfolio: portfolio)],
                  ),
                ],
              );
            },
          )),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, size: 48, color: semantic?.textMuted),
            const SizedBox(height: 16),
            Text('No investments yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create a portfolio to start tracking your investments.',
              textAlign: TextAlign.center,
              style: TextStyle(color: semantic?.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => showPortfolioSheet(context),
              child: const Text('Create portfolio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(investmentOverviewProvider);
    final t = context.tokens;

    return SkeletonSwitcher(child: overviewAsync.when(
      loading: () => const SkeletonHero(),
      error: (err, _) => InlineError(
        message: err is ApiError ? err.message : 'Failed to load overview',
        onRetry: () => ref.invalidate(investmentOverviewProvider),
      ),
      data: (overview) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroMetricCard(
              label: 'Total value',
              value: formatZAR(overview.totalValue),
              amount: overview.totalValue.toDouble(),
              deltaText: '${signedPl(overview.unrealizedPl)} if sold today',
            ),
            const SizedBox(height: AppSpace.rowGap),
            AppCard(
              // Aligned on the figures, so a label that wraps on a narrow
              // phone lifts itself rather than dropping its figure.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _StatColumn(
                      label: 'Gain if sold today',
                      value: signedPl(overview.unrealizedPl),
                      color: plColor(t, overview.unrealizedPl),
                    ),
                  ),
                  Expanded(
                    child: _StatColumn(label: "Year's dividends", value: formatZAR(overview.ytdDividends)),
                  ),
                  Expanded(
                    child: _StatColumn(label: 'Portfolios', value: '${overview.portfolioCount}'),
                  ),
                ],
              ),
            ),
            if (overview.allocation.isNotEmpty) ...[
              const SizedBox(height: AppSpace.rowGap),
              AllocationDonut(items: overview.allocation),
            ],
            if (overview.topHoldings.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sectionGap),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Top holdings', style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AllHoldingsScreen()),
                    ),
                    child: const Text('See all'),
                  ),
                ],
              ),
              GroupCard(
                children: [
                  for (final holding in overview.topHoldings.take(3))
                    GroupRow(
                      key: ValueKey('top-holding-${holding.holdingId}'),
                      onTap: () => _openTopHolding(context, ref, holding),
                      title: holding.ticker,
                      subtitle: holding.name,
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatZAR(holding.value), style: moneyTextStyle(context, fontSize: 14)),
                          Text(
                            signedPl(holding.unrealizedPl),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: plColor(t, holding.unrealizedPl),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    ));
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted)),
        const SizedBox(height: AppSpace.s4),
        Text(value, style: moneyTextStyle(context, fontSize: 15, color: color)),
      ],
    );
  }
}

class _PortfolioRow extends StatelessWidget {
  const _PortfolioRow({required this.portfolio});
  final Portfolio portfolio;

  @override
  Widget build(BuildContext context) {
    return ContainerTransform(
      openBuilder: (_) => PortfolioDetailScreen(portfolio: portfolio),
      closedBuilder: (context, open) => GroupRow(
        leadingIcon: Icons.folder_outlined,
        title: portfolio.name,
        subtitle: portfolioTypeLabels[portfolio.portfolioType],
        trailing: const Icon(Icons.chevron_right),
        onTap: open,
      ),
    );
  }
}

/// A top-holdings row opens the same detail sheet as All holdings (QA G).
/// The overview only carries a summary, so the full holding is read from
/// its portfolio first.
Future<void> _openTopHolding(BuildContext context, WidgetRef ref, TopHolding top) async {
  try {
    final holdings = await ref.read(portfolioHoldingsProvider(top.portfolioId).future);
    final holding = holdings.where((h) => h.id == top.holdingId).firstOrNull;
    if (!context.mounted) return;
    if (holding == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't find that holding. Pull to refresh.")));
      return;
    }
    await showHoldingDetailSheet(context, holding: holding);
  } on ApiError catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }
}
