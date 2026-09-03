import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calc/chart_utils.dart';
import '../../../core/calc/risk_metrics.dart' as risk;
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ticker_autocomplete_field.dart';
import '../models/comparison_entry.dart';
import '../models/ticker_search_result.dart';
import '../providers/comparison_provider.dart';

/// Power-user chart tool comparing up to 5 instruments by price, return,
/// volatility, drawdown, Sharpe ratio and pairwise correlation. Per the
/// migration-status doc this screen has no delivered mockup — built in the
/// app's plain-screen style (same precedent as the Imports screen), reached
/// via an icon button on Invest's app bar.
///
/// CPI/STeFI benchmark overlays, CSV export, and shareable URL state are
/// intentionally not ported — the web app itself frames benchmarks as
/// "coming soon", and the other two have no equivalent in a router-less,
/// multi-page-less Flutter app.
class InstrumentComparisonScreen extends ConsumerStatefulWidget {
  const InstrumentComparisonScreen({super.key});

  @override
  ConsumerState<InstrumentComparisonScreen> createState() => _InstrumentComparisonScreenState();
}

class _InstrumentComparisonScreenState extends ConsumerState<InstrumentComparisonScreen> {
  final _tickerController = TextEditingController();

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  void _submitTicker() {
    final value = _tickerController.text;
    if (value.trim().isEmpty) return;
    ref.read(comparisonControllerProvider.notifier).addTicker(value);
    _tickerController.clear();
  }

