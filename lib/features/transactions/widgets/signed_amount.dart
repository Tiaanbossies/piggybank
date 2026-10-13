import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/transaction.dart';

/// A transaction's amount as a list shows it (visual spec §3): tabular
/// `titleSmall`, right-aligned by its row. Spending is a minus sign in ink,
/// not red, since red means over budget; income is "+" in the positive
/// green; a transfer carries no sign.
class SignedAmount extends StatelessWidget {
  const SignedAmount({required this.amount, required this.type, super.key});

  SignedAmount.of(Transaction transaction, {Key? key})
      : this(amount: transaction.amount, type: transaction.transactionType, key: key);

  final Decimal amount;
  final TransactionType type;

  /// "−R 642,35", "+R 500,00" or "R 1 000,00".
  static String format(Decimal amount, TransactionType type) {
    final value = formatZAR(amount.abs());
    return switch (type) {
      TransactionType.expense => '−$value',
      TransactionType.income => '+$value',
      TransactionType.transfer => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      format(amount, type),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: type == TransactionType.income ? t.positive : t.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}
