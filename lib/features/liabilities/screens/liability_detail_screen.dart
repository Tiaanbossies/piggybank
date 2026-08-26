import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../../../shared/widgets/progress_card.dart';
import '../models/liability.dart';
import '../models/liability_payment.dart';
import '../providers/liabilities_provider.dart';
import 'liabilities_screen.dart' show showLiabilitySheet;

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Structural port of the web's `LiabilityDetailPage.tsx` (`/liabilities/:id`):
/// progress card (only shown once `originalBalance` is set, matching the
/// web's own fallback) + a payment-log ledger — same summary+list+add-sheet+
/// delete shape as [RaLedgerScreen]/[TfsaLedgerScreen], but keyed by
/// `liabilityId` via family providers since (unlike RA/TFSA, one ledger per
/// user) there are many liabilities per user.
class LiabilityDetailScreen extends ConsumerWidget {
  const LiabilityDetailScreen({required this.liability, super.key});
  final Liability liability;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(liabilityPaymentsProvider(liability.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(liability.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showLiabilitySheet(context, existing: liability),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(liabilityProgressProvider(liability.id));
            ref.invalidate(liabilityPaymentsProvider(liability.id));
          },
          child: paymentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load payments')),
            data: (payments) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(liability: liability),
                  const SizedBox(height: 24),
                  _ProgressSection(liability: liability),
                  const SizedBox(height: 24),
                  Text('Payment history', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (payments.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 8), child: Text('No payments logged yet.'))
                  else
                    GroupCard(
                      children: [for (final p in payments) _PaymentRow(liabilityId: liability.id, payment: p)],
                    ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _LogPaymentSheet(liabilityId: liability.id),
        ),
        label: const Text('Log payment'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.liability});
  final Liability liability;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          liabilityTypeLabels[liability.liabilityType] ?? '',
          style: TextStyle(color: semantic?.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(formatZAR(liability.outstandingAmount), style: moneyTextStyle(context, fontSize: 28)),
      ],
    );
  }
}

class _ProgressSection extends ConsumerWidget {
  const _ProgressSection({required this.liability});
  final Liability liability;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (liability.originalBalance == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              IconChip(icon: Icons.info_outline),
              SizedBox(width: 12),
              Expanded(
                child: Text('Set original balance on the liability to track progress.'),
              ),
            ],
          ),
        ),
      );
    }

    final progressAsync = ref.watch(liabilityProgressProvider(liability.id));
    return progressAsync.when(
      loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
      error: (err, _) => Text(err is ApiError ? err.message : 'Failed to load progress'),
      data: (progress) {
        final pct = progress.percentPaid.toDouble() / 100;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressCard(
              title: 'Paid off',
              pct: pct,
              footnote:
                  '${formatZAR(progress.totalPrincipalPaid)} principal paid of ${formatZAR(progress.originalBalance)}',
            ),
            const SizedBox(height: 12),
            Text('Loan breakdown', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Stat(label: 'Original', value: formatZAR(progress.originalBalance)),
                    _Stat(label: 'Principal paid', value: formatZAR(progress.totalPrincipalPaid)),
                    _Stat(label: 'Interest paid', value: formatZAR(progress.totalInterestPaid)),
                    _Stat(label: 'Payments', value: '${progress.paymentCount}'),
                    if (progress.projectedPayoffDate != null)
                      _Stat(label: 'Projected payoff', value: _formatDate(progress.projectedPayoffDate!)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: moneyTextStyle(context, fontSize: 15)),
        ],
      ),
    );
  }
}

class _PaymentRow extends ConsumerWidget {
  const _PaymentRow({required this.liabilityId, required this.payment});
  final String liabilityId;
  final LiabilityPayment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleParts = <String>[
      _formatDate(payment.paymentDate),
      'Principal ${formatZAR(payment.principalPortion)}',
      'Interest ${formatZAR(payment.interestPortion)}',
      if (payment.notes != null) payment.notes!,
    ];
    return GroupRow(
      leadingIcon: Icons.payments_outlined,
      title: formatZAR(payment.amount),
      subtitle: subtitleParts.join(' · '),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _delete(context, ref),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestroy(
      context,
      title: 'Delete payment?',
      message: "This restores the outstanding balance by this payment's principal portion. This cannot be undone.",
    );
    if (!confirmed) return;
    try {
      await ref.read(liabilitiesApiProvider).deletePayment(liabilityId, payment.id);
      ref.invalidate(liabilityPaymentsProvider(liabilityId));
      ref.invalidate(liabilityProgressProvider(liabilityId));
    } on ApiError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _LogPaymentSheet extends ConsumerStatefulWidget {
  const _LogPaymentSheet({required this.liabilityId});
  final String liabilityId;

  @override
  ConsumerState<_LogPaymentSheet> createState() => _LogPaymentSheetState();
}

class _LogPaymentSheetState extends ConsumerState<_LogPaymentSheet> {
  final _amountController = TextEditingController();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final amount = Decimal.tryParse(_amountController.text.trim());
      final principal = Decimal.tryParse(_principalController.text.trim());
      final interest = Decimal.tryParse(_interestController.text.trim());
      if (amount == null || principal == null || interest == null) {
        setState(() => _error = 'Enter valid amounts.');
        return;
      }
      if (principal + interest != amount) {
        setState(() => _error = 'Principal + interest must equal the payment amount.');
        return;
      }
      await ref.read(liabilitiesApiProvider).createPayment(
            widget.liabilityId,
            paymentDate: _paymentDate,
            amount: _amountController.text.trim(),
            principalPortion: _principalController.text.trim(),
            interestPortion: _interestController.text.trim(),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
      ref.invalidate(liabilityPaymentsProvider(widget.liabilityId));
      ref.invalidate(liabilityProgressProvider(widget.liabilityId));
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
            Text('Log payment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Payment date'),
              subtitle: Text(_formatDate(_paymentDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (ZAR)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _principalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Principal portion (ZAR)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _interestController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Interest portion (ZAR)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
