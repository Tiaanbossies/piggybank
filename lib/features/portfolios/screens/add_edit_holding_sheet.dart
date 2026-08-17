import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/ticker_autocomplete_field.dart';
import '../asset_class_style.dart';
import '../models/holding.dart';
import '../models/ticker_search_result.dart';
import '../providers/portfolios_provider.dart';
import 'sell_holding_sheet.dart';

/// Add/Edit Holding — per `ui-ux-mockup-brief.md` §5.3/§5.4. The ticker
/// autocomplete autofills Name/Price/inferred Asset class on selection, but
/// never silently overwrites a field the user already typed something
/// different into: it shows a one-tap "Use suggested value" conflict banner
/// instead. Editing also exposes "Sell" (a separate destructive-styled
/// Trade-recording flow, not a quantity edit) and "Delete".
Future<void> showAddEditHoldingSheet(BuildContext context, {required String portfolioId, Holding? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HoldingSheet(portfolioId: portfolioId, existing: existing),
  );
}

class _FieldConflict {
  const _FieldConflict({required this.suggested, required this.apply});
  final String suggested;
  final VoidCallback apply;
}

class _HoldingSheet extends ConsumerStatefulWidget {
  const _HoldingSheet({required this.portfolioId, this.existing});
  final String portfolioId;
  final Holding? existing;

  @override
  ConsumerState<_HoldingSheet> createState() => _HoldingSheetState();
}

