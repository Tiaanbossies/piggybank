import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:piggybank/core/router/app_shell.dart';

/// Step 3 of the nav/Stitch/OTA-update blueprint: verifies `AppShell`'s
/// tab-switch fade in isolation, using a synthetic 5-branch router with
/// trivial `Text` screens instead of the real feature screens.
///
/// Doing this against the real app (real auth, real 5 feature screens, each
/// with their own API-backed providers) isn't practical here: production
/// login is CORS-blocked from a browser (confirmed in a prior session, see
/// `plans/piggybank-full-suite-qa-v2.md` Step 0), and `IndexedStack` builds
/// all 5 branches eagerly, so a full router-widget test would need every
/// feature screen's providers mocked just to reach the shell — disproportionate
/// to what this step needs to prove. A synthetic router with 5 branches
/// (matching `AppShell`'s hardcoded 5-destination `NavigationBar`) isolates
/// the actual thing Step 1 changed: the `FadeTransition` wrapper, not the
/// screens inside it.
/// A minimal branch screen with its own local state (a counter), so the
/// "state survives a tab switch" test has something real to prove — a plain
/// `Text` would render identically whether or not its element was actually
/// preserved underneath.
class _CounterScreen extends StatefulWidget {
  const _CounterScreen();

  @override
  State<_CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<_CounterScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => setState(() => _count++),
          child: Text('Home count: $_count'),
        ),
      ),
    );
  }
}

void main() {
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const _CounterScreen())]),
            StatefulShellBranch(
              routes: [GoRoute(path: '/transactions', builder: (context, state) => const Text('Transactions branch content'))],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: '/plan', builder: (context, state) => const Text('Plan branch content'))],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: '/invest', builder: (context, state) => const Text('Invest branch content'))],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: '/assistant', builder: (context, state) => const Text('Penny branch content'))],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpShell(WidgetTester tester, {bool disableAnimations = false}) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  FadeTransition findFade() =>
      find.byKey(const ValueKey('appShellFade')).evaluate().single.widget as FadeTransition;

  testWidgets('tab switch fades through: the new tab fades in from 0.92 scale', (tester) async {
    await pumpShell(tester);
    expect(find.text('Home count: 0'), findsOneWidget);
    expect(findFade().opacity.value, 1.0);

    await tester.tap(find.text('Invest')); // NavigationBar destination label
    await tester.pump();
    // Partway through the 160 ms fade-in, it is neither invisible nor done,
    // and it is scaled down, proving the fade-through actually runs.
    await tester.pump(const Duration(milliseconds: 40));
    final scale = tester.widget<ScaleTransition>(
      find.descendant(of: find.byKey(const ValueKey('appShellFade')), matching: find.byType(ScaleTransition)).first,
    );
    expect(findFade().opacity.value, inExclusiveRange(0.0, 1.0));
    expect(scale.scale.value, inInclusiveRange(0.92, 1.0));
    expect(scale.scale.value, lessThan(1.0));

    await tester.pumpAndSettle();
    expect(find.text('Invest branch content'), findsOneWidget);
    expect(findFade().opacity.value, 1.0);
  });

  testWidgets('preserves branch state across tab switches (no rebuild-from-scratch)', (tester) async {
    await pumpShell(tester);
    final router = GoRouter.of(tester.element(find.text('Home count: 0')));

    // Mutate Home's local state, then switch away and back.
    await tester.tap(find.text('Home count: 0'));
    await tester.pump();
    expect(find.text('Home count: 1'), findsOneWidget);

    router.go('/invest');
    await tester.pumpAndSettle();
    expect(find.text('Invest branch content'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    // If the fade wrapper had re-keyed/rebuilt navigationShell's subtree (the
    // bug this step's context brief specifically warned against), Home's
    // State would have been torn down and this counter would have reset to 0.
    expect(find.text('Home count: 1'), findsOneWidget);
  });

  testWidgets('reduced motion: tab switch is instant, opacity never dips', (tester) async {
    await pumpShell(tester, disableAnimations: true);
    expect(findFade().opacity.value, 1.0);

    await tester.tap(find.text('Plan'));
    await tester.pump();
    // Even immediately after the tap, with reduced motion the opacity
    // should never have left 1.0 — no animation was started at all.
    expect(findFade().opacity.value, 1.0);

    await tester.pumpAndSettle();
    expect(find.text('Plan branch content'), findsOneWidget);
    expect(findFade().opacity.value, 1.0);
  });

  testWidgets('shows the five rework tabs, with no Settings tab', (tester) async {
    await pumpShell(tester);
    for (final label in ['Home', 'Transactions', 'Plan', 'Invest', 'Penny']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
    }
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')), findsNothing);
  });
}
