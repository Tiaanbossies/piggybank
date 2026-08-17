import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/summaries/schemas.py`'s `NetWorthSummary`.
class NetWorthSummary {
  const NetWorthSummary({required this.totalAssets, required this.liabilitiesTotal, required this.netWorth});
  final Decimal totalAssets;
  final Decimal liabilitiesTotal;
  final Decimal netWorth;

  factory NetWorthSummary.fromJson(Map<String, dynamic> json) => NetWorthSummary(
        totalAssets: Decimal.parse(json['total_assets'].toString()),
        liabilitiesTotal: Decimal.parse(json['liabilities_total'].toString()),
        netWorth: Decimal.parse(json['net_worth'].toString()),
      );
}

/// Mirrors `backend/app/summaries/schemas.py`'s `CashflowSummary`.
class CashflowSummary {
  const CashflowSummary({required this.incomeTotal, required this.expenseTotal, required this.netCashflow});
  final Decimal incomeTotal;
  final Decimal expenseTotal;
  final Decimal netCashflow;

  factory CashflowSummary.fromJson(Map<String, dynamic> json) => CashflowSummary(
        incomeTotal: Decimal.parse(json['income_total'].toString()),
        expenseTotal: Decimal.parse(json['expense_total'].toString()),
        netCashflow: Decimal.parse(json['net_cashflow'].toString()),
      );
}
