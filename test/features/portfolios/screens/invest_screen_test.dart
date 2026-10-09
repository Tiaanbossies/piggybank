import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/portfolios/data/portfolios_api.dart';
import 'package:piggybank/features/portfolios/providers/portfolios_provider.dart';
import 'package:piggybank/features/portfolios/screens/invest_screen.dart';

import '../../../test_helpers/pump_app.dart';

class _MockPortfoliosApi extends Mock implements PortfoliosApi {}

void main() {
  late _MockPortfoliosApi api;

  setUp(() => api = _MockPortfoliosApi());

  Future<void> pumpInvest(WidgetTester tester) =>
      pumpApp(tester, const InvestScreen(), overrides: [portfoliosApiProvider.overrideWithValue(api)]);

  testWidgets('shows a skeleton, not a bare spinner, while loading', (tester) async {
    final pending = Completer<Never>();
    when(api.listPortfolios).thenAnswer((_) => pending.future);
    await pumpInvest(tester);
    await tester.pump();

    expect(find.byKey(const Key('invest-skeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failed load offers Retry, and Retry asks again', (tester) async {
    var calls = 0;
    when(api.listPortfolios).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return const [];
    });
    await pumpInvest(tester);
    await tester.pumpAndSettle();

    expect(find.text('Failed to load portfolios'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('No investments yet'), findsOneWidget);
  });

  testWidgets('Compare is labelled, not a bare icon', (tester) async {
    when(api.listPortfolios).thenAnswer((_) async => const []);
    await pumpInvest(tester);
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byKey(const Key('invest-compare')), matching: find.text('Compare')), findsOneWidget);
  });
}
