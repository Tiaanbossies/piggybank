import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/tfsa/models/tfsa_contribution.dart';
import 'package:piggybank/features/tfsa/models/tfsa_summary.dart';

/// Mirrors ticker_models_test.dart's group-per-model convention — exercises
/// the Decimal-as-JSON-number-or-string gotcha explicitly for both models.
void main() {
  group('TfsaContribution.fromJson', () {
    test('parses a numeric amount and all optional fields populated', () {
      final contribution = TfsaContribution.fromJson({
        'id': 'c1',
        'tax_year': 2026,
        'amount': 5000.50,
        'contribution_date': '2026-04-15',
        'notes': 'Monthly debit order',
        'ticker': 'STX40',
        'over_annual_limit_warning': false,
        'created_at': '2026-04-15T08:00:00Z',
        'updated_at': '2026-04-15T08:00:00Z',
      });
      expect(contribution.amount, Decimal.parse('5000.50'));
      expect(contribution.contributionDate, DateTime.parse('2026-04-15'));
      expect(contribution.notes, 'Monthly debit order');
      expect(contribution.ticker, 'STX40');
      expect(contribution.overAnnualLimitWarning, isFalse);
    });

    test('parses a stringified amount identically to numeric, with optional fields null', () {
      final contribution = TfsaContribution.fromJson({
        'id': 'c2',
        'tax_year': 2026,
        'amount': '36500.00',
        'contribution_date': null,
        'notes': null,
        'ticker': null,
        'over_annual_limit_warning': true,
        'created_at': '2026-04-15T08:00:00Z',
        'updated_at': '2026-04-15T08:00:00Z',
      });
      expect(contribution.amount, Decimal.parse('36500.00'));
      expect(contribution.contributionDate, isNull);
      expect(contribution.notes, isNull);
      expect(contribution.ticker, isNull);
      expect(contribution.overAnnualLimitWarning, isTrue);
    });
  });

  group('TfsaSummary.fromJson', () {
    test('parses a full summary with a by-year breakdown', () {
      final summary = TfsaSummary.fromJson({
        'lifetime_limit': 500000.00,
        'lifetime_contributed': '41500.50',
        'lifetime_remaining': 458499.50,
        'annual_limit': 36000.00,
        'current_year': 2026,
        'current_year_contributed': '5000.50',
        'current_year_remaining': 30999.50,
        'years_to_lifetime_limit': 13,
        'by_year': [
          {'tax_year': 2026, 'contributed': 5000.50, 'limit': 36000.00, 'over_limit': false},
          {'tax_year': 2025, 'contributed': '36500.00', 'limit': 36000.00, 'over_limit': true},
        ],
      });
      expect(summary.lifetimeLimit, Decimal.parse('500000.00'));
      expect(summary.lifetimeContributed, Decimal.parse('41500.50'));
      expect(summary.currentYear, 2026);
      expect(summary.yearsToLifetimeLimit, 13);
      expect(summary.byYear, hasLength(2));
      expect(summary.byYear[1].overLimit, isTrue);
    });

    test('parses a null years_to_lifetime_limit and an empty by_year list', () {
      final summary = TfsaSummary.fromJson({
        'lifetime_limit': 500000.00,
        'lifetime_contributed': 0,
        'lifetime_remaining': 500000.00,
        'annual_limit': 36000.00,
        'current_year': 2026,
        'current_year_contributed': 0,
        'current_year_remaining': 36000.00,
        'years_to_lifetime_limit': null,
        'by_year': [],
      });
      expect(summary.yearsToLifetimeLimit, isNull);
      expect(summary.byYear, isEmpty);
    });
  });
}
