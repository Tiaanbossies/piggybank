import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/swipe_background.dart';
import '../models/savings.dart';
import '../providers/savings_provider.dart';

/// The Savings plan (cost-cutting plan, item 2): what the user needs left
/// over each month, what they actually have, and the recurring costs that
/// could close the gap.
///
/// A pushed screen, not a tab — DESIGN.md locks the bottom nav at five
/// tabs (plan decision D2). It opens from the Home card and from Settings.
class SavingsPlanScreen extends ConsumerWidget {
  const SavingsPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings plan')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            refreshSavings(ref);
            await Future.wait([
              ref.read(savingsOverviewProvider.future),
              ref.read(recurringCostsProvider.future),
            ]).catchError((_) => <Object>[]);
          },
          child: ListView(
            // The bottom inset clears the Add cost button, as on Home.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: const [
              _TargetSection(),
              SizedBox(height: 24),
              _CostsSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecurringCostSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add cost'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Target and breakdown
// ---------------------------------------------------------------------------

class _TargetSection extends ConsumerWidget {
  const _TargetSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(savingsOverviewProvider).when(
          loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
          error: (err, _) => InlineError(
            message: err is ApiError ? err.message : "Couldn't load your savings plan",
            onRetry: () => ref.invalidate(savingsOverviewProvider),
          ),
          data: (overview) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overview.target case final SavingsTarget target)
                    _TargetHeader(overview: overview, target: target)
                  else
                    const _NoTargetHeader(),
                  const SizedBox(height: 16),
                  _Breakdown(overview: overview),
                ],
              ),
            ),
          ),
        );
  }
}

class _NoTargetHeader extends StatelessWidget {
  const _NoTargetHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconChip(icon: Icons.savings_outlined, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text('Set a monthly target', style: Theme.of(context).textTheme.titleMedium)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tell Piggybank what you need left over each month, rent for example, '
          'and it shows how far you are from it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => showTargetSheet(context), child: const Text('Set target')),
      ],
    );
  }
}

class _TargetHeader extends StatelessWidget {
  const _TargetHeader({required this.overview, required this.target});
  final SavingsOverview overview;
  final SavingsTarget target;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final textTheme = Theme.of(context).textTheme;
    final date = target.targetDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(target.displayLabel, style: textTheme.titleMedium)),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit target',
              onPressed: () => showTargetSheet(context, existing: target),
            ),
          ],
        ),
        Text(
          overview.targetMet ? 'Target met' : 'Gap ${formatZAR(overview.gap)}',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: overview.targetMet ? semantic?.success : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Target ${formatZAR(target.monthlyAmount)} a month'
          '${date == null ? '' : ' · by ${dayLabel(date)}'}',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: overview.progress,
            minHeight: 8,
            color: overview.targetMet ? semantic?.success : Theme.of(context).colorScheme.primary,
            backgroundColor: semantic?.accentChipBg,
          ),
        ),
      ],
    );
  }
}

/// Income − fixed − everyday = left over, as the server computed it.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.overview});
  final SavingsOverview overview;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final negative = overview.leftOver < Decimal.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BreakdownRow(
          label: overview.incomeIsOverride ? 'Income (your figure)' : 'Income',
          value: formatZAR(overview.income),
        ),
        _BreakdownRow(label: 'Fixed costs', value: '−${formatZAR(overview.fixedCosts)}'),
        _BreakdownRow(label: 'Everyday spending', value: '−${formatZAR(overview.everydaySpending)}'),
        const Divider(height: 16),
        _BreakdownRow(
          label: 'Left over each month',
          value: formatZAR(overview.leftOver),
          bold: true,
          color: negative ? semantic?.danger : null,
        ),
        if (overview.savingsFound > Decimal.zero)
          _BreakdownRow(
            label: 'Savings found so far',
            value: '${formatZAR(overview.savingsFound)} a month',
            color: semantic?.success,
          ),
        const SizedBox(height: 8),
        Text(basisNote(overview), style: TextStyle(color: semantic?.textMuted, fontSize: 12)),
      ],
    );
  }
}

