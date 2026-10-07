import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/assets/data/assets_api.dart';
import 'package:piggybank/features/assets/models/asset.dart';
import 'package:piggybank/features/assets/providers/assets_provider.dart';
import 'package:piggybank/features/savings/data/savings_api.dart';
import 'package:piggybank/features/savings/models/policy.dart';
import 'package:piggybank/features/savings/models/savings.dart';
import 'package:piggybank/features/savings/providers/savings_provider.dart';
import 'package:piggybank/features/savings/screens/policy_screen.dart';

import '../../test_helpers/pump_app.dart';

class _MockSavingsApi extends Mock implements SavingsApi {}

class _MockAssetsApi extends Mock implements AssetsApi {}

final _cost = RecurringCost(
  id: 'c1',
  name: 'Car insurance',
  kind: RecurringCostKind.insurance,
  monthlyAmount: Decimal.parse('500'),
  status: RecurringCostStatus.confirmed,
  decision: RecurringCostDecision.undecided,
  savedAmount: null,
  cutOn: null,
);

final _polo = Asset(
  id: 'a-car',
  assetType: AssetType.vehicle,
  name: 'Polo',
  currentValue: Decimal.parse('185000'),
  valuationDate: null,
  institutionName: null,
  notes: null,
);

final _house = Asset(
  id: 'a-house',
  assetType: AssetType.property,
  name: 'Flat',
  currentValue: Decimal.parse('1500000'),
  valuationDate: null,
  institutionName: null,
  notes: null,
);

