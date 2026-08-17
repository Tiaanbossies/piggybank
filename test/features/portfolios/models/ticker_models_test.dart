import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/portfolios/models/ticker_history.dart';
import 'package:piggybank/features/portfolios/models/ticker_lookup.dart';
import 'package:piggybank/features/portfolios/models/ticker_search_result.dart';

/// Written first (TDD) per the approved Phase 4 plan's Stage 1 — exercises
/// the Decimal-as-JSON-number gotcha explicitly: a numeric price and a
/// stringified price must parse identically.
void main() {
  group('TickerLookup.fromJson', () {
    test('parses a numeric current_price and dividend_yield', () {
      final lookup = TickerLookup.fromJson({
        'ticker': 'AAPL',
        'name': 'Apple Inc.',
        'current_price': 227.5231,
        'expense_ratio': null,
        'fund_family': null,
        'inception_date': null,
        'fund_category': null,
        'dividend_yield': 0.0045,
      });
      expect(lookup.currentPrice, Decimal.parse('227.5231'));
      expect(lookup.dividendYield, Decimal.parse('0.0045'));
      expect(lookup.fundFamily, isNull);
    });

    test('parses a stringified current_price identically to numeric', () {
      final lookup = TickerLookup.fromJson({
        'ticker': 'AAPL',
        'name': 'Apple Inc.',
        'current_price': '227.5231',
        'expense_ratio': null,
        'fund_family': null,
        'inception_date': null,
        'fund_category': null,
        'dividend_yield': null,
      });
      expect(lookup.currentPrice, Decimal.parse('227.5231'));
      expect(lookup.dividendYield, isNull);
    });

    test('parses a fund with expense_ratio, fund_family, and inception_date populated', () {
      final lookup = TickerLookup.fromJson({
        'ticker': 'VOO',
        'name': 'Vanguard S&P 500 ETF',
        'current_price': 512.10,
        'expense_ratio': 0.03,
        'fund_family': 'Vanguard',
        'inception_date': '2010-09-07',
        'fund_category': 'Large Blend',
        'dividend_yield': 1.25,
      });
      expect(lookup.expenseRatio, Decimal.parse('0.03'));
      expect(lookup.fundFamily, 'Vanguard');
      expect(lookup.inceptionDate, DateTime.parse('2010-09-07'));
      expect(lookup.fundCategory, 'Large Blend');
    });
  });

  group('TickerSearchResult.fromJson', () {
    test('parses all fields', () {
      final result = TickerSearchResult.fromJson({
        'ticker': 'AAPL',
        'name': 'Apple Inc',
        'instrument_type': 'Common Stock',
        'exchange': 'NASDAQ',
      });
      expect(result.ticker, 'AAPL');
      expect(result.name, 'Apple Inc');
      expect(result.instrumentType, 'Common Stock');
      expect(result.exchange, 'NASDAQ');
    });
  });

  group('TickerHistory.fromJson', () {
    test('parses ticker/name/currency and a list of price points', () {
      final history = TickerHistory.fromJson({
        'ticker': 'AAPL',
        'name': 'Apple Inc.',
        'currency': 'USD',
        'data': [
          {'price_date': '2024-01-02', 'close': 185.64},
          {'price_date': '2024-01-03', 'close': '186.19'},
        ],
      });
      expect(history.ticker, 'AAPL');
      expect(history.currency, 'USD');
      expect(history.data, hasLength(2));
      expect(history.data[0].date, DateTime.parse('2024-01-02'));
      expect(history.data[0].close, Decimal.parse('185.64'));
      expect(history.data[1].close, Decimal.parse('186.19'));
    });

    test('parses an empty data list without throwing', () {
      final history = TickerHistory.fromJson({
        'ticker': 'ZZZ',
        'name': 'Unknown',
        'currency': 'USD',
        'data': [],
      });
      expect(history.data, isEmpty);
    });
  });
}
