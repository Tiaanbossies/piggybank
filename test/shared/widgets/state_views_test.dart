// Visual rework Step 4 (spec M11, M13, M14): the skeleton loading view, the
// first-load stagger and InlineError's fade and Retry ring.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/app_tokens.dart';
import 'package:piggybank/shared/motion/stagger_in.dart';
import 'package:piggybank/shared/widgets/app_skeleton.dart';
import 'package:piggybank/shared/widgets/state_views.dart';
import 'package:skeletonizer/skeletonizer.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool reduced = false}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
    ),
  );
}

Skeletonizer _skeletonizer(WidgetTester tester) =>
    tester.widget<Skeletonizer>(find.byWidgetPredicate((w) => w is Skeletonizer).first);

void main() {
  group('AppSkeleton (M11)', () {
    testWidgets('draws the real rows as sunk bones that shimmer', (tester) async {
      await _pump(tester, const SkeletonPage(hero: true));
      await tester.pump(const Duration(milliseconds: 100));

      final effect = _skeletonizer(tester).effect;
      expect(effect, isA<ShimmerEffect>());
      expect((effect! as ShimmerEffect).colors.first, AppTokens.light.sunk);
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'the shimmer runs');
      // Built from the real cards, not grey boxes.
      expect(find.text('Placeholder name'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('holds still under reduced motion', (tester) async {
      await _pump(tester, const SkeletonRows(), reduced: true);
      await tester.pump();

      final effect = _skeletonizer(tester).effect;
      expect(effect, isA<SolidColorEffect>());
      expect((effect! as SolidColorEffect).color, AppTokens.light.sunk);
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no shimmer');
    });

    testWidgets('bones ignore taps', (tester) async {
      var taps = 0;
      await _pump(tester, AppSkeleton(child: TextButton(onPressed: () => taps++, child: const Text('Tap'))));
      await tester.tap(find.byType(TextButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('SkeletonSwitcher crossfades to the content over 200 ms', (tester) async {
      await _pump(tester, const SkeletonSwitcher(child: SkeletonRows(key: ValueKey('loading'))));
      await _pump(tester, const SkeletonSwitcher(child: Text('Loaded', key: ValueKey('data'))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonRows), findsOneWidget, reason: 'still fading out halfway');
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(SkeletonRows), findsNothing);
      expect(find.text('Loaded'), findsOneWidget);
    });
  });

  group('StaggerIn (M11)', () {
    double opacityOf(WidgetTester tester, int index) {
      final opacity = find.descendant(of: find.byKey(ValueKey('row-$index')), matching: find.byType(Opacity));
      return tester.widget<Opacity>(opacity).opacity;
    }

    Widget rows() => ListView(
          children: [for (var i = 0; i < 8; i++) StaggerIn(key: ValueKey('row-$i'), index: i, child: Text('Row $i'))],
        );

    testWidgets('the first six rows fade in 30 ms apart; the rest are there at once', (tester) async {
      await _pump(tester, rows());
      await tester.pump(const Duration(milliseconds: 60));

      expect(opacityOf(tester, 0), greaterThan(opacityOf(tester, 1)));
      expect(opacityOf(tester, 1), greaterThan(opacityOf(tester, 2)));
      expect(opacityOf(tester, 3), 0, reason: 'starts at 90 ms');
      expect(find.descendant(of: find.byKey(const ValueKey('row-6')), matching: find.byType(Opacity)), findsNothing);

      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        expect(opacityOf(tester, i), 1);
      }
    });

    testWidgets('no stagger under reduced motion', (tester) async {
      await _pump(tester, rows(), reduced: true);
      expect(find.descendant(of: find.byType(StaggerIn), matching: find.byType(Opacity)), findsNothing);
      expect(find.text('Row 0'), findsOneWidget);
    });
  });

  group('InlineError (M14)', () {
    testWidgets('fades in over 200 ms', (tester) async {
      await _pump(tester, const InlineError(message: 'Failed to load'));
      final fade = find.descendant(of: find.byKey(const Key('inline-error-in')), matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(fade).opacity, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Opacity>(fade).opacity, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<Opacity>(fade).opacity, 1);
    });

    testWidgets('is there at once under reduced motion', (tester) async {
      await _pump(tester, const InlineError(message: 'Failed to load'), reduced: true);
      expect(find.byKey(const Key('inline-error-in')), findsNothing);
      expect(find.text('Failed to load'), findsOneWidget);
    });

    testWidgets('Retry presses, then shows its ring until the next result arrives', (tester) async {
      var retries = 0;
      Widget error(String message) => InlineError(message: message, onRetry: () => retries++);

      await _pump(tester, error('Failed to load'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('retry-ring')), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pump();
      expect(retries, 1);
      expect(find.byKey(const Key('retry-ring')), findsOneWidget);

      // The screen rebuilds into "refreshing" at once: the ring stays.
      await _pump(tester, error('Failed to load'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('retry-ring')), findsOneWidget);

      // The new result arrives later: back to plain Retry, ready again.
      await tester.pump(InlineError.minRetry);
      await _pump(tester, error('Still offline'));
      await tester.pump();
      expect(find.byKey(const Key('retry-ring')), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      expect(retries, 2);
      await tester.pumpAndSettle(InlineError.maxRetry);
    });

    testWidgets('a failure faster than the ring still clears it', (tester) async {
      Widget error() => InlineError(message: 'Failed to load', onRetry: () {});
      await _pump(tester, error());
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pump();
      await _pump(tester, error());
      await _pump(tester, error());
      await tester.pump(InlineError.minRetry);
      await tester.pump();
      expect(find.byKey(const Key('retry-ring')), findsNothing);
    });
  });
}
