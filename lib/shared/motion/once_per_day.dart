import 'package:shared_preferences/shared_preferences.dart';

/// Rate-limits a mascot moment (UX rework spec §3.3: "at most once a day per
/// kind"). Local UI state only: a SharedPreferences key per moment.
///
/// Returns true the first time it's called for [kind] today (or ever, when
/// [daily] is false, for a one-off event like a goal reaching 100 %), and
/// records it, so every later call returns false.
bool claimMoment(SharedPreferences prefs, String kind, {bool daily = true, DateTime? now}) {
  final key = 'mascot.$kind';
  final today = now ?? DateTime.now();
  final stamp = daily
      ? '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}'
      : '1';
  if (prefs.getString(key) == stamp) return false;
  prefs.setString(key, stamp);
  return true;
}
