import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/imports/models/import_job.dart';
import 'package:piggybank/shared/widgets/status_badge.dart';

void main() {
  group('StatusBadge', () {
    for (final status in ImportStatus.values) {
      testWidgets('renders the uppercased label for ${status.name}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: StatusBadge(status: status))),
        );

        expect(find.text(status.name.toUpperCase()), findsOneWidget);
      });
    }
  });
}
