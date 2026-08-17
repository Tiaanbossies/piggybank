import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/group_card.dart';
import '../models/dividend.dart';
import '../models/holding.dart';
import '../providers/portfolios_provider.dart';
import '../providers/ticker_provider.dart';
import 'add_edit_holding_sheet.dart';
import 'sell_holding_sheet.dart';

/// Tapping a holding row opens this — per DESIGN.md §9: "price history as a
/// single clean line chart..., then dividend history as a row-card list
/// beneath it, then a Sell pill action." Edit/Delete are added alongside
/// Sell since the mobile screen has no separate per-row action buttons the
/// way the (unmocked, web-only) dense table in `ui-ux-mockup-brief.md` §5.3
/// does.
Future<void> showHoldingDetailSheet(BuildContext context, {required Holding holding}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HoldingDetailSheet(holding: holding),
  );
}

class _HoldingDetailSheet extends ConsumerWidget {
  const _HoldingDetailSheet({required this.holding});
  final Holding holding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(holding.ticker, style: Theme.of(context).textTheme.titleLarge),
                    Text(holding.name, style: TextStyle(color: semantic?.textMuted)),
                  ],
                ),
              ),
              if (holding.isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: semantic?.accentChipBg, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Closed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(label: 'Value', value: formatZAR(holding.marketValue)),
              ),
              Expanded(
                child: _Stat(
                  label: 'Unrealized P&L',
                  value: formatZAR(holding.unrealizedPl),
                  color: holding.unrealizedPl >= Decimal.zero ? semantic?.success : semantic?.danger,
                ),
              ),
              if (holding.realizedPl != null)
                Expanded(
                  child: _Stat(label: 'Realized P&L', value: formatZAR(holding.realizedPl)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _PriceHistoryChart(ticker: holding.ticker),
          const SizedBox(height: 24),
          _DividendSection(holding: holding),
          const SizedBox(height: 24),
          if (!holding.isClosed)
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                showSellHoldingSheet(context, holding: holding);
              },
              child: const Text('Sell'),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showAddEditHoldingSheet(context, portfolioId: holding.portfolioId, existing: holding);
            },
            child: const Text('Edit'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final confirmed = await confirmDestroy(
                context,
                title: 'Delete holding?',
                message: 'This removes "${holding.ticker}" and its trade/dividend history. This cannot be undone.',
              );
              if (!confirmed || !context.mounted) return;
              try {
                await ref.read(portfoliosApiProvider).deleteHolding(holding.id);
                ref.invalidate(portfolioHoldingsProvider(holding.portfolioId));
                ref.invalidate(portfolioValueProvider(holding.portfolioId));
                ref.invalidate(investmentOverviewProvider);
                if (context.mounted) Navigator.of(context).pop();
              } on ApiError catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            child: Text('Delete holding', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
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

class _PriceHistoryChart extends ConsumerWidget {
  const _PriceHistoryChart({required this.ticker});
  final String ticker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(tickerHistoryProvider((ticker: ticker, period: '3mo')));
    final accent = Theme.of(context).colorScheme.primary;

    return historyAsync.when(
      loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const SizedBox.shrink(),
      data: (history) {
        if (history.data.isEmpty) return const SizedBox.shrink();
        final spots = [
          for (var i = 0; i < history.data.length; i++) FlSpot(i.toDouble(), history.data[i].close.toDouble()),
        ];
        return SizedBox(
          height: 140,
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
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: accent.withValues(alpha: 0.1)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DividendSection extends ConsumerStatefulWidget {
  const _DividendSection({required this.holding});
  final Holding holding;

  @override
  ConsumerState<_DividendSection> createState() => _DividendSectionState();
}

class _DividendSectionState extends ConsumerState<_DividendSection> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final dividendsAsync = ref.watch(holdingDividendsProvider(widget.holding.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Dividends', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => _adding = !_adding),
            ),
          ],
        ),
        if (_adding)
          _AddDividendRow(
            holdingId: widget.holding.id,
            onDone: () => setState(() => _adding = false),
          ),
        dividendsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text(err is ApiError ? err.message : 'Failed to load dividends'),
          data: (dividends) {
            if (dividends.isEmpty) return const Text('No dividends recorded yet.');
            return GroupCard(
              children: [for (final d in dividends) _DividendRow(dividend: d, holdingId: widget.holding.id)],
            );
          },
        ),
      ],
    );
  }
}

class _DividendRow extends ConsumerWidget {
  const _DividendRow({required this.dividend, required this.holdingId});
  final Dividend dividend;
  final String holdingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupRow(
      title: formatZAR(dividend.amount),
      subtitle:
          '${dividend.payDate.year}-${dividend.payDate.month.toString().padLeft(2, '0')}-${dividend.payDate.day.toString().padLeft(2, '0')}'
          '${dividend.note != null ? ' · ${dividend.note}' : ''}',
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () async {
          final confirmed = await confirmDestroy(context, title: 'Delete dividend?');
          if (!confirmed) return;
          await ref.read(portfoliosApiProvider).deleteDividend(dividend.id);
          ref.invalidate(holdingDividendsProvider(holdingId));
        },
      ),
    );
  }
}

class _AddDividendRow extends ConsumerStatefulWidget {
  const _AddDividendRow({required this.holdingId, required this.onDone});
  final String holdingId;
  final VoidCallback onDone;

  @override
  ConsumerState<_AddDividendRow> createState() => _AddDividendRowState();
}

class _AddDividendRowState extends ConsumerState<_AddDividendRow> {
  final _amountController = TextEditingController();
  DateTime _payDate = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(portfoliosApiProvider).createDividend(
            widget.holdingId,
            payDate: _payDate,
            amount: _amountController.text.trim(),
          );
      ref.invalidate(holdingDividendsProvider(widget.holdingId));
      widget.onDone();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (ZAR)'),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _payDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _payDate = picked);
                },
                child: Text(
                  '${_payDate.year}-${_payDate.month.toString().padLeft(2, '0')}-${_payDate.day.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}
