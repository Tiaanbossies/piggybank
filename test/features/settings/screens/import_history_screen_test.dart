import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/features/imports/data/imports_api.dart';
import 'package:piggybank/features/imports/providers/imports_provider.dart';
import 'package:piggybank/features/settings/screens/import_history_screen.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);
  final List<ResponseBody Function()> responses;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final index = callCount < responses.length ? callCount : responses.length - 1;
    callCount++;
    return responses[index]();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, dynamic data) {
  return ResponseBody.fromString(jsonEncode(data), status, headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  });
}

ImportsApi _apiWith(_FakeAdapter adapter) {
  final client = ApiClient(
    baseUrl: 'https://api.test',
    getAccessToken: () => 'token',
    refreshAccessToken: () async => false,
    onSessionExpired: () {},
  );
  client.dio.httpClientAdapter = adapter;
  return ImportsApi(client);
}

void main() {
  group('ImportHistoryScreen', () {
    testWidgets('lists past imports with filename, row counts, and a status badge', (tester) async {
      final adapter = _FakeAdapter([
        () => _json(200, [
              {
                'id': 'j1',
                'filename': 'fnb_august.csv',
                'status': 'completed',
                'total_rows': 42,
                'imported_rows': 40,
                'failed_rows': 0,
                'auto_categorized_rows': 5,
                'duplicate_rows': 2,
                'error_message': null,
                'imported_balance': null,
                'created_at': '2026-08-01T00:00:00Z',
              },
            ]),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [importsApiProvider.overrideWithValue(_apiWith(adapter))],
          child: const MaterialApp(home: ImportHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('fnb_august.csv'), findsOneWidget);
      expect(find.textContaining('40 / 42'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    testWidgets('shows an empty state when there are no imports', (tester) async {
      final adapter = _FakeAdapter([() => _json(200, [])]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [importsApiProvider.overrideWithValue(_apiWith(adapter))],
          child: const MaterialApp(home: ImportHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No imports yet'), findsOneWidget);
    });
  });
}
