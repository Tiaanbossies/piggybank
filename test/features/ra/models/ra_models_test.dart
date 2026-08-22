import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/ra/models/ra_contribution.dart';
import 'package:piggybank/features/ra/models/ra_summary.dart';

/// Mirrors tfsa_models_test.dart's group-per-model convention — exercises
/// the Decimal-as-JSON-number-or-string gotcha explicitly for both models,
/// and confirms RA's `provider` field / lack of lifetime fields vs TFSA.
void main() {
  group('RaContribution.fromJson', () {
    test('parses a numeric amount and all optional fields populated', () {
      final contribution = RaContribution.fromJson({
        'id': 'c1',
        'tax_year': 2026,
        'amount': 5000.50,
        'contribution_date': '2026-04-15',
        'notes': 'Monthly debit order',
        'provider': 'Allan Gray',
        'over_annual_limit_warning': false,
        'created_at': '2026-04-15T08:00:00Z',
        'updated_at': '2026-04-15T08:00:00Z',
      });
      expect(contribution.amount, Decimal.parse('5000.50'));
      expect(contribution.contributionDate, DateTime.parse('2026-04-15'));
      expect(contribution.notes, 'Monthly debit order');
      expect(contribution.provider, 'Allan Gray');
      expect(contribution.overAnnualLimitWarning, isFalse);
    });

    test('parses a stringified amount identically to numeric, with optional fields null', () {
      final contribution = RaContribution.fromJson({
        'id': 'c2',
        'tax_year': 2026,
        'amount': '40000.00',
        'contribution_date': null,
        'notes': null,
        'provider': null,
        'over_annual_limit_warning': true,
        'created_at': '2026-04-15T08:00:00Z',
        'updated_at': '2026-04-15T08:00:00Z',
      });
      expect(contribution.amount, Decimal.parse('40000.00'));
      expect(contribution.contributionDate, isNull);
      expect(contribution.notes, isNull);
      expect(contribution.provider, isNull);
      expect(contribution.overAnnualLimitWarning, isTrue);
    });
  });

  group('RaSummary.fromJson', () {
    test('parses a full summary with a by-year breakdown, no lifetime fields', () {
      final summary = RaSummary.fromJson({
        'annual_limit': 36000.00,
        'total_contributed': '41500.50',
        'current_year': 2026,
        'current_year_contributed': '5000.50',
        'current_year_remaining': 30999.50,
        'by_year': [
          {'tax_year': 2026, 'contributed': 5000.50, 'limit': 36000.00, 'over_limit': false},
          {'tax_year': 2025, 'contributed': '40000.00', 'limit': 36000.00, 'over_limit': true},
        ],
      });
      expect(summary.annualLimit, Decimal.parse('36000.00'));
      expect(summary.totalContributed, Decimal.parse('41500.50'));
      expect(summary.currentYear, 2026);
      expect(summary.byYear, hasLength(2));
      expect(summary.byYear[1].overLimit, isTrue);
    });

    test('parses an empty by_year list', () {
      final summary = RaSummary.fromJson({
        'annual_limit': 36000.00,
        'total_contributed': 0,
        'current_year': 2026,
        'current_year_contributed': 0,
        'current_year_remaining': 36000.00,
        'by_year': [],
      });
      expect(summary.byYear, isEmpty);
    });
  });
}
