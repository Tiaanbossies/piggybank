import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../consent_documents.dart';
import '../data/consents_api.dart';

/// Reused both as the gating `/consent` route (nothing outstanding → the
/// router redirects away before this even builds meaningfully) and pushed
/// from Settings for later review, where "nothing outstanding" is the
/// expected common case and shows a read-only "up to date" state instead of
/// the accept button.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  /// Document types already accepted at the current required version.
  Set<String> _alreadyAccepted = {};

  /// Document types the user has ticked in this session (starts seeded with
  /// whatever's already accepted, since those checkboxes render checked and
  /// disabled).
  Set<String> _checked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(consentsApiProvider);
      final required = await api.listRequired();
      final accepted = await api.listAccepted();
      final acceptedPairs = accepted.map((c) => (c.documentType, c.documentVersion)).toSet();
      final alreadyAccepted = {
        for (final doc in required)
          if (acceptedPairs.contains((doc.documentType, doc.documentVersion))) doc.documentType,
      };
      if (!mounted) return;
      setState(() {
        _alreadyAccepted = alreadyAccepted;
        _checked = Set.of(alreadyAccepted);
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _allOutstanding =>
      consentDocuments.every((doc) => _alreadyAccepted.contains(doc.documentType));

  bool get _allChecked => consentDocuments.every((doc) => _checked.contains(doc.documentType));

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(consentsApiProvider);
      for (final doc in consentDocuments) {
        if (!_alreadyAccepted.contains(doc.documentType)) {
          await api.accept(documentType: doc.documentType, documentVersion: doc.documentVersion);
        }
      }
      await ref.read(authControllerProvider.notifier).refreshConsentStatus();
      // No manual navigation: the router's redirect listener clears the
      // /consent gate automatically once `consentsRequired` flips false. If
      // this screen was pushed from Settings (already up to date, nothing
      // outstanding), that branch doesn't fire and we pop instead below.
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// A shorter stand-in for [ConsentDocument.summary] for this row only —
  /// `GroupRow` (group_card.dart) fixes its subtitle at `maxLines: 1` with
  /// ellipsis, and the full summaries run too long to fit alongside the
  /// leading icon and trailing chevron on narrow screens. The full summary
  /// still appears unclipped in the first-run checklist's wrapping subtitle
  /// (see the `CheckboxListTile` below), so this only shortens what's shown
  /// once already accepted.
  String _shortSummary(ConsentDocument doc) {
    switch (doc.documentType) {
      case 'privacy_policy':
        return 'How we handle your data';
      case 'terms_of_service':
        return 'Rules for using the app';
      default:
        return doc.summary;
    }
  }

  void _showDocument(ConsentDocument doc) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc.label),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Text(doc.body)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & consent')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null && _alreadyAccepted.isEmpty && _checked.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_allOutstanding) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: IconChip(icon: Icons.check_circle_outline, size: 56)),
          const SizedBox(height: 16),
          Text(
            "You're up to date",
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "You've accepted the current Privacy Policy and Terms of Service.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GroupCard(
            children: [
              for (final doc in consentDocuments)
                GroupRow(
                  leadingIcon: Icons.description_outlined,
                  title: doc.label,
                  subtitle: _shortSummary(doc),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDocument(doc),
                ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Before you continue', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Please review and accept the following documents to access your financial data.'),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
        ],
        for (final doc in consentDocuments)
          CheckboxListTile(
            value: _checked.contains(doc.documentType),
            onChanged: _alreadyAccepted.contains(doc.documentType)
                ? null
                : (checked) => setState(() {
                      if (checked ?? false) {
                        _checked.add(doc.documentType);
                      } else {
                        _checked.remove(doc.documentType);
                      }
                    }),
            title: Text(doc.label),
            subtitle: InkWell(
              onTap: () => _showDocument(doc),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '${doc.summary} (Read)',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: (_allChecked && !_submitting) ? _submit : null,
          child: _submitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Accept and continue'),
        ),
      ],
    );
  }
}
