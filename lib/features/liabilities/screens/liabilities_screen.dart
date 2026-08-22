import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../models/liability.dart';
import '../providers/liabilities_provider.dart';
import 'liability_detail_screen.dart';

Future<void> showLiabilitySheet(BuildContext context, {Liability? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LiabilitySheet(existing: existing),
  );
}

/// Grouped-list-cells pattern per DESIGN.md's reused component family.
/// Payment-log/progress tracking is a documented v1 gap, not built.
class LiabilitiesScreen extends ConsumerWidget {
  const LiabilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liabilitiesAsync = ref.watch(liabilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Liabilities')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(liabilitiesProvider.future),
          child: liabilitiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load liabilities')),
            data: (liabilities) {
              if (liabilities.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [Center(child: Padding(padding: EdgeInsets.only(top: 48), child: Text('No liabilities yet.')))],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [GroupCard(children: [for (final liability in liabilities) _LiabilityRow(liability: liability)])],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLiabilitySheet(context),
        label: const Text('Add liability'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _LiabilityRow extends StatelessWidget {
  const _LiabilityRow({required this.liability});
  final Liability liability;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return GroupRow(
      leadingIcon: Icons.request_quote_outlined,
      leadingDanger: true,
      title: liability.name,
      subtitle: liabilityTypeLabels[liability.liabilityType],
      trailing: Text(
        formatZAR(liability.outstandingAmount),
        style: moneyTextStyle(context, fontSize: 15, color: semantic?.danger),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiabilityDetailScreen(liability: liability)),
      ),
    );
  }
}

class _LiabilitySheet extends ConsumerStatefulWidget {
  const _LiabilitySheet({this.existing});
  final Liability? existing;

  @override
  ConsumerState<_LiabilitySheet> createState() => _LiabilitySheetState();
}

class _LiabilitySheetState extends ConsumerState<_LiabilitySheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _originalBalanceController;
  late final TextEditingController _interestRateController;
  late final TextEditingController _termMonthsController;
  late LiabilityType _liabilityType;
  late DateTime _startDate;
  bool _useLoanParams = false;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _amountController = TextEditingController(text: existing != null ? existing.outstandingAmount.toString() : '');
    _originalBalanceController = TextEditingController(text: existing?.originalBalance?.toString() ?? '');
    _interestRateController = TextEditingController(text: existing?.interestRate?.toString() ?? '');
    _termMonthsController = TextEditingController(text: existing?.termMonths?.toString() ?? '');
    _liabilityType = existing?.liabilityType ?? LiabilityType.personalLoan;
    _startDate = existing?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _originalBalanceController.dispose();
    _interestRateController.dispose();
    _termMonthsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(liabilitiesApiProvider);
      final name = _nameController.text.trim();
      if (widget.existing == null) {
        if (_useLoanParams) {
          await api.create(
            liabilityType: _liabilityType,
            name: name,
            originalBalance: _originalBalanceController.text.trim(),
            interestRate: _interestRateController.text.trim(),
            termMonths: int.tryParse(_termMonthsController.text.trim()),
            startDate: _startDate,
          );
        } else {
          await api.create(liabilityType: _liabilityType, name: name, outstandingAmount: _amountController.text.trim());
        }
      } else {
        await api.update(
          widget.existing!.id,
          liabilityType: _liabilityType,
          name: name,
          outstandingAmount: _amountController.text.trim(),
        );
      }
      ref.invalidate(liabilitiesProvider);
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
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(liabilitiesApiProvider).delete(existing.id);
      ref.invalidate(liabilitiesProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
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
            Text(isEdit ? 'Edit liability' : 'Add liability', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<LiabilityType>(
              initialValue: _liabilityType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final t in LiabilityType.values) DropdownMenuItem(value: t, child: Text(liabilityTypeLabels[t]!))],
              onChanged: (value) => setState(() => _liabilityType = value ?? _liabilityType),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Liability name')),
            const SizedBox(height: 16),
            if (!isEdit)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Amount owed')),
                  ButtonSegment(value: true, label: Text('Loan details')),
                ],
                selected: {_useLoanParams},
                onSelectionChanged: (selection) => setState(() => _useLoanParams = selection.first),
              ),
            const SizedBox(height: 16),
            if (isEdit || !_useLoanParams)
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Outstanding amount (ZAR)'),
              )
            else ...[
              TextField(
                controller: _originalBalanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Original loan amount (ZAR)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _interestRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Annual interest rate (%)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _termMonthsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Term (months)'),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start date'),
                subtitle: Text('${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickStartDate,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : _submit,
              child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
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
