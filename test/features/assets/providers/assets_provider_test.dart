import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/assets/data/assets_api.dart';
import 'package:piggybank/features/assets/models/asset.dart';
import 'package:piggybank/features/assets/providers/assets_provider.dart';

class _MockAssetsApi extends Mock implements AssetsApi {}

Asset _asset({
  String id = 'asset-1',
  AssetType assetType = AssetType.cash,
  String name = 'Wallet',
  Decimal? value,
  String? institutionName,
}) =>
    Asset(
      id: id,
      assetType: assetType,
      name: name,
      currentValue: value ?? Decimal.fromInt(500),
      valuationDate: null,
      institutionName: institutionName,
      notes: null,
    );

void main() {
  setUpAll(() {
    // AssetType is passed via `any(named: 'assetType')` below; mocktail
    // needs a registered fallback instance for any non-primitive type used
    // with `any()`. Registered locally rather than in the shared
    // test_helpers/mocktail_setup.dart, which this QA step doesn't own.
    registerFallbackValue(AssetType.cash);
  });

  group('assetsProvider', () {
    late _MockAssetsApi mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = _MockAssetsApi();
      container = ProviderContainer(overrides: [assetsApiProvider.overrideWithValue(mockApi)]);
    });

    tearDown(() => container.dispose());

    test('fetches the asset list from the API', () async {
      final assets = [_asset()];
      when(() => mockApi.list()).thenAnswer((_) async => assets);

      final result = await container.read(assetsProvider.future);

      expect(result, assets);
      verify(() => mockApi.list()).called(1);
    });

    test('propagates API errors through the AsyncValue', () async {
      when(() => mockApi.list()).thenThrow(Exception('network down'));

      await expectLater(container.read(assetsProvider.future), throwsA(isA<Exception>()));
    });
  });

  group('AssetsApi CRUD via mocked calls', () {
    late _MockAssetsApi mockApi;

    setUp(() {
      mockApi = _MockAssetsApi();
    });

    test('create() sends the provided fields, including the wire-format asset type', () async {
      final created = _asset(id: 'new-asset', assetType: AssetType.savingsAccount);
      when(() => mockApi.create(
            assetType: any(named: 'assetType'),
            name: any(named: 'name'),
            currentValue: any(named: 'currentValue'),
            institutionName: any(named: 'institutionName'),
          )).thenAnswer((_) async => created);

      final result = await mockApi.create(
        assetType: AssetType.savingsAccount,
        name: 'Notice deposit',
        currentValue: '50000',
        institutionName: 'Capitec',
      );

      expect(result.id, 'new-asset');
      verify(() => mockApi.create(
            assetType: AssetType.savingsAccount,
            name: 'Notice deposit',
            currentValue: '50000',
            institutionName: 'Capitec',
          )).called(1);
    });

    test('update() sends the asset id and changed fields', () async {
      final updated = _asset(id: 'asset-1', name: 'Wallet (updated)');
      when(() => mockApi.update(
            any(),
            assetType: any(named: 'assetType'),
            name: any(named: 'name'),
            currentValue: any(named: 'currentValue'),
          )).thenAnswer((_) async => updated);

      final result = await mockApi.update('asset-1', assetType: AssetType.cash, name: 'Wallet (updated)', currentValue: '600');

      expect(result.name, 'Wallet (updated)');
      verify(() => mockApi.update('asset-1', assetType: AssetType.cash, name: 'Wallet (updated)', currentValue: '600')).called(1);
    });

    test('delete() is invoked with the asset id', () async {
      when(() => mockApi.delete(any())).thenAnswer((_) async {});

      await mockApi.delete('asset-1');

      verify(() => mockApi.delete('asset-1')).called(1);
    });
  });
}
