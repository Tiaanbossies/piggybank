import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/paywall_dialog.dart';
import '../models/portfolio.dart';
import '../providers/portfolios_provider.dart';

/// Add/Edit portfolio — per `ui-ux-mockup-brief.md` §5.2. Portfolio type is
/// only chosen at creation (the backend's `updatePortfolio` only accepts
/// name/description, so type is effectively immutable once set).
Future<void> showPortfolioSheet(BuildContext context, {Portfolio? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PortfolioSheet(existing: existing),
  );
}

class _PortfolioSheet extends ConsumerStatefulWidget {
  const _PortfolioSheet({this.existing});
  final Portfolio? existing;

  @override
  ConsumerState<_PortfolioSheet> createState() => _PortfolioSheetState();
}

class _PortfolioSheetState extends ConsumerState<_PortfolioSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late PortfolioType _portfolioType;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _portfolioType = existing?.portfolioType ?? PortfolioType.general;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(portfoliosApiProvider);
      final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
      if (widget.existing == null) {
        await api.createPortfolio(
          name: _nameController.text.trim(),
          description: description,
          portfolioType: _portfolioType,
        );
      } else {
        await api.updatePortfolio(widget.existing!.id, name: _nameController.text.trim(), description: description);
      }
      ref.invalidate(portfoliosProvider);
      ref.invalidate(investmentOverviewProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (e.isPaywall) {
        if (mounted) {
          Navigator.of(context).pop();
          unawaited(showPaywallPrompt(context, message: e.message));
        }
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await confirmDestroy(
      context,
      title: 'Delete portfolio?',
      message: 'This deletes "${existing.name}" and everything in it. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(portfoliosApiProvider).deletePortfolio(existing.id);
      ref.invalidate(portfoliosProvider);
      ref.invalidate(investmentOverviewProvider);
      if (mounted) {
        // This sheet is only ever reachable via Portfolio Detail's edit
        // action, so the deleted portfolio's detail screen is always the
        // route directly beneath this one — pop both, back to the Invest
        // tab, rather than leaving a stale detail screen for a portfolio
        // that no longer exists.
        Navigator.of(context)
          ..pop()
          ..pop();
      }
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
            Text(isEdit ? 'Edit portfolio' : 'Create portfolio', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Portfolio name')),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            if (!isEdit) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<PortfolioType>(
                initialValue: _portfolioType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final t in PortfolioType.values)
                    DropdownMenuItem(value: t, child: Text(portfolioTypeLabels[t]!)),
                ],
                onChanged: (value) => setState(() => _portfolioType = value ?? _portfolioType),
              ),
              if (singletonPortfolioTypes.contains(_portfolioType)) ...[
                const SizedBox(height: 8),
                Text(
                  "You can only have one ${portfolioTypeLabels[_portfolioType]} portfolio.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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
