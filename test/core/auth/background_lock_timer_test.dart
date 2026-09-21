import 'package:flutter_test/flutter_test.dart';

import 'package:piggybank/core/auth/background_lock_timer.dart';

void main() {
  group('BackgroundLockTimer', () {
    test('resuming before the timeout elapses does not lock', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final timer = BackgroundLockTimer(timeout: const Duration(seconds: 30), now: () => now);

      timer.onPaused();
      now = now.add(const Duration(seconds: 10));

      expect(timer.onResumed(), false);
    });

    test('resuming after the timeout elapses locks', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final timer = BackgroundLockTimer(timeout: const Duration(seconds: 30), now: () => now);

      timer.onPaused();
      now = now.add(const Duration(seconds: 31));

      expect(timer.onResumed(), true);
    });

    test('resuming exactly at the timeout locks (inclusive boundary)', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final timer = BackgroundLockTimer(timeout: const Duration(seconds: 30), now: () => now);

      timer.onPaused();
      now = now.add(const Duration(seconds: 30));

      expect(timer.onResumed(), true);
    });

    test('resuming without a prior pause does not lock', () {
      final timer = BackgroundLockTimer();

      expect(timer.onResumed(), false);
    });

    test('a second resume with no intervening pause does not lock again', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final timer = BackgroundLockTimer(timeout: const Duration(seconds: 30), now: () => now);

      timer.onPaused();
      now = now.add(const Duration(seconds: 31));
      expect(timer.onResumed(), true);

      now = now.add(const Duration(seconds: 5));
      expect(timer.onResumed(), false);
    });

    test('pausing again after a resume restarts the window', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final timer = BackgroundLockTimer(timeout: const Duration(seconds: 30), now: () => now);

      timer.onPaused();
      now = now.add(const Duration(seconds: 10));
      expect(timer.onResumed(), false);

      timer.onPaused();
      now = now.add(const Duration(seconds: 10));
      expect(timer.onResumed(), false);
    });
  });
}
