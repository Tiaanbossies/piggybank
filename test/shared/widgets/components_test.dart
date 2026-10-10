// Visual rework Step 3: the shared kit against spec §3 and the motion rows
// it owns (M4, M5, M21–M23, M27, M29, M41, M42).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/app_tokens.dart';
import 'package:piggybank/features/imports/models/import_job.dart';
import 'package:piggybank/features/transactions/category_icons.dart';
import 'package:piggybank/shared/motion/count_up_text.dart';
import 'package:piggybank/shared/motion/press_scale.dart';
import 'package:piggybank/shared/motion/tab_retap.dart';
import 'package:piggybank/shared/widgets/app_banner.dart';
import 'package:piggybank/shared/widgets/app_card.dart';
import 'package:piggybank/shared/widgets/app_filter_chip.dart';
import 'package:piggybank/shared/widgets/category_tile.dart';
import 'package:piggybank/shared/widgets/confirm_dialog.dart';
import 'package:piggybank/shared/widgets/expand_section.dart';
import 'package:piggybank/shared/widgets/group_card.dart';
import 'package:piggybank/shared/widgets/hero_metric_card.dart';
import 'package:piggybank/shared/widgets/icon_chip.dart';
import 'package:piggybank/shared/widgets/percent_pill.dart';
import 'package:piggybank/shared/widgets/progress_card.dart';
import 'package:piggybank/shared/widgets/shrinking_fab.dart';
import 'package:piggybank/shared/widgets/status_badge.dart';
import 'package:piggybank/shared/widgets/tab_app_bar.dart';

const light = AppTokens.light;

/// Amounts as [formatZAR] writes them, with no-break spaces.
String zar(String s) => s.replaceAll(' ', ' ');

Future<void> pump(WidgetTester tester, Widget child, {bool reduced = false, bool dark = false}) =>
    tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );

/// The decoration of the first [DecoratedBox] under [of].
BoxDecoration decorationUnder(WidgetTester tester, Finder of) => tester
    .widgetList<DecoratedBox>(find.descendant(of: of, matching: find.byType(DecoratedBox)))
    .map((b) => b.decoration)
    .whereType<BoxDecoration>()
    .first;

