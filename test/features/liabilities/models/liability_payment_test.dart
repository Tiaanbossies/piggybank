import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/liabilities/models/liability_payment.dart';

/// Mirrors ra_models_test.dart's group-per-model convention — exercises the
/// Decimal-as-JSON-number-or-string gotcha, and the nullable
/// `original_balance`/`projected_payoff_date` fallback case (a liability
/// created without loan params).
void main() {
  group('LiabilityPayment.fromJson', () {
    test('parses a numeric amount and notes populated', () {
      final payment = LiabilityPayment.fromJson({
        'id': 'p1',
        'liability_id': 'l1',
        'payment_date': '2026-05-01',
        'amount': 2500.00,
        'principal_portion': 2000.00,
        'interest_portion': 500.00,
        'notes': 'Extra payment',
        'created_at': '2026-05-01T08:00:00Z',
      });
      expect(payment.amount, Decimal.parse('2500.00'));
      expect(payment.principalPortion, Decimal.parse('2000.00'));
      expect(payment.interestPortion, Decimal.parse('500.00'));
      expect(payment.notes, 'Extra payment');
      expect(payment.paymentDate, DateTime.parse('2026-05-01'));
    });

    test('parses stringified amounts identically to numeric, with notes null', () {
      final payment = LiabilityPayment.fromJson({
        'id': 'p2',
        'liability_id': 'l1',
        'payment_date': '2026-06-01',
        'amount': '2643.01',
        'principal_portion': '1893.01',
        'interest_portion': '750.00',
        'notes': null,
        'created_at': '2026-06-01T08:00:00Z',
      });
      expect(payment.amount, Decimal.parse('2643.01'));
      expect(payment.notes, isNull);
    });
  });

  group('LiabilityProgress.fromJson', () {
    test('parses a full progress payload with a projected payoff date', () {
      final progress = LiabilityProgress.fromJson({
        'liability_id': 'l1',
        'original_balance': 200000.00,
        'current_balance': '198000.00',
        'total_principal_paid': '2000.00',
        'total_interest_paid': '500.00',
        'percent_paid': 1.00,
        'payment_count': 1,
        'projected_payoff_date': '2031-01-01',
      });
      expect(progress.originalBalance, Decimal.parse('200000.00'));
      expect(progress.percentPaid, Decimal.parse('1.00'));
      expect(progress.paymentCount, 1);
      expect(progress.projectedPayoffDate, DateTime.parse('2031-01-01'));
    });

    test('parses the no-loan-params fallback (null original_balance and projected_payoff_date)', () {
      final progress = LiabilityProgress.fromJson({
        'liability_id': 'l2',
        'original_balance': null,
        'current_balance': '5000.00',
        'total_principal_paid': 0,
        'total_interest_paid': 0,
        'percent_paid': 0,
        'payment_count': 0,
        'projected_payoff_date': null,
      });
      expect(progress.originalBalance, isNull);
      expect(progress.projectedPayoffDate, isNull);
      expect(progress.paymentCount, 0);
    });
  });
}
