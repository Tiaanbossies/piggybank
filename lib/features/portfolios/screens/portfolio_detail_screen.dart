import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/allocation_bar.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../asset_class_style.dart';
import '../models/holding.dart';
import '../models/investment_overview.dart';
import '../models/portfolio.dart';
import '../providers/portfolios_provider.dart';
import 'add_edit_holding_sheet.dart';
import 'holding_detail_sheet.dart';
import 'portfolio_sheet.dart';

/// The largest, most complex screen in the product per
/// `ui-ux-mockup-brief.md` §5.3 — no mockup exists for it (DESIGN.md §9
/// carries over the superseded spec's mobile direction: hero value, a
/// stacked-bar allocation block, a row-card holdings list with a tap-to-open
/// detail sheet, replacing the web's dense sortable table entirely). The
/// Projected Income table at the bottom is undesigned in both docs; it's
/// implemented as a compact, purely client-side what-if calculator (editing
/// a yield here does not persist — use Edit Holding for that) rather than
/// firing an update on every keystroke.
class PortfolioDetailScreen extends ConsumerWidget {
  const PortfolioDetailScreen({required this.portfolio, super.key});
  final Portfolio portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingsAsync = ref.watch(portfolioHoldingsProvider(portfolio.id));
    final valueAsync = ref.watch(portfolioValueProvider(portfolio.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(portfolio.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showPortfolioSheet(context, existing: portfolio),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(portfolioHoldingsProvider(portfolio.id));
            ref.invalidate(portfolioValueProvider(portfolio.id));
          },
          child: holdingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load holdings')),
            data: (holdings) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${holdings.length} holding${holdings.length == 1 ? '' : 's'}'
                          '${portfolio.description != null ? ' · ${portfolio.description}' : ''}',
                          style: TextStyle(color: Theme.of(context).extension<AppSemanticColors>()?.textMuted),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).extension<AppSemanticColors>()?.accentChipBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          portfolio.currency,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  valueAsync.when(
                    loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (value) {
                      final plUp = value.unrealizedPl >= Decimal.zero;
                      return HeroMetricCard(
                        label: 'Portfolio value',
                        value: formatZAR(value.totalValue),
                        deltaText: '${plUp ? '+' : ''}${formatZAR(value.unrealizedPl)} unrealized',
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _AllocationSection(holdings: holdings),
                  const SizedBox(height: 24),
                  Text('Holdings', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (holdings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: Text('No holdings yet.')),
                    )
                  else
                    GroupCard(children: [for (final h in holdings) _HoldingRow(holding: h)]),
                  if (holdings.any((h) => h.currentPrice != null)) ...[
                    const SizedBox(height: 24),
                    Text('Projected income', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Estimates only — edit a holding to save its dividend yield.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _ProjectedIncomeTable(holdings: holdings.where((h) => h.currentPrice != null).toList()),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEditHoldingSheet(context, portfolioId: portfolio.id),
        label: const Text('Add holding'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _AllocationSection extends StatelessWidget {
  const _AllocationSection({required this.holdings});
  final List<Holding> holdings;

  @override
  Widget build(BuildContext context) {
    final priced = holdings.where((h) => h.marketValue > Decimal.zero).toList();
    if (priced.isEmpty) return const SizedBox.shrink();

    final totals = <AssetClass, Decimal>{};
    var total = Decimal.zero;
    for (final h in priced) {
      totals[h.assetClass] = (totals[h.assetClass] ?? Decimal.zero) + h.marketValue;
      total += h.marketValue;
    }
    if (total == Decimal.zero) return const SizedBox.shrink();

    final items = [
      for (final entry in totals.entries)
        AllocationItem(
          assetClass: entry.key,
          value: entry.value,
          percent: Decimal.parse((entry.value.toDouble() / total.toDouble() * 100).toStringAsFixed(2)),
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));

    return AllocationBar(items: items);
  }
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding});
  final Holding holding;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final plUp = holding.unrealizedPl >= Decimal.zero;

    return Opacity(
      opacity: holding.isClosed ? 0.5 : 1,
      child: GroupRow(
        leadingIcon: assetClassIcons[holding.assetClass],
        title: holding.ticker,
        subtitle: holding.name,
        trailing: holding.isClosed
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: semantic?.accentChipBg, borderRadius: BorderRadius.circular(999)),
                child: const Text('Closed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatZAR(holding.marketValue), style: moneyTextStyle(context, fontSize: 14)),
                  Text(
                    formatZAR(holding.unrealizedPl),
                    style: TextStyle(fontSize: 12, color: plUp ? semantic?.success : semantic?.danger),
                  ),
                ],
              ),
        onTap: () => showHoldingDetailSheet(context, holding: holding),
      ),
    );
  }
}

class _ProjectedIncomeTable extends StatefulWidget {
  const _ProjectedIncomeTable({required this.holdings});
  final List<Holding> holdings;

  @override
  State<_ProjectedIncomeTable> createState() => _ProjectedIncomeTableState();
}

class _ProjectedIncomeTableState extends State<_ProjectedIncomeTable> {
  late Map<String, double> _yields;

  @override
  void initState() {
    super.initState();
    _yields = {for (final h in widget.holdings) h.id: h.dividendYield?.toDouble() ?? 0};
  }

  @override
  Widget build(BuildContext context) {
    var totalAnnual = 0.0;
    var totalMonthly = 0.0;
    final rows = <DataRow>[];

    for (final h in widget.holdings) {
      final yieldPct = _yields[h.id] ?? 0;
      final marketValue = h.marketValue.toDouble();
      final annual = marketValue * yieldPct / 100;
      final monthly = annual / 12;
      totalAnnual += annual;
      totalMonthly += monthly;

      rows.add(DataRow(cells: [
        DataCell(Text(h.ticker)),
        DataCell(Text(formatZAR(marketValue))),
        DataCell(
          SizedBox(
            width: 64,
            child: TextFormField(
              initialValue: yieldPct == 0 ? '' : yieldPct.toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: '%', isDense: true),
              onChanged: (value) => setState(() => _yields[h.id] = double.tryParse(value) ?? 0),
            ),
          ),
        ),
        DataCell(Text(formatZAR(annual))),
        DataCell(Text(formatZAR(monthly))),
      ]));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Ticker')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Yield')),
          DataColumn(label: Text('Annual')),
          DataColumn(label: Text('Monthly')),
        ],
        rows: [
          ...rows,
          DataRow(cells: [
            const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
            const DataCell(Text('')),
            const DataCell(Text('')),
            DataCell(Text(formatZAR(totalAnnual), style: const TextStyle(fontWeight: FontWeight.w700))),
            DataCell(Text(formatZAR(totalMonthly), style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ],
      ),
    );
  }
}
