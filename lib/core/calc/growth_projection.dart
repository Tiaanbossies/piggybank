import 'dart:math' as math;

/// Ports `frontend/src/pages/TfsaPage.tsx`'s `growthProjection` bit-for-bit —
/// a hypothetical constant-rate lump-sum compounding of the user's total
/// contributed balance, not a real historical backtest. There is
/// deliberately no monthly-contribution term; the reference implementation
/// only compounds the existing balance.
///
/// Formula: projected = startBalance * (1 + rate/100)^years.
double growthProjection(double startBalance, double ratePercent, int years) {
  if (startBalance <= 0 || years <= 0) return startBalance;
  return startBalance * math.pow(1 + ratePercent / 100, years);
}
