import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:piggybank/shared/widgets/tab_app_bar.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, TabAppBar bar) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => Scaffold(appBar: bar, body: const SizedBox())),
        GoRoute(path: '/settings', builder: (context, state) => const Scaffold(body: Text('Settings route'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('the avatar opens Settings', (tester) async {
    await pumpBar(tester, const TabAppBar(title: 'Home'));
    await tester.tap(find.byKey(const Key('tab-app-bar-avatar')));
    await tester.pumpAndSettle();
    expect(find.text('Settings route'), findsOneWidget);
  });

  testWidgets('has no notification bell', (tester) async {
    await pumpBar(tester, const TabAppBar(title: 'Home'));
    expect(find.byIcon(Icons.notifications_none), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
  });

  testWidgets('shows the subtitle and title mark when given', (tester) async {
    await pumpBar(
      tester,
      const TabAppBar(title: 'Penny', subtitle: 'Ask me anything', titleLeading: Icon(Icons.savings)),
    );
    expect(find.text('Penny'), findsOneWidget);
    expect(find.text('Ask me anything'), findsOneWidget);
    expect(find.byIcon(Icons.savings), findsOneWidget);
  });

  testWidgets('more than two actions plus an overflow is a programming error', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            appBar: TabAppBar(title: 'Too many', actions: [SizedBox(), SizedBox(), SizedBox(), SizedBox()]),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(tester.takeException(), isAssertionError);
  });
}
