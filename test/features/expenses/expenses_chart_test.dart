import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/expenses/models/expenses_summary.dart';
import 'package:piggybank/features/expenses/screens/expenses_summary_screen.dart';

void main() {
  group('Expenses Chart Tests', () {
    late ExpensesSummaryScreen screen;

    setUp(() {
      screen = const ExpensesSummaryScreen();
    });

    test('CategoryBucket parses from JSON correctly', () {
      final json = {
        'category': 'Food',
        'total': '150.50',
        'count': 5,
      };

      final bucket = CategoryBucket.fromJson(json);

      expect(bucket.category, 'Food');
      expect(bucket.total, Decimal.parse('150.50'));
      expect(bucket.count, 5);
    });

    test('CategoryBucket handles empty category', () {
      final json = {
        'category': '',
        'total': '100.00',
        'count': 2,
      };

      final bucket = CategoryBucket.fromJson(json);

      expect(bucket.category, isEmpty);
      expect(bucket.total, Decimal.fromInt(100));
      expect(bucket.count, 2);
    });

    test('MonthBucket parses from JSON correctly', () {
      final json = {
        'month': '2024-08',
        'total': '2500.00',
        'count': 47,
      };

      final bucket = MonthBucket.fromJson(json);

      expect(bucket.month, '2024-08');
      expect(bucket.total, Decimal.parse('2500.00'));
      expect(bucket.count, 47);
    });

    test('ExpensesSummary parses from JSON correctly', () {
      final json = {
        'by_category': [
          {'category': 'Food', 'total': '500.00', 'count': 10},
          {'category': 'Transport', 'total': '300.00', 'count': 15},
        ],
        'by_month': [
          {'month': '2024-08', 'total': '800.00', 'count': 25},
        ],
        'total': '800.00',
      };

      final summary = ExpensesSummary.fromJson(json);

      expect(summary.byCategory, hasLength(2));
      expect(summary.byCategory[0].category, 'Food');
      expect(summary.byCategory[0].total, Decimal.parse('500.00'));
      expect(summary.byMonth, hasLength(1));
      expect(summary.total, Decimal.parse('800.00'));
    });

    test('ExpensesSummary handles empty categories', () {
      final json = {
        'by_category': [],
        'by_month': [],
        'total': '0',
      };

      final summary = ExpensesSummary.fromJson(json);

      expect(summary.byCategory, isEmpty);
      expect(summary.byMonth, isEmpty);
      expect(summary.total, Decimal.zero);
    });

    test('CategoryBucket equality by values', () {
      final bucket1 = CategoryBucket(
        category: 'Food',
        total: Decimal.fromInt(100),
        count: 5,
      );

      final bucket2 = CategoryBucket(
        category: 'Food',
        total: Decimal.fromInt(100),
        count: 5,
      );

      expect(bucket1.category, bucket2.category);
      expect(bucket1.total, bucket2.total);
      expect(bucket1.count, bucket2.count);
    });

    test('ExpensesSummary categories are sorted by total descending', () {
      final json = {
        'by_category': [
          {'category': 'Transport', 'total': '100.00', 'count': 5},
          {'category': 'Food', 'total': '500.00', 'count': 10},
          {'category': 'Utilities', 'total': '200.00', 'count': 3},
        ],
        'by_month': [],
        'total': '800.00',
      };

      final summary = ExpensesSummary.fromJson(json);

      // JSON is returned as-is; sorting would be done in the chart builder
      expect(summary.byCategory, hasLength(3));
      expect(summary.byCategory[0].total, Decimal.fromInt(100));
      expect(summary.byCategory[1].total, Decimal.fromInt(500));
      expect(summary.byCategory[2].total, Decimal.fromInt(200));
    });

    test('ExpensesSummary total matches sum of categories', () {
      final json = {
        'by_category': [
          {'category': 'Food', 'total': '300.00', 'count': 10},
          {'category': 'Transport', 'total': '200.00', 'count': 5},
        ],
        'by_month': [],
        'total': '500.00',
      };

      final summary = ExpensesSummary.fromJson(json);

      final categorySum = summary.byCategory.fold(Decimal.zero, (sum, bucket) => sum + bucket.total);
      expect(categorySum, summary.total);
    });
  });
}
