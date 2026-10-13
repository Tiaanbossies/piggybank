import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/format/pay_period.dart';
import 'package:piggybank/features/budgets/providers/budgets_provider.dart';
import 'package:piggybank/features/summaries/data/summaries_api.dart';
import 'package:piggybank/features/summaries/providers/summaries_provider.dart';

/// Mirrors backend tests/test_pay_period.py: the two copies of the rule
/// must agree.
void main() {
  group('pay-cycle months', () {
    test('no salary day, or the 1st, is a calendar month', () {
      for (final day in [null, 1]) {
        final p = periodContaining(DateTime(2026, 10, 12), day);
        expect(p.label, DateTime(2026, 10));
        expect(p.start, DateTime(2026, 10));
        expect(p.end, DateTime(2026, 10, 31));
        expect(p.rangeLabel, '');
      }
    });

    test('salary day 25: 25 Sep – 24 Oct is October', () {
      final october = periodForLabel(DateTime(2026, 10), 25);
      expect(october.start, DateTime(2026, 9, 25));
      expect(october.end, DateTime(2026, 10, 24));
      expect(october.rangeLabel, '25 Sep – 24 Oct');
      expect(labelForDate(DateTime(2026, 9, 24), 25), DateTime(2026, 9));
      expect(labelForDate(DateTime(2026, 9, 25), 25), DateTime(2026, 10));
      expect(labelForDate(DateTime(2026, 10, 25), 25), DateTime(2026, 11));
    });

    test('salary day 3: 3 Oct – 2 Nov is October', () {
      final october = periodForLabel(DateTime(2026, 10), 3);
      expect(october.start, DateTime(2026, 10, 3));
      expect(october.end, DateTime(2026, 11, 2));
      expect(labelForDate(DateTime(2026, 10, 2), 3), DateTime(2026, 9));
    });

    test('the year rolls over', () {
      final january = periodForLabel(DateTime(2027), 25);
      expect(january.start, DateTime(2026, 12, 25));
      expect(january.end, DateTime(2027, 1, 24));
      expect(labelForDate(DateTime(2026, 12, 28), 25), DateTime(2027));
    });

    test('days left count to the period end', () {
      final p = periodContaining(DateTime(2026, 10, 12), 25);
      expect(p.daysLeftAfter(DateTime(2026, 10, 12)), 12);
      expect(p.daysLeftAfter(DateTime(2026, 10, 24)), 0);
    });
  });

  test('the Budgets tab opens on the pay-cycle month', () {
    final notifier = SelectedMonthNotifier(clock: () => DateTime(2026, 9, 26), salaryDay: 25);
    expect(notifier.state, DateTime(2026, 10));
    notifier.next();
    expect(notifier.state, DateTime(2026, 11));
  });

  group('server pay periods', _serverTests);
}

class _MockSummariesApi extends Mock implements SummariesApi {}

void _serverTests() {
  test("the server's moved dates win once they arrive (Pro payday)", () async {
    final api = _MockSummariesApi();
    when(() => api.payPeriod(month: DateTime(2026, 10)))
        .thenAnswer((_) async => PayPeriod(label: DateTime(2026, 10), start: DateTime(2026, 9, 23), end: DateTime(2026, 10, 24)));
    final container = ProviderContainer(overrides: [
      summariesApiProvider.overrideWithValue(api),
      salaryDayProvider.overrideWithValue(25),
    ]);
    addTearDown(container.dispose);

    final sub = container.listen(payPeriodForLabelProvider(DateTime(2026, 10)), (_, _) {});
    expect(sub.read().start, DateTime(2026, 9, 25), reason: 'local rule until the server answers');
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().start, DateTime(2026, 9, 23));
  });

  test('no salary day never asks the server', () {
    final api = _MockSummariesApi();
    final container = ProviderContainer(overrides: [
      summariesApiProvider.overrideWithValue(api),
      salaryDayProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    expect(container.read(payPeriodForLabelProvider(DateTime(2026, 10))).start, DateTime(2026, 10));
    verifyZeroInteractions(api);
  });
}
