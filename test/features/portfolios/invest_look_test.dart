import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/app_tokens.dart';
import 'package:piggybank/features/portfolios/asset_class_style.dart';
import 'package:piggybank/features/portfolios/models/holding.dart';
import 'package:piggybank/features/portfolios/models/investment_overview.dart';
import 'package:piggybank/shared/motion/chart_reveal.dart';
import 'package:piggybank/shared/widgets/allocation_donut.dart';
import 'package:piggybank/shared/widgets/chart_style.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool reduced = false}) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Center(child: child))),
      ),
    );

void main() {
  group('Chart colours', () {
    test('asset classes come from the chart ramp, in light and dark', () {
      for (final t in [AppTokens.light, AppTokens.dark]) {
        final ramp = chartPalette(t);
        final allowed = {...ramp, for (final c in ramp) chartTint(t, c)};
        for (final assetClass in AssetClass.values) {
          expect(allowed, contains(assetClassColor(t, assetClass)), reason: '$assetClass');
        }
        expect(assetClassColor(t, AssetClass.stock), t.chartSeries.first);
        expect(assetClassColor(t, AssetClass.other), t.categoryIcon(CategoryFamily.neutral));
      }
      expect(assetClassColor(AppTokens.light, AssetClass.stock), isNot(assetClassColor(AppTokens.dark, AssetClass.stock)));
    });

    test('no class shares a colour with another', () {
      final colours = {for (final c in AssetClass.values) assetClassColor(AppTokens.light, c)};
      expect(colours, hasLength(AssetClass.values.length));
    });

    test('asset_class_style.dart holds no raw hex', () {
      final source = File('lib/features/portfolios/asset_class_style.dart').readAsStringSync();
      expect(source, isNot(contains('Color(0x')));
    });

    test('five distinct series for the five comparison lines', () {
      expect(chartPalette(AppTokens.light).toSet(), hasLength(5));
    });
  });

  group('P&L (J4)', () {
    test('a gain is "+" in green; a loss is "−" in ink, never red', () {
      const t = AppTokens.light;
      expect(signedPl(Decimal.parse('1200')), '+R 1 200,00');
      expect(plColor(t, Decimal.parse('1200')), t.positive);
      expect(signedPl(Decimal.parse('-300')), '−R 300,00');
      expect(plColor(t, Decimal.parse('-300')), t.ink);
      expect(plColor(t, Decimal.parse('-300')), isNot(t.danger));
    });
  });

  group('ChartReveal (M24)', () {
    testWidgets('a wipe draws left to right over 600 ms, then gets out of the way', (tester) async {
      await _pump(tester, const ChartReveal(child: SizedBox(width: 200, height: 100)));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      final clip = tester.widget<ClipRect>(find.byKey(const Key('chart-reveal')));
      final rect = clip.clipper!.getClip(const Size(200, 100));
      expect(rect.width, inExclusiveRange(0, 200));
      expect(rect.left, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('chart-reveal')), findsNothing);
    });

    testWidgets('a donut sweeps in', (tester) async {
      await _pump(
        tester,
        AllocationDonut(items: [
          AllocationItem(assetClass: AssetClass.stock, value: Decimal.fromInt(600), percent: Decimal.fromInt(60)),
          AllocationItem(assetClass: AssetClass.bond, value: Decimal.fromInt(400), percent: Decimal.fromInt(40)),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('chart-reveal')), findsOneWidget);
      expect(tester.widget(find.byKey(const Key('chart-reveal'))), isA<ClipPath>());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chart-reveal')), findsNothing);
    });

    testWidgets('reduced motion: the chart is simply there', (tester) async {
      await _pump(tester, const ChartReveal(child: SizedBox(width: 200, height: 100)), reduced: true);
      expect(find.byKey(const Key('chart-reveal')), findsNothing);
    });

    testWidgets('a new revealKey draws it again', (tester) async {
      await _pump(tester, const ChartReveal(revealKey: 'a', child: SizedBox(width: 200, height: 100)));
      await tester.pumpAndSettle();
      await _pump(tester, const ChartReveal(revealKey: 'b', child: SizedBox(width: 200, height: 100)));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('chart-reveal')), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('the datatip ticks once per new point, not per frame', (tester) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      DatatipHaptics()
        ..touched(3)
        ..touched(3)
        ..touched(4)
        ..touched(null)
        ..touched(4);
      await tester.pump();
      expect(haptics, List.filled(3, 'HapticFeedbackType.selectionClick'));
    });
  });
}
