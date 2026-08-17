import 'package:decimal/decimal.dart';

/// Mirrors `backend/app/expenses/schemas.py`'s `CategoryBucket`.
class CategoryBucket {
  const CategoryBucket({required this.category, required this.total, required this.count});
  final String category;
  final Decimal total;
  final int count;

  factory CategoryBucket.fromJson(Map<String, dynamic> json) => CategoryBucket(
        category: json['category'] as String,
        total: Decimal.parse(json['total'].toString()),
        count: json['count'] as int,
      );
}

/// Mirrors `backend/app/expenses/schemas.py`'s `MonthBucket`.
class MonthBucket {
  const MonthBucket({required this.month, required this.total, required this.count});
  final String month;
  final Decimal total;
  final int count;

  factory MonthBucket.fromJson(Map<String, dynamic> json) => MonthBucket(
        month: json['month'] as String,
        total: Decimal.parse(json['total'].toString()),
        count: json['count'] as int,
      );
}

/// Mirrors `backend/app/expenses/schemas.py`'s `ExpensesSummary`.
class ExpensesSummary {
  const ExpensesSummary({required this.byCategory, required this.byMonth, required this.total});
  final List<CategoryBucket> byCategory;
  final List<MonthBucket> byMonth;
  final Decimal total;

  factory ExpensesSummary.fromJson(Map<String, dynamic> json) => ExpensesSummary(
        byCategory: (json['by_category'] as List).map((e) => CategoryBucket.fromJson(e as Map<String, dynamic>)).toList(),
        byMonth: (json['by_month'] as List).map((e) => MonthBucket.fromJson(e as Map<String, dynamic>)).toList(),
        total: Decimal.parse(json['total'].toString()),
      );
}