class _HoldingSheetState extends ConsumerState<_HoldingSheet> {
  late final TextEditingController _tickerController;
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _costBasisController;
  late final TextEditingController _priceController;
  late final TextEditingController _yearController;
  late final TextEditingController _dividendYieldController;
  late AssetClass _assetClass;
  bool _submitting = false;
  bool _deleting = false;
  bool _lookingUp = false;
  String? _error;
  _FieldConflict? _nameConflict;
  _FieldConflict? _priceConflict;
  _FieldConflict? _assetClassConflict;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _tickerController = TextEditingController(text: existing?.ticker ?? '');
    _nameController = TextEditingController(text: existing?.name ?? '');
    _quantityController = TextEditingController(text: existing != null ? existing.quantity.toString() : '');
    _costBasisController = TextEditingController(text: existing != null ? existing.costBasis.toString() : '');
    _priceController = TextEditingController(text: existing?.currentPrice?.toString() ?? '');
    _yearController = TextEditingController(text: existing?.contributionYear?.toString() ?? '');
    _dividendYieldController = TextEditingController(text: existing?.dividendYield?.toString() ?? '');
    _assetClass = existing?.assetClass ?? AssetClass.stock;
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _costBasisController.dispose();
    _priceController.dispose();
    _yearController.dispose();
    _dividendYieldController.dispose();
    super.dispose();
  }

  void _applyOrConflict({
    required String suggested,
    required TextEditingController controller,
    required void Function(_FieldConflict?) setConflict,
  }) {
    final current = controller.text.trim();
    if (current.isEmpty || current == suggested) {
      controller.text = suggested;
      setConflict(null);
      return;
    }
    setConflict(_FieldConflict(
      suggested: suggested,
      apply: () => setState(() {
        controller.text = suggested;
        setConflict(null);
      }),
    ));
  }

  Future<void> _onTickerSelected(TickerSearchResult result) async {
    setState(() {
      _nameConflict = null;
      _assetClassConflict = null;
    });

    _applyOrConflict(
      suggested: result.name,
      controller: _nameController,
      setConflict: (c) => setState(() => _nameConflict = c),
    );

    final inferred = inferAssetClassFromInstrumentType(result.instrumentType);
    if (_assetClass != inferred) {
      setState(() {
        _assetClassConflict = _FieldConflict(
          suggested: assetClassLabels[inferred]!,
          apply: () => setState(() {
            _assetClass = inferred;
            _assetClassConflict = null;
          }),
        );
      });
    }

    setState(() => _lookingUp = true);
    try {
      final lookup = await ref.read(portfoliosApiProvider).tickerLookup(result.ticker);
      if (!mounted || lookup == null) return;
      _applyOrConflict(
        suggested: lookup.currentPrice.toString(),
        controller: _priceController,
        setConflict: (c) => setState(() => _priceConflict = c),
      );
    } on ApiError {
      // Best-effort autofill — the ticker/name from search already landed.
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(portfoliosApiProvider);
      final year = _yearController.text.trim().isEmpty ? null : int.tryParse(_yearController.text.trim());
      final price = _priceController.text.trim().isEmpty ? null : _priceController.text.trim();
      if (widget.existing == null) {
        await api.createHolding(
          widget.portfolioId,
          ticker: _tickerController.text.trim().toUpperCase(),
          name: _nameController.text.trim(),
          quantity: _quantityController.text.trim(),
          costBasis: _costBasisController.text.trim(),
          currentPrice: price,
          assetClass: _assetClass,
          contributionYear: year,
        );
      } else {
        final dividendYield =
            _dividendYieldController.text.trim().isEmpty ? null : _dividendYieldController.text.trim();
        await api.updateHolding(
          widget.existing!.id,
          ticker: _tickerController.text.trim().toUpperCase(),
          name: _nameController.text.trim(),
          quantity: _quantityController.text.trim(),
          costBasis: _costBasisController.text.trim(),
          currentPrice: price,
          assetClass: _assetClass,
          dividendYield: dividendYield,
        );
      }
      ref.invalidate(portfolioHoldingsProvider(widget.portfolioId));
      ref.invalidate(portfolioValueProvider(widget.portfolioId));
      ref.invalidate(investmentOverviewProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await confirmDestroy(
      context,
      title: 'Delete holding?',
      message: 'This removes "${existing.ticker}" and its trade/dividend history. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(portfoliosApiProvider).deleteHolding(existing.id);
      ref.invalidate(portfolioHoldingsProvider(widget.portfolioId));
      ref.invalidate(portfolioValueProvider(widget.portfolioId));
      ref.invalidate(investmentOverviewProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _deleting;
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isEdit ? 'Edit holding' : 'Add holding', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TickerAutocompleteField(controller: _tickerController, onSelected: _onTickerSelected),
            if (_lookingUp) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            if (_nameConflict != null) _ConflictBanner(conflict: _nameConflict!),
            const SizedBox(height: 16),
            DropdownButtonFormField<AssetClass>(
              initialValue: _assetClass,
              decoration: const InputDecoration(labelText: 'Asset class'),
              items: [
                for (final c in AssetClass.values) DropdownMenuItem(value: c, child: Text(assetClassLabels[c]!)),
              ],
              onChanged: (value) => setState(() => _assetClass = value ?? _assetClass),
            ),
            if (_assetClassConflict != null) _ConflictBanner(conflict: _assetClassConflict!),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _costBasisController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cost basis per unit (ZAR)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Current price (optional)'),
            ),
            if (_priceConflict != null) _ConflictBanner(conflict: _priceConflict!),
            const SizedBox(height: 16),
            TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Contribution year (optional)'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _dividendYieldController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Dividend yield % (optional)'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
            if (isEdit && widget.existing!.isClosed == false) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        showSellHoldingSheet(context, holding: widget.existing!);
                      },
                child: const Text('Sell'),
              ),
            ],
            if (isEdit) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : _delete,
                child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Lookup returned X. Kept your manual entry Y." conflict banner, per
/// `ui-ux-mockup-brief.md` §5.3 — one-tap "Use suggested value" instead of
/// silently overwriting what the user typed.
class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.conflict});
  final _FieldConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Lookup suggests "${conflict.suggested}". Kept your entry.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: conflict.apply, child: const Text('Use suggested')),
        ],
      ),
    );
  }
}
