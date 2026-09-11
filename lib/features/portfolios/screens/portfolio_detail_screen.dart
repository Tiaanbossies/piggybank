import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/allocation_bar.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../ra/screens/ra_ledger_screen.dart';
import '../../tfsa/screens/tfsa_ledger_screen.dart';
import '../asset_class_style.dart';
import '../models/holding.dart';
import '../models/investment_overview.dart';
import '../models/portfolio.dart';
import '../providers/portfolios_provider.dart';
import '../providers/ticker_provider.dart';
import 'add_edit_holding_sheet.dart';
import 'holding_detail_sheet.dart';
import 'portfolio_sheet.dart';

/// The largest, most complex screen in the product — per
/// `stitch-design-brief.md` §8's "Portfolio detail" (grounded, highest
/// complexity): hero value card, a stacked-bar allocation block, a row-card
/// holdings list (ticker/name, sparkline, value, day-change%) with a
/// tap-to-open detail sheet, replacing the web's dense sortable table
/// entirely. The Projected Income table at the bottom is undesigned in the
/// brief; it's implemented as a compact, purely client-side what-if
/// calculator (editing a yield here does not persist — use Edit Holding for
/// that) rather than firing an update on every keystroke.
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
          if (portfolio.portfolioType == PortfolioType.tfsa)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'TFSA contribution ledger',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TfsaLedgerScreen()),
              ),
            ),
          if (portfolio.portfolioType == PortfolioType.ra)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Retirement Annuity ledger',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RaLedgerScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit portfolio',
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
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Sparkline(ticker: holding.ticker),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatZAR(holding.marketValue), style: moneyTextStyle(context, fontSize: 14)),
                      _DayChange(ticker: holding.ticker),
                    ],
                  ),
                ],
              ),
        onTap: () => showHoldingDetailSheet(context, holding: holding),
      ),
    );
  }
}

/// Day-change percentage beneath the holding's value, per
/// `stitch-design-brief.md` §8's "day-change as a small percentage beneath
/// (green if up, red if down)" — the one place red/green on an ordinary
/// figure is correct, since it's price direction, not a budget state.
/// Derived from the same '1mo' [tickerHistoryProvider] key [_Sparkline]
/// already watches (Riverpod shares the cached result — no extra request),
/// comparing the last two closes rather than fetching a dedicated '1d'/'5d'
/// period, since the backend's `VALID_PERIODS` doesn't offer one.
class _DayChange extends ConsumerWidget {
  const _DayChange({required this.ticker});
  final String ticker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final historyAsync = ref.watch(tickerHistoryProvider((ticker: ticker, period: '1mo')));

    return historyAsync.when(
      loading: () => const SizedBox(height: 14),
      error: (_, _) => const SizedBox(height: 14),
      data: (history) {
        if (history.data.length < 2) return const SizedBox(height: 14);
        final prev = history.data[history.data.length - 2].close.toDouble();
        final last = history.data.last.close.toDouble();
        if (prev == 0) return const SizedBox(height: 14);
        final pct = (last - prev) / prev * 100;
        final up = pct >= 0;
        return Text(
          '${up ? '+' : ''}${pct.toStringAsFixed(2)}%',
          style: TextStyle(fontSize: 12, color: up ? semantic?.success : semantic?.danger),
        );
      },
    );
  }
}

/// Small inline price-trend indicator per holding row, per DESIGN.md §9's
/// "small inline sparkline" note. Reuses the same [tickerHistoryProvider]
/// the Holding Detail sheet's full price chart uses, just with a shorter
/// period — purely decorative, so loading/error states render nothing
/// rather than a spinner or error text, never blocking the row.
class _Sparkline extends ConsumerWidget {
  const _Sparkline({required this.ticker});
  final String ticker;

  static const _size = Size(60, 24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(tickerHistoryProvider((ticker: ticker, period: '1mo')));
    final accent = Theme.of(context).colorScheme.primary;

    return historyAsync.when(
      loading: () => SizedBox.fromSize(size: _size),
      error: (_, _) => SizedBox.fromSize(size: _size),
      data: (history) {
        if (history.data.length < 2) return SizedBox.fromSize(size: _size);
        final spots = [
          for (var i = 0; i < history.data.length; i++) FlSpot(i.toDouble(), history.data[i].close.toDouble()),
        ];
        return SizedBox.fromSize(
          size: _size,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: accent,
                  barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        );
      },
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

    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final headerStyle = TextStyle(color: semantic?.textMuted, fontSize: 12, fontWeight: FontWeight.w600);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columnSpacing: 20,
          horizontalMargin: 16,
          columns: [
            DataColumn(label: Text('Ticker', style: headerStyle)),
            DataColumn(label: Text('Value', style: headerStyle)),
            DataColumn(label: Text('Yield', style: headerStyle)),
            DataColumn(label: Text('Annual', style: headerStyle)),
            DataColumn(label: Text('Monthly', style: headerStyle)),
          ],
          rows: [
            ...rows,
            DataRow(cells: [
              const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(formatZAR(totalAnnual), style: moneyTextStyle(context, fontSize: 14))),
              DataCell(Text(formatZAR(totalMonthly), style: moneyTextStyle(context, fontSize: 14))),
            ]),
          ],
        ),
      ),
    );
  }
}
