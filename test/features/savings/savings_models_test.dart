import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/savings/models/savings.dart';

Map<String, dynamic> _overviewJson({Object? target, String leftOver = '7500.00'}) => {
      'target': target,
      'basis': 'full_months',
      'months_of_data': 2,
      'income': '20000.00',
      'income_is_override': false,
      'fixed_costs': '2000.00',
      'everyday_spending': '10500.00',
      'left_over': leftOver,
      'gap': target == null ? null : '1500.00',
      'target_met': false,
      'savings_found': '0.00',
      'confirmed_count': 2,
      'suggested_count': 1,
    };

const _targetJson = {
  'id': 't1',
  'label': null,
  'monthly_amount': '9000.00',
  'target_date': '2027-03-01',
  'income_override': '25000.00',
  'created_at': '2026-10-07T10:00:00Z',
  'updated_at': '2026-10-07T10:00:00Z',
};

void main() {
  test('overview parses every field', () {
    final o = SavingsOverview.fromJson(_overviewJson(target: _targetJson));
    expect(o.basis, OverviewBasis.fullMonths);
    expect(o.leftOver, Decimal.parse('7500'));
    expect(o.gap, Decimal.parse('1500'));
    expect(o.suggestedCount, 1);
    expect(o.target!.displayLabel, 'Savings target');
    expect(o.target!.targetDate, DateTime(2027, 3, 1));
    expect(o.target!.incomeOverride, Decimal.parse('25000'));
  });

  test('month_to_date basis parses', () {
    final json = _overviewJson()..['basis'] = 'month_to_date';
    expect(SavingsOverview.fromJson(json).basis, OverviewBasis.monthToDate);
  });

  test('progress is left over over target, clamped to 0..1', () {
    expect(SavingsOverview.fromJson(_overviewJson(target: _targetJson)).progress, closeTo(7500 / 9000, 1e-9));
    expect(SavingsOverview.fromJson(_overviewJson(target: _targetJson, leftOver: '-200.00')).progress, 0);
    expect(SavingsOverview.fromJson(_overviewJson(target: _targetJson, leftOver: '20000.00')).progress, 1);
    expect(SavingsOverview.fromJson(_overviewJson()).progress, 0);
  });

  test('recurring cost parses snake_case enums', () {
    final c = RecurringCost.fromJson(const {
      'id': 'c1',
      'name': 'Gym',
      'merchant_key': null,
      'kind': 'debit_order',
      'monthly_amount': '450.00',
      'source': 'manual',
      'status': 'confirmed',
      'decision': 'cut_candidate',
      'saved_amount': null,
      'cut_on': null,
      'last_seen_on': null,
      'created_at': '2026-10-07T10:00:00Z',
      'updated_at': '2026-10-07T10:00:00Z',
    });
    expect(c.kind, RecurringCostKind.debitOrder);
    expect(c.decision, RecurringCostDecision.cutCandidate);
    expect(c.savedAmount, isNull);
    // A backend from before detection sends neither field.
    expect(c.lastSeenOn, isNull);
    expect(c.stillCharged, isFalse);
    expect(c.isSuggestion, isFalse);
  });

  test('recurring cost parses detection fields', () {
    final c = RecurringCost.fromJson(const {
      'id': 'c2',
      'name': 'Showmax',
      'merchant_key': 'showmax',
      'kind': 'subscription',
      'monthly_amount': '99.00',
      'source': 'detected',
      'status': 'suggested',
      'decision': 'undecided',
      'saved_amount': null,
      'cut_on': null,
      'last_seen_on': '2026-10-02',
      'still_charged': true,
      'created_at': '2026-10-07T10:00:00Z',
      'updated_at': '2026-10-07T10:00:00Z',
    });
    expect(c.lastSeenOn, DateTime(2026, 10, 2));
    expect(c.stillCharged, isTrue);
    expect(c.isSuggestion, isTrue);
  });

  test('detect result parses', () {
    final r = DetectResult.fromJson(const {'suggested': 2, 'linked': 1, 'updated': 5});
    expect([r.suggested, r.linked, r.updated], [2, 1, 5]);
  });

  test('an unknown kind from a newer backend falls back to other', () {
    expect(RecurringCostKind.fromWire('gym_membership'), RecurringCostKind.other);
  });
}