/// How much history the averages stand on, in plain words. With under a
/// month of data the figures are a rough first look, and the user should
/// know that before acting on them.
String basisNote(SavingsOverview overview) {
  if (overview.basis == OverviewBasis.monthToDate) {
    return 'Based on this month so far: a first look until a full month is in.';
  }
  if (overview.monthsOfData == 1) {
    return "Based on last month's transactions. More history gives a steadier number.";
  }
  return 'Averaged over your last ${overview.monthsOfData} months of transactions.';
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value, this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w600 : null, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recurring costs
// ---------------------------------------------------------------------------

IconData kindIcon(RecurringCostKind kind) => switch (kind) {
      RecurringCostKind.subscription => Icons.subscriptions_outlined,
      RecurringCostKind.insurance => Icons.shield_outlined,
      RecurringCostKind.debitOrder => Icons.account_balance_outlined,
      RecurringCostKind.utility => Icons.bolt_outlined,
      RecurringCostKind.other => Icons.autorenew,
    };

/// What a "Find costs" run tells the user. A run that finds nothing says
/// why it might have, since thin bank history is the usual cause.
String detectMessage(DetectResult result) {
  if (result.suggested > 0) {
    return result.suggested == 1
        ? 'Found 1 new recurring cost to review.'
        : 'Found ${result.suggested} new recurring costs to review.';
  }
  if (result.linked > 0) {
    return result.linked == 1
        ? 'Matched 1 of your costs to its bank charges.'
        : 'Matched ${result.linked} of your costs to their bank charges.';
  }
  return 'Nothing new found. Finding costs needs at least two months of bank history.';
}

/// The recurring-costs list (cost-cutting plan, item 4). Detected
/// suggestions sit on top for a one-tap Confirm or Dismiss, the same as
/// pending review: the change waits behind an Undo snackbar and is only
/// sent once it closes. Below them, the confirmed costs in the server's
/// order — cut candidates first, then by amount.
class _CostsSection extends ConsumerStatefulWidget {
  const _CostsSection();

  @override
  ConsumerState<_CostsSection> createState() => _CostsSectionState();
}

class _CostsSectionState extends ConsumerState<_CostsSection> {
  /// Suggestions hidden while their Undo window is open or their request
  /// is in flight. Only suggestion rows are filtered by it: a confirmed
  /// cost comes back from the refetch as confirmed and shows in the main
  /// list, and a dismissed one doesn't come back at all.
  final Set<String> _settling = {};
  bool _detecting = false;

  Future<void> _settle(RecurringCost cost, RecurringCostStatus status) async {
    // Captured up front: the snackbar outlives this screen if the user backs
    // out during the Undo window, and the change must still be sent then.
    final api = ref.read(savingsApiProvider);
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final verb = status == RecurringCostStatus.confirmed ? 'Confirmed' : 'Dismissed';

    setState(() => _settling.add(cost.id));
    messenger.hideCurrentSnackBar();
    final reason = await messenger
        .showSnackBar(SnackBar(
          content: Text('$verb · ${cost.name}'),
          duration: const Duration(seconds: 4),
          // Without this an action snackbar persists (Flutter 3.29+) and the
          // last item reviewed would never be sent.
          persist: false,
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ))
        .closed;

    if (reason == SnackBarClosedReason.action) {
      if (mounted) setState(() => _settling.remove(cost.id));
      return;
    }

    try {
      await api.updateRecurring(cost.id, status: status);
    } on ApiError catch (e) {
      if (mounted) setState(() => _settling.remove(cost.id));
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    // Confirming adds to fixed costs, so the overview moves too.
    container.invalidate(savingsOverviewProvider);
    container.invalidate(recurringCostsProvider);
  }

  Future<void> _detect() async {
    final api = ref.read(savingsApiProvider);
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _detecting = true);
    try {
      final result = await api.detectRecurring();
      container.invalidate(savingsOverviewProvider);
      container.invalidate(recurringCostsProvider);
      messenger.showSnackBar(SnackBar(content: Text(detectMessage(result))));
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Recurring costs', style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(
              key: const Key('find-costs'),
              onPressed: _detecting ? null : _detect,
              icon: _detecting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.manage_search),
              label: const Text('Find costs'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ref.watch(recurringCostsProvider).when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => InlineError(
                message: err is ApiError ? err.message : "Couldn't load your recurring costs",
                onRetry: () => ref.invalidate(recurringCostsProvider),
              ),
              data: (all) {
                final suggestions = all.where((c) => c.isSuggestion && !_settling.contains(c.id)).toList();
                final costs = all.where((c) => !c.isSuggestion).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (suggestions.isNotEmpty) ...[
                      _SuggestionsHeader(count: suggestions.length),
                      for (final cost in suggestions)
                        _SuggestionCard(
                          key: ValueKey(cost.id),
                          cost: cost,
                          onConfirm: () => _settle(cost, RecurringCostStatus.confirmed),
                          onDismiss: () => _settle(cost, RecurringCostStatus.dismissed),
                        ),
                      if (costs.isNotEmpty) const SizedBox(height: 16),
                    ],
                    if (costs.isEmpty && suggestions.isEmpty)
                      const EmptyState(
                        icon: Icons.autorenew,
                        title: 'No recurring costs yet.',
                        hint: 'Tap "Find costs" to spot them in your bank history, '
                            'or add subscriptions, debit orders and premiums with "Add cost".',
                        topPadding: 16,
                      )
                    else
                      for (final cost in costs) _CostRow(cost: cost),
                  ],
                );
              },
            ),
      ],
    );
  }
}

