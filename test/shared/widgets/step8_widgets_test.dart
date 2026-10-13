import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:piggybank/core/router/app_router.dart';
import 'package:piggybank/core/theme/app_motion.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/app_tokens.dart';
import 'package:piggybank/features/auth/screens/login_screen.dart';
import 'package:piggybank/features/auth/widgets/auth_layout.dart';
import 'package:piggybank/shared/widgets/bubble_border.dart';
import 'package:piggybank/shared/widgets/mascot_moment.dart';
import 'package:piggybank/shared/widgets/submit_button.dart';
import 'package:piggybank/shared/widgets/tick_icon_button.dart';

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: Scaffold(body: child),
        ),
      ),
    );

List<Object?> _recordHaptics(WidgetTester tester) {
  final haptics = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return haptics;
}

void main() {
  group('SubmitButton (M9)', () {
    Widget button({required bool busy}) => Center(
          child: SubmitButton(key: const Key('submit'), label: 'Create account', busy: busy, onPressed: () {}),
        );

    testWidgets('the label turns into a ring inside the same box', (tester) async {
      await tester.pumpWidget(_app(button(busy: false)));
      final before = tester.getSize(find.byKey(const Key('submit')));
      expect(find.byKey(const Key('submit-ring')), findsNothing);

      await tester.pumpWidget(_app(button(busy: true)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('submit-ring')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('submit'))), before);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getSize(find.byKey(const Key('submit'))), before);
    });

    testWidgets('busy, the fill stays primary rather than greying out', (tester) async {
      await tester.pumpWidget(_app(button(busy: true)));
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(ElevatedButton), matching: find.byType(Material)).first,
      );
      expect(material.color, AppTokens.light.primary);
    });
  });

  group('TickIconButton (M37)', () {
    testWidgets('a tick replaces the icon for 1.5 s, with one light tap', (tester) async {
      final haptics = _recordHaptics(tester);
      var copies = 0;
      await tester.pumpWidget(
        _app(TickIconButton(icon: Icons.copy_outlined, tooltip: 'Copy to clipboard', onPressed: () async => copies++)),
      );
      await tester.tap(find.byTooltip('Copy to clipboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(copies, 1);
      expect(find.byKey(const Key('action-tick')), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.lightImpact']);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.byKey(const Key('action-tick')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action-tick')), findsNothing);
      expect(find.byKey(const Key('action-icon')), findsOneWidget);
    });
  });

  group('BubbleBorder', () {
    test('the tail takes 12 dp on its own side', () {
      expect(const BubbleBorder(tail: BubbleTail.up).dimensions, const EdgeInsets.only(top: 12));
      expect(const BubbleBorder(tail: BubbleTail.bottomStart).dimensions, const EdgeInsets.only(bottom: 12));
    });

    test('the tail pokes out beyond the radius-24 body', () {
      const rect = Rect.fromLTWH(0, 0, 200, 100);
      final up = const BubbleBorder(tail: BubbleTail.up).getOuterPath(rect);
      expect(up.contains(const Offset(100, 4)), isTrue, reason: 'tail tip region, above the body');
      expect(up.contains(const Offset(10, 4)), isFalse, reason: 'beside the tail is outside');
      final end = const BubbleBorder(tail: BubbleTail.bottomEnd).getOuterPath(rect);
      expect(end.contains(const Offset(180, 95)), isTrue);
      expect(end.contains(const Offset(20, 95)), isFalse);
    });
  });

  group('Shared-axis pages (M3, M34, M35)', () {
    Future<CustomTransitionPage<void>> pageUnder(WidgetTester tester, {required bool reduced}) async {
      late CustomTransitionPage<void> page;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              page = sharedAxisPage(context, const ValueKey('p'), SharedAxisTransitionType.vertical, const SizedBox());
              return const SizedBox();
            },
          ),
          reduced: reduced,
        ),
      );
      return page;
    }

    testWidgets('250 ms shared axis, or a 150 ms fade under reduced motion', (tester) async {
      final page = await pageUnder(tester, reduced: false);
      expect(page.transitionDuration, AppMotion.pageTransition);
      final reduced = await pageUnder(tester, reduced: true);
      expect(reduced.transitionDuration, AppMotion.feedback);
      expect(reduced.reverseTransitionDuration, AppMotion.feedback);
    });
  });

  group('Login layout (spec §4.1)', () {
    testWidgets('welcoming Penny at 140 dp, the wordmark in primary, then the card', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(child: _app(const LoginScreen())));
      await tester.pumpAndSettle();

      final penny = find.byKey(const Key('auth-penny'));
      expect(tester.widget<MascotMoment>(penny).asset, MascotMoment.welcoming);
      expect(tester.getSize(penny), const Size.square(AuthLayout.pennySize));
      expect(find.descendant(of: penny, matching: find.byType(ClipOval)), findsNothing);

      final wordmark = tester.widget<Text>(find.byKey(const Key('auth-wordmark')));
      expect(wordmark.style?.color, AppTokens.light.primary);
      expect(
        tester.getTopLeft(find.byKey(const Key('login-submit'))).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const Key('auth-wordmark'))).dy),
      );
    });
  });
}
