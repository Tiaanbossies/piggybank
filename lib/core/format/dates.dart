const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

/// Midnight at the start of [date]'s calendar day — for comparing days, not
/// instants.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// "Today", "Yesterday", or "3 Oct 2026" — the Transactions list's day
/// headers and the Dashboard's recent rows. [now] is injectable for tests.
/// [withYear] lets a compact row drop the year when it's the current one.
String dayLabel(DateTime date, {DateTime? now, bool withYear = true}) {
  final today = dateOnly(now ?? DateTime.now());
  final day = dateOnly(date);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  final short = '${day.day} ${_monthAbbreviations[day.month - 1]}';
  return withYear ? '$short ${day.year}' : short;
}
