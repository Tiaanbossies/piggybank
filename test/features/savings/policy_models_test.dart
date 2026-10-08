import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/features/savings/models/policy.dart';
import 'package:piggybank/features/savings/models/savings.dart';
import 'package:piggybank/features/savings/screens/policy_screen.dart';

PolicyDetails _car({String make = 'VW', String model = 'Polo', int? year = 2019, String? insurer}) => PolicyDetails(
      type: PolicyType.car,
      make: make,
      model: model,
      year: year,
      coverType: CarCoverType.comprehensive,
      insurer: insurer,
      assetId: 'a-car',
      vehicleValue: Decimal.parse('185000'),
    );

PolicyCheck _check({
  PolicyType type = PolicyType.car,
  CoverPosition? position,
  String? cover,
  String? asset,
  String? diff,
}) =>
    PolicyCheck(
      policyId: 'p1',
      policyType: type,
      monthlyPremium: Decimal.parse('500'),
      premiumPerYear: Decimal.parse('6000'),
      coverValue: cover == null ? null : Decimal.parse(cover),
      assetValue: asset == null ? null : Decimal.parse(asset),
      coverVsAsset: diff == null ? null : Decimal.parse(diff),
      coverPosition: position,
    );

void main() {
  group('PolicyDetails.toJson', () {
    test('sends only the fields the type takes', () {
      final json = _car().toJson();
      expect(json['policy_type'], 'car');
      expect(json['cover_type'], 'comprehensive');
      expect(json['vehicle_value'], '185000');
      expect(json['asset_id'], 'a-car');
      expect(json.containsKey('cover_amount'), isFalse);
      expect(json.containsKey('plan_name'), isFalse);
    });

    test('home contents takes no asset link', () {
      final json = PolicyDetails(type: PolicyType.homeContents, insuredValue: Decimal.fromInt(80000), assetId: 'h')
          .toJson();
      expect(json.containsKey('asset_id'), isFalse);
      expect(json['insured_value'], '80000');
    });

    test('life cover sends its cover amount and nothing of a car', () {
      final json = PolicyDetails(type: PolicyType.life, coverAmount: Decimal.fromInt(1000000)).toJson();
      expect(json['cover_amount'], '1000000');
      expect(json.containsKey('make'), isFalse);
    });
  });

  group('PolicyDetails.problem', () {
    test('names what each type is missing', () {
      expect(const PolicyDetails(type: PolicyType.car, model: 'Polo').problem, 'Enter the make.');
      expect(_car(year: null).problem, 'Enter the year it was made.');
      expect(_car(year: 1900).problem, 'Enter the year it was made.');
      expect(const PolicyDetails(type: PolicyType.building).problem, "Enter the amount it's insured for.");
      expect(const PolicyDetails(type: PolicyType.funeral).problem, 'Enter the cover amount.');
      expect(const PolicyDetails(type: PolicyType.gapCover).problem, 'Enter the plan name.');
      expect(_car().problem, isNull);
    });

    test('refuses ID, policy and account numbers', () {
      expect(_car(insurer: 'Outsurance 9001015009087').problem, 'Leave out ID, policy and account numbers.');
      expect(_car(model: 'Polo 900101 5009 087').problem, 'Leave out ID, policy and account numbers.');
      expect(_car(insurer: 'Policy 48213377').problem, 'Leave out ID, policy and account numbers.');
      // Short numbers in a model name are fine.
      expect(_car(model: 'Polo 1.0 TSI 2019').problem, isNull);
    });
  });

  test('PolicyCheck.fromJson keeps missing facts null', () {
    final check = PolicyCheck.fromJson({
      'policy_id': 'p1',
      'policy_type': 'car',
      'monthly_premium': '500.00',
      'premium_per_year': '6000.00',
      'cover_value': '200000.00',
      'premium_pct_of_cover': '3.0',
      'asset_value': null,
      'asset_valued_on': null,
      'cover_vs_asset': null,
      'cover_vs_asset_pct': null,
      'cover_position': null,
      'premium_now': null,
      'premium_year_ago': null,
      'premium_year_ago_on': null,
      'premium_increase_pct': null,
      'income': null,
      'premium_pct_of_income': null,
    });
    expect(check.premiumPerYear, Decimal.parse('6000'));
    expect(check.premiumPctOfCover, Decimal.parse('3'));
    expect(check.assetValue, isNull);
    expect(check.coverPosition, isNull);
    expect(check.income, isNull);
  });

  test('RecurringCost.fromJson reads the attached policy', () {
    final cost = RecurringCost.fromJson({
      'id': 'c1',
      'name': 'Car insurance',
      'kind': 'insurance',
      'monthly_amount': '500.00',
      'status': 'confirmed',
      'decision': 'undecided',
      'saved_amount': null,
      'cut_on': null,
      'policy_id': 'p1',
    });
    expect(cost.policyId, 'p1');
  });

  group('policyFacts', () {
    test('a car insured above its value is flagged for attention', () {
      final facts = policyFacts(_check(
        position: CoverPosition.overInsured,
        cover: '200000',
        asset: '185000',
        diff: '15000',
      ));
      final fact = facts.firstWhere((f) => f.label == 'Cover against car value');
      expect(fact.value, 'R\u00A015\u00A0000,00 more');
      expect(fact.tone, FactTone.attention);
    });

    test('a building gap is stated, not flagged: market value includes the land', () {
      final facts = policyFacts(_check(
        type: PolicyType.building,
        position: CoverPosition.underInsured,
        cover: '1200000',
        asset: '1500000',
        diff: '-300000',
      ));
      final fact = facts.firstWhere((f) => f.label == 'Cover against property value');
      expect(fact.value, 'R\u00A0300\u00A0000,00 less');
      expect(fact.tone, FactTone.neutral);
      expect(fact.note, contains('cost to rebuild'));
    });

    test('only the premium a year when nothing else is known, never a zero', () {
      final facts = policyFacts(_check());
      expect(facts.map((f) => f.label), ['Premium per year']);
      expect(facts.single.value, 'R\u00A06\u00A0000,00');
    });
  });

  group('missingFactHints', () {
    test('asks for the car value before the asset link', () {
      expect(missingFactHints(_check()).first, contains("car's insured value"));
      expect(missingFactHints(_check(cover: '200000')).first, contains('Link the car'));
    });

    test('cover with no asset to link asks only for history and income', () {
      final hints = missingFactHints(_check(type: PolicyType.life, cover: '1000000'));
      expect(hints, hasLength(2));
      expect(hints.any((h) => h.contains('Assets')), isFalse);
    });
  });
}
