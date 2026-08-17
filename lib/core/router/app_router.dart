import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/lock_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/budgets/screens/budgets_home_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/portfolios/screens/invest_screen.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'app_shell.dart';
import 'placeholder_screens.dart';

/// Redirects on [AuthState]: unknown → splash (empty), unauthenticated →
/// /login, authenticated+locked → /lock, authenticated+unlocked → the shell.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _RouterRefreshListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (auth.status == AuthStatus.unknown) return null;
      if (!auth.isAuthenticated) return loggingIn ? null : '/login';
      if (auth.locked) return '/lock';
      if (loggingIn || state.matchedLocation == '/lock') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
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
