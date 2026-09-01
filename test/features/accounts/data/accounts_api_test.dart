import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/accounts/models/account.dart';

void main() {
  group('Account Model', () {
    test('can create account with all fields', () {
      final account = Account(
        id: 'acc-123',
        name: 'Checking',
        accountType: 'bank',
        currency: 'ZAR',
        balance: Decimal.fromInt(5000),
        isActive: true,
        institutionName: 'Test Bank',
      );

      expect(account.id, 'acc-123');
      expect(account.name, 'Checking');
      expect(account.accountType, 'bank');
      expect(account.currency, 'ZAR');
      expect(account.balance, Decimal.fromInt(5000));
      expect(account.isActive, true);
      expect(account.institutionName, 'Test Bank');
    });

    test('can create account without institution', () {
      final account = Account(
        id: 'acc-456',
        name: 'Savings',
        accountType: 'bank',
        currency: 'ZAR',
        balance: Decimal.fromInt(10000),
        isActive: true,
      );

      expect(account.id, 'acc-456');
      expect(account.institutionName, isNull);
    });

    test('can create inactive account', () {
      final account = Account(
        id: 'acc-789',
        name: 'Old Account',
        accountType: 'bank',
        currency: 'ZAR',
        balance: Decimal.zero,
        isActive: false,
      );

      expect(account.isActive, false);
    });

    test('fromJson parses account correctly', () {
      final json = {
        'id': 'acc-001',
        'name': 'Test Account',
        'account_type': 'bank',
        'currency': 'ZAR',
        'balance': '1500.50',
        'is_active': true,
        'institution_name': 'First Bank',
      };

      final account = Account.fromJson(json);

      expect(account.id, 'acc-001');
      expect(account.name, 'Test Account');
      expect(account.accountType, 'bank');
      expect(account.currency, 'ZAR');
      expect(account.balance, Decimal.parse('1500.50'));
      expect(account.isActive, true);
      expect(account.institutionName, 'First Bank');
    });

    test('fromJson handles null institution', () {
      final json = {
        'id': 'acc-002',
        'name': 'Another Account',
        'account_type': 'savings',
        'currency': 'ZAR',
        'balance': 2000,
        'is_active': true,
        'institution_name': null,
      };

      final account = Account.fromJson(json);

      expect(account.institutionName, isNull);
    });

    test('fromJson handles null balance as zero', () {
      final json = {
        'id': 'acc-003',
        'name': 'Empty Account',
        'account_type': 'bank',
        'currency': 'ZAR',
        'balance': null,
        'is_active': true,
      };

      final account = Account.fromJson(json);

      expect(account.balance, Decimal.zero);
    });

    test('account equality by field values', () {
      final acc1 = Account(
        id: 'acc-same',
        name: 'Same Account',
        accountType: 'bank',
        currency: 'ZAR',
        balance: Decimal.fromInt(1000),
        isActive: true,
      );

      final acc2 = Account(
        id: 'acc-same',
        name: 'Same Account',
        accountType: 'bank',
        currency: 'ZAR',
        balance: Decimal.fromInt(1000),
        isActive: true,
      );

      expect(acc1.id, acc2.id);
      expect(acc1.name, acc2.name);
      expect(acc1.balance, acc2.balance);
    });
  });
}
