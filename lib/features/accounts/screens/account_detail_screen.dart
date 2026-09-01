import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../../transactions/models/transaction.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../models/account.dart';
import 'account_edit_screen.dart';

/// Read-only account detail view (fix-it Step 6, L4). Tapping an account row
/// on [AccountsScreen] opens this instead of [AccountEditScreen] directly —
/// per the user's 2026-09-01 decision, editing is now a separate explicit
/// action (the AppBar's edit button), not the default tap target.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({required this.account, super.key});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(accountTransactionsProvider(account.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit account',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AccountEditScreen(account: account)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(accountTransactionsProvider(account.id).future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GroupCard(
                children: [
                  GroupRow(
                    leadingIcon: Icons.account_balance_wallet_outlined,
                    title: 'Balance',
                    subtitle: account.isActive ? null : 'Inactive',
                    trailing: Text(
                      formatZAR(account.balance),
                      style: moneyTextStyle(context, fontSize: 16),
                    ),
                  ),
                  GroupRow(leadingIcon: Icons.category_outlined, title: 'Account type', trailing: Text(account.accountType)),
                  if (account.institutionName case String institution)
                    GroupRow(leadingIcon: Icons.account_balance_outlined, title: 'Institution', trailing: Text(institution)),
                  GroupRow(leadingIcon: Icons.payments_outlined, title: 'Currency', trailing: Text(account.currency)),
                ],
              ),
              const SizedBox(height: 24),
              Text('Recent transactions', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 12),
              transactionsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (err, _) => const Text('Failed to load transactions'),
                data: (page) {
                  if (page.items.isEmpty) return const Text('No transactions yet.');
                  return GroupCard(children: [for (final t in page.items) _AccountTransactionRow(transaction: t)]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTransactionRow extends StatelessWidget {
  const _AccountTransactionRow({required this.transaction});
  final Transaction transaction;

  IconData get _icon {
    switch (transaction.transactionType) {
      case TransactionType.transfer:
        return Icons.swap_horiz;
      case TransactionType.income:
        return Icons.arrow_downward;
      case TransactionType.expense:
        return Icons.arrow_upward;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.transactionType == TransactionType.expense;
    final isIncome = transaction.transactionType == TransactionType.income;
    final signedAmount = isExpense ? -transaction.amount.toDouble() : transaction.amount.toDouble();
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final date = transaction.transactionDate;
    final dateLabel = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return GroupRow(
      leadingIcon: _icon,
      title: transaction.merchantName ?? transaction.description ?? transaction.category,
      subtitle: '${transaction.category} · $dateLabel',
      trailing: Text(
        formatZAR(signedAmount),
        style: moneyTextStyle(
          context,
          fontSize: 15,
          color: isIncome ? semantic?.success : (isExpense ? semantic?.danger : null),
        ),
      ),
    );
  }
}
