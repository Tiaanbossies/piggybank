import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/liabilities/schemas.py`'s `LiabilityPaymentOut`.
class LiabilityPayment {
  const LiabilityPayment({
    required this.id,
    required this.liabilityId,
    required this.paymentDate,
    required this.amount,
    required this.principalPortion,
    required this.interestPortion,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String liabilityId;
  final DateTime paymentDate;
  final Decimal amount;
  final Decimal principalPortion;
  final Decimal interestPortion;
  final String? notes;
  final DateTime createdAt;

  factory LiabilityPayment.fromJson(Map<String, dynamic> json) => LiabilityPayment(
        id: json['id'] as String,
        liabilityId: json['liability_id'] as String,
        paymentDate: DateTime.parse(json['payment_date'] as String),
        amount: Decimal.parse(json['amount'].toString()),
        principalPortion: Decimal.parse(json['principal_portion'].toString()),
        interestPortion: Decimal.parse(json['interest_portion'].toString()),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Mirrors `backend/app/liabilities/schemas.py`'s `LiabilityProgressOut`.
/// `originalBalance` (and therefore `projectedPayoffDate`) can be null when
/// the liability was created without loan params — the progress card falls
/// back to a "set original balance to track progress" message in that case.
class LiabilityProgress {
  const LiabilityProgress({
    required this.liabilityId,
    required this.originalBalance,
    required this.currentBalance,
    required this.totalPrincipalPaid,
    required this.totalInterestPaid,
    required this.percentPaid,
    required this.paymentCount,
    required this.projectedPayoffDate,
  });

  final String liabilityId;
  final Decimal? originalBalance;
  final Decimal currentBalance;
  final Decimal totalPrincipalPaid;
  final Decimal totalInterestPaid;
  final Decimal percentPaid;
  final int paymentCount;
  final DateTime? projectedPayoffDate;

  factory LiabilityProgress.fromJson(Map<String, dynamic> json) => LiabilityProgress(
        liabilityId: json['liability_id'] as String,
        originalBalance: json['original_balance'] == null ? null : Decimal.parse(json['original_balance'].toString()),
        currentBalance: Decimal.parse(json['current_balance'].toString()),
        totalPrincipalPaid: Decimal.parse(json['total_principal_paid'].toString()),
        totalInterestPaid: Decimal.parse(json['total_interest_paid'].toString()),
        percentPaid: Decimal.parse(json['percent_paid'].toString()),
        paymentCount: json['payment_count'] as int,
        projectedPayoffDate:
            json['projected_payoff_date'] == null ? null : DateTime.parse(json['projected_payoff_date'] as String),
      );
}
