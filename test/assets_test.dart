import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Visual rework Step 2: Penny ships only as the transparent cutouts in
/// assets/penny/, and the retired default pose is gone from the bundle.
void main() {
  test('pubspec bundles assets/penny/ and no mascot jpg', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final bundled = RegExp(r'^\s+- (assets/\S+)', multiLine: true).allMatches(pubspec).map((m) => m[1]!).toList();
    expect(bundled, contains('assets/penny/'));
    expect(bundled.where((p) => p.contains('mascot')), isEmpty);
    expect(File('assets/mascot.jpg').existsSync(), isFalse);
  });

  test('every pose the app names exists as a cutout', () {
    for (final pose in ['celebrating', 'thinking', 'sleeping', 'welcoming']) {
      expect(File('assets/penny/$pose.png').existsSync(), isTrue, reason: pose);
    }
  });

  test('no code or test points at the old jpgs', () {
    final offenders = <String>[];
    for (final dir in ['lib', 'test']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.endsWith('assets_test.dart')) continue;
        if (RegExp(r'mascot(_\w+)?\.jpg').hasMatch(f.readAsStringSync())) offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
