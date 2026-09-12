import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/auth/auth_state.dart';
import 'package:piggybank/core/router/app_router.dart';

void main() {
  group('computeRedirect', () {
    AuthState state({
      AuthStatus status = AuthStatus.authenticated,
      bool locked = false,
      bool consentsRequired = false,
      bool onboardingRequired = false,
    }) {
      return AuthState(
        status: status,
        locked: locked,
        consentsRequired: consentsRequired,
        onboardingRequired: onboardingRequired,
      );
    }

    test('unknown status never redirects (splash)', () {
      expect(computeRedirect(state(status: AuthStatus.unknown), '/login'), isNull);
      expect(computeRedirect(state(status: AuthStatus.unknown), '/'), isNull);
    });

    test('unauthenticated redirects to /login unless already on /login or /register', () {
      final unauth = state(status: AuthStatus.unauthenticated);
      expect(computeRedirect(unauth, '/'), '/login');
      expect(computeRedirect(unauth, '/lock'), '/login');
      expect(computeRedirect(unauth, '/consent'), '/login');
      expect(computeRedirect(unauth, '/login'), isNull);
      expect(computeRedirect(unauth, '/register'), isNull);
    });

    test('locked wins over consentsRequired', () {
      final lockedAndConsentsRequired = state(locked: true, consentsRequired: true);
      expect(computeRedirect(lockedAndConsentsRequired, '/'), '/lock');
      expect(computeRedirect(lockedAndConsentsRequired, '/consent'), '/lock');
      // Already at /lock: go_router treats a redirect target equal to the
      // current location as a no-op, so returning '/lock' again here isn't
      // a loop — this is the same property the pre-existing /lock redirect
      // already relied on before this plan's changes.
      expect(computeRedirect(lockedAndConsentsRequired, '/lock'), '/lock');
    });

    test('locked (no consents outstanding) redirects to /lock', () {
      final locked = state(locked: true);
      expect(computeRedirect(locked, '/'), '/lock');
      expect(computeRedirect(locked, '/login'), '/lock');
      expect(computeRedirect(locked, '/lock'), '/lock');
    });

    test('unlocked + consentsRequired redirects to /consent from anywhere but /consent', () {
      final consentsRequired = state(consentsRequired: true);
      expect(computeRedirect(consentsRequired, '/'), '/consent');
      expect(computeRedirect(consentsRequired, '/invest'), '/consent');
      expect(computeRedirect(consentsRequired, '/settings'), '/consent');
      expect(computeRedirect(consentsRequired, '/consent'), isNull);
    });

    test('consentsRequired wins over onboardingRequired', () {
      final both = state(consentsRequired: true, onboardingRequired: true);
      expect(computeRedirect(both, '/'), '/consent');
      expect(computeRedirect(both, '/onboarding'), '/consent');
      // Already at /consent: no-op, same property /lock relies on.
      expect(computeRedirect(both, '/consent'), isNull);
    });

    test('locked wins over onboardingRequired', () {
      final both = state(locked: true, onboardingRequired: true);
      expect(computeRedirect(both, '/'), '/lock');
      expect(computeRedirect(both, '/onboarding'), '/lock');
    });

    test('unlocked, consented + onboardingRequired redirects to /onboarding from anywhere but /onboarding', () {
      final onboardingRequired = state(onboardingRequired: true);
      expect(computeRedirect(onboardingRequired, '/'), '/onboarding');
      expect(computeRedirect(onboardingRequired, '/invest'), '/onboarding');
      expect(computeRedirect(onboardingRequired, '/settings'), '/onboarding');
      expect(computeRedirect(onboardingRequired, '/onboarding'), isNull);
    });

    test('fully cleared (unlocked, consented, onboarded) leaves the shell alone', () {
      final clear = state();
      expect(computeRedirect(clear, '/'), isNull);
      expect(computeRedirect(clear, '/invest'), isNull);
      expect(computeRedirect(clear, '/settings'), isNull);
    });

    test('fully cleared bounces away from /login, /register, /lock, /consent, and /onboarding to /', () {
      final clear = state();
      expect(computeRedirect(clear, '/login'), '/');
      expect(computeRedirect(clear, '/register'), '/');
      expect(computeRedirect(clear, '/lock'), '/');
      expect(computeRedirect(clear, '/consent'), '/');
      expect(computeRedirect(clear, '/onboarding'), '/');
    });

    test('no redirect loop: redirect target always resolves to a stable location', () {
      // Every (status, locked, consentsRequired) combination should map to
      // exactly one stable target: applying computeRedirect a second time
      // at the resolved location either returns null, or returns the same
      // location again (which go_router treats as a no-op, same property
      // the pre-existing /lock redirect already relied on) — never a
      // *different* location, which would indicate an actual loop.
      final combinations = [
        state(status: AuthStatus.unknown),
        state(status: AuthStatus.unauthenticated),
        for (final locked in [true, false])
          for (final consentsRequired in [true, false])
            for (final onboardingRequired in [true, false])
              state(locked: locked, consentsRequired: consentsRequired, onboardingRequired: onboardingRequired),
      ];
      for (final s in combinations) {
        for (final location in ['/', '/login', '/register', '/lock', '/consent', '/onboarding', '/invest']) {
          final target = computeRedirect(s, location);
          final resolvedLocation = target ?? location;
          final secondPass = computeRedirect(s, resolvedLocation);
          expect(
            secondPass == null || secondPass == resolvedLocation,
            isTrue,
            reason: 'state=$s location=$location target=$target should stabilize, got $secondPass',
          );
        }
      }
    });
  });
}
