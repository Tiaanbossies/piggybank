import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/shared/motion/container_transform.dart';
import 'package:piggybank/shared/motion/count_up_text.dart';
import 'package:piggybank/shared/motion/press_scale.dart';
import 'package:piggybank/shared/motion/saved_highlight.dart';

/// UX rework Step 6: each motion piece reaches its final state in a single
/// pump under reduced motion, and actually animates otherwise.
Future<void> _pump(WidgetTester tester, Widget child, {bool reduced = false}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    ),
  );
}

/// Shows [CountUpText] for 100, then 200 once "Change" is tapped.
Widget _countUpHarness() {
  var amount = 100.0;
  return StatefulBuilder(
    builder: (context, setState) => Column(
      children: [
        CountUpText(text: amount == 100 ? 'R 100,00' : 'R 200,00', amount: amount),
        TextButton(onPressed: () => setState(() => amount = 200), child: const Text('Change')),
      ],
    ),
  );
}

void main() {
  group('CountUpText', () {
    testWidgets('first build shows the figure without animating', (tester) async {
      await _pump(tester, _countUpHarness());
      expect(find.text('R 100,00'), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('a change rolls through in-between values and settles on the exact text', (tester) async {
      await _pump(tester, _countUpHarness());
      await tester.tap(find.text('Change'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('R 100,00'), findsNothing);
      expect(find.text('R 200,00'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('R 200,00'), findsOneWidget);
    });

    testWidgets('reduced motion: the new figure shows in a single pump', (tester) async {
      await _pump(tester, _countUpHarness(), reduced: true);
      await tester.tap(find.text('Change'));
      await tester.pump();
      expect(find.text('R 200,00'), findsOneWidget);
    });

    testWidgets('uses tabular figures so digits do not jitter', (tester) async {
      await _pump(tester, _countUpHarness());
      final text = tester.widget<Text>(find.text('R 100,00'));
      expect(text.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('PressScale', () {
    double scaleOf(WidgetTester tester) => tester
        .widget<Transform>(find.descendant(of: find.byType(PressScale), matching: find.byType(Transform)).first)
        .transform
        .storage[0];

    testWidgets('springs to 0.97 from pointer-down, back on release, and the tap still lands', (tester) async {
      var taps = 0;
      await _pump(tester, PressScale(child: TextButton(onPressed: () => taps++, child: const Text('Card'))));
      final gesture = await tester.startGesture(tester.getCenter(find.text('Card')));
      // Feedback starts before the finger lifts (M4): the spring's first
      // frame sets its clock, the second (16 ms on) already shows it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(scaleOf(tester), lessThan(1));
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(PressScale.pressedScale, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1, 0.001));
      expect(taps, 1);
    });

    testWidgets('reduced motion: no scale at all', (tester) async {
      await _pump(tester, PressScale(child: TextButton(onPressed: () {}, child: const Text('Card'))), reduced: true);
      expect(find.descendant(of: find.byType(PressScale), matching: find.byType(Transform)), findsNothing);
    });
  });

  group('SavedHighlight', () {
    Widget harness() => Consumer(
          builder: (context, ref, _) => Column(
            children: [
              const SavedHighlight(id: 'a', child: SizedBox(height: 40, child: Text('Row A'))),
              const SavedHighlight(id: 'b', child: SizedBox(height: 40, child: Text('Row B'))),
              TextButton(onPressed: () => markSaved(ref, 'a'), child: const Text('Save A')),
            ],
          ),
        );

    testWidgets('tints only the saved row, then fades it away', (tester) async {
      await _pump(tester, harness());
      expect(find.byKey(const Key('saved-highlight')), findsNothing);

      await tester.tap(find.text('Save A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final tint = find.byKey(const Key('saved-highlight'));
      expect(tint, findsOneWidget);
      expect(
        tester.widget<SavedHighlight>(find.ancestor(of: tint, matching: find.byType(SavedHighlight))).id,
        'a',
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('saved-highlight')), findsNothing);
    });

    testWidgets('reduced motion: no tint', (tester) async {
      await _pump(tester, harness(), reduced: true);
      await tester.tap(find.text('Save A'));
      await tester.pump();
      expect(find.byKey(const Key('saved-highlight')), findsNothing);
    });
  });

  group('ContainerTransform', () {
    Widget harness() => ContainerTransform(
          openBuilder: (_) => const Scaffold(body: Text('Detail')),
          closedBuilder: (context, open) => ListTile(title: const Text('Row'), onTap: open),
        );

    testWidgets('the row grows into its screen', (tester) async {
      await _pump(tester, harness());
      await tester.tap(find.text('Row'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-transform, the screen is on its way in.
      expect(find.text('Detail'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
    });

    testWidgets('reduced motion: a plain push', (tester) async {
      await _pump(tester, harness(), reduced: true);
      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
    });
  });
}
