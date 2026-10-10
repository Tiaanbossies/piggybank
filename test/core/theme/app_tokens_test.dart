import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/app_tokens.dart';

void main() {
  test('dark is designed, not the light theme reused', () {
    expect(AppTokens.dark.bg, isNot(AppTokens.light.bg));
    expect(AppTokens.dark.hero, isNot(AppTokens.light.hero));
    // S1: text on the dark primary is dark, not white.
    expect(AppTokens.dark.onPrimary.computeLuminance(), lessThan(0.1));
  });

  test('lerp hits both ends', () {
    expect(AppTokens.light.lerp(AppTokens.dark, 0).primary, AppTokens.light.primary);
    expect(AppTokens.light.lerp(AppTokens.dark, 1).primary, AppTokens.dark.primary);
    expect(AppTokens.light.lerp(AppTokens.dark, 1).chartSeries, AppTokens.dark.chartSeries);
  });

  test('every family has a tile and an icon colour; the chart ramp has 4', () {
    for (final t in [AppTokens.light, AppTokens.dark]) {
      expect(t.tiles, hasLength(CategoryFamily.values.length));
      expect(t.tileIcons, hasLength(CategoryFamily.values.length));
      expect(t.chartSeries, hasLength(4));
    }
  });

  for (final (name, build, tokens) in [
    ('light', AppTheme.light, AppTokens.light),
    ('dark', AppTheme.dark, AppTokens.dark),
  ]) {
    testWidgets('$name theme carries its tokens and maps them onto the scheme', (tester) async {
      final theme = build();
      late AppTokens seen;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Builder(builder: (context) {
          seen = context.tokens;
          return const SizedBox();
        }),
      ));
      expect(seen.primary, tokens.primary);
      expect(theme.colorScheme.primary, tokens.primary);
      expect(theme.colorScheme.onPrimary, tokens.onPrimary);
      expect(theme.colorScheme.error, tokens.danger);
      expect(theme.scaffoldBackgroundColor, tokens.bg);
      // The legacy extension keeps its names but reads the new values.
      final semantic = theme.extension<AppSemanticColors>()!;
      expect(semantic.success, tokens.positive);
      expect(semantic.textMuted, tokens.muted);
    });
  }

  testWidgets('context.tokens falls back to light outside AppTheme', (tester) async {
    late AppTokens seen;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      seen = context.tokens;
      return const SizedBox();
    })));
    expect(seen.bg, AppTokens.light.bg);
  });
}
