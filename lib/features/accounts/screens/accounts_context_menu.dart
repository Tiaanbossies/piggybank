import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/widgets/paywall_dialog.dart';
import '../models/account.dart';
import '../providers/accounts_mutation_provider.dart';

class AccountContextMenu extends ConsumerWidget {
  const AccountContextMenu({required this.account, super.key});
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
            ListTile(
              key: const Key('account-restore'),
              leading: const Icon(Icons.unarchive_outlined),
              title: const Text('Restore account'),
              subtitle: const Text('Brings it back with all its transactions.'),
              // The menu stays up until the request lands: a paywall needs
              // a live context to open from.
              onTap: () async {
                await restoreAccount(context, ref, account);
                if (context.mounted) Navigator.pop(context);
              },
            ),
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

/// Restores [account] and says so; a 402 (over the free tier's account
/// limit) opens the paywall instead. Used by the long-press menu and the
/// edit screen. Returns whether it worked.
Future<bool> restoreAccount(BuildContext context, WidgetRef ref, Account account) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(reactivateAccountProvider(account.id).future);
    messenger.showSnackBar(SnackBar(content: Text('${account.name} restored')));
    return true;
  } on ApiError catch (e) {
    if (e.isPaywall && context.mounted) {
      await showPaywallPrompt(context, message: e.message);
    } else {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
    return false;
  }
}