class _SuggestionsHeader extends StatelessWidget {
  const _SuggestionsHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 1 ? 'Found 1 recurring cost' : 'Found $count recurring costs',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            'These charged you every month. Confirm the real ones, dismiss the rest.',
            style: TextStyle(fontSize: 12, color: semantic?.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A detected charge waiting for review. Swipe right or tap Confirm to add
/// it to the plan; swipe left or tap Dismiss and it is never suggested
/// again. Tapping the card opens the sheet to correct it first.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.cost, required this.onConfirm, required this.onDismiss, super.key});
  final RecurringCost cost;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final colors = Theme.of(context).colorScheme;
    final seen = cost.lastSeenOn;
    return Dismissible(
      key: ValueKey('dismiss-${cost.id}'),
      background: SwipeBackground(
        color: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
        icon: Icons.check,
        label: 'Confirm',
        alignment: Alignment.centerLeft,
        bottomMargin: 8,
      ),
      secondaryBackground: SwipeBackground(
        color: colors.errorContainer,
        foreground: colors.onErrorContainer,
        icon: Icons.close,
        label: 'Dismiss',
        alignment: Alignment.centerRight,
        bottomMargin: 8,
      ),
      onDismissed: (direction) => direction == DismissDirection.startToEnd ? onConfirm() : onDismiss(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showRecurringCostSheet(context, existing: cost),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    IconChip(icon: kindIcon(cost.kind), size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cost.name,
                              style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            [
                              cost.kind.label,
                              if (seen != null) 'last charged ${dayLabel(seen, withYear: false)}',
                            ].join(' · '),
                            style: TextStyle(fontSize: 12, color: semantic?.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatZAR(cost.monthlyAmount)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
                    const SizedBox(width: 8),
                    FilledButton.tonal(onPressed: onConfirm, child: const Text('Confirm')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.cost});
  final RecurringCost cost;

  String get _subtitle {
    final parts = <String>[cost.kind.label];
    if (cost.decision == RecurringCostDecision.cut && cost.savedAmount != null) {
      parts.add('Cut, saves ${formatZAR(cost.savedAmount)}');
    } else if (cost.decision != RecurringCostDecision.undecided) {
      parts.add(cost.decision.label);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final isCut = cost.decision == RecurringCostDecision.cut;
    final isCandidate = cost.decision == RecurringCostDecision.cutCandidate;
    final seen = cost.lastSeenOn;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showRecurringCostSheet(context, existing: cost),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconChip(icon: kindIcon(cost.kind), size: 40, danger: isCandidate || cost.stillCharged),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cost.name, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCut ? semantic?.success : (isCandidate ? semantic?.danger : semantic?.textMuted),
                      ),
                    ),
                    if (cost.stillCharged) ...[
                      const SizedBox(height: 4),
                      _Pill(
                        label: seen == null ? 'Still charged' : 'Still charged · ${dayLabel(seen, withYear: false)}',
                        color: semantic?.danger,
                        background: semantic?.dangerChipBg,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatZAR(cost.monthlyAmount),
                style: TextStyle(
                  decoration: isCut ? TextDecoration.lineThrough : null,
                  color: isCut ? semantic?.textMuted : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small status pill, styled like the shared `StatusBadge`.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color, this.background});
  final String label;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets
// ---------------------------------------------------------------------------

/// "1 200,50" and "1200.50" both mean R1 200.50 to a South African user;
/// the API wants the second. Null when it isn't a positive number.
Decimal? parseAmount(String text) {
  final cleaned = text.replaceAll(' ', '').replaceAll(',', '.');
  final value = Decimal.tryParse(cleaned);
  if (value == null || value <= Decimal.zero) return null;
  return value;
}

Future<void> showTargetSheet(BuildContext context, {SavingsTarget? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => TargetSheet(existing: existing),
  );
}

class TargetSheet extends ConsumerStatefulWidget {
  const TargetSheet({this.existing, super.key});
  final SavingsTarget? existing;

  @override
  ConsumerState<TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<TargetSheet> {
  late final TextEditingController _label;
  late final TextEditingController _amount;
  late final TextEditingController _income;
  DateTime? _targetDate;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = TextEditingController(text: existing?.label ?? '');
    _amount = TextEditingController(text: existing?.monthlyAmount.toString() ?? '');
    _income = TextEditingController(text: existing?.incomeOverride?.toString() ?? '');
    _targetDate = existing?.targetDate;
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _income.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      refreshSavings(ref);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter the amount you need each month.');
      return;
    }
    final incomeText = _income.text.trim();
    final income = incomeText.isEmpty ? null : parseAmount(incomeText);
    if (incomeText.isNotEmpty && income == null) {
      setState(() => _error = 'Enter your income as a number, or leave it empty.');
      return;
    }
    final label = _label.text.trim();
    _run(() => ref.read(savingsApiProvider).putTarget(
          monthlyAmount: amount.toString(),
          label: label.isEmpty ? null : label,
          targetDate: _targetDate,
          incomeOverride: income?.toString(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final date = _targetDate;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Set your target' : 'Edit target',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              key: const Key('target-amount'),
              controller: _amount,
              autofocus: widget.existing == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Needed each month (R)', hintText: 'e.g. 8000'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('target-label'),
              controller: _label,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'What is it for? (optional)', hintText: 'e.g. Rent'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('By when? (optional)'),
              subtitle: Text(date == null ? 'No date' : dayLabel(date)),
              trailing: date == null
                  ? const Icon(Icons.calendar_today)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear date',
                      onPressed: () => setState(() => _targetDate = null),
                    ),
              onTap: _pickDate,
            ),
            TextField(
              key: const Key('target-income'),
              controller: _income,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monthly income (optional)',
                helperText: 'Leave empty to use the income Piggybank has recorded.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _run(() => ref.read(savingsApiProvider).deleteTarget()),
                child: Text('Remove target', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showRecurringCostSheet(BuildContext context, {RecurringCost? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => RecurringCostSheet(existing: existing),
  );
}

class RecurringCostSheet extends ConsumerStatefulWidget {
  const RecurringCostSheet({this.existing, super.key});
  final RecurringCost? existing;

  @override
  ConsumerState<RecurringCostSheet> createState() => _RecurringCostSheetState();
}

class _RecurringCostSheetState extends ConsumerState<RecurringCostSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _saved;
  late RecurringCostKind _kind;
  late RecurringCostDecision _decision;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _amount = TextEditingController(text: existing?.monthlyAmount.toString() ?? '');
    _saved = TextEditingController(text: existing?.savedAmount?.toString() ?? '');
    _kind = existing?.kind ?? RecurringCostKind.subscription;
    _decision = existing?.decision ?? RecurringCostDecision.undecided;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _saved.dispose();
    super.dispose();
  }

  void _pickDecision(Set<RecurringCostDecision> selection) {
    final next = selection.isEmpty ? RecurringCostDecision.undecided : selection.first;
    setState(() {
      _decision = next;
      // A cut defaults to a cancellation: the whole monthly amount saved.
      if (next == RecurringCostDecision.cut && _saved.text.trim().isEmpty) _saved.text = _amount.text.trim();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      refreshSavings(ref);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter the monthly amount.');
      return;
    }
    Decimal? saved;
    if (_decision == RecurringCostDecision.cut) {
      saved = parseAmount(_saved.text) ?? amount;
      if (saved > amount) {
        setState(() => _error = "The saving can't be more than the cost.");
        return;
      }
    }
    final api = ref.read(savingsApiProvider);
    final existing = widget.existing;
    _run(() async {
      if (existing == null) {
        await api.createRecurring(
          name: name,
          monthlyAmount: amount.toString(),
          kind: _kind,
          decision: _decision,
          savedAmount: saved?.toString(),
        );
      } else {
        await api.updateRecurring(
          existing.id,
          name: name,
          monthlyAmount: amount.toString(),
          kind: _kind,
          // Correcting a suggestion and saving it accepts it.
          status: existing.isSuggestion ? RecurringCostStatus.confirmed : null,
          decision: _decision,
          savedAmount: saved?.toString(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add recurring cost' : 'Edit recurring cost',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              key: const Key('cost-name'),
              controller: _name,
              autofocus: existing == null,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Netflix, car insurance'),
            ),
            TextField(
              key: const Key('cost-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Per month (R)'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RecurringCostKind>(
              key: const Key('cost-kind'),
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final kind in RecurringCostKind.values) DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: (kind) => setState(() => _kind = kind ?? _kind),
            ),
            const SizedBox(height: 20),
            Text('Keep it or cut it?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<RecurringCostDecision>(
              key: const Key('cost-decision'),
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [
                for (final d in [
                  RecurringCostDecision.keep,
                  RecurringCostDecision.cutCandidate,
                  RecurringCostDecision.cut,
                ])
                  ButtonSegment(value: d, label: Text(d.label)),
              ],
              selected: _decision == RecurringCostDecision.undecided ? {} : {_decision},
              onSelectionChanged: _pickDecision,
            ),
            if (_decision == RecurringCostDecision.cut) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('cost-saved'),
                controller: _saved,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Saving per month (R)',
                  helperText: 'The whole amount if you cancelled it, or what a cheaper plan saves.',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(existing?.isSuggestion ?? false ? 'Save and confirm' : 'Save'),
            ),
            if (existing != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _run(() => ref.read(savingsApiProvider).deleteRecurring(existing.id)),
                child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
