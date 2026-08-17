import 'dart:math' as math;

/// Ports `frontend/src/lib/loanCalc.ts` bit-for-bit — do not reinvent this
/// math, per the approved migration plan's Phase 3 instruction.

/// Formula: PMT = P * r / (1 - (1 + r)^-n), where P = principal, r = monthly
/// rate, n = term in months. Special case: if r = 0, PMT = P / n.
double calcPmt(double principal, double annualRate, num termMonths) {
  if (termMonths <= 0) return 0;
  if (principal <= 0) return 0;

  final r = annualRate / 100 / 12;

  if (r == 0) {
    return principal / termMonths;
  }

  return (principal * r) / (1 - math.pow(1 + r, -termMonths));
}

/// Returns the number of months to fully repay a loan given a monthly payment.
double calcPayoffMonths(double principal, double annualRate, double monthlyPayment) {
  if (principal <= 0 || monthlyPayment <= 0) return 0;
  final r = annualRate / 100 / 12;
  if (r == 0) return (principal / monthlyPayment).ceilToDouble();
  if (monthlyPayment <= principal * r) return double.infinity;
  return (-math.log(1 - (principal * r) / monthlyPayment) / math.log(1 + r)).ceilToDouble();
}

/// Returns the extra monthly payment needed to pay off a loan `monthsEarly`
/// months sooner than its remaining term. Returns 0 if monthsEarly <= 0 or
/// targetTerm < 1.
double calcExtraForTarget(double outstanding, double annualRate, num remainingMonths, num monthsEarly) {
  if (outstanding <= 0 || remainingMonths <= 0 || monthsEarly <= 0) return 0;
  final targetTerm = remainingMonths - monthsEarly;
  if (targetTerm < 1) return 0;
  final basePmt = calcPmt(outstanding, annualRate, remainingMonths);
  final newPmt = calcPmt(outstanding, annualRate, targetTerm);
  return math.max(0, newPmt - basePmt);
}

class AcceleratedPayoffResult {
  const AcceleratedPayoffResult({required this.newMonths, required this.monthsSaved, required this.interestSaved});
  final double newMonths;
  final double monthsSaved;
  final double interestSaved;
}

/// Returns months remaining and months saved when paying `extraPerMonth` on
/// top of the scheduled payment.
AcceleratedPayoffResult calcAcceleratedPayoff(double outstanding, double annualRate, num remainingMonths, double extraPerMonth) {
  if (outstanding <= 0 || remainingMonths <= 0) {
    return const AcceleratedPayoffResult(newMonths: 0, monthsSaved: 0, interestSaved: 0);
  }
  final basePmt = calcPmt(outstanding, annualRate, remainingMonths);
  final totalPmt = basePmt + math.max(0, extraPerMonth);
  final newMonths = extraPerMonth > 0
      ? math.min(calcPayoffMonths(outstanding, annualRate, totalPmt), remainingMonths.toDouble())
      : remainingMonths.toDouble();
  final monthsSaved = math.max(0.0, remainingMonths - newMonths).toDouble();
  final baseInterest = math.max(0.0, basePmt * remainingMonths - outstanding).toDouble();
  final newInterest = math.max(0.0, totalPmt * newMonths - outstanding).toDouble();
  final interestSaved = math.max(0.0, baseInterest - newInterest);
  return AcceleratedPayoffResult(newMonths: newMonths, monthsSaved: monthsSaved, interestSaved: interestSaved);
}
