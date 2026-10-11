import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/lock_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/chatbot/screens/chatbot_screen.dart';
import '../../features/consent/screens/consent_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/plan/screens/plan_screen.dart';
import '../../features/portfolios/screens/invest_screen.dart';
import '../../features/settings/screens/data_export_screen.dart';
import '../../features/transactions/screens/transactions_screen.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../theme/app_motion.dart';
import 'app_shell.dart';
import 'placeholder_screens.dart';

/// Redirects on [AuthState]: unknown → splash (empty), unauthenticated →
/// /login, authenticated+locked → /lock, authenticated+unlocked+
/// consentsRequired → /consent, authenticated+unlocked+consented+
/// onboardingRequired → /onboarding, otherwise → the shell. See
/// [computeRedirect] for the precedence rules — `locked` wins over
/// `consentsRequired`, which wins over `onboardingRequired`.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _RouterRefreshListenable(ref),
    redirect: (context, state) => computeRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
      GoRoute(path: '/consent', builder: (context, state) => const ConsentScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      // Settings sits above the shell (opened from the tab-root avatar), so
      // it covers the bottom bar and pops back to whichever tab opened it.
      GoRoute(
        path: '/settings',
        // Shared axis Z (spec §3.1, M3): Settings comes forward, above the
        // tabs, rather than sliding in like a sibling screen.
        pageBuilder: (context, state) =>
            sharedAxisPage(context, state.pageKey, SharedAxisTransitionType.scaled, const SettingsScreen()),
        routes: [GoRoute(path: 'data-export', builder: (context, state) => const DataExportScreen())],
      ),
      StatefulShellRoute.indexedStack(
        // Shared axis Y (M34, M35): signing in, unlocking or finishing the
        // tour rises into the shell rather than sliding in sideways.
        pageBuilder: (context, state, navigationShell) => sharedAxisPage(
          context,
          state.pageKey,
          SharedAxisTransitionType.vertical,
          AppShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const DashboardScreen())]),
          StatefulShellBranch(
            routes: [GoRoute(path: '/transactions', builder: (context, state) => const TransactionsScreen())],
          ),
          StatefulShellBranch(routes: [GoRoute(path: '/plan', builder: (context, state) => const PlanScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/invest', builder: (context, state) => const InvestScreen())]),
          // Penny keeps the /assistant path so askPenny's go('/assistant') holds.
          StatefulShellBranch(routes: [GoRoute(path: '/assistant', builder: (context, state) => const ChatbotScreen())]),
        ],
      ),
    ],
  );
});

/// A route page with a shared-axis transition of [type] over 250 ms, or a
/// 150 ms fade under reduced motion (M3, M34, M35).
CustomTransitionPage<void> sharedAxisPage(
  BuildContext context,
  LocalKey key,
  SharedAxisTransitionType type,
  Widget child,
) {
  final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  final duration = reduced ? AppMotion.feedback : AppMotion.pageTransition;
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => reduced
        ? FadeTransition(opacity: animation, child: child)
        : SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: type,
            child: child,
          ),
  );
}

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
/// Precedence: `locked` wins over `consentsRequired`, which wins over
/// `onboardingRequired` — nothing (including the consent screen or the
/// onboarding tour) should render before the device-lock gate clears, and
/// unresolved consents outrank the tour. No redirect loop: each state maps
/// to exactly one target, and go_router doesn't re-navigate when the
/// redirect target equals the current location (the same property `/lock`
/// already relies on).
String? computeRedirect(AuthState auth, String matchedLocation) {
  final loggingIn = matchedLocation == '/login' ||
      matchedLocation == '/register' ||
      matchedLocation == '/forgot-password' ||
      matchedLocation == '/reset-password';

  if (auth.status == AuthStatus.unknown) return null;
  if (!auth.isAuthenticated) return loggingIn ? null : '/login';
  if (auth.locked) return '/lock';
  if (auth.consentsRequired) return matchedLocation == '/consent' ? null : '/consent';
  if (auth.onboardingRequired) return matchedLocation == '/onboarding' ? null : '/onboarding';
  if (loggingIn || matchedLocation == '/lock' || matchedLocation == '/consent' || matchedLocation == '/onboarding') {
    return '/';
  }
  return null;
}
