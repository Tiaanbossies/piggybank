// The visual spec's contrast table (docs/visual-rework/04-visual-spec.md
// §1.4) as a test over the real tokens, so a changed hex that breaks WCAG AA
// fails here instead of on someone's phone. Floors: 4.5:1 for text, 3:1 for
// UI parts and large figures (WCAG 1.4.3, 1.4.11).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/theme/app_tokens.dart';

double _channel(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) => 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const _text = 4.5;
const _ui = 3.0;

/// (label, foreground, background, floor) for one theme.
List<(String, Color, Color, double)> pairs(AppTokens t, {required bool dark}) => [
      ('ink on bg', t.ink, t.bg, _text),
      ('ink on surface', t.ink, t.surface, _text),
      ('muted on bg', t.muted, t.bg, _text),
      ('muted on surface', t.muted, t.surface, _text),
      ('muted on sunk', t.muted, t.sunk, _text),
      ('onPrimary on primary', t.onPrimary, t.primary, _text),
      ('primary on surface', t.primary, t.surface, _text),
      ('primary on bg', t.primary, t.bg, _text),
      ('onPrimaryContainer on primaryContainer', t.onPrimaryContainer, t.primaryContainer, _text),
      ('positive on surface', t.positive, t.surface, _text),
      ('danger on surface', t.danger, t.surface, _text),
      ('danger on bg', t.danger, t.bg, _text),
      ('onDangerContainer on dangerContainer', t.onDangerContainer, t.dangerContainer, _text),
      ('hero figure on hero', t.heroInk, t.hero, _text),
      ('hero secondary on hero', t.heroSecondary, t.hero, _text),
      ('danger on hero', t.danger, t.hero, _text),
      ('positive on hero', t.positive, t.hero, _text),
      if (dark) ('ink on surfaceRaised', t.ink, t.surfaceRaised, _text),
      if (dark) ('muted on surfaceRaised', t.muted, t.surfaceRaised, _text),
      ('hero bar on track', t.heroBar, t.heroTrack, _ui),
      ('hero bar on hero', t.heroBar, t.hero, _ui),
      ('outline on surface', t.outline, t.surface, _ui),
      ('primary on primaryContainer', t.primary, t.primaryContainer, _ui),
      ('focus ring on bg', t.primary, t.bg, _ui),
      for (final f in CategoryFamily.values) ('${f.name} icon on tile', t.categoryIcon(f), t.categoryTile(f), _ui),
      for (var i = 0; i < t.chartSeries.length; i++) ('chart series $i on surface', t.chartSeries[i], t.surface, _ui),
    ];

void main() {
  for (final (name, tokens, dark) in [('light', AppTokens.light, false), ('dark', AppTokens.dark, true)]) {
    group('$name theme meets WCAG AA', () {
      for (final (label, fg, bg, floor) in pairs(tokens, dark: dark)) {
        test(label, () {
          final ratio = contrast(fg, bg);
          expect(ratio, greaterThanOrEqualTo(floor), reason: '$label is ${ratio.toStringAsFixed(2)}:1, floor $floor');
        });
      }
    });
  }

  test('the formula matches the spec\'s measured values', () {
    // Spec §1.4: ink on bg 15.23, white on primary 8.01, hero figure 10.22.
    expect(contrast(AppTokens.light.ink, AppTokens.light.bg), closeTo(15.23, 0.02));
    expect(contrast(AppTokens.light.onPrimary, AppTokens.light.primary), closeTo(8.01, 0.02));
    expect(contrast(AppTokens.light.heroInk, AppTokens.light.hero), closeTo(10.22, 0.02));
  });
}
