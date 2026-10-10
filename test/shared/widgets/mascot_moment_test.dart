import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/theme/app_motion.dart';
import 'package:piggybank/core/theme/shared_preferences_provider.dart';
import 'package:piggybank/shared/motion/once_per_day.dart';
import 'package:piggybank/shared/widgets/mascot_moment.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The asset behind an [Image.asset], through the decode-size wrapper.
String assetName(Image image) {
  final provider = image.image;
  return ((provider is ResizeImage ? provider.imageProvider : provider) as AssetImage).assetName;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('claimMoment', () {
    test('once a day per kind', () {
      final today = DateTime(2026, 10, 9, 8);
      expect(claimMoment(prefs, 'review-cleared', now: today), isTrue);
      expect(claimMoment(prefs, 'review-cleared', now: today.add(const Duration(hours: 10))), isFalse);
      // Another kind has its own allowance.
      expect(claimMoment(prefs, 'savings-target-met', now: today), isTrue);
      // Tomorrow it may play again.
      expect(claimMoment(prefs, 'review-cleared', now: DateTime(2026, 10, 10, 7)), isTrue);
    });

    test('a one-off event plays once ever', () {
      expect(claimMoment(prefs, 'goal-reached.g1', daily: false), isTrue);
      expect(claimMoment(prefs, 'goal-reached.g1', daily: false, now: DateTime(2030)), isFalse);
      expect(claimMoment(prefs, 'goal-reached.g2', daily: false), isTrue);
    });
  });

  group('MascotMoment', () {
    const pop = MascotMoment(asset: MascotMoment.celebrating, motion: MascotMotion.pop, kind: 'test-pop');

    /// Same preferences across pumps, so "later the same day" is real.
    Future<void> pump(WidgetTester tester, Widget child, {bool reduced = false}) => tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: MaterialApp(home: Center(child: child)),
            ),
          ),
        );

    testWidgets('pops the first time, then shows static the same day', (tester) async {
      await pump(tester, pop);
      expect(find.byKey(const Key('mascot-pop')), findsOneWidget);
      await tester.pumpAndSettle();

      // Leaving and coming back the same day: the pose stays, the pop doesn't.
      await tester.pumpWidget(const SizedBox());
      await pump(tester, pop);
      expect(find.byType(MascotMoment), findsOneWidget);
      expect(find.byKey(const Key('mascot-pop')), findsNothing);
    });

    testWidgets('reduced motion: static, and the day is not used up', (tester) async {
      await pump(tester, pop, reduced: true);
      expect(find.byType(MascotMoment), findsOneWidget);
      expect(find.byKey(const Key('mascot-pop')), findsNothing);
      expect(prefs.getString('mascot.test-pop'), isNull);
    });

    testWidgets('is a cutout straight on the surface: no clip, no box', (tester) async {
      await pump(tester, const MascotMoment(asset: MascotMoment.sleeping));
      expect(find.byType(ClipOval), findsNothing);
      expect(find.byType(ClipRRect), findsNothing);
      expect(find.byType(DecoratedBox), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect(assetName(image), 'assets/penny/sleeping.png');
    });

    test('every pose is a cutout under assets/penny/', () {
      for (final pose in [
        MascotMoment.celebrating,
        MascotMoment.thinking,
        MascotMoment.sleeping,
        MascotMoment.welcoming,
      ]) {
        expect(pose, startsWith('assets/penny/'));
        expect(pose, endsWith('.png'));
      }
    });

    testWidgets('the pop runs on a spring and settles at full size', (tester) async {
      await pump(tester, pop);
      final scales = <double>[];
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        scales.add(tester.widget<Transform>(find.byKey(const Key('mascot-pop'))).transform.storage[0]);
      }
      expect(scales.first, lessThan(1));
      expect(scales.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(1 + AppMotion.popOvershootCap));
      await tester.pumpAndSettle();
      expect(tester.widget<Transform>(find.byKey(const Key('mascot-pop'))).transform.storage[0],
          closeTo(1, 0.01));
    });
  });

  test('popScale starts at 0.8 and caps the overshoot at 6 %', () {
    expect(popScale(0), 0.8);
    expect(popScale(1), 1);
    expect(popScale(2), 1 + AppMotion.popOvershootCap);
  });
}