void main() {
  group('categoryFamily (spec §1.3)', () {
    const expected = {
      CategoryFamily.forest: ['groceries', 'food', 'salary', 'freelance', 'interest'],
      CategoryFamily.ochre: ['transport', 'gas', 'petrol'],
      CategoryFamily.clay: ['dining', 'dining out', 'shopping', 'clothing', 'entertainment'],
      CategoryFamily.sage: ['utilities', 'rent', 'insurance', 'gym', 'healthcare', 'medical'],
    };

    test('every named category lands in its family, case and space blind', () {
      for (final MapEntry(key: family, value: names) in expected.entries) {
        for (final name in names) {
          expect(categoryFamily(name), family, reason: name);
          expect(categoryFamily('  ${name.toUpperCase()} '), family, reason: name);
        }
      }
    });

    test('every category with its own icon has a family other than neutral', () {
      for (final names in expected.values) {
        for (final name in names) {
          expect(categoryIcon(name), isNot(Icons.sell_outlined), reason: name);
        }
      }
    });

    test('unknown is neutral and gets a tag, never a direction arrow (S6)', () {
      for (final unknown in [null, '', 'Pets', 'Gifts']) {
        expect(categoryFamily(unknown), CategoryFamily.neutral);
        for (final isExpense in [true, false]) {
          final icon = categoryIcon(unknown, isExpense: isExpense);
          expect(icon, Icons.sell_outlined);
          expect(icon, isNot(anyOf(Icons.arrow_upward, Icons.arrow_downward)));
        }
      }
    });
  });

  group('CategoryTile and IconChip', () {
    testWidgets('the tile is 40 dp, radius 14, in the family tint and icon colour', (tester) async {
      await pump(tester, const CategoryTile(icon: Icons.directions_car_outlined, family: CategoryFamily.ochre));
      expect(tester.getSize(find.byType(CategoryTile)), const Size(40, 40));
      final box = tester.widget<Container>(find.byType(Container)).decoration! as BoxDecoration;
      expect(box.color, light.categoryTile(CategoryFamily.ochre));
      expect(box.borderRadius, AppRadius.tileAll);
      expect(tester.widget<Icon>(find.byType(Icon)).color, light.categoryIcon(CategoryFamily.ochre));
    });

    testWidgets('IconChip with a family renders the tile; without one, the primaryContainer circle', (tester) async {
      await pump(tester, const IconChip(icon: Icons.bolt_outlined, family: CategoryFamily.sage));
      expect(find.byType(CategoryTile), findsOneWidget);

      await pump(tester, const IconChip(icon: Icons.bolt_outlined));
      final box = tester.widget<Container>(find.byType(Container)).decoration! as BoxDecoration;
      expect(box.color, light.primaryContainer);
      expect(box.shape, BoxShape.circle);
    });

    testWidgets('a danger chip uses the danger container, even with a family', (tester) async {
      await pump(tester, const IconChip(icon: Icons.bolt_outlined, family: CategoryFamily.sage, danger: true));
      expect(find.byType(CategoryTile), findsNothing);
      final box = tester.widget<Container>(find.byType(Container)).decoration! as BoxDecoration;
      expect(box.color, light.dangerContainer);
    });
  });

  group('AppCard (spec §1.6, M4)', () {
    testWidgets('surface, radius 24, padding 20, forest level-1 shadow in light', (tester) async {
      await pump(tester, const AppCard(child: Text('x')));
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(AppCard), matching: find.byType(Material)).first,
      );
      expect(material.color, light.surface);
      expect(material.borderRadius, AppRadius.cardAll);
      final shadow = decorationUnder(tester, find.byType(AppCard)).boxShadow!;
      expect(shadow, AppShadows.level1(Brightness.light));
      expect(shadow.single.color.a, closeTo(0.08, 0.01));
      final padding = tester.widget<Padding>(
        find.ancestor(of: find.text('x'), matching: find.byType(Padding)).first,
      );
      expect(padding.padding, const EdgeInsets.all(20));
    });

    testWidgets('dark: tonal, no shadow', (tester) async {
      await pump(tester, const AppCard(child: Text('x')), dark: true);
      final box = decorationUnder(tester, find.byType(AppCard));
      expect(box.boxShadow ?? const [], isEmpty);
    });

    testWidgets('only a tappable card presses', (tester) async {
      await pump(tester, const AppCard(child: Text('x')));
      expect(find.byType(PressScale), findsNothing);
      var taps = 0;
      await pump(tester, AppCard(onTap: () => taps++, child: const Text('x')));
      expect(find.byType(PressScale), findsOneWidget);
      await tester.tap(find.text('x'));
      expect(taps, 1);
    });
  });

  group('GroupCard (spec §1.6, M5)', () {
    Widget group({VoidCallback? onTap}) => GroupCard(
          children: [
            GroupRow(title: 'Woolworths', leadingIcon: Icons.shopping_cart_outlined, onTap: onTap),
            const GroupRow(title: 'Uber'),
          ],
        );

    testWidgets('one card, rows separated by space not dividers, rows at least 64 dp', (tester) async {
      await pump(tester, group());
      expect(find.byType(AppCard), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      for (final element in find.byType(GroupRow).evaluate()) {
        expect(element.size!.height, greaterThanOrEqualTo(GroupRow.minHeight));
      }
    });

    testWidgets('a press tints the row sunk at 60 % from pointer-down, and clears on release', (tester) async {
      await pump(tester, group(onTap: () {}));
      Color tint() {
        final c = tester.widget<AnimatedContainer>(find.byKey(const Key('group-row-highlight')).first);
        return (c.decoration! as BoxDecoration).color!;
      }

      expect(tint().a, 0);
      final gesture = await tester.startGesture(tester.getCenter(find.text('Woolworths')));
      await tester.pump();
      expect(tint(), light.sunk.withValues(alpha: 0.6));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tint().a, 0);
    });

    testWidgets('a row with no action never tints', (tester) async {
      await pump(tester, group());
      final gesture = await tester.startGesture(tester.getCenter(find.text('Uber')));
      await tester.pump();
      final c = tester.widget<AnimatedContainer>(find.byKey(const Key('group-row-highlight')).last);
      expect((c.decoration! as BoxDecoration).color!.a, 0);
      await gesture.up();
    });
  });

  group('HeroMetricCard (spec §3)', () {
    test('wholeRand rounds to the rand and passes non-amounts through', () {
      expect(HeroMetricCard.wholeRand(zar('R 4 210,00')), zar('R 4 210'));
      expect(HeroMetricCard.wholeRand(zar('R 4 210,60')), zar('R 4 211'));
      expect(HeroMetricCard.wholeRand(zar('R 999,50')), zar('R 1 000'));
      expect(HeroMetricCard.wholeRand(zar('-R 12,40')), zar('-R 12'));
      expect(HeroMetricCard.wholeRand('—'), '—');
      expect(HeroMetricCard.wholeRand('R —'), 'R —');
    });

    testWidgets('hero fill and ink, no cents, the pill bar on the hero track', (tester) async {
      await pump(
        tester,
        HeroMetricCard(label: 'Left to spend', value: zar('R 4 210,00'), deltaText: 'R 140 a day', progress: 0.4),
      );
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(AppCard), matching: find.byType(Material)).first,
      );
      expect(material.color, light.hero);
      expect(find.text(zar('R 4 210')), findsOneWidget);
      expect(tester.widget<Text>(find.text(zar('R 4 210'))).style?.color, light.heroInk);
      expect(tester.widget<Text>(find.text('R 140 a day')).style?.color, light.heroSecondary);
      final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.color, light.heroBar);
      expect(bar.backgroundColor, light.heroTrack);
      expect(bar.minHeight, 8);
    });

    testWidgets('with onTap the whole card is the button', (tester) async {
      var taps = 0;
      await pump(tester, HeroMetricCard(label: 'Net worth', value: 'R 1,00', onTap: () => taps++));
      await tester.tap(find.text('Net worth'));
      expect(taps, 1);
    });
  });

  group('progress (M23)', () {
    testWidgets('ProgressCard: primary on a sunk track, danger only when over budget', (tester) async {
      await pump(tester, const ProgressCard(title: 'Food', pct: 0.5, footnote: 'f'));
      var bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.color, light.primary);
      expect(bar.backgroundColor, light.sunk);

      // A goal past 100 % is good news: still primary.
      await pump(tester, const ProgressCard(title: 'Trip', pct: 1.3, footnote: 'f'));
      bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.color, light.primary);

      await pump(tester, const ProgressCard(title: 'Food', pct: 1.3, footnote: 'f', overBudget: true));
      bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.color, light.danger);
    });

    testWidgets('the fill animates over 400 ms and reports reaching 100 % once', (tester) async {
      var reached = 0;
      Widget card(double pct) => ProgressCard(title: 'Trip', pct: pct, footnote: 'f', onReached: () => reached++);
      await pump(tester, card(0.6));
      await pump(tester, card(1));
      await tester.pump(const Duration(milliseconds: 200));
      final mid = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value!;
      expect(mid, inExclusiveRange(0.6, 1.0));
      expect(reached, 0);
      await tester.pumpAndSettle();
      expect(reached, 1);
    });

    testWidgets('reduced motion: the fill lands in one frame', (tester) async {
      await pump(tester, const ProgressCard(title: 'Trip', pct: 0.2, footnote: 'f'), reduced: true);
      await pump(tester, const ProgressCard(title: 'Trip', pct: 0.9, footnote: 'f'), reduced: true);
      await tester.pump();
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.9);
    });
  });

  group('pills', () {
    testWidgets('PercentPill: primaryContainer, the danger container only when over', (tester) async {
      await pump(tester, const PercentPill(pct: 40));
      var box = tester.widget<Container>(find.byType(Container)).decoration! as BoxDecoration;
      expect(box.color, light.primaryContainer);
      expect(box.borderRadius, AppRadius.pillAll);
      await pump(tester, const PercentPill(pct: 130, danger: true));
      box = tester.widget<Container>(find.byType(Container)).decoration! as BoxDecoration;
      expect(box.color, light.dangerContainer);
    });

    testWidgets('StatusBadge: danger only for a failure', (tester) async {
      for (final (status, color) in [
        (ImportStatus.completed, light.primaryContainer),
        (ImportStatus.partial, light.primaryContainer),
        (ImportStatus.failed, light.dangerContainer),
        (ImportStatus.pending, light.sunk),
      ]) {
        await pump(tester, StatusBadge(status: status));
        final box = tester.widget<Container>(find.byType(Container)).decoration! as BoxDecoration;
        expect(box.color, color, reason: status.name);
      }
    });
  });

  group('CrossfadeDigits (M22)', () {
    Widget digits(double amount) => CrossfadeDigits(text: 'R $amount', amount: amount);

    double slideOf(WidgetTester tester, String text) => tester
        .widget<Transform>(find.ancestor(of: find.text(text), matching: find.byType(Transform)).first)
        .transform
        .getTranslation()
        .y;

    testWidgets('a rise slides the new figure up into place over 150 ms', (tester) async {
      await pump(tester, digits(10));
      await pump(tester, digits(20));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('R 10.0'), findsOneWidget);
      expect(slideOf(tester, 'R 20.0'), inExclusiveRange(0, CrossfadeDigits.slide));
      await tester.pumpAndSettle();
      expect(find.text('R 10.0'), findsNothing);
      expect(find.text('R 20.0'), findsOneWidget);
    });

    testWidgets('a fall comes from above', (tester) async {
      await pump(tester, digits(20));
      await pump(tester, digits(10));
      await tester.pump(const Duration(milliseconds: 50));
      expect(slideOf(tester, 'R 10.0'), lessThan(0));
    });

    testWidgets('reduced motion: swaps at once', (tester) async {
      await pump(tester, digits(10), reduced: true);
      await pump(tester, digits(20), reduced: true);
      expect(find.text('R 10.0'), findsNothing);
      expect(find.text('R 20.0'), findsOneWidget);
    });
  });

  group('ExpandSection (M29)', () {
    testWidgets('opens with the chevron turning 180° over 200 ms, and closes again', (tester) async {
      await pump(tester, const ExpandSection(title: 'More', child: Text('Body')));
      RotationTransition chevron() => tester.widget(find.byKey(const Key('expand-chevron')));
      SizeTransition body() => tester.widget(find.byKey(const Key('expand-body')));
      expect(body().sizeFactor.value, 0);

      await tester.tap(find.text('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(body().sizeFactor.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(body().sizeFactor.value, 1);
      expect(chevron().turns.value, 0.5);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(body().sizeFactor.value, 0);
    });

    testWidgets('reduced motion: instant', (tester) async {
      await pump(tester, const ExpandSection(title: 'More', child: Text('Body')), reduced: true);
      await tester.tap(find.text('More'));
      await tester.pump();
      expect(tester.widget<SizeTransition>(find.byKey(const Key('expand-body'))).sizeFactor.value, 1);
    });
  });

  group('AppBanner (M41)', () {
    testWidgets('a primaryContainer pill that slides down 8 dp and fades in', (tester) async {
      await pump(tester, AppBanner(message: '3 to review', onTap: () {}));
      Opacity opacity() => tester.widget(find.byKey(const Key('app-banner-in')));
      expect(opacity().opacity, lessThan(0.5));
      await tester.pumpAndSettle();
      expect(opacity().opacity, 1);
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(AppBanner), matching: find.byType(Material)).first,
      );
      expect(material.color, light.primaryContainer);
      expect(material.borderRadius, AppRadius.pillAll);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('reduced motion: there at once', (tester) async {
      await pump(tester, AppBanner(message: '3 to review', onTap: () {}), reduced: true);
      expect(tester.widget<Opacity>(find.byKey(const Key('app-banner-in'))).opacity, 1);
    });
  });

  group('AppFilterChip (M27)', () {
    testWidgets('a selection clicks once and the check grows in', (tester) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      var selected = false;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => AppFilterChip(
            label: 'Groceries',
            selected: selected,
            onSelected: (v) => setState(() => selected = v),
          ),
        ),
      );
      expect(tester.widget<AnimatedScale>(find.byKey(const Key('filter-chip-check'))).scale, 0);
      await tester.tap(find.text('Groceries'));
      await tester.pump();
      expect(selected, isTrue);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      final check = tester.widget<AnimatedScale>(find.byKey(const Key('filter-chip-check')));
      expect(check.scale, 1);
      expect(check.duration, const Duration(milliseconds: 150));
    });
  });

  group('ShrinkingFab (M42)', () {
    testWidgets('folds to its icon scrolling down and opens scrolling up', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(controller: controller, children: [for (var i = 0; i < 60; i++) Text('Row $i')]),
            floatingActionButton: ShrinkingFab(
              controller: controller,
              icon: Icons.add,
              label: 'Add transaction',
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.text('Add transaction'), findsOneWidget);
      await tester.drag(find.text('Row 5'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Add transaction'), findsNothing);
      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.drag(find.text('Row 15'), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(find.text('Add transaction'), findsOneWidget);
    });
  });

  group('ConfirmDialog (M17)', () {
    testWidgets("the destructive action is a danger text button; the shape is the theme's", (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmDestroy(context, title: 'Delete holding?'),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final button = tester.widget<TextButton>(find.byKey(const Key('confirm-destroy')));
      expect(button.style?.foregroundColor?.resolve({}), light.danger);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.shape, isNull);
      final shape = Theme.of(tester.element(find.byType(AlertDialog))).dialogTheme.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, AppRadius.cardAll);
    });
  });

  group('TabAppBar (M2, M42)', () {
    Future<ScrollController> pumpBar(WidgetTester tester, {ValueNotifier<int>? retaps, bool reduced = false}) async {
      late ScrollController primary;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              appBar: const TabAppBar(title: 'Home'),
              body: Builder(
                builder: (context) {
                  primary = PrimaryScrollController.of(context);
                  return ListView(primary: true, children: [for (var i = 0; i < 60; i++) Text('Row $i')]);
                },
              ),
            ),
          ),
        ],
      );
      Widget app = MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
      if (retaps != null) app = TabRetapScope(retaps: retaps, child: app);
      await tester.pumpWidget(MediaQuery(data: MediaQueryData(disableAnimations: reduced), child: app));
      await tester.pumpAndSettle();
      return primary;
    }

    AnimatedContainer bar(WidgetTester tester) => tester.widget(find.byKey(const Key('tab-app-bar-surface')));
    BoxDecoration surface(WidgetTester tester) => bar(tester).decoration! as BoxDecoration;
    Border hairline(WidgetTester tester) => (bar(tester).foregroundDecoration! as BoxDecoration).border! as Border;

    List<BoxShadow>? flash(WidgetTester tester) =>
        (tester.widget<DecoratedBox>(find.byKey(const Key('tab-app-bar-flash'))).decoration as BoxDecoration).boxShadow;

    testWidgets('flat on bg; surface and a hairline once content scrolls under it', (tester) async {
      await pumpBar(tester);
      expect(surface(tester).color, light.bg);
      expect(hairline(tester).bottom.color.a, 0);

      await tester.drag(find.text('Row 3'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(surface(tester).color, light.surface);
      expect(hairline(tester).bottom.color.a, greaterThan(0));
    });

    testWidgets('the avatar is 40 dp in a target of at least 48 dp; the title is headline', (tester) async {
      await pumpBar(tester);
      expect(tester.getSize(find.byType(CircleAvatar)), const Size(40, 40));
      final target = tester.getSize(find.byKey(const Key('tab-app-bar-avatar')));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      expect(tester.widget<AppBar>(find.byType(AppBar)).titleTextStyle?.fontSize, 24);
    });

    testWidgets('a re-tap at the root scrolls to the top with a shadow flash', (tester) async {
      final retaps = ValueNotifier(0);
      addTearDown(retaps.dispose);
      final primary = await pumpBar(tester, retaps: retaps);
      await tester.drag(find.text('Row 3'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(primary.offset, greaterThan(0));

      retaps.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(flash(tester), isNotEmpty);
      await tester.pumpAndSettle();
      expect(primary.offset, 0);
      expect(flash(tester), isNull);
    });

    testWidgets('reduced motion: the re-tap jumps to the top, no flash', (tester) async {
      final retaps = ValueNotifier(0);
      addTearDown(retaps.dispose);
      final primary = await pumpBar(tester, retaps: retaps, reduced: true);
      await tester.drag(find.text('Row 3'), const Offset(0, -400));
      await tester.pumpAndSettle();
      retaps.value++;
      await tester.pump();
      expect(primary.offset, 0);
      expect(flash(tester), isNull);
    });
  });

  testWidgets('PressScale: a cancelled press springs back', (tester) async {
    await pump(tester, PressScale(child: TextButton(onPressed: () {}, child: const Text('Card'))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Card')), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    await gesture.cancel();
    await tester.pumpAndSettle();
    final scale = tester
        .widget<Transform>(find.descendant(of: find.byType(PressScale), matching: find.byType(Transform)).first)
        .transform
        .storage[0];
    expect(scale, closeTo(1, 0.001));
  });
}