final _policy = InsurancePolicy(
  id: 'p1',
  recurringCostId: 'c1',
  details: PolicyDetails(
    type: PolicyType.car,
    make: 'VW',
    model: 'Polo',
    year: 2019,
    coverType: CarCoverType.comprehensive,
    vehicleValue: Decimal.parse('200000'),
    assetId: 'a-car',
  ),
);

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late _MockSavingsApi api;
  late _MockAssetsApi assetsApi;

  setUpAll(() {
    registerFallbackValue(const PolicyDetails(type: PolicyType.life));
  });

  setUp(() {
    api = _MockSavingsApi();
    assetsApi = _MockAssetsApi();
    when(() => api.getPolicy(any())).thenAnswer((_) async => null);
    when(() => api.listRecurring()).thenAnswer((_) async => const []);
    when(() => assetsApi.list()).thenAnswer((_) async => [_polo, _house]);
  });

  Future<void> pump(WidgetTester tester) async {
    _useTallView(tester);
    await pumpApp(
      tester,
      PolicyScreen(cost: _cost),
      overrides: [
        savingsApiProvider.overrideWithValue(api),
        assetsApiProvider.overrideWithValue(assetsApi),
      ],
      useAppTheme: true,
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseType(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('policy-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  group('The form', () {
    testWidgets('starts with what the policy covers, then shows that type\'s fields', (tester) async {
      await pump(tester);
      expect(find.text('Add the policy details'), findsOneWidget);
      expect(find.byKey(const Key('policy-make')), findsNothing);

      await chooseType(tester, 'Car');
      expect(find.byKey(const Key('policy-make')), findsOneWidget);
      expect(find.byKey(const Key('policy-cover-type')), findsOneWidget);
      expect(find.byKey(const Key('policy-cover-amount')), findsNothing);

      await chooseType(tester, 'Life cover');
      expect(find.byKey(const Key('policy-cover-amount')), findsOneWidget);
      expect(find.byKey(const Key('policy-make')), findsNothing);
      expect(find.byKey(const Key('policy-asset')), findsNothing);
    });

    testWidgets('home contents offers no asset to link; building offers the property', (tester) async {
      await pump(tester);
      await chooseType(tester, 'Home contents');
      expect(find.byKey(const Key('policy-insured-value')), findsOneWidget);
      expect(find.byKey(const Key('policy-asset')), findsNothing);

      await chooseType(tester, 'Building');
      expect(find.byKey(const Key('policy-asset')), findsOneWidget);
    });

    testWidgets('saving without the make says so and sends nothing', (tester) async {
      await pump(tester);
      await chooseType(tester, 'Car');
      await tester.enterText(find.byKey(const Key('policy-model')), 'Polo');
      await tester.tap(find.byKey(const Key('policy-save')));
      await tester.pumpAndSettle();

      expect(find.text('Enter the make.'), findsOneWidget);
      verifyNever(() => api.putPolicy(any(), any()));
    });

    testWidgets('refuses a policy number before it leaves the phone', (tester) async {
      await pump(tester);
      await chooseType(tester, 'Life cover');
      await tester.enterText(find.byKey(const Key('policy-cover-amount')), '1000000');
      await tester.enterText(find.byKey(const Key('policy-insurer')), 'Policy 48213377');
      await tester.tap(find.byKey(const Key('policy-save')));
      await tester.pumpAndSettle();

      expect(find.text('Leave out ID, policy and account numbers.'), findsOneWidget);
      verifyNever(() => api.putPolicy(any(), any()));
    });

    testWidgets('linking the car fills in its value, and a full car policy is saved', (tester) async {
      when(() => api.putPolicy(any(), any())).thenAnswer((_) async => _policy);
      await pump(tester);
      await chooseType(tester, 'Car');

      await tester.tap(find.byKey(const Key('policy-asset')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Polo ·').last);
      await tester.pumpAndSettle();
      final value = tester.widget<TextField>(find.byKey(const Key('policy-vehicle-value')));
      expect(value.controller!.text, '185000');

      await tester.enterText(find.byKey(const Key('policy-make')), 'VW');
      await tester.enterText(find.byKey(const Key('policy-model')), 'Polo 1.0 TSI');
      await tester.enterText(find.byKey(const Key('policy-year')), '2019');
      await tester.tap(find.byKey(const Key('policy-cover-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comprehensive').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('policy-save')));
      await tester.pumpAndSettle();

      final sent = verify(() => api.putPolicy('c1', captureAny())).captured.single as PolicyDetails;
      expect(sent.type, PolicyType.car);
      expect(sent.make, 'VW');
      expect(sent.model, 'Polo 1.0 TSI');
      expect(sent.year, 2019);
      expect(sent.coverType, CarCoverType.comprehensive);
      expect(sent.assetId, 'a-car');
      expect(sent.vehicleValue, Decimal.parse('185000'));
      expect(find.text('Policy details saved.'), findsOneWidget);
    });

    testWidgets('a value already typed is kept when the car is linked', (tester) async {
      await pump(tester);
      await chooseType(tester, 'Car');
      await tester.enterText(find.byKey(const Key('policy-vehicle-value')), '210000');
      await tester.tap(find.byKey(const Key('policy-asset')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Polo ·').last);
      await tester.pumpAndSettle();

      final value = tester.widget<TextField>(find.byKey(const Key('policy-vehicle-value')));
      expect(value.controller!.text, '210000');
    });
  });

  group('The check card', () {
    testWidgets('hides the facts it could not work out instead of showing zero', (tester) async {
      when(() => api.getPolicy('c1')).thenAnswer((_) async => _policy);
      when(() => api.checkPolicy('p1')).thenAnswer((_) async => PolicyCheck(
            policyId: 'p1',
            policyType: PolicyType.car,
            monthlyPremium: Decimal.parse('500'),
            premiumPerYear: Decimal.parse('6000'),
          ));
      await pump(tester);

      expect(find.text('Policy check'), findsOneWidget);
      expect(find.text('Premium per year'), findsOneWidget);
      expect(find.text('R 6 000,00'), findsOneWidget);
      expect(find.text('Share of your income'), findsNothing);
      expect(find.text('Change in a year'), findsNothing);
      expect(find.textContaining('R 0,00'), findsNothing);
      expect(find.textContaining('shows once Piggybank knows your income'), findsOneWidget);
      // The saved details are in the form, ready to change.
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Remove policy details'), findsOneWidget);
    });

    testWidgets('lays out every fact with its explanation when the data is there', (tester) async {
      when(() => api.getPolicy('c1')).thenAnswer((_) async => _policy);
      when(() => api.checkPolicy('p1')).thenAnswer((_) async => PolicyCheck(
            policyId: 'p1',
            policyType: PolicyType.car,
            monthlyPremium: Decimal.parse('500'),
            premiumPerYear: Decimal.parse('6000'),
            coverValue: Decimal.parse('200000'),
            premiumPctOfCover: Decimal.parse('3.2'),
            assetValue: Decimal.parse('185000'),
            coverVsAsset: Decimal.parse('15000'),
            coverVsAssetPct: Decimal.parse('8.1'),
            coverPosition: CoverPosition.overInsured,
            premiumNow: Decimal.parse('500'),
            premiumYearAgo: Decimal.parse('444.44'),
            premiumYearAgoOn: DateTime(2025, 10, 1),
            premiumIncreasePct: Decimal.parse('12.5'),
            income: Decimal.parse('20000'),
            premiumPctOfIncome: Decimal.parse('2.5'),
          ));
      await pump(tester);

      expect(find.text('3,2%'), findsOneWidget);
      expect(find.text('R 15 000,00 more'), findsOneWidget);
      expect(find.text('Up 12,5%'), findsOneWidget);
      expect(find.text('2,5%'), findsOneWidget);
      expect(find.textContaining('R 444,44 on 1 Oct 2025'), findsOneWidget);
      expect(find.textContaining('not advice'), findsOneWidget);
      // Every fact was known, so nothing is asked for.
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('removing the details sends the delete', (tester) async {
      var policy = _policy as InsurancePolicy?;
      when(() => api.getPolicy('c1')).thenAnswer((_) async => policy);
      when(() => api.checkPolicy('p1')).thenAnswer((_) async => PolicyCheck(
            policyId: 'p1',
            policyType: PolicyType.car,
            monthlyPremium: Decimal.parse('500'),
            premiumPerYear: Decimal.parse('6000'),
          ));
      when(() => api.deletePolicy('c1')).thenAnswer((_) async => policy = null);
      await pump(tester);

      await tester.tap(find.text('Remove policy details'));
      await tester.pumpAndSettle();

      verify(() => api.deletePolicy('c1')).called(1);
      expect(find.text('Policy check'), findsNothing);
      expect(find.text('Add the policy details'), findsOneWidget);
    });
  });
}
