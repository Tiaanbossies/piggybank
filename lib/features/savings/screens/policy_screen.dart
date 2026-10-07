import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/state_views.dart';
import '../../assets/models/asset.dart';
import '../../assets/providers/assets_provider.dart';
import '../models/policy.dart';
import '../models/savings.dart';
import '../providers/savings_provider.dart';
import 'savings_plan_screen.dart' show parseAmount;

/// One insurance cost's policy details and the facts-only check on them
/// (cost-cutting plan, item 6). Opens from the policy button on an
/// insurance cost in the Savings plan.
///
/// The check never says a premium is too high. It lays out what the
/// premium is against what it covers, against the asset's value, against a
/// year ago and against income, each in plain words, and the user decides
/// (FAIS: information, not advice).
class PolicyScreen extends ConsumerStatefulWidget {
  const PolicyScreen({required this.cost, super.key});
  final RecurringCost cost;

  @override
  ConsumerState<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends ConsumerState<PolicyScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// After a save the check card appears (or changes) at the top, while the
  /// user is at the Save button at the bottom.
  void _showCheck() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cost = widget.cost;
    return Scaffold(
      appBar: AppBar(title: Text(cost.name, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ref.watch(policyProvider(cost.id)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: InlineError(
                  message: err is ApiError ? err.message : "Couldn't load the policy details",
                  onRetry: () => ref.invalidate(policyProvider(cost.id)),
                ),
              ),
              data: (policy) => ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (policy != null) ...[
                    PolicyCheckCard(policyId: policy.id),
                    const SizedBox(height: 24),
                    Text('Policy details', style: Theme.of(context).textTheme.titleMedium),
                  ] else
                    _Intro(premium: cost.monthlyAmount),
                  const SizedBox(height: 8),
                  _PolicyForm(
                    // A fresh form after the first save, so its fields start
                    // from what the server stored.
                    key: ValueKey(policy?.id ?? 'new'),
                    costId: cost.id,
                    existing: policy,
                    onSaved: _showCheck,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.premium});
  final Decimal premium;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add the policy details', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Tell Piggybank what this ${formatZAR(premium)} a month covers, and it lays out the facts: '
          'what you pay a year, how that compares with what it covers, and how much it went up. '
          "Leave out policy and ID numbers; they aren't needed.",
          style: TextStyle(fontSize: 13, color: semantic?.textMuted),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The check
// ---------------------------------------------------------------------------

enum FactTone { neutral, attention }

/// One line of the policy check: a short label, the figure, and one
/// sentence on what it means.
class PolicyFact {
  const PolicyFact({required this.label, required this.value, required this.note, this.tone = FactTone.neutral});
  final String label;
  final String value;
  final String note;
  final FactTone tone;
}

/// "4.2" → "4,2%", in the same South African style as `formatZAR`.
String _pct(Decimal value) => '${value.toString().replaceAll('.', ',')}%';

String _valuedOn(DateTime? date) => date == null ? '' : ' (valued ${dayLabel(date)})';

/// The facts the check could work out, in reading order. A fact the server
/// returned as null is left out, never shown as zero.
List<PolicyFact> policyFacts(PolicyCheck check) {
  final facts = <PolicyFact>[
    PolicyFact(
      label: 'Premium per year',
      value: formatZAR(check.premiumPerYear),
      note: '${formatZAR(check.monthlyPremium)} a month, times 12.',
    ),
  ];

  final pctOfCover = check.premiumPctOfCover;
  if (pctOfCover != null) {
    facts.add(PolicyFact(
      label: 'Share of what it covers',
      value: _pct(pctOfCover),
      note: 'Each year the premium comes to this share of the ${formatZAR(check.coverValue)} the policy covers.',
    ));
  }

  final position = check.coverPosition;
  final diff = check.coverVsAsset;
  if (position != null && diff != null && check.assetValue != null) {
    final cover = formatZAR(check.coverValue);
    final worth = '${formatZAR(check.assetValue)}${_valuedOn(check.assetValuedOn)}';
    final value = switch (position) {
      CoverPosition.inLine => 'In line',
      CoverPosition.overInsured => '${formatZAR(diff.abs())} more',
      CoverPosition.underInsured => '${formatZAR(diff.abs())} less',
    };
    if (check.policyType == PolicyType.building) {
      // A property's value includes the land; building cover is meant to
      // pay for rebuilding. A gap is a fact to know, not a red flag.
      facts.add(PolicyFact(
        label: 'Cover against property value',
        value: value,
        note: 'Insured for $cover; your Assets list values the property at $worth. '
            'Building cover is meant to pay the cost to rebuild, which can differ from what it would sell for.',
      ));
    } else {
      facts.add(PolicyFact(
        label: 'Cover against car value',
        value: value,
        tone: position == CoverPosition.inLine ? FactTone.neutral : FactTone.attention,
        note: switch (position) {
          CoverPosition.inLine => 'Insured for $cover; your Assets list values the car at $worth. Within 10%.',
          CoverPosition.overInsured => 'Insured for $cover, but your Assets list values the car at $worth. '
              'A claim usually pays what the car is worth at the time, so see how your policy settles claims.',
          CoverPosition.underInsured => 'Insured for $cover, but your Assets list values the car at $worth. '
              'A claim could pay out less than the car is worth.',
        },
      ));
    }
  }

  final increase = check.premiumIncreasePct;
  final yearAgo = check.premiumYearAgo;
  if (increase != null && yearAgo != null) {
    final on = check.premiumYearAgoOn;
    facts.add(PolicyFact(
      label: 'Change in a year',
      value: increase > Decimal.zero
          ? 'Up ${_pct(increase)}'
          : (increase < Decimal.zero ? 'Down ${_pct(increase.abs())}' : 'No change'),
      tone: increase > Decimal.zero ? FactTone.attention : FactTone.neutral,
      note: 'Your bank was charged ${formatZAR(yearAgo)}${on == null ? '' : ' on ${dayLabel(on)}'}, '
          'and ${formatZAR(check.premiumNow)} on the latest charge.',
    ));
  }

  final ofIncome = check.premiumPctOfIncome;
  if (ofIncome != null) {
    facts.add(PolicyFact(
      label: 'Share of your income',
      value: _pct(ofIncome),
      note: 'The ${formatZAR(check.monthlyPremium)} premium out of ${formatZAR(check.income)} a month.',
    ));
  }
  return facts;
}

/// What would fill in the facts the check had to leave out.
List<String> missingFactHints(PolicyCheck check) {
  final type = check.policyType;
  return [
    if (type.assetType != null && check.coverPosition == null)
      if (type == PolicyType.car && check.coverValue == null)
        "Add the car's insured value to compare it with what the car is worth."
      else if (check.assetValue == null && type == PolicyType.car)
        'Link the car from your Assets list to compare the cover with what it is worth.'
      else if (check.assetValue == null)
        'Link the property from your Assets list to compare the cover with its value.',
    if (check.premiumIncreasePct == null)
      'The change in a year shows once Piggybank has matched a year of bank charges to this premium.',
    if (check.premiumPctOfIncome == null) 'The share of your income shows once Piggybank knows your income.',
  ];
}

class PolicyCheckCard extends ConsumerWidget {
  const PolicyCheckCard({required this.policyId, super.key});
  final String policyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return ref.watch(policyCheckProvider(policyId)).when(
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (err, _) => InlineError(
            message: err is ApiError ? err.message : "Couldn't run the policy check",
            onRetry: () => ref.invalidate(policyCheckProvider(policyId)),
          ),
          data: (check) {
            final hints = missingFactHints(check);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Policy check', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    for (final fact in policyFacts(check)) _FactRow(fact: fact),
                    if (hints.isNotEmpty) ...[
                      const Divider(height: 16),
                      for (final hint in hints)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 16, color: semantic?.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(hint, style: TextStyle(fontSize: 12, color: semantic?.textMuted)),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Facts from your own figures, not advice. What to do about them is your call.',
                      style: TextStyle(fontSize: 12, color: semantic?.textMuted, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});
  final PolicyFact fact;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final attention = fact.tone == FactTone.attention;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(fact.label, style: Theme.of(context).textTheme.titleSmall)),
              const SizedBox(width: 8),
              Text(
                fact.value,
                style: TextStyle(fontWeight: FontWeight.w600, color: attention ? semantic?.danger : null),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(fact.note, style: TextStyle(fontSize: 12, color: semantic?.textMuted)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The form
// ---------------------------------------------------------------------------

/// Empty is null; anything else must be a number, at least zero when
/// [allowZero] (an excess can be R0), above zero otherwise.
({Decimal? value, bool ok}) _optionalAmount(String text, {bool allowZero = false}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return (value: null, ok: true);
  if (allowZero && Decimal.tryParse(trimmed.replaceAll(' ', '').replaceAll(',', '.')) == Decimal.zero) {
    return (value: Decimal.zero, ok: true);
  }
  final value = parseAmount(trimmed);
  return (value: value, ok: value != null);
}

String? _text(TextEditingController controller) {
  final trimmed = controller.text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _PolicyForm extends ConsumerStatefulWidget {
  const _PolicyForm({required this.costId, required this.existing, required this.onSaved, super.key});
  final String costId;
  final InsurancePolicy? existing;
  final VoidCallback onSaved;

  @override
  ConsumerState<_PolicyForm> createState() => _PolicyFormState();
}

class _PolicyFormState extends ConsumerState<_PolicyForm> {
  final _insurer = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _vehicleValue = TextEditingController();
  final _excess = TextEditingController();
  final _insuredValue = TextEditingController();
  final _coverAmount = TextEditingController();
  final _planName = TextEditingController();
  PolicyType? _type;
  Province? _province;
  CarCoverType? _coverType;
  String? _assetId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.existing?.details;
    if (d == null) return;
    _type = d.type;
    _province = d.province;
    _coverType = d.coverType;
    _assetId = d.assetId;
    _insurer.text = d.insurer ?? '';
    _make.text = d.make ?? '';
    _model.text = d.model ?? '';
    _year.text = d.year?.toString() ?? '';
    _vehicleValue.text = d.vehicleValue?.toString() ?? '';
    _excess.text = d.excess?.toString() ?? '';
    _insuredValue.text = d.insuredValue?.toString() ?? '';
    _coverAmount.text = d.coverAmount?.toString() ?? '';
    _planName.text = d.planName ?? '';
  }

  @override
  void dispose() {
    for (final c in [_insurer, _make, _model, _year, _vehicleValue, _excess, _insuredValue, _coverAmount, _planName]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickType(PolicyType? type) {
    setState(() {
      // A vehicle can't stay linked to building cover, and so on.
      if (type?.assetType != _type?.assetType) _assetId = null;
      _type = type;
      _error = null;
    });
  }

  /// Linking an asset fills in the insured value when it's still empty; the
  /// user corrects it to the figure on their schedule.
  void _pickAsset(Asset? asset) {
    setState(() {
      _assetId = asset?.id;
      if (asset == null) return;
      final field = _type == PolicyType.car ? _vehicleValue : _insuredValue;
      if (field.text.trim().isEmpty) field.text = asset.currentValue.toString();
    });
  }

  /// Reads the form into details the server accepts, or sets [_error].
  PolicyDetails? _read(PolicyType type) {
    final vehicleValue = _optionalAmount(_vehicleValue.text);
    final excess = _optionalAmount(_excess.text, allowZero: true);
    final insuredValue = _optionalAmount(_insuredValue.text);
    final coverAmount = _optionalAmount(_coverAmount.text);
    final String? bad = switch (type.form) {
      PolicyForm.car when !vehicleValue.ok => 'Enter the insured value as a number, or leave it empty.',
      PolicyForm.car when !excess.ok => 'Enter the excess as a number, or leave it empty.',
      PolicyForm.property when !insuredValue.ok => "Enter the amount it's insured for as a number.",
      PolicyForm.cover when !coverAmount.ok => 'Enter the cover amount as a number.',
      _ => null,
    };
    final yearText = _year.text.trim();
    final year = int.tryParse(yearText);
    final details = PolicyDetails(
      type: type,
      insurer: _text(_insurer),
      province: _province,
      assetId: type.assetType == null ? null : _assetId,
      make: _text(_make),
      model: _text(_model),
      year: year,
      vehicleValue: vehicleValue.value,
      coverType: _coverType,
      excess: excess.value,
      insuredValue: insuredValue.value,
      coverAmount: coverAmount.value,
      planName: _text(_planName),
    );
    final problem = bad ?? details.problem;
    if (problem != null) {
      setState(() => _error = problem);
      return null;
    }
    return details;
  }

  Future<void> _run(Future<void> Function() action, {required String done}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // The cost list shows whether a policy is attached; the check reads
      // the new details.
      ref.invalidate(recurringCostsProvider);
      if (widget.existing case final InsurancePolicy p) ref.invalidate(policyCheckProvider(p.id));
      ref.invalidate(policyProvider(widget.costId));
      messenger.showSnackBar(SnackBar(content: Text(done)));
      widget.onSaved();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final type = _type;
    if (type == null) {
      setState(() => _error = 'Choose what the policy covers.');
      return;
    }
    final details = _read(type);
    if (details == null) return;
    final api = ref.read(savingsApiProvider);
    _run(() => api.putPolicy(widget.costId, details), done: 'Policy details saved.');
  }

  void _remove() {
    final api = ref.read(savingsApiProvider);
    _run(() => api.deletePolicy(widget.costId), done: 'Policy details removed.');
  }

  @override
  Widget build(BuildContext context) {
    final type = _type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        DropdownButtonFormField<PolicyType>(
          key: const Key('policy-type'),
          initialValue: type,
          decoration: const InputDecoration(labelText: 'What does it cover?'),
          items: [for (final t in PolicyType.values) DropdownMenuItem(value: t, child: Text(t.label))],
          onChanged: _busy ? null : _pickType,
        ),
        if (type != null) ...[
          const SizedBox(height: 16),
          ..._fieldsFor(type),
          const SizedBox(height: 16),
          TextField(
            key: const Key('policy-insurer'),
            controller: _insurer,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Insurer (optional)'),
          ),
          DropdownButtonFormField<Province?>(
            key: const Key('policy-province'),
            initialValue: _province,
            decoration: const InputDecoration(
              labelText: 'Province (optional)',
              helperText: 'Premiums differ from area to area.',
            ),
            items: [
              const DropdownMenuItem<Province?>(value: null, child: Text('Not set')),
              for (final p in Province.values) DropdownMenuItem<Province?>(value: p, child: Text(p.label)),
            ],
            onChanged: _busy ? null : (p) => setState(() => _province = p),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('policy-save'),
          onPressed: _busy ? null : _save,
          child: Text(widget.existing == null ? 'Save and check' : 'Save changes'),
        ),
        if (widget.existing != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _remove,
            child: Text('Remove policy details', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ],
    );
  }

  List<Widget> _fieldsFor(PolicyType type) {
    const money = TextInputType.numberWithOptions(decimal: true);
    final assetType = type.assetType;
    return switch (type.form) {
      PolicyForm.car => [
          if (assetType != null) _AssetPicker(assetType: assetType, selectedId: _assetId, onChanged: _pickAsset),
          TextField(
            key: const Key('policy-make'),
            controller: _make,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Make', hintText: 'e.g. Toyota'),
          ),
          TextField(
            key: const Key('policy-model'),
            controller: _model,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Model', hintText: 'e.g. Corolla 1.8'),
          ),
          TextField(
            key: const Key('policy-year'),
            controller: _year,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Year', counterText: ''),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CarCoverType>(
            key: const Key('policy-cover-type'),
            initialValue: _coverType,
            decoration: const InputDecoration(labelText: 'Type of cover'),
            items: [for (final c in CarCoverType.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: _busy ? null : (c) => setState(() => _coverType = c),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('policy-vehicle-value'),
            controller: _vehicleValue,
            keyboardType: money,
            decoration: const InputDecoration(
              labelText: 'Insured value (R, optional)',
              helperText: 'The value on your policy schedule.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('policy-excess'),
            controller: _excess,
            keyboardType: money,
            decoration: const InputDecoration(labelText: 'Basic excess (R, optional)'),
          ),
        ],
      PolicyForm.property => [
          if (assetType != null) _AssetPicker(assetType: assetType, selectedId: _assetId, onChanged: _pickAsset),
          TextField(
            key: const Key('policy-insured-value'),
            controller: _insuredValue,
            keyboardType: money,
            decoration: InputDecoration(
              labelText: 'Sum insured (R)',
              helperText: type == PolicyType.building
                  ? 'What the policy covers the building for, on your schedule.'
                  : 'What the policy covers your belongings for, on your schedule.',
            ),
          ),
        ],
      PolicyForm.cover => [
          TextField(
            key: const Key('policy-cover-amount'),
            controller: _coverAmount,
            keyboardType: money,
            decoration: const InputDecoration(labelText: 'Cover amount (R)', helperText: 'What the policy pays out.'),
          ),
        ],
      PolicyForm.plan => [
          TextField(
            key: const Key('policy-plan'),
            controller: _planName,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Plan name',
              helperText: 'As it shows on your statement, without your membership number.',
            ),
          ),
        ],
    };
  }
}

/// Links a vehicle (car cover) or property (building cover) from the
/// user's Assets list. A failed or empty asset load never blocks the form:
/// the link is optional.
class _AssetPicker extends ConsumerWidget {
  const _AssetPicker({required this.assetType, required this.selectedId, required this.onChanged});
  final AssetType assetType;
  final String? selectedId;
  final ValueChanged<Asset?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCar = assetType == AssetType.vehicle;
    final assets = ref.watch(assetsProvider).valueOrNull;
    if (assets == null) return const SizedBox.shrink();
    final matching = assets.where((a) => a.assetType == assetType).toList();
    if (matching.isEmpty) {
      final semantic = Theme.of(context).extension<AppSemanticColors>();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          isCar
              ? 'Add your car to your Assets list to compare the cover with what it is worth.'
              : 'Add the property to your Assets list to compare the cover with its value.',
          style: TextStyle(fontSize: 12, color: semantic?.textMuted),
        ),
      );
    }
    // A linked asset that has since been deleted shows as not linked.
    final selected = matching.any((a) => a.id == selectedId) ? selectedId : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String?>(
        key: const Key('policy-asset'),
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: isCar ? 'Which car? (optional)' : 'Which property? (optional)',
          helperText: 'From your Assets list, to compare the cover with its value.',
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Not linked')),
          for (final a in matching)
            DropdownMenuItem<String?>(
              value: a.id,
              child: Text('${a.name} · ${formatZAR(a.currentValue)}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) => onChanged(id == null ? null : matching.firstWhere((a) => a.id == id)),
      ),
    );
  }
}
