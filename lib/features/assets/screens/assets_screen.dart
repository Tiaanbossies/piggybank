import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../models/asset.dart';
import '../providers/assets_provider.dart';

const _assetTypeIcons = {
  AssetType.cash: Icons.payments_outlined,
  AssetType.savingsAccount: Icons.savings_outlined,
  AssetType.property: Icons.home_outlined,
  AssetType.vehicle: Icons.directions_car_outlined,
  AssetType.investment: Icons.show_chart_outlined,
  AssetType.retirement: Icons.beach_access_outlined,
  AssetType.other: Icons.category_outlined,
};

/// Grouped-list-cells pattern per DESIGN.md's reused component family, plus
/// a "Total assets" hero card (client-side sum, same pattern as Accounts'
/// "Total balance" — no new API call) and per-[AssetType] icon chips. Core
/// CRUD only — the savings-account preset/interest-calculator sub-feature is
/// a documented v1 gap.
class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Assets')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(assetsProvider.future),
          child: assetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load assets')),
            data: (assets) {
              if (assets.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [Center(child: Padding(padding: EdgeInsets.only(top: 48), child: Text('No assets yet.')))],
                );
              }
              final total = assets.fold(Decimal.zero, (sum, a) => sum + a.currentValue);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  HeroMetricCard(label: 'Total assets', value: formatZAR(total)),
                  const SizedBox(height: 24),
                  GroupCard(children: [for (final asset in assets) _AssetRow(asset: asset)]),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _AssetSheet()),
        label: const Text('Add asset'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    return GroupRow(
      leadingIcon: _assetTypeIcons[asset.assetType],
      title: asset.name,
      subtitle:
          '${assetTypeLabels[asset.assetType]}${asset.institutionName != null ? ' · ${asset.institutionName}' : ''}',
      trailing: Text(formatZAR(asset.currentValue), style: moneyTextStyle(context, fontSize: 15)),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _AssetSheet(existing: asset),
      ),
    );
  }
}

class _AssetSheet extends ConsumerStatefulWidget {
  const _AssetSheet({this.existing});
  final Asset? existing;

  @override
  ConsumerState<_AssetSheet> createState() => _AssetSheetState();
}

class _AssetSheetState extends ConsumerState<_AssetSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late final TextEditingController _institutionController;
  late AssetType _assetType;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _valueController = TextEditingController(text: existing != null ? existing.currentValue.toString() : '');
    _institutionController = TextEditingController(text: existing?.institutionName ?? '');
    _assetType = existing?.assetType ?? AssetType.cash;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(assetsApiProvider);
      final institution = _institutionController.text.trim().isEmpty ? null : _institutionController.text.trim();
      if (widget.existing == null) {
        await api.create(
          assetType: _assetType,
          name: _nameController.text.trim(),
          currentValue: _valueController.text.trim(),
          institutionName: institution,
        );
      } else {
        await api.update(
          widget.existing!.id,
          assetType: _assetType,
          name: _nameController.text.trim(),
          currentValue: _valueController.text.trim(),
          institutionName: institution,
        );
      }
      ref.invalidate(assetsProvider);
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
      await ref.read(assetsApiProvider).delete(existing.id);
      ref.invalidate(assetsProvider);
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
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Add asset' : 'Edit asset', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<AssetType>(
              initialValue: _assetType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final t in AssetType.values) DropdownMenuItem(value: t, child: Text(assetTypeLabels[t]!))],
              onChanged: (value) => setState(() => _assetType = value ?? _assetType),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Asset name')),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Current value (ZAR)'),
            ),
            const SizedBox(height: 16),
            TextField(controller: _institutionController, decoration: const InputDecoration(labelText: 'Institution (optional)')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : _submit,
              child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
            if (widget.existing != null) ...[
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
