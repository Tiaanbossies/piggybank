import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../portfolios/providers/portfolios_provider.dart';
import '../../transactions/providers/transactions_provider.dart' show commonCategories;
import '../models/detected_event.dart';
import '../providers/detection_provider.dart';

/// Settings > Notification & email detection > Review — plan §5 Phase E's
/// "pending-items review screen (extracted fields shown, Confirm/Discard,
/// holding-selection prompt for investment events)". Every row here is a
/// [DetectedEvent] the backend already ran through Ollama extraction; this
/// screen is the one place a suggestion becomes (or doesn't become) a real
/// Transaction/Dividend/HoldingTrade — nothing here is written automatically.
class PendingReviewScreen extends ConsumerWidget {
  const PendingReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review detected items')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(pendingEventsProvider),
          child: pendingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) =>
                Center(child: Text(err is ApiError ? err.message : 'Failed to load detected items')),
            data: (events) {
              if (events.isEmpty) {
                return ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nothing waiting for review. New suggestions from your allowlisted apps and '
                        'connected Gmail account will show up here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, i) => _EventCard(event: events[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EventCard extends ConsumerStatefulWidget {
  const _EventCard({required this.event});
  final DetectedEvent event;

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  bool _busy = false;
  String? _error;

  Future<void> _discard() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(detectionApiProvider).discardEvent(widget.event.id);
      ref.invalidate(pendingEventsProvider);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final result = await showModalBottomSheet<_ConfirmResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConfirmSheet(event: widget.event),
    );
    if (result == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(detectionApiProvider).confirmEvent(
            widget.event.id,
            accountId: result.accountId,
            category: result.category,
            subcategory: result.subcategory,
            holdingId: result.holdingId,
            quantity: result.quantity,
            pricePerUnit: result.pricePerUnit,
            tradeType: result.tradeType,
          );
      ref.invalidate(pendingEventsProvider);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final extracted = event.extractedJson;
    final isSkippedInvalid = event.status == DetectionStatus.skippedInvalid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(event.sourceType == DetectionSourceType.email ? Icons.email_outlined : Icons.notifications_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(event.sourceRef, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.rawText, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            if (isSkippedInvalid)
              Text(
                event.errorReason ?? 'Could not extract a financial event from this item.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (extracted != null)
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Field('Kind', event.eventKind ?? '—'),
                  _Field('Amount', formatZAR(extracted['amount'])),
                  if (extracted['date'] != null) _Field('Date', extracted['date'].toString()),
                  if (extracted['ticker'] != null) _Field('Ticker', extracted['ticker'].toString()),
                  if (extracted['description'] != null) _Field('Description', extracted['description'].toString()),
                ],
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _busy ? null : _discard, child: const Text('Discard')),
                const SizedBox(width: 8),
                if (!isSkippedInvalid)
                  ElevatedButton(onPressed: _busy ? null : _confirm, child: const Text('Confirm')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ],
    );
  }
}

/// What `_ConfirmSheet` hands back to `_EventCard._confirm` — only the
/// fields relevant to the event's own `event_kind` are ever non-null; the
/// rest pass straight through as null to `DetectionApi.confirmEvent`.
class _ConfirmResult {
  const _ConfirmResult({
    this.accountId,
    this.category,
    this.subcategory,
    this.holdingId,
    this.quantity,
    this.pricePerUnit,
    this.tradeType,
  });

  final String? accountId;
  final String? category;
  final String? subcategory;
  final String? holdingId;
  final String? quantity;
  final String? pricePerUnit;
  final String? tradeType;
}

class _ConfirmSheet extends ConsumerStatefulWidget {
  const _ConfirmSheet({required this.event});
  final DetectedEvent event;

  @override
  ConsumerState<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends ConsumerState<_ConfirmSheet> {
  final _categoryController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  String? _accountId;
  String? _holdingId;
  String _tradeType = 'buy';
  String? _error;

  @override
  void dispose() {
    _categoryController.dispose();
    _subcategoryController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final kind = widget.event.eventKind;
    if (kind == 'transaction') {
      if (_categoryController.text.trim().isEmpty) {
        setState(() => _error = 'Choose a category — the extraction never proposes one.');
        return;
      }
      Navigator.of(context).pop(_ConfirmResult(
        accountId: _accountId,
        category: _categoryController.text.trim(),
        subcategory: _subcategoryController.text.trim().isEmpty ? null : _subcategoryController.text.trim(),
      ));
    } else if (kind == 'dividend') {
      if (_holdingId == null) {
        setState(() => _error = 'Select which holding this dividend belongs to.');
        return;
      }
      Navigator.of(context).pop(_ConfirmResult(holdingId: _holdingId));
    } else if (kind == 'trade') {
      final qty = _quantityController.text.trim();
      final price = _priceController.text.trim();
      if (_holdingId == null || qty.isEmpty || price.isEmpty) {
        setState(() => _error = 'Select a holding and enter quantity + price to confirm this trade.');
        return;
      }
      Navigator.of(context).pop(_ConfirmResult(
        holdingId: _holdingId,
        quantity: qty,
        pricePerUnit: price,
        tradeType: _tradeType,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.event.eventKind;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Confirm ${kind ?? 'item'}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (kind == 'transaction') ..._transactionFields(),
            if (kind == 'dividend') ..._holdingField(),
            if (kind == 'trade') ..._tradeFields(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _submit, child: const Text('Confirm')),
          ],
        ),
      ),
    );
  }

  List<Widget> _transactionFields() {
    final accountsAsync = ref.watch(accountsProvider);
    return [
      Autocomplete<String>(
        optionsBuilder: (value) {
          if (value.text.isEmpty) return commonCategories;
          return commonCategories.where((c) => c.toLowerCase().contains(value.text.toLowerCase()));
        },
        onSelected: (selection) => _categoryController.text = selection,
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          controller.addListener(() => _categoryController.text = controller.text);
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(labelText: 'Category'),
          );
        },
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _subcategoryController,
        decoration: const InputDecoration(labelText: 'Subcategory (optional)'),
      ),
      const SizedBox(height: 16),
      accountsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const SizedBox.shrink(),
        data: (accounts) => DropdownButtonFormField<String>(
          initialValue: _accountId,
          decoration: const InputDecoration(labelText: 'Account (optional)'),
          items: [
            const DropdownMenuItem(child: Text('None')),
            for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: (value) => setState(() => _accountId = value),
        ),
      ),
    ];
  }

  List<Widget> _holdingField() {
    final holdingsAsync = ref.watch(allHoldingsProvider);
    return [
      holdingsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('Could not load holdings.'),
        data: (entries) => DropdownButtonFormField<String>(
          initialValue: _holdingId,
          decoration: const InputDecoration(labelText: 'Holding'),
          items: [
            for (final (portfolio, holding) in entries)
              DropdownMenuItem(value: holding.id, child: Text('${holding.ticker} — ${portfolio.name}')),
          ],
          onChanged: (value) => setState(() => _holdingId = value),
        ),
      ),
    ];
  }

  List<Widget> _tradeFields() {
    return [
      ..._holdingField(),
      const SizedBox(height: 16),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'buy', label: Text('Buy')),
          ButtonSegment(value: 'sell', label: Text('Sell')),
        ],
        selected: {_tradeType},
        onSelectionChanged: (selection) => setState(() => _tradeType = selection.first),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _quantityController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Quantity'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _priceController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Price per unit (ZAR)'),
      ),
    ];
  }
}
