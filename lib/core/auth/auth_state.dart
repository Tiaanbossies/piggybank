import 'user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// [locked] is the app-lock (biometric/PIN) gate, independent of
/// [status] — a user can be `authenticated` against the backend while the
/// UI still shows a lock screen until they pass the local device check.
///
/// [consentsRequired] is a second, independent gate: the backend enforces
/// acceptance of `privacy_policy`/`terms_of_service` before almost any
/// authenticated action works. [locked] takes precedence over it — nothing,
/// including the consent screen, should render before the device-lock gate
/// clears.
///
/// [onboardingRequired] is a third, independent gate for the first-run Penny
/// tour (see `plans/piggybank-penny-onboarding-tour.md`) — purely local, with
/// no backend concept of it (unlike [consentsRequired]). It's derived from
/// `OnboardingStore.isPending(userId)` on every auth path, not hand-set per
/// path, so an interrupted tour resumes on the next login/restore rather than
/// being silently lost.
class AuthState {
  const AuthState({
    required this.status,
    this.accessToken,
    this.user,
    this.locked = false,
    this.consentsRequired = false,
    this.onboardingRequired = false,
  });

  final AuthStatus status;
  final String? accessToken;
  final User? user;
  final bool locked;
  final bool consentsRequired;
  final bool onboardingRequired;

  static const initial = AuthState(status: AuthStatus.unknown);

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    String? accessToken,
    User? user,
    bool? locked,
    bool? consentsRequired,
    bool? onboardingRequired,
  }) {
    return AuthState(
      status: status ?? this.status,
      accessToken: accessToken ?? this.accessToken,
      user: user ?? this.user,
      locked: locked ?? this.locked,
      consentsRequired: consentsRequired ?? this.consentsRequired,
      onboardingRequired: onboardingRequired ?? this.onboardingRequired,
    );
  }

  static AuthState unauthenticated() => const AuthState(status: AuthStatus.unauthenticated);
}
