import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/api/api_client.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/summaries/data/summaries_api.dart';
import 'package:piggybank/features/summaries/models/summaries.dart';

/// Canned-response fake adapter, mirrors
/// `test/features/chatbot/data/chatbot_api_test.dart`.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);
  final List<ResponseBody Function()> responses;
  int callCount = 0;
  final requestLog = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requestLog.add(options);
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

ApiClient _clientWith(_FakeAdapter adapter) {
  final client = ApiClient(
    baseUrl: 'https://api.test',
    getAccessToken: () => 'token',
    refreshAccessToken: () async => false,
    onSessionExpired: () {},
  );
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  group('monthKey', () {
    test('zero-pads the month', () {
      expect(monthKey(DateTime(2026, 1, 15)), '2026-01');
      expect(monthKey(DateTime(2026, 12, 1)), '2026-12');
    });
  });

  group('SummariesApi.budgetUsage', () {
    test('GETs /summaries/budget-usage with the month and parses the summary', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'budget_total': '5000.00',
              'actual_spend': '3250.50',
              'remaining': '1749.50',
              'percent_used': '65.01',
            }),
      ]);
      final api = SummariesApi(_clientWith(adapter));

      final usage = await api.budgetUsage(month: '2026-08');

      expect(adapter.requestLog.single.path, '/summaries/budget-usage');
      expect(adapter.requestLog.single.queryParameters['month'], '2026-08');
      expect(usage.budgetTotal, Decimal.parse('5000.00'));
      expect(usage.actualSpend, Decimal.parse('3250.50'));
      expect(usage.remaining, Decimal.parse('1749.50'));
      expect(usage.percentUsed, Decimal.parse('65.01'));
      expect(usage.hasBudget, isTrue);
    });

    test('a month with no budget parses as zeros, not an error', () async {
      final adapter = _FakeAdapter([
        () => _json(200, {
              'budget_total': '0.00',
              'actual_spend': '0.00',
              'remaining': '0.00',
              'percent_used': '0.00',
            }),
      ]);
      final api = SummariesApi(_clientWith(adapter));

      final usage = await api.budgetUsage(month: '2026-03');

      expect(usage.hasBudget, isFalse);
      expect(usage.budgetTotal, Decimal.zero);
    });

    test('converts a DioException into an ApiError', () async {
      final adapter = _FakeAdapter([() => _json(422, {'detail': 'month must be in YYYY-MM format'})]);
      final api = SummariesApi(_clientWith(adapter));

      await expectLater(
        api.budgetUsage(month: 'nope'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 422)),
      );
    });
  });

  group('SummariesApi.recurringExpenses', () {
    test('parses the list and defaults month to the current month', () async {
      final adapter = _FakeAdapter([
        () => _json(200, [
              {
                'category': 'Groceries',
                'occurrences': 3,
                'avg_amount': '1200.00',
                'total_amount': '3600.00',
                'last_date': '2026-08-20',
              },
            ]),
      ]);
      final api = SummariesApi(_clientWith(adapter));

      final recurring = await api.recurringExpenses();

      expect(adapter.requestLog.single.path, '/summaries/recurring-expenses');
      expect(adapter.requestLog.single.queryParameters['month'], currentMonthKey());
      expect(recurring, hasLength(1));
      expect(recurring.single.category, 'Groceries');
      expect(recurring.single.occurrences, 3);
      expect(recurring.single.avgAmount, Decimal.parse('1200.00'));
      expect(recurring.single.totalAmount, Decimal.parse('3600.00'));
      expect(recurring.single.lastDate, DateTime(2026, 8, 20));
    });

    test('passes an explicit month through when given', () async {
      final adapter = _FakeAdapter([() => _json(200, <dynamic>[])]);
      final api = SummariesApi(_clientWith(adapter));

      final recurring = await api.recurringExpenses(month: '2026-05');

      expect(adapter.requestLog.single.queryParameters['month'], '2026-05');
      expect(recurring, isEmpty);
    });

    test('converts a DioException into an ApiError', () async {
      final adapter = _FakeAdapter([() => _json(500, {'detail': 'boom'})]);
      final api = SummariesApi(_clientWith(adapter));

      await expectLater(api.recurringExpenses(), throwsA(isA<ApiError>()));
    });
  });

  group('SummariesApi.highCostExpenses', () {
    test('parses the list and sends month + top_n', () async {
      final adapter = _FakeAdapter([
        () => _json(200, [
              {
                'category': 'Rent',
                'count': 1,
                'total_amount': '9000.00',
                'max_single_amount': '9000.00',
                'avg_amount': '9000.00',
                'last_date': '2026-08-01',
              },
            ]),
      ]);
      final api = SummariesApi(_clientWith(adapter));

      final top = await api.highCostExpenses(month: '2026-08', topN: 3);

      expect(adapter.requestLog.single.path, '/summaries/high-cost-expenses');
      expect(adapter.requestLog.single.queryParameters['month'], '2026-08');
      expect(adapter.requestLog.single.queryParameters['top_n'], 3);
      expect(top.single.category, 'Rent');
      expect(top.single.count, 1);
      expect(top.single.maxSingleAmount, Decimal.parse('9000.00'));
    });

    test('converts a DioException into an ApiError', () async {
      final adapter = _FakeAdapter([() => _json(503, {'detail': 'down'})]);
      final api = SummariesApi(_clientWith(adapter));

      await expectLater(api.highCostExpenses(), throwsA(isA<ApiError>()));
    });
  });
}
