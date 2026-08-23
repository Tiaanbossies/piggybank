import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/lock_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/budgets/screens/budgets_home_screen.dart';
import '../../features/consent/screens/consent_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/portfolios/screens/invest_screen.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'app_shell.dart';
import 'placeholder_screens.dart';

/// Redirects on [AuthState]: unknown → splash (empty), unauthenticated →
/// /login, authenticated+locked → /lock, authenticated+unlocked+
/// consentsRequired → /consent, authenticated+unlocked+consented → the
/// shell. See [computeRedirect] for the precedence rules — `locked` always
/// wins over `consentsRequired`.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _RouterRefreshListenable(ref),
    redirect: (context, state) => computeRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
      GoRoute(path: '/consent', builder: (context, state) => const ConsentScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/invest', builder: (context, state) => const InvestScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/budgets', builder: (context, state) => const BudgetsHomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/insights', builder: (context, state) => const PlaceholderScreen(title: 'Insights'))]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen())]),
        ],
      ),
    ],
  );
});

/// Bridges [AuthController]'s Riverpod state changes into a [Listenable]
/// go_router can watch for `refreshListenable`.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }
}

/// Pure redirect logic, extracted out of the `GoRouter.redirect` closure so
/// it's directly unit-testable without pumping a widget tree.
///
/// Precedence: `locked` wins over `consentsRequired` — nothing (including
/// the consent screen) should render before the device-lock gate clears.
/// No redirect loop: each state maps to exactly one target, and go_router
/// doesn't re-navigate when the redirect target equals the current
/// location (the same property `/lock` already relies on).
String? computeRedirect(AuthState auth, String matchedLocation) {
  final loggingIn = matchedLocation == '/login' || matchedLocation == '/register';

  if (auth.status == AuthStatus.unknown) return null;
  if (!auth.isAuthenticated) return loggingIn ? null : '/login';
  if (auth.locked) return '/lock';
  if (auth.consentsRequired) return matchedLocation == '/consent' ? null : '/consent';
  if (loggingIn || matchedLocation == '/lock' || matchedLocation == '/consent') return '/';
  return null;
}