  /// Selecting a suggestion from [TickerAutocompleteField] adds it straight
  /// away — unlike Add/Edit Holding, there's no separate Name/Price/Asset
  /// class fields to conflict-resolve here, just the one ticker value, so
  /// the field's autofill is a direct add rather than a banner-mediated one.
  void _onTickerSelected(TickerSearchResult result) {
    final comparison = ref.read(comparisonControllerProvider);
    if (comparison.entries.length >= maxComparisonEntries) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can compare up to 5 instruments at once.')),
      );
      return;
    }
    _submitTicker();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ComparisonState>(comparisonControllerProvider, (previous, next) {
      final previousErrors = {for (final e in previous?.entries ?? const []) e.id: e.error};
      for (final entry in next.entries) {
        if (entry.error != null && previousErrors[entry.id] != entry.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${entry.ticker}: ${entry.error}')),
          );
        }
      }
    });
    final comparison = ref.watch(comparisonControllerProvider);
    final controller = ref.read(comparisonControllerProvider.notifier);
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    // The chart isn't useful while the ticker keyboard is up, and its fixed
    // 220px height is what pushes the non-scrollable Column into overflow
    // once chips wrap to a second line with the keyboard open. Collapsing
    // it while typing frees that space back up.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compare instruments'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Risk metrics'),
              Tab(text: 'Correlation'),
              Tab(text: 'Factsheet'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TickerAutocompleteField(
                        controller: _tickerController,
                        onSelected: _onTickerSelected,
                        onSubmitted: _submitTicker,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FilledButton(
                        onPressed: comparison.entries.length >= maxComparisonEntries ? null : _submitTicker,
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ),
              if (comparison.entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in comparison.entries)
                        Tooltip(
                          message: entry.error ?? '',
                          triggerMode: entry.error == null ? TooltipTriggerMode.manual : null,
                          child: InputChip(
                            avatar: CircleAvatar(backgroundColor: entry.color, radius: 6),
                            label: Text(
                              entry.loading ? '${entry.ticker} …' : (entry.error != null ? '${entry.ticker} ⚠' : entry.ticker),
                            ),
                            onDeleted: () => controller.removeTicker(entry.id),
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ComparisonPeriod>(
                        initialValue: comparison.period,
                        isDense: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                        items: [
                          for (final p in ComparisonPeriod.values)
                            DropdownMenuItem(value: p, child: Text(p.apiValue)),
                        ],
                        onChanged: (p) {
                          if (p != null) controller.setPeriod(p);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('%'),
                    Switch(
                      value: comparison.percentMode,
                      onChanged: controller.setPercentMode,
                    ),
                    const Text('Abs'),
                  ],
                ),
              ),
              if (!keyboardOpen) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 220,
                    child: comparison.entries.isEmpty
                        ? Center(
                            child: Text(
                              'Add up to $maxComparisonEntries tickers to compare',
                              style: TextStyle(color: semantic?.textMuted),
                            ),
                          )
                        : _ComparisonLineChart(entries: comparison.entries, percentMode: comparison.percentMode),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _SummaryTab(entries: comparison.entries, periodYears: comparison.period.years),
                    _RiskMetricsTab(entries: comparison.entries, periodYears: comparison.period.years),
                    _CorrelationTab(entries: comparison.entries),
                    _FactsheetTab(entries: comparison.entries),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryStats {
  _EntryStats(ComparisonEntry entry, double nominalYears)
      : ticker = entry.ticker,
        color = entry.color,
        currency = entry.currency,
        dividendYield = entry.lookup?.dividendYield?.toDouble() {
    final prices = entry.data.map((p) => p.close.toDouble()).toList();
    final dates = entry.data.map((p) => p.date.toIso8601String().substring(0, 10)).toList();
    final years = risk.actualYearsSpan(dates) > 0 ? risk.actualYearsSpan(dates) : nominalYears;
    annualisedReturn = risk.calcAnnualisedReturn(prices, years);
    volatility = risk.calcVolatility(prices);
    maxDrawdown = risk.calcMaxDrawdown(prices);
    sharpeRatio = risk.calcSharpeRatio(annualisedReturn, volatility);
    totalReturn = risk.calcTotalReturn(prices);
    dailyReturns = risk.calcDailyReturns(prices);
  }

  final String ticker;
  final Color color;
  final String currency;
  final double? dividendYield;
  late final double annualisedReturn;
  late final double volatility;
  late final double maxDrawdown;
  late final double sharpeRatio;
  late final double totalReturn;
  late final List<double> dailyReturns;
}

String _pct(double v, {int decimals = 1}) => '${(v * 100).toStringAsFixed(decimals)}%';

class _ComparisonLineChart extends StatelessWidget {
  const _ComparisonLineChart({required this.entries, required this.percentMode});
  final List<ComparisonEntry> entries;
  final bool percentMode;

  @override
  Widget build(BuildContext context) {
    final ready = entries.where((e) => e.data.isNotEmpty).toList();
    if (ready.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final series = [
      for (final e in ready)
        ChartSeries(
          key: e.ticker,
          dates: e.data.map((p) => p.date.toIso8601String().substring(0, 10)).toList(),
          prices: e.data.map((p) => p.close.toDouble()).toList(),
        ),
    ];
    final rows = buildChartData(series, percent: percentMode);
    if (rows.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                // fl_chart always draws a title at the exact axis max in
                // addition to its regular interval-spaced ones — when the
                // data's real max isn't already a multiple of that interval
                // (the common case), the two labels land within a few
                // pixels of each other and overlap (L2). Drop the exact-max
                // label whenever it's this close to the interval-derived
                // one just below it.
                final nearestBelow = (meta.max / meta.appliedInterval).floor() * meta.appliedInterval;
                final tooCloseToGridline = value == meta.max && (meta.max - nearestBelow) < meta.appliedInterval * 0.15;
                if (tooCloseToGridline) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(meta.formattedValue, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          for (final e in ready)
            LineChartBarData(
              isCurved: false,
              color: e.color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              spots: [
                for (var i = 0; i < rows.length; i++)
                  if (rows[i][e.ticker] != null) FlSpot(i.toDouble(), rows[i][e.ticker] as double),
              ],
            ),
        ],
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.entries, required this.periodYears});
  final List<ComparisonEntry> entries;
  final double periodYears;

  @override
  Widget build(BuildContext context) {
    final ready = entries.where((e) => e.data.length >= 2).toList();
    if (ready.isEmpty) {
      return const Center(child: Text('Add at least one ticker with price history'));
    }
    final stats = [for (final e in ready) _EntryStats(e, periodYears)];
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final headerStyle = TextStyle(color: semantic?.textMuted, fontSize: 12, fontWeight: FontWeight.w600);
    Widget money(String v) => Text(v, style: moneyTextStyle(context, fontSize: 13));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
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
              DataColumn(label: Text('Total return', style: headerStyle), numeric: true),
              DataColumn(label: Text('Annualised', style: headerStyle), numeric: true),
              DataColumn(label: Text('Volatility', style: headerStyle), numeric: true),
              DataColumn(label: Text('Max drawdown', style: headerStyle), numeric: true),
              DataColumn(label: Text('Sharpe', style: headerStyle), numeric: true),
              DataColumn(label: Text('Div yield', style: headerStyle), numeric: true),
            ],
            rows: [
              for (final s in stats)
                DataRow(cells: [
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(backgroundColor: s.color, radius: 5),
                      const SizedBox(width: 6),
                      Text(s.ticker, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  )),
                  DataCell(money(_pct(s.totalReturn))),
                  DataCell(money(_pct(s.annualisedReturn))),
                  DataCell(money(_pct(s.volatility))),
                  DataCell(money(_pct(s.maxDrawdown))),
                  DataCell(money(s.sharpeRatio.toStringAsFixed(2))),
                  DataCell(money(s.dividendYield != null ? _pct(s.dividendYield! / 100) : '—')),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskMetricsTab extends StatelessWidget {
  const _RiskMetricsTab({required this.entries, required this.periodYears});
  final List<ComparisonEntry> entries;
  final double periodYears;

  @override
  Widget build(BuildContext context) {
    final ready = entries.where((e) => e.data.length >= 2).toList();
    if (ready.isEmpty) {
      return const Center(child: Text('Add at least one ticker with price history'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in ready) ...[
          _RiskMetricCard(stats: _EntryStats(e, periodYears)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RiskMetricCard extends StatelessWidget {
  const _RiskMetricCard({required this.stats});
  final _EntryStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(backgroundColor: stats.color, radius: 6),
              const SizedBox(width: 8),
              Text(stats.ticker, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _Stat('Annualised return', _pct(stats.annualisedReturn)),
                _Stat('Volatility (ann.)', _pct(stats.volatility)),
                _Stat('Max drawdown', _pct(stats.maxDrawdown)),
                _Stat('Sharpe ratio', stats.sharpeRatio.toStringAsFixed(2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
        Text(value, style: moneyTextStyle(context, fontSize: 15)),
      ],
    );
  }
}

class _CorrelationTab extends StatelessWidget {
  const _CorrelationTab({required this.entries});
  final List<ComparisonEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ready = entries.where((e) => e.data.length >= 2).toList();
    if (ready.length < 2) {
      return const Center(child: Text('Add at least 2 tickers with price history to see correlation'));
    }
    final returns = {for (final e in ready) e.ticker: risk.calcDailyReturns(e.data.map((p) => p.close.toDouble()).toList())};
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final success = semantic?.success ?? Colors.green;
    final danger = semantic?.danger ?? Colors.red;
    final border = Theme.of(context).colorScheme.outline;

    Color cellColor(double v) {
      if (v >= 0) return success.withValues(alpha: v * 0.7);
      return danger.withValues(alpha: -v * 0.7);
    }

    Color textColorFor(double v) => v.abs() >= 0.5 ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Correlation Matrix', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, size: 20),
                    tooltip: 'How to read this',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Correlation matrix'),
                        content: const Text(
                          'Each cell is the Pearson correlation of daily returns between two '
                          'instruments, from -1 (inverse) to +1 (perfectly aligned). Diagonal '
                          'cells compare an instrument to itself and are always 1.00.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Got it')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  border: TableBorder.all(color: border, borderRadius: BorderRadius.circular(8)),
                  defaultColumnWidth: const FixedColumnWidth(64),
                  children: [
                    TableRow(children: [
                      const SizedBox(),
                      for (final e in ready)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            e.ticker,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: semantic?.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ]),
                    for (final rowEntry in ready)
                      TableRow(children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            rowEntry.ticker,
                            style: TextStyle(color: semantic?.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        for (final colEntry in ready)
                          Builder(builder: (context) {
                            final isDiagonal = rowEntry.ticker == colEntry.ticker;
                            final r =
                                isDiagonal ? 1.0 : risk.calcPearson(returns[rowEntry.ticker]!, returns[colEntry.ticker]!);
                            final bg = isDiagonal ? Theme.of(context).colorScheme.surfaceContainerHighest : cellColor(r);
                            return Container(
                              color: bg,
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                r.toStringAsFixed(2),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDiagonal ? semantic?.textMuted : textColorFor(r),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }),
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Inverse', style: TextStyle(color: semantic?.textMuted, fontSize: 11)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(colors: [danger, border, success]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Aligned', style: TextStyle(color: semantic?.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactsheetTab extends StatelessWidget {
  const _FactsheetTab({required this.entries});
  final List<ComparisonEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('Add a ticker to see its factsheet'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in entries) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(backgroundColor: e.color, radius: 6),
                    const SizedBox(width: 8),
                    Text(e.name, style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 8),
                  if (e.lookup case final lookup?) ...[
                    _FactRow('Fund family', lookup.fundFamily ?? '—'),
                    _FactRow('Category', lookup.fundCategory ?? '—'),
                    _FactRow(
                      'Expense ratio',
                      lookup.expenseRatio != null ? _pct(lookup.expenseRatio!.toDouble() / 100) : '—',
                    ),
                    _FactRow(
                      'Dividend yield',
                      lookup.dividendYield != null ? _pct(lookup.dividendYield!.toDouble() / 100) : '—',
                    ),
                    _FactRow(
                      'Inception',
                      lookup.inceptionDate != null ? lookup.inceptionDate!.toIso8601String().substring(0, 10) : '—',
                    ),
                  ] else
                    const Text('No factsheet data available'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: semantic?.textMuted)),
          Text(value),
        ],
      ),
    );
  }
}
