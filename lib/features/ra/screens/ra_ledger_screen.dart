import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/growth_projection_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../models/ra_contribution.dart';
import '../providers/ra_provider.dart';

/// Retirement Annuity contribution ledger — structurally identical to
/// [TfsaLedgerScreen] per `ui-ux-mockup-brief.md` §5.6: annual limit (R36,000)
/// tracking only, no lifetime cap (SA RA limits are annual/income-percentage
/// based, not lifetime, unlike TFSA). Reached by pushing from an RA-type
/// portfolio's detail screen (the ledger itself is user-scoped, not
/// portfolio-scoped, per the backend's `/ra/*` endpoints).
class RaLedgerScreen extends ConsumerWidget {
  const RaLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionsAsync = ref.watch(raContributionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Retirement Annuity ledger')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(raSummaryProvider);
            ref.invalidate(raContributionsProvider);
          },
          child: contributionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load contributions')),
            data: (contributions) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _SummarySection(),
                  const SizedBox(height: 24),
                  const _ByYearSection(),
                  const SizedBox(height: 24),
                  const _GrowthProjectionSection(),
                  const SizedBox(height: 24),
                  Text('Contributions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (contributions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: Text('No contributions recorded yet.')),
                    )
                  else
                    GroupCard(
                      children: [for (final c in contributions) _ContributionRow(contribution: c)],
                    ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddRaContributionSheet(context),
        label: const Text('Add contribution'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _SummarySection extends ConsumerWidget {
  const _SummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(raSummaryProvider);

    return summaryAsync.when(
      loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
      error: (err, _) => Text(err is ApiError ? err.message : 'Failed to load summary'),
      data: (summary) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroMetricCard(
              label: 'Total contributed',
              value: formatZAR(summary.totalContributed),
            ),
            const SizedBox(height: 16),
            Text('This tax year', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatColumn(
                        label: 'Tax year ${summary.currentYear}',
                        value: formatZAR(summary.currentYearContributed),
                      ),
                    ),
                    Expanded(
                      child: _StatColumn(
                        label: 'Year remaining',
                        value: formatZAR(summary.currentYearRemaining),
                      ),
                    ),
                    Expanded(
                      child: _StatColumn(
                        label: 'Annual limit',
                        value: formatZAR(summary.annualLimit),
                      ),
                    ),
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

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: moneyTextStyle(context, fontSize: 15)),
      ],
    );
  }
}

class _ByYearSection extends ConsumerWidget {
  const _ByYearSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(raSummaryProvider);
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.byYear.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By tax year', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GroupCard(
              children: [
                for (final y in summary.byYear)
                  GroupRow(
                    title: 'Tax year ${y.taxYear}',
                    subtitle: y.overLimit ? 'Over the annual limit' : null,
                    trailing: Text(
                      '${formatZAR(y.contributed)} / ${formatZAR(y.limit)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: y.overLimit ? semantic?.danger : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _GrowthProjectionSection extends ConsumerWidget {
  const _GrowthProjectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(raSummaryProvider);

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) => GrowthProjectionCard(
        startingBalance: summary.totalContributed.toDouble(),
        label: 'RA',
      ),
    );
  }
}

class _ContributionRow extends ConsumerWidget {
  const _ContributionRow({required this.contribution});
  final RaContribution contribution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final subtitleParts = <String>[
      'Tax year ${contribution.taxYear}',
      if (contribution.provider != null) contribution.provider!,
      if (contribution.notes != null) contribution.notes!,
    ];

    return GroupRow(
      title: formatZAR(contribution.amount),
      subtitle: subtitleParts.join(' · '),
      leadingIcon: Icons.savings_outlined,
      leadingDanger: contribution.overAnnualLimitWarning,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (contribution.overAnnualLimitWarning)
            Icon(Icons.warning_amber_rounded, color: semantic?.danger, size: 18),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestroy(
      context,
      title: 'Delete contribution?',
      message: 'This removes this contribution from your RA ledger. This cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await ref.read(raApiProvider).deleteContribution(contribution.id);
      ref.invalidate(raContributionsProvider);
      ref.invalidate(raSummaryProvider);
    } on ApiError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

Future<void> showAddRaContributionSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AddContributionSheet(),
  );
}

class _AddContributionSheet extends ConsumerStatefulWidget {
  const _AddContributionSheet();

  @override
  ConsumerState<_AddContributionSheet> createState() => _AddContributionSheetState();
}

class _AddContributionSheetState extends ConsumerState<_AddContributionSheet> {
  late final TextEditingController _taxYearController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late final TextEditingController _providerController;
  DateTime? _contributionDate;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final currentTaxYear = DateTime.now().month >= 3 ? DateTime.now().year : DateTime.now().year - 1;
    _taxYearController = TextEditingController(text: '$currentTaxYear');
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _providerController = TextEditingController();
  }

  @override
  void dispose() {
    _taxYearController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _providerController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _contributionDate ?? DateTime.now(),
      firstDate: DateTime(2008),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _contributionDate = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final taxYear = int.tryParse(_taxYearController.text.trim());
      if (taxYear == null) {
        setState(() => _error = 'Enter a valid tax year.');
        return;
      }
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
      final provider = _providerController.text.trim().isEmpty ? null : _providerController.text.trim();
      await ref.read(raApiProvider).createContribution(
            taxYear: taxYear,
            amount: _amountController.text.trim(),
            contributionDate: _contributionDate,
            notes: notes,
            provider: provider,
          );
      ref.invalidate(raContributionsProvider);
      ref.invalidate(raSummaryProvider);
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
            Text('Add contribution', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _taxYearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tax year'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: 'R '),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _contributionDate == null
                    ? 'Contribution date (optional)'
                    : '${_contributionDate!.year}-${_contributionDate!.month.toString().padLeft(2, '0')}-${_contributionDate!.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            TextField(
              controller: _providerController,
              decoration: const InputDecoration(labelText: 'Provider (optional)'),
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
