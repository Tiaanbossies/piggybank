import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/app_tokens.dart';
import 'package:piggybank/shared/widgets/app_controls.dart';

List<Object?> _recordHaptics(WidgetTester tester) {
  final haptics = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return haptics;
}

Widget _app(Widget child) => MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

void main() {
  group('AppRefresh (M12)', () {
    testWidgets('primary on surface, and one light tap when the pull triggers', (tester) async {
      final haptics = _recordHaptics(tester);
      var refreshes = 0;
      await tester.pumpWidget(
        _app(
          AppRefresh(
            onRefresh: () async => refreshes++,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 2000, child: Text('rows'))]),
          ),
        ),
      );
      final indicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      expect(indicator.color, AppTokens.light.primary);
      expect(indicator.backgroundColor, AppTokens.light.surface);

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });
  });

  group('AppSwitch (M28)', () {
    testWidgets('one selection tick per toggle, and the value goes through', (tester) async {
      final haptics = _recordHaptics(tester);
      bool? seen;
      await tester.pumpWidget(_app(Center(child: AppSwitch(value: false, onChanged: (v) => seen = v))));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(seen, isTrue);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('disabled: no tick and no change', (tester) async {
      final haptics = _recordHaptics(tester);
      await tester.pumpWidget(_app(const Center(child: AppSwitch(value: false, onChanged: null))));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(haptics, isEmpty);
    });
  });
}
