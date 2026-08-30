import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../asset_class_style.dart';
import '../providers/portfolios_provider.dart';
import 'holding_detail_sheet.dart';

/// Every holding across every portfolio, flattened into one list — the
/// destination for Invest's "Top holdings" preview "See all" link (Step 4,
/// blueprint task 2). Deliberately simpler than [PortfolioDetailScreen]'s
/// holdings table (no sparkline/day-change, which are tied to that screen's
/// own ticker-history providers) — a flat, sorted-by-value list is enough
/// for a "see everything" screen.
class AllHoldingsScreen extends ConsumerWidget {
  const AllHoldingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingsAsync = ref.watch(allHoldingsProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    return Scaffold(
      appBar: AppBar(title: const Text('All Holdings')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(allHoldingsProvider),
          child: holdingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load holdings')),
            data: (entries) {
              if (entries.isEmpty) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up, size: 48, color: semantic?.textMuted),
                          const SizedBox(height: 16),
                          const Text('No holdings yet', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GroupCard(
                    children: [
                      for (final (portfolio, holding) in entries)
                        Opacity(
                          opacity: holding.isClosed ? 0.5 : 1,
                          child: GroupRow(
                            leadingIcon: assetClassIcons[holding.assetClass],
                            title: holding.ticker,
                            subtitle: '${holding.name} · ${portfolio.name}',
                            trailing: Text(formatZAR(holding.marketValue), style: moneyTextStyle(context, fontSize: 14)),
                            onTap: () => showHoldingDetailSheet(context, holding: holding),
                          ),
                        ),
                    ],
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
