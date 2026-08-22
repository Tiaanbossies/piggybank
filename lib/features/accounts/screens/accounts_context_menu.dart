import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../models/account.dart';
import '../providers/accounts_mutation_provider.dart';

class AccountContextMenu extends ConsumerWidget {
  const AccountContextMenu({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${account.name} options', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (account.isActive)
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Deactivate'),
              onTap: () => _confirmDeactivate(context, ref),
            )
          else
            const Text('This account is inactive. Contact support to restore it.', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate account?'),
        content: Text('This will deactivate "${account.name}". You can restore it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
              try {
                await ref.read(deactivateAccountProvider(account.id).future);
                messenger.showSnackBar(
                  SnackBar(content: Text('${account.name} deactivated')),
                );
              } on ApiError catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: ${e.message}')),
                );
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}
