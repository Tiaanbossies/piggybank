import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'dates.dart';

/// Pay-cycle months (QA pass 1): the app's copy of the backend's
/// `app/shared/pay_period.py`, so labels and "days left" need no round trip.
/// Keep the two in step.
///
/// - No salary day, or the 1st: calendar months.
/// - Salary on the 16th–28th: named after the next month (day 25 makes
///   25 Sep – 24 Oct "October").
/// - Salary on the 2nd–15th: named after the month it starts in.
class PayPeriod {
  const PayPeriod({required this.label, required this.start, required this.end});

  /// The first of the month this period counts as.
  final DateTime label;

  /// First and last day, both inclusive.
  final DateTime start;
  final DateTime end;

  bool get isCalendarMonth => start.day == 1 && start.month == label.month;

  /// "25 Sep – 24 Oct"; empty for a plain calendar month.
  String get rangeLabel => isCalendarMonth ? '' : '${dayMonth(start)} – ${dayMonth(end)}';

  /// Days after [today] up to and including the last day: 12 on 12 Oct for
  /// a period ending 24 Oct.
  int daysLeftAfter(DateTime today) => dateOnly(end).difference(dateOnly(today)).inDays;

  @override
  bool operator ==(Object other) =>
      other is PayPeriod && other.label == label && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(label, start, end);
}

const _lateSalaryFrom = 16;

bool _calendar(int? salaryDay) => salaryDay == null || salaryDay <= 1;

DateTime _first(DateTime d) => DateTime(d.year, d.month, 1);

PayPeriod periodForLabel(DateTime label, int? salaryDay) {
  final first = _first(label);
  if (_calendar(salaryDay)) {
    return PayPeriod(label: first, start: first, end: DateTime(first.year, first.month + 1, 0));
  }
  final startMonth = salaryDay! >= _lateSalaryFrom ? DateTime(first.year, first.month - 1, 1) : first;
  final start = DateTime(startMonth.year, startMonth.month, salaryDay);
  final end = DateTime(start.year, start.month + 1, salaryDay - 1);
  return PayPeriod(label: first, start: start, end: end);
}

DateTime labelForDate(DateTime day, int? salaryDay) {
  if (_calendar(salaryDay)) return _first(day);
  final startMonth = day.day >= salaryDay! ? _first(day) : DateTime(day.year, day.month - 1, 1);
  return salaryDay >= _lateSalaryFrom ? DateTime(startMonth.year, startMonth.month + 1, 1) : startMonth;
}

PayPeriod periodContaining(DateTime day, int? salaryDay) => periodForLabel(labelForDate(day, salaryDay), salaryDay);

/// The signed-in user's salary day (Settings → Profile), or null. Null too
/// when there's no auth state to read (provider-level tests that never set
/// one up): calendar months are the safe default.
final salaryDayProvider = Provider<int?>((ref) {
  try {
    return ref.watch(authControllerProvider.select((s) => s.user?.salaryDay));
  } on Object {
    return null;
  }
});
