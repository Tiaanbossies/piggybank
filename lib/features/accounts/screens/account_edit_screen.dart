import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../models/account.dart';
import '../providers/accounts_mutation_provider.dart';
import '../providers/accounts_provider.dart';

/// Edit/detail screen for an account. Allows renaming, updating institution,
/// and deactivating/restoring (when backend supports restore).
class AccountEditScreen extends ConsumerStatefulWidget {
  const AccountEditScreen({required this.account, super.key});
  final Account account;

  @override
  ConsumerState<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends ConsumerState<AccountEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _institutionController;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _institutionController = TextEditingController(text: widget.account.institutionName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Account name is required');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(accountsApiProvider).update(
            widget.account.id,
            name: name,
            institutionName: _institutionController.text.trim().isEmpty ? null : _institutionController.text.trim(),
          );
      if (mounted) {
        ref.invalidate(accountsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account updated')),
        );
        Navigator.pop(context);
      }
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    }
  }

  Future<void> _confirmDeactivate() async {
    unawaited(
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
        title: const Text('Deactivate account?'),
        content: Text('This will deactivate "${widget.account.name}". You can restore it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(deactivateAccountProvider(widget.account.id).future);
                if (mounted) {
                  ref.invalidate(accountsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.account.name} deactivated')),
                  );
                  Navigator.pop(context);
                }
              } on ApiError catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.message}')),
                  );
                }
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Account name'),
                enabled: !_submitting,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _institutionController,
                decoration: const InputDecoration(labelText: 'Institution (optional)'),
                enabled: !_submitting,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Account type: ${widget.account.accountType}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Currency: ${widget.account.currency}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
                    : const Text('Save changes'),
              ),
              const SizedBox(height: 12),
              if (widget.account.isActive)
                TextButton(
                  onPressed: _submitting ? null : _confirmDeactivate,
                  child: Text(
                    'Deactivate account',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'This account is inactive.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
