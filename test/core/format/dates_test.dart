import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/format/dates.dart';

void main() {
  final now = DateTime(2026, 10, 6, 14, 30);

  test('same calendar day is Today, whatever the time', () {
    expect(dayLabel(DateTime(2026, 10, 6, 0, 1), now: now), 'Today');
    expect(dayLabel(DateTime(2026, 10, 6, 23, 59), now: now), 'Today');
  });

  test('the previous calendar day is Yesterday, across a month boundary too', () {
    expect(dayLabel(DateTime(2026, 10, 5, 23, 59), now: now), 'Yesterday');
    expect(dayLabel(DateTime(2026, 9, 30), now: DateTime(2026, 10, 1, 8)), 'Yesterday');
  });

  test('older days show day and month, with the year unless asked not to', () {
    expect(dayLabel(DateTime(2026, 10, 3), now: now), '3 Oct 2026');
    expect(dayLabel(DateTime(2026, 10, 3), now: now, withYear: false), '3 Oct');
  });
}
