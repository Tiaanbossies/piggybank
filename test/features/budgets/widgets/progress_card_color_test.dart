import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/shared/widgets/progress_card.dart';

/// Focused coverage for [ProgressCard]'s bar-colour conditional — the
/// green-on-track vs red-over-budget logic that Budgets (and Goals, via the
/// same shared component) rely on. `overBudget: true` must colour the bar
/// with the theme's semantic `danger` colour; otherwise it uses the
/// colour scheme's `primary` (on-track/green-ish per the brand palette).
void main() {
  Future<AppSemanticColors> pumpAndGetSemantics(WidgetTester tester, {required bool overBudget}) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return ProgressCard(
              title: 'Groceries',
              pct: overBudget ? 1.2 : 0.5,
              footnote: 'footnote',
              overBudget: overBudget,
            );
          },
        ),
      ),
    );
    return Theme.of(capturedContext).extension<AppSemanticColors>()!;
  }

  testWidgets('on-track budget colours the progress bar with the primary colour, not danger', (tester) async {
    final semantics = await pumpAndGetSemantics(tester, overBudget: false);

    final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.color, isNot(semantics.danger));
  });

  testWidgets('over-budget colours the progress bar with the danger colour', (tester) async {
    final semantics = await pumpAndGetSemantics(tester, overBudget: true);

    final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.color, semantics.danger);
  });

  testWidgets('over-budget renders the footnote in the danger colour', (tester) async {
    final semantics = await pumpAndGetSemantics(tester, overBudget: true);

    final footnote = tester.widget<Text>(find.text('footnote'));
    expect(footnote.style?.color, semantics.danger);
  });

  testWidgets('on-track renders the footnote in the muted text colour', (tester) async {
    final semantics = await pumpAndGetSemantics(tester, overBudget: false);

    final footnote = tester.widget<Text>(find.text('footnote'));
    expect(footnote.style?.color, semantics.textMuted);
  });

  testWidgets('the progress bar value is clamped to 1.0 even when pct exceeds 100%', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const ProgressCard(title: 'Over', pct: 1.8, footnote: 'f', overBudget: true),
      ),
    );

    final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.value, 1.0);
  });

  testWidgets('indented cards get extra left margin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const ProgressCard(title: 'Sub', pct: 0.3, footnote: 'f', indented: true),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    final margin = card.margin! as EdgeInsets;
    expect(margin.left, 24);
  });
}
