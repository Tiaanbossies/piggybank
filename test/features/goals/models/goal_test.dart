import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/goals/models/goal.dart';

void main() {
  group('goalStatusFromJson', () {
    test('maps each backend status string to its enum value', () {
      expect(goalStatusFromJson('active'), GoalStatus.active);
      expect(goalStatusFromJson('completed'), GoalStatus.completed);
      expect(goalStatusFromJson('paused'), GoalStatus.paused);
    });

    test('throws for an unrecognised status string', () {
      expect(() => goalStatusFromJson('archived'), throwsStateError);
    });
  });

  group('Goal.fromJson', () {
    test('parses a full active goal', () {
      final json = {
        'id': 'goal-1',
        'name': 'Emergency fund',
        'target_amount': '10000.00',
        'current_amount': '2500.00',
        'target_date': '2027-01-01',
        'category': 'Savings',
        'status': 'active',
        'notes': 'Six months of expenses',
        'progress_pct': 25.0,
      };

      final goal = Goal.fromJson(json);

      expect(goal.id, 'goal-1');
      expect(goal.name, 'Emergency fund');
      expect(goal.targetAmount, Decimal.parse('10000.00'));
      expect(goal.currentAmount, Decimal.parse('2500.00'));
      expect(goal.targetDate, DateTime.parse('2027-01-01'));
      expect(goal.category, 'Savings');
      expect(goal.status, GoalStatus.active);
      expect(goal.notes, 'Six months of expenses');
      expect(goal.progressPct, 25.0);
    });

    test('parses nullable fields as null when absent', () {
      final json = {
        'id': 'goal-2',
        'name': 'New laptop',
        'target_amount': '20000.00',
        'current_amount': '0',
        'target_date': null,
        'category': null,
        'status': 'active',
        'notes': null,
        'progress_pct': 0.0,
      };

      final goal = Goal.fromJson(json);

      expect(goal.targetDate, isNull);
      expect(goal.category, isNull);
      expect(goal.notes, isNull);
    });

    test('parses a completed goal', () {
      final json = {
        'id': 'goal-3',
        'name': 'Holiday',
        'target_amount': '5000.00',
        'current_amount': '5000.00',
        'target_date': null,
        'category': null,
        'status': 'completed',
        'notes': null,
        'progress_pct': 100.0,
      };

      final goal = Goal.fromJson(json);

      expect(goal.status, GoalStatus.completed);
      expect(goal.progressPct, 100.0);
    });

    test('parses progress_pct from an int JSON value', () {
      final json = {
        'id': 'goal-4',
        'name': 'Car',
        'target_amount': '100000',
        'current_amount': '50000',
        'target_date': null,
        'category': null,
        'status': 'active',
        'notes': null,
        'progress_pct': 50,
      };

      final goal = Goal.fromJson(json);

      expect(goal.progressPct, 50.0);
    });
  });
}
