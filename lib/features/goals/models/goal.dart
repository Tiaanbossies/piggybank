import 'package:decimal/decimal.dart';

enum GoalStatus { active, completed, paused }

GoalStatus goalStatusFromJson(String value) => GoalStatus.values.firstWhere((s) => s.name == value);

/// Mirrors `backend/app/goals/schemas.py`'s `GoalOut`.
class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.category,
    required this.status,
    required this.notes,
    required this.progressPct,
  });

  final String id;
  final String name;
  final Decimal targetAmount;
  final Decimal currentAmount;
  final DateTime? targetDate;
  final String? category;
  final GoalStatus status;
  final String? notes;
  final double progressPct;

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        name: json['name'] as String,
        targetAmount: Decimal.parse(json['target_amount'].toString()),
        currentAmount: Decimal.parse(json['current_amount'].toString()),
        targetDate: json['target_date'] == null ? null : DateTime.parse(json['target_date'] as String),
        category: json['category'] as String?,
        status: goalStatusFromJson(json['status'] as String),
        notes: json['notes'] as String?,
        progressPct: (json['progress_pct'] as num).toDouble(),
      );
}
