import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/assets/data/assets_api.dart';
import 'package:piggybank/features/assets/models/asset.dart';
import 'package:piggybank/features/assets/providers/assets_provider.dart';
import 'package:piggybank/features/assets/screens/assets_screen.dart';
import 'package:piggybank/shared/widgets/group_card.dart';
import 'package:piggybank/shared/widgets/hero_metric_card.dart';

import '../../../test_helpers/pump_app.dart';

class _MockAssetsApi extends Mock implements AssetsApi {}

Asset _asset({
  required String id,
  required AssetType assetType,
  required String name,
  required Decimal value,
  String? institutionName,
}) =>
    Asset(
      id: id,
      assetType: assetType,
      name: name,
      currentValue: value,
      valuationDate: null,
      institutionName: institutionName,
      notes: null,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(AssetType.cash);
  });

  group('AssetsScreen', () {
    testWidgets('renders a row per asset returned by the API', (tester) async {
      final mockApi = _MockAssetsApi();
      when(() => mockApi.list()).thenAnswer((_) async => [
            _asset(id: 'a1', assetType: AssetType.cash, name: 'Wallet', value: Decimal.fromInt(500)),
            _asset(id: 'a2', assetType: AssetType.property, name: 'Home', value: Decimal.fromInt(1500000)),
          ]);

      await pumpApp(
        tester,
        const AssetsScreen(),
        overrides: [assetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(GroupRow), findsNWidgets(2));
    });

    testWidgets('shows a Total assets hero card summing all asset values', (tester) async {
      final mockApi = _MockAssetsApi();
      when(() => mockApi.list()).thenAnswer((_) async => [
            _asset(id: 'a1', assetType: AssetType.cash, name: 'Wallet', value: Decimal.fromInt(500)),
            _asset(id: 'a2', assetType: AssetType.investment, name: 'Shares', value: Decimal.fromInt(1500)),
          ]);

      await pumpApp(
        tester,
        const AssetsScreen(),
        overrides: [assetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Total assets'), findsOneWidget);
      expect(find.byType(HeroMetricCard), findsOneWidget);
    });

    testWidgets('shows the empty state and no hero card when the API returns no assets', (tester) async {
      final mockApi = _MockAssetsApi();
      when(() => mockApi.list()).thenAnswer((_) async => []);

      await pumpApp(
        tester,
        const AssetsScreen(),
        overrides: [assetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('No assets yet.'), findsOneWidget);
      expect(find.byType(HeroMetricCard), findsNothing);
    });

    testWidgets('shows the error message when the API call fails', (tester) async {
      final mockApi = _MockAssetsApi();
      when(() => mockApi.list()).thenThrow(Exception('boom'));

      await pumpApp(
        tester,
        const AssetsScreen(),
        overrides: [assetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load assets'), findsOneWidget);
    });

    testWidgets('row subtitle includes the institution name only when present', (tester) async {
      final mockApi = _MockAssetsApi();
      when(() => mockApi.list()).thenAnswer((_) async => [
            _asset(id: 'a1', assetType: AssetType.savingsAccount, name: 'Notice deposit', value: Decimal.fromInt(50000), institutionName: 'Capitec'),
            _asset(id: 'a2', assetType: AssetType.cash, name: 'Wallet', value: Decimal.fromInt(500)),
          ]);

      await pumpApp(
        tester,
        const AssetsScreen(),
        overrides: [assetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Savings account · Capitec'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
    });
  });

  group('Asset type picker (add-asset sheet)', () {
    // Parametrized coverage of the enum-to-UI mapping: every AssetType must
    // appear as a selectable dropdown item labelled with its
    // assetTypeLabels entry, so the picker never silently drops a type.
    for (final type in AssetType.values) {
      testWidgets('offers "${assetTypeLabels[type]}" as a selectable option for $type', (tester) async {
        final mockApi = _MockAssetsApi();
        when(() => mockApi.list()).thenAnswer((_) async => []);

        await pumpApp(
          tester,
          const AssetsScreen(),
          overrides: [assetsApiProvider.overrideWithValue(mockApi)],
          useAppTheme: true,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add asset'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<AssetType>));
        await tester.pumpAndSettle();

        expect(find.text(assetTypeLabels[type]!).hitTestable(), findsWidgets);
      });
    }

    testWidgets('every AssetType.values entry is represented in the dropdown menu items', (tester) async {
      final mockApi = _MockAssetsApi();
      when(() => mockApi.list()).thenAnswer((_) async => []);

      await pumpApp(
        tester,
        const AssetsScreen(),
        overrides: [assetsApiProvider.overrideWithValue(mockApi)],
        useAppTheme: true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add asset'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<AssetType>));
      await tester.pumpAndSettle();

      final menuItems = tester.widgetList<DropdownMenuItem<AssetType>>(find.byType(DropdownMenuItem<AssetType>));
      final itemValues = menuItems.map((item) => item.value).toSet();
      expect(itemValues, AssetType.values.toSet());
    });
  });
}
