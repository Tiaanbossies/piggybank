import 'package:decimal/decimal.dart';

enum LiabilityType { creditCard, personalLoan, vehicleLoan, mortgage, tax, other }

LiabilityType liabilityTypeFromJson(String value) {
  switch (value) {
    case 'credit_card':
      return LiabilityType.creditCard;
    case 'personal_loan':
      return LiabilityType.personalLoan;
    case 'vehicle_loan':
      return LiabilityType.vehicleLoan;
    default:
      return LiabilityType.values.firstWhere((t) => t.name == value, orElse: () => LiabilityType.other);
  }
}

String liabilityTypeToJson(LiabilityType type) {
  switch (type) {
    case LiabilityType.creditCard:
      return 'credit_card';
    case LiabilityType.personalLoan:
      return 'personal_loan';
    case LiabilityType.vehicleLoan:
      return 'vehicle_loan';
    default:
      return type.name;
  }
}

const liabilityTypeLabels = {
  LiabilityType.creditCard: 'Credit card',
  LiabilityType.personalLoan: 'Personal loan',
  LiabilityType.vehicleLoan: 'Vehicle loan',
  LiabilityType.mortgage: 'Mortgage',
  LiabilityType.tax: 'Tax',
  LiabilityType.other: 'Other',
};

/// Mirrors `backend/app/liabilities/schemas.py`'s `LiabilityOut` — core
/// fields plus the loan-params fields needed for the smart-form (backend
/// auto-computes `outstanding_amount` when `original_balance`/`interest_rate`/
/// `start_date` and one of `term_months`/`monthly_amount` are given instead).
///
/// The balance is worked out on the server from an anchor: a balance and the
/// date it was true on ([anchorDate]). An [isAmortising] loan moves on by one
/// instalment a month by itself, so only extra payments need logging.
/// [needsReview] marks a loan whose balance may have counted payments twice
/// before that change. The newer fields default safely for older servers.
class Liability {
  const Liability({
    required this.id,
    required this.liabilityType,
    required this.name,
    required this.outstandingAmount,
    required this.originalBalance,
    required this.interestRate,
    required this.termMonths,
    required this.startDate,
    this.anchorDate,
    this.isAmortising = false,
    this.needsReview = false,
  });

  final String id;
  final LiabilityType liabilityType;
  final String name;
  final Decimal outstandingAmount;
  final Decimal? originalBalance;
  final Decimal? interestRate;
  final int? termMonths;
  final DateTime? startDate;
  final DateTime? anchorDate;
  final bool isAmortising;
  final bool needsReview;

  factory Liability.fromJson(Map<String, dynamic> json) => Liability(
        id: json['id'] as String,
        liabilityType: liabilityTypeFromJson(json['liability_type'] as String),
        name: json['name'] as String,
        outstandingAmount: Decimal.parse(json['outstanding_amount'].toString()),
        originalBalance: json['original_balance'] == null ? null : Decimal.parse(json['original_balance'].toString()),
        interestRate: json['interest_rate'] == null ? null : Decimal.parse(json['interest_rate'].toString()),
        termMonths: json['term_months'] as int?,
        startDate: json['start_date'] == null ? null : DateTime.parse(json['start_date'] as String),
        anchorDate: json['anchor_date'] == null ? null : DateTime.parse(json['anchor_date'] as String),
        isAmortising: json['is_amortising'] as bool? ?? false,
        needsReview: json['needs_review'] as bool? ?? false,
      );
}
