import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/hero_metric_card.dart';
import '../../../shared/widgets/paywall_dialog.dart';
import '../../transactions/screens/transactions_screen.dart';
import '../models/account.dart';
import '../providers/accounts_provider.dart';
import 'account_edit_screen.dart';
import 'accounts_context_menu.dart';

/// Grouped-card pattern per DESIGN.md § Accounts: a "Total balance" hero card
/// (client-side sum of active balances, no new API call), then active
/// accounts as rows sharing one [GroupCard], then a separate [GroupCard] for
/// soft-deleted "Inactive" accounts.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _inactiveExpanded = true;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Transactions',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(accountsProvider.future),
          child: accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(err is ApiError ? err.message : 'Failed to load accounts')),
            data: (accounts) {
              final active = accounts.where((a) => a.isActive).toList();
              final inactive = accounts.where((a) => !a.isActive).toList();
              final totalBalance = active.fold(Decimal.zero, (sum, a) => sum + a.balance);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  HeroMetricCard(label: 'Total balance', value: formatZAR(totalBalance)),
                  const SizedBox(height: 24),
                  Text('Active accounts', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 12),
                  if (active.isEmpty)
                    const Text('No accounts yet.')
                  else
                    GroupCard(children: [for (final account in active) _AccountRow(account: account)]),
                  if (inactive.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setState(() => _inactiveExpanded = !_inactiveExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Inactive accounts', style: Theme.of(context).textTheme.labelMedium),
                            Icon(_inactiveExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_inactiveExpanded)
                      GroupCard(children: [for (final account in inactive) _AccountRow(account: account)]),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountSheet(context, ref),
        label: const Text('Add account'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddAccountSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddAccountSheet(),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.account});
  final Account account;

  // Per the delivered accounts.jpeg mockup: each account type gets a
  // distinct icon (bank building / piggy / wallet), not one icon for all.
  IconData get _icon {
    switch (account.accountType) {
      case 'savings':
        return Icons.savings_outlined;
      case 'cash':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.account_balance_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AccountEditScreen(account: account)),
      ),
      onLongPress: () => showModalBottomSheet(
        context: context,
        builder: (_) => AccountContextMenu(account: account),
      ),
      child: GroupRow(
        leadingIcon: _icon,
        muted: !account.isActive,
        title: account.name,
        subtitle: account.institutionName,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatZAR(account.balance),
              style: moneyTextStyle(context, fontSize: 15, color: account.isActive ? semantic?.success : null),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: semantic?.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  const _AddAccountSheet();

  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _nameController = TextEditingController();
  String _accountType = 'bank';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(accountsApiProvider).create(
            name: _nameController.text.trim(),
            accountType: _accountType,
            currency: 'ZAR',
          );
      ref.invalidate(accountsProvider);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Account name')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _accountType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'bank', child: Text('Bank account')),
              DropdownMenuItem(value: 'savings', child: Text('Savings account')),
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
            ],
            onChanged: (value) => setState(() => _accountType = value ?? _accountType),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
