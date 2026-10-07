import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/models.py`'s `RecurringCostKind` (snake_case on the
/// wire).
enum RecurringCostKind {
  subscription('subscription', 'Subscription'),
  insurance('insurance', 'Insurance'),
  debitOrder('debit_order', 'Debit order'),
  utility('utility', 'Utility'),
  other('other', 'Other');

  const RecurringCostKind(this.wire, this.label);
  final String wire;
  final String label;

  static RecurringCostKind fromWire(String value) =>
      values.firstWhere((k) => k.wire == value, orElse: () => RecurringCostKind.other);
}

enum RecurringCostStatus {
  suggested('suggested'),
  confirmed('confirmed'),
  dismissed('dismissed');

  const RecurringCostStatus(this.wire);
  final String wire;

  static RecurringCostStatus fromWire(String value) => values.firstWhere((s) => s.wire == value);
}

/// Keep / cut decision. `undecided` is the starting state, so the picker
/// shows nothing selected rather than a fourth "Undecided" segment.
enum RecurringCostDecision {
  undecided('undecided', 'Undecided'),
  keep('keep', 'Keep'),
  cutCandidate('cut_candidate', 'Maybe cut'),
  cut('cut', 'Cut');

  const RecurringCostDecision(this.wire, this.label);
  final String wire;
  final String label;

  static RecurringCostDecision fromWire(String value) => values.firstWhere((d) => d.wire == value);
}

DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);
Decimal _money(Object? value) => Decimal.parse(value.toString());
Decimal? _moneyOrNull(Object? value) => value == null ? null : Decimal.parse(value.toString());

/// Mirrors `backend/app/savings/schemas.py`'s `SavingsTargetOut`.
class SavingsTarget {
  const SavingsTarget({
    required this.id,
    required this.label,
    required this.monthlyAmount,
    required this.targetDate,
    required this.incomeOverride,
  });

  final String id;
  final String? label;
  final Decimal monthlyAmount;
  final DateTime? targetDate;
  final Decimal? incomeOverride;

  /// What to call the target when the user didn't name it.
  String get displayLabel => label ?? 'Savings target';

  factory SavingsTarget.fromJson(Map<String, dynamic> json) => SavingsTarget(
        id: json['id'] as String,
        label: json['label'] as String?,
        monthlyAmount: _money(json['monthly_amount']),
        targetDate: _date(json['target_date']),
        incomeOverride: _moneyOrNull(json['income_override']),
      );
}

/// Mirrors `backend/app/savings/schemas.py`'s `RecurringCostOut`.
class RecurringCost {
  const RecurringCost({
    required this.id,
    required this.name,
    required this.kind,
    required this.monthlyAmount,
    required this.status,
    required this.decision,
    required this.savedAmount,
    required this.cutOn,
  });

  final String id;
  final String name;
  final RecurringCostKind kind;
  final Decimal monthlyAmount;
  final RecurringCostStatus status;
  final RecurringCostDecision decision;
  final Decimal? savedAmount;
  final DateTime? cutOn;

  factory RecurringCost.fromJson(Map<String, dynamic> json) => RecurringCost(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: RecurringCostKind.fromWire(json['kind'] as String),
        monthlyAmount: _money(json['monthly_amount']),
        status: RecurringCostStatus.fromWire(json['status'] as String),
        decision: RecurringCostDecision.fromWire(json['decision'] as String),
        savedAmount: _moneyOrNull(json['saved_amount']),
        cutOn: _date(json['cut_on']),
      );
}

/// What the overview's averages stand on — see the backend's
/// `SavingsOverview` docstring.
enum OverviewBasis { fullMonths, monthToDate }

/// Mirrors `backend/app/savings/schemas.py`'s `SavingsOverview`. Every
/// figure is computed on the server; the app only shows them.
class SavingsOverview {
  const SavingsOverview({
    required this.target,
    required this.basis,
    required this.monthsOfData,
    required this.income,
    required this.incomeIsOverride,
    required this.fixedCosts,
    required this.everydaySpending,
    required this.leftOver,
    required this.gap,
    required this.targetMet,
    required this.savingsFound,
    required this.confirmedCount,
    required this.suggestedCount,
  });

  final SavingsTarget? target;
  final OverviewBasis basis;
  final int monthsOfData;
  final Decimal income;
  final bool incomeIsOverride;
  final Decimal fixedCosts;
  final Decimal everydaySpending;
  final Decimal leftOver;
  final Decimal? gap;
  final bool targetMet;
  final Decimal savingsFound;
  final int confirmedCount;
  final int suggestedCount;

  /// Left over as a share of the target, 0.0–1.0, for the progress bar.
  /// Zero when there's no target or nothing is left over.
  double get progress {
    final target = this.target;
    if (target == null || target.monthlyAmount <= Decimal.zero || leftOver <= Decimal.zero) return 0;
    final pct = leftOver.toDouble() / target.monthlyAmount.toDouble();
    return pct > 1 ? 1 : pct;
  }

  factory SavingsOverview.fromJson(Map<String, dynamic> json) => SavingsOverview(
        target: json['target'] == null ? null : SavingsTarget.fromJson(json['target'] as Map<String, dynamic>),
        basis: json['basis'] == 'full_months' ? OverviewBasis.fullMonths : OverviewBasis.monthToDate,
        monthsOfData: json['months_of_data'] as int,
        income: _money(json['income']),
        incomeIsOverride: json['income_is_override'] as bool,
        fixedCosts: _money(json['fixed_costs']),
        everydaySpending: _money(json['everyday_spending']),
        leftOver: _money(json['left_over']),
        gap: _moneyOrNull(json['gap']),
        targetMet: json['target_met'] as bool,
        savingsFound: _money(json['savings_found']),
        confirmedCount: json['confirmed_count'] as int,
        suggestedCount: json['suggested_count'] as int,
      );
}
