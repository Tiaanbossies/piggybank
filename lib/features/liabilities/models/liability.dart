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
/// Payment-log/progress tracking (`/payments`, `/progress`) is a documented
/// v1 gap, not built.
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
  });

  final String id;
  final LiabilityType liabilityType;
  final String name;
  final Decimal outstandingAmount;
  final Decimal? originalBalance;
  final Decimal? interestRate;
  final int? termMonths;
  final DateTime? startDate;

  factory Liability.fromJson(Map<String, dynamic> json) => Liability(
        id: json['id'] as String,
        liabilityType: liabilityTypeFromJson(json['liability_type'] as String),
        name: json['name'] as String,
        outstandingAmount: Decimal.parse(json['outstanding_amount'].toString()),
        originalBalance: json['original_balance'] == null ? null : Decimal.parse(json['original_balance'].toString()),
        interestRate: json['interest_rate'] == null ? null : Decimal.parse(json['interest_rate'].toString()),
        termMonths: json['term_months'] as int?,
        startDate: json['start_date'] == null ? null : DateTime.parse(json['start_date'] as String),
      );
}
