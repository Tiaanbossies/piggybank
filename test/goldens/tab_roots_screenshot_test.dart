// Golden screenshots of the five tab roots, light and dark, on sample data.
// Regenerate with: flutter test --update-goldens test/goldens/
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screenshot_harness.dart';

void main() {
  setUpAll(loadRealFonts);

  const names = ['home', 'transactions', 'plan', 'invest', 'penny'];
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (var i = 0; i < tabRoots.length; i++) {
      testWidgets('${names[i]} (${mode.name})', (tester) async {
        await pumpShell(tester, tabRoots[i], mode: mode);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('tab_roots/${names[i]}_${mode.name}.png'));
        endShot();
      });
    }
  }
}
