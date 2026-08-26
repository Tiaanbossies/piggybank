import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/assets/models/asset.dart';

void main() {
  group('AssetType enum-to-JSON mapping', () {
    // Parametrized coverage of every AssetType value: the backend uses a
    // snake_case wire format (only `savings_account` differs from the Dart
    // enum name's obvious .name mapping) and a matching UI label. Verifies
    // fromJson/toJson round-trip and the label table for each type.
    final cases = <AssetType, String>{
      AssetType.cash: 'cash',
      AssetType.savingsAccount: 'savings_account',
      AssetType.property: 'property',
      AssetType.vehicle: 'vehicle',
      AssetType.investment: 'investment',
      AssetType.retirement: 'retirement',
      AssetType.other: 'other',
    };

    for (final entry in cases.entries) {
      test('${entry.key} <-> "${entry.value}" round-trips through toJson/fromJson', () {
        expect(assetTypeToJson(entry.key), entry.value);
        expect(assetTypeFromJson(entry.value), entry.key);
      });

      test('${entry.key} has a non-empty UI label', () {
        expect(assetTypeLabels[entry.key], isNotNull);
        expect(assetTypeLabels[entry.key], isNotEmpty);
      });
    }

    test('assetTypeLabels covers every AssetType value with no gaps', () {
      expect(assetTypeLabels.keys.toSet(), AssetType.values.toSet());
    });

    test('assetTypeFromJson falls back to AssetType.other for an unknown wire value', () {
      expect(assetTypeFromJson('cryptocurrency'), AssetType.other);
    });

    test('the savings_account wire value is the only asset type that departs from .name', () {
      for (final type in AssetType.values) {
        if (type == AssetType.savingsAccount) {
          expect(assetTypeToJson(type), isNot(type.name));
        } else {
          expect(assetTypeToJson(type), type.name);
        }
      }
    });
  });

  group('Asset.fromJson', () {
    test('parses a full asset', () {
      final json = {
        'id': 'asset-1',
        'asset_type': 'property',
        'name': 'Home',
        'current_value': '1500000.00',
        'valuation_date': '2026-01-15',
        'institution_name': null,
        'notes': 'Primary residence',
      };

      final asset = Asset.fromJson(json);

      expect(asset.id, 'asset-1');
      expect(asset.assetType, AssetType.property);
      expect(asset.name, 'Home');
      expect(asset.currentValue, Decimal.parse('1500000.00'));
      expect(asset.valuationDate, DateTime.parse('2026-01-15'));
      expect(asset.institutionName, isNull);
      expect(asset.notes, 'Primary residence');
    });

    test('parses a savings account asset with the snake_case wire type', () {
      final json = {
        'id': 'asset-2',
        'asset_type': 'savings_account',
        'name': 'Notice deposit',
        'current_value': '50000',
        'valuation_date': null,
        'institution_name': 'Capitec',
        'notes': null,
      };

      final asset = Asset.fromJson(json);

      expect(asset.assetType, AssetType.savingsAccount);
      expect(asset.institutionName, 'Capitec');
      expect(asset.valuationDate, isNull);
    });

    test('parses current_value from a numeric JSON value', () {
      final json = {
        'id': 'asset-3',
        'asset_type': 'cash',
        'name': 'Wallet',
        'current_value': 500,
        'valuation_date': null,
        'institution_name': null,
        'notes': null,
      };

      final asset = Asset.fromJson(json);

      expect(asset.currentValue, Decimal.fromInt(500));
    });
  });
}
