import 'dart:math' as math;

// Pure risk metric calculations, ported bit-for-bit from the web app's
// `InstrumentComparison/riskMetrics.ts`. No Flutter/project imports.
// All inputs are lists of close prices (chronological) unless noted.

double calcAnnualisedReturn(List<double> prices, double periodYears) {
  if (prices.length < 2 || periodYears <= 0) return 0;
  final first = prices.first;
  final last = prices.last;
  if (first <= 0) return 0;
  return math.pow(last / first, 1 / periodYears).toDouble() - 1;
}

/// Actual elapsed time covered by a series of chronological ISO date strings,
/// in years. Use this instead of a requested/nominal period length (e.g.
/// "5y") when annualising returns — a ticker with less history than the
/// requested period would otherwise have its return over-annualised against
/// a period it doesn't actually cover.
double actualYearsSpan(List<String> dates) {
  if (dates.length < 2) return 0;
  final first = DateTime.tryParse(dates.first)?.millisecondsSinceEpoch;
  final last = DateTime.tryParse(dates.last)?.millisecondsSinceEpoch;
  if (first == null || last == null || last <= first) return 0;
  return (last - first) / (365.25 * 24 * 60 * 60 * 1000);
}

double calcVolatility(List<double> prices) {
  if (prices.length < 2) return 0;
  final logReturns = <double>[];
  for (var i = 1; i < prices.length; i++) {
    final prev = prices[i - 1];
    final cur = prices[i];
    if (prev <= 0 || cur <= 0) continue;
    logReturns.add(math.log(cur / prev));
  }
  if (logReturns.length < 2) return 0;
  final mean = logReturns.reduce((s, v) => s + v) / logReturns.length;
  final variance = logReturns.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) / (logReturns.length - 1);
  final dailyStd = math.sqrt(variance);
  return dailyStd * math.sqrt(252);
}

double calcMaxDrawdown(List<double> prices) {
  if (prices.length < 2) return 0;
  var peak = prices.first;
  var maxDd = 0.0;
  for (final p in prices) {
    if (p > peak) peak = p;
    if (peak <= 0) continue;
    final dd = (peak - p) / peak;
    if (dd > maxDd) maxDd = dd;
  }
  return maxDd;
}

double calcSharpeRatio(double annualisedReturn, double volatility, [double riskFreeRate = 0.07]) {
  if (volatility <= 0) return 0;
  return (annualisedReturn - riskFreeRate) / volatility;
}

List<double> calcPercentChange(List<double> prices) {
  if (prices.isEmpty) return [];
  final base = prices.first;
  if (base == 0) return prices.map((_) => 0.0).toList();
  return prices.map((p) => (p - base) / base * 100).toList();
}

double calcTotalReturn(List<double> prices) {
  if (prices.length < 2) return 0;
  final first = prices.first;
  if (first <= 0) return 0;
  return (prices.last - first) / first;
}

List<double> calcDailyReturns(List<double> prices) {
  final out = <double>[];
  for (var i = 1; i < prices.length; i++) {
    final prev = prices[i - 1];
    final cur = prices[i];
    if (prev <= 0) {
      out.add(0);
      continue;
    }
    out.add((cur - prev) / prev);
  }
  return out;
}

double calcPearson(List<double> a, List<double> b) {
  final n = math.min(a.length, b.length);
  if (n < 2) return 0;
  var sumA = 0.0;
  var sumB = 0.0;
  for (var i = 0; i < n; i++) {
    sumA += a[i];
    sumB += b[i];
  }
  final meanA = sumA / n;
  final meanB = sumB / n;
  var num = 0.0;
  var denomA = 0.0;
  var denomB = 0.0;
  for (var i = 0; i < n; i++) {
    final da = a[i] - meanA;
    final db = b[i] - meanB;
    num += da * db;
    denomA += da * da;
    denomB += db * db;
  }
  final denom = math.sqrt(denomA * denomB);
  if (denom == 0) return 0;
  return num / denom;
}
