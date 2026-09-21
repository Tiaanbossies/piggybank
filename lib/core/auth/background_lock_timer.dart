/// Decides whether resuming the app after time spent backgrounded should
/// re-lock it. Kept separate from the `WidgetsBindingObserver` wiring in
/// `app.dart` so the timing decision is unit-testable without pumping a
/// real widget tree or waiting on a real clock.
class BackgroundLockTimer {
  BackgroundLockTimer({this.timeout = const Duration(seconds: 30), DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// How long the app can sit backgrounded before the next resume re-locks
  /// it — a brief app-switch (e.g. copying a 2FA code, taking a call)
  /// shouldn't force a re-unlock, but leaving Piggybank backgrounded any
  /// longer than this should.
  final Duration timeout;
  final DateTime Function() _now;
  DateTime? _backgroundedAt;

  /// Call when the app is backgrounded (`AppLifecycleState.paused`).
  void onPaused() => _backgroundedAt = _now();

  /// Call when the app is foregrounded (`AppLifecycleState.resumed`).
  /// Returns `true` if it was backgrounded for at least [timeout] and
  /// should now be re-locked. Always clears the recorded timestamp,
  /// whether or not it triggers a lock, so a later resume with no
  /// intervening pause never fires (e.g. `resumed` before `paused` on
  /// startup, or a duplicate `resumed` from the platform).
  bool onResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return false;
    return _now().difference(backgroundedAt) >= timeout;
  }
}
