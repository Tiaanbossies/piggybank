import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../models/holding.dart';
import '../models/trade.dart';
import '../providers/portfolios_provider.dart';

/// Sell modal — per `ui-ux-mockup-brief.md` §5.3: "Submit button is
/// intentionally styled as a destructive/red action even though it's a
/// normal workflow step (selling records an audit-trail Trade, it does not
/// just edit the holding)."
Future<void> showSellHoldingSheet(BuildContext context, {required Holding holding}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SellHoldingSheet(holding: holding),
  );
}

class _SellHoldingSheet extends ConsumerStatefulWidget {
  const _SellHoldingSheet({required this.holding});
  final Holding holding;

  @override
  ConsumerState<_SellHoldingSheet> createState() => _SellHoldingSheetState();
}

class _SellHoldingSheetState extends ConsumerState<_SellHoldingSheet> {
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _feeController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  DateTime _tradeDate = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.holding.currentPrice?.toString() ?? '';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tradeDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _tradeDate = picked);
  }

  Future<void> _submit() async {
    final qty = Decimal.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= Decimal.zero) {
      setState(() => _error = 'Enter a quantity to sell.');
      return;
    }
    if (qty > widget.holding.quantity) {
      setState(() => _error = 'Only ${widget.holding.quantity} units available.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(portfoliosApiProvider).createTrade(
            widget.holding.id,
            tradeType: HoldingTradeType.sell,
            quantity: _quantityController.text.trim(),
            pricePerUnit: _priceController.text.trim(),
            tradeDate: _tradeDate,
            fee: _feeController.text.trim().isEmpty ? '0' : _feeController.text.trim(),
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );
      ref.invalidate(portfolioHoldingsProvider(widget.holding.portfolioId));
      ref.invalidate(portfolioValueProvider(widget.holding.portfolioId));
      ref.invalidate(holdingTradesProvider(widget.holding.id));
      ref.invalidate(investmentOverviewProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sell ${widget.holding.ticker}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Available: ${widget.holding.quantity} units', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity to sell'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price per unit (ZAR)'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trade date'),
              subtitle: Text(
                '${_tradeDate.year}-${_tradeDate.month.toString().padLeft(2, '0')}-${_tradeDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _feeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fee (optional)'),
            ),
            const SizedBox(height: 16),
            TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sell'),
            ),
          ],
        ),
      ),
    );
  }
}
