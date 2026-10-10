// Visual rework Step 3 (spec §3, M1/M2): the nav bar's sliding pill, the
// selection click on every tab tap, and re-tap-to-top. The fade-through and
// branch-state tests stay in app_shell_test.dart, unchanged.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:piggybank/core/router/app_shell.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/app_tokens.dart';
import 'package:piggybank/shared/widgets/tab_app_bar.dart';

void main() {
  late List<Object?> haptics;

  setUp(() => haptics = []);

  GoRouter buildRouter() {
    Widget list(String name) => Scaffold(
          appBar: TabAppBar(title: name),
          body: ListView(primary: true, children: [for (var i = 0; i < 60; i++) Text('$name row $i')]),
        );
    return GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
          branches: [
            for (final (path, name) in [
              ('/', 'Home'),
              ('/transactions', 'Transactions'),
              ('/plan', 'Plan'),
              ('/invest', 'Invest'),
              ('/assistant', 'Penny'),
            ])
              StatefulShellBranch(routes: [GoRoute(path: path, builder: (context, state) => list('$name tab'))]),
          ],
        ),
      ],
    );
  }

  Future<void> pumpShell(WidgetTester tester, {bool reduced = false}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: buildRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder navLabel(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  /// The pill's centre x and the centre x of [label]'s destination.
  (double, double) pillAndTab(WidgetTester tester, String label) =>
      (tester.getCenter(find.byKey(const Key('nav-pill'))).dx, tester.getCenter(navLabel(label)).dx);

  testWidgets('the pill sits under the selected tab, in primaryContainer, and the theme indicator is off', (
    tester,
  ) async {
    await pumpShell(tester);
    final (pill, tab) = pillAndTab(tester, 'Home');
    expect(pill, closeTo(tab, 1));
    expect(tester.getSize(find.byKey(const Key('nav-pill'))), const Size(64, 32));
    // It sits on the icon row, above the label.
    expect(tester.getCenter(find.byKey(const Key('nav-pill'))).dy, lessThan(tester.getCenter(navLabel('Home')).dy));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byKey(const Key('nav-pill')), matching: find.byType(DecoratedBox)),
    );
    expect((box.decoration as BoxDecoration).color, AppTokens.light.primaryContainer);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).indicatorColor, Colors.transparent);
  });

  testWidgets('the pill slides to the new tab on a spring, passing through the tabs between', (tester) async {
    await pumpShell(tester);
    final (start, _) = pillAndTab(tester, 'Home');
    await tester.tap(navLabel('Invest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    final (mid, investX) = pillAndTab(tester, 'Invest');
    expect(mid, inExclusiveRange(start, investX));
    await tester.pumpAndSettle();
    final (end, _) = pillAndTab(tester, 'Invest');
    expect(end, closeTo(investX, 1));
  });

  testWidgets('reduced motion: the pill jumps', (tester) async {
    await pumpShell(tester, reduced: true);
    await tester.tap(navLabel('Plan'));
    await tester.pump();
    final (pill, tab) = pillAndTab(tester, 'Plan');
    expect(pill, closeTo(tab, 1));
  });

  testWidgets('one selection click per tab tap, re-taps included', (tester) async {
    await pumpShell(tester);
    await tester.tap(navLabel('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(navLabel('Invest'));
    await tester.pumpAndSettle();
    await tester.tap(navLabel('Invest'));
    await tester.pumpAndSettle();
    expect(haptics, List.filled(3, 'HapticFeedbackType.selectionClick'));
  });

  testWidgets('re-tapping the open tab at its root scrolls it to the top', (tester) async {
    await pumpShell(tester);
    await tester.drag(find.text('Home tab row 3'), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Home tab row 0'), findsNothing);

    await tester.tap(navLabel('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home tab row 0'), findsOneWidget);
  });

  testWidgets('a re-tap scrolls only the visible tab', (tester) async {
    await pumpShell(tester);
    await tester.drag(find.text('Home tab row 3'), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(navLabel('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(navLabel('Plan'));
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Home'));
    await tester.pumpAndSettle();
    // Home kept its place; only a re-tap on Home itself would move it.
    expect(find.text('Home tab row 0'), findsNothing);
  });
}
