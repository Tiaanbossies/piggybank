import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/motion/container_transform.dart';
import '../../../shared/widgets/allocation_donut.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tab_app_bar.dart';
import '../models/portfolio.dart';
import '../providers/portfolios_provider.dart';
import 'all_holdings_screen.dart';
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
          TextButton.icon(
            key: const Key('invest-compare'),
            icon: const Icon(Icons.stacked_line_chart),
            label: const Text('Compare'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InstrumentComparisonScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(investmentOverviewProvider);
            ref.invalidate(portfoliosProvider);
          },
          child: portfoliosAsync.when(
            loading: () => ListView(
              key: const Key('invest-skeleton'),
              padding: const EdgeInsets.all(16),
              children: const [
                SkeletonBox(height: 120, radius: 24),
                SizedBox(height: 16),
                SkeletonBox(height: 96),
                SizedBox(height: 24),
                SkeletonBox(),
                SizedBox(height: 8),
                SkeletonBox(),
              ],
            ),
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
                padding: const EdgeInsets.all(16),
                children: [
                  const _OverviewSection(),
                  const SizedBox(height: 24),
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
          ),
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
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    return overviewAsync.when(
      loading: () => const SkeletonBox(height: 120, radius: 24),
      error: (err, _) => InlineError(
        message: err is ApiError ? err.message : 'Failed to load overview',
        onRetry: () => ref.invalidate(investmentOverviewProvider),
      ),
      data: (overview) {
        final plUp = overview.unrealizedPl >= Decimal.zero;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroMetricCard(
              label: 'Total value',
              value: formatZAR(overview.totalValue),
              amount: overview.totalValue.toDouble(),
              deltaText: '${plUp ? '+' : ''}${formatZAR(overview.unrealizedPl)} unrealized',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatColumn(
                        label: 'Unrealized P&L',
                        value: formatZAR(overview.unrealizedPl),
                        color: plUp ? semantic?.success : semantic?.danger,
                      ),
                    ),
                    Expanded(
                      child: _StatColumn(label: 'YTD dividends', value: formatZAR(overview.ytdDividends)),
                    ),
                    Expanded(
                      child: _StatColumn(label: 'Portfolios', value: '${overview.portfolioCount}'),
                    ),
                  ],
                ),
              ),
            ),
            if (overview.allocation.isNotEmpty) ...[
              const SizedBox(height: 16),
              AllocationDonut(items: overview.allocation),
            ],
            if (overview.topHoldings.isNotEmpty) ...[
              const SizedBox(height: 24),
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
                      title: holding.ticker,
                      subtitle: holding.name,
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatZAR(holding.value), style: moneyTextStyle(context, fontSize: 14)),
                          Text(
                            formatZAR(holding.unrealizedPl),
                            style: TextStyle(
                              fontSize: 12,
                              color: holding.unrealizedPl >= Decimal.zero ? semantic?.success : semantic?.danger,
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
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
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
