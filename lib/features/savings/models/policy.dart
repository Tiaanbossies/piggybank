import 'package:decimal/decimal.dart';

import '../../assets/models/asset.dart';

/// Which detail fields a policy type's form shows.
enum PolicyForm { car, property, cover, plan }

/// Mirrors `backend/app/models.py`'s `InsurancePolicyType`.
enum PolicyType {
  car('car', 'Car', PolicyForm.car, AssetType.vehicle),
  homeContents('home_contents', 'Home contents', PolicyForm.property, null),
  building('building', 'Building', PolicyForm.property, AssetType.property),
  life('life', 'Life cover', PolicyForm.cover, null),
  funeral('funeral', 'Funeral cover', PolicyForm.cover, null),
  disability('disability', 'Disability cover', PolicyForm.cover, null),
  medicalAid('medical_aid', 'Medical aid', PolicyForm.plan, null),
  gapCover('gap_cover', 'Gap cover', PolicyForm.plan, null);

  const PolicyType(this.wire, this.label, this.form, this.assetType);
  final String wire;
  final String label;
  final PolicyForm form;

  /// The kind of asset this cover may link to, or null when it takes none.
  /// Home contents takes none: its sum insured isn't comparable with the
  /// house's value.
  final AssetType? assetType;

  static PolicyType fromWire(String value) => values.firstWhere((t) => t.wire == value);
}

/// Mirrors `backend/app/models.py`'s `CarCoverType`.
enum CarCoverType {
  comprehensive('comprehensive', 'Comprehensive'),
  thirdPartyFireTheft('third_party_fire_theft', 'Third party, fire and theft'),
  thirdParty('third_party', 'Third party only');

  const CarCoverType(this.wire, this.label);
  final String wire;
  final String label;

  static CarCoverType fromWire(String value) => values.firstWhere((c) => c.wire == value);
}

/// Mirrors `backend/app/models.py`'s `Province`.
enum Province {
  easternCape('eastern_cape', 'Eastern Cape'),
  freeState('free_state', 'Free State'),
  gauteng('gauteng', 'Gauteng'),
  kwazuluNatal('kwazulu_natal', 'KwaZulu-Natal'),
  limpopo('limpopo', 'Limpopo'),
  mpumalanga('mpumalanga', 'Mpumalanga'),
  northWest('north_west', 'North West'),
  northernCape('northern_cape', 'Northern Cape'),
  westernCape('western_cape', 'Western Cape');

  const Province(this.wire, this.label);
  final String wire;
  final String label;

  static Province fromWire(String value) => values.firstWhere((p) => p.wire == value);
}

DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);
Decimal? _decimal(Object? value) => value == null ? null : Decimal.parse(value.toString());

/// A South African ID number, however it's spaced, or eight digits or more
/// in a row (a policy or account number). Mirrors the server's check in
/// `backend/app/savings/schemas.py`, which refuses them too.
final _saId = RegExp(r'\d(?:[ -]?\d){12}');
final _longNumber = RegExp(r'\d{8,}');

bool looksLikeIdentifier(String text) => _saId.hasMatch(text) || _longNumber.hasMatch(text);

/// What the user tells Piggybank about a policy. Deliberately no policy
/// number, ID number or notes: the check needs none of them, and Penny's
/// research (plan item 7) builds web searches from these fields.
class PolicyDetails {
  const PolicyDetails({
    required this.type,
    this.insurer,
    this.province,
    this.assetId,
    this.make,
    this.model,
    this.year,
    this.vehicleValue,
    this.coverType,
    this.excess,
    this.insuredValue,
    this.coverAmount,
    this.planName,
  });

  final PolicyType type;
  final String? insurer;
  final Province? province;
  final String? assetId;
  final String? make;
  final String? model;
  final int? year;
  final Decimal? vehicleValue;
  final CarCoverType? coverType;
  final Decimal? excess;
  final Decimal? insuredValue;
  final Decimal? coverAmount;
  final String? planName;

  /// The first thing stopping the server from accepting these details, in
  /// words for the form, or null when they're complete.
  String? get problem {
    for (final text in [insurer, make, model, planName]) {
      if (text != null && looksLikeIdentifier(text)) return 'Leave out ID, policy and account numbers.';
    }
    switch (type.form) {
      case PolicyForm.car:
        if (make == null) return 'Enter the make.';
        if (model == null) return 'Enter the model.';
        final year = this.year;
        if (year == null || year < 1950 || year > DateTime.now().year + 1) return 'Enter the year it was made.';
        if (coverType == null) return 'Choose the type of cover.';
      case PolicyForm.property:
        if (insuredValue == null) return "Enter the amount it's insured for.";
      case PolicyForm.cover:
        if (coverAmount == null) return 'Enter the cover amount.';
      case PolicyForm.plan:
        if (planName == null) return 'Enter the plan name.';
    }
    return null;
  }

  /// The body for `PUT /savings/recurring/{id}/policy`: only the fields this
  /// type takes, since the server refuses another type's fields.
  Map<String, dynamic> toJson() => {
        'policy_type': type.wire,
        'insurer': insurer,
        'province': province?.wire,
        if (type.assetType != null) 'asset_id': assetId,
        ...switch (type.form) {
          PolicyForm.car => {
              'make': make,
              'model': model,
              'year': year,
              'vehicle_value': vehicleValue?.toString(),
              'cover_type': coverType?.wire,
              'excess': excess?.toString(),
            },
          PolicyForm.property => {'insured_value': insuredValue?.toString()},
          PolicyForm.cover => {'cover_amount': coverAmount?.toString()},
          PolicyForm.plan => {'plan_name': planName},
        },
      };

  factory PolicyDetails.fromJson(Map<String, dynamic> json) => PolicyDetails(
        type: PolicyType.fromWire(json['policy_type'] as String),
        insurer: json['insurer'] as String?,
        province: json['province'] == null ? null : Province.fromWire(json['province'] as String),
        assetId: json['asset_id'] as String?,
        make: json['make'] as String?,
        model: json['model'] as String?,
        year: json['year'] as int?,
        vehicleValue: _decimal(json['vehicle_value']),
        coverType: json['cover_type'] == null ? null : CarCoverType.fromWire(json['cover_type'] as String),
        excess: _decimal(json['excess']),
        insuredValue: _decimal(json['insured_value']),
        coverAmount: _decimal(json['cover_amount']),
        planName: json['plan_name'] as String?,
      );
}

/// Mirrors `backend/app/savings/schemas.py`'s `InsurancePolicyOut`.
class InsurancePolicy {
  const InsurancePolicy({required this.id, required this.recurringCostId, required this.details});

  final String id;
  final String recurringCostId;
  final PolicyDetails details;

  factory InsurancePolicy.fromJson(Map<String, dynamic> json) => InsurancePolicy(
        id: json['id'] as String,
        recurringCostId: json['recurring_cost_id'] as String,
        details: PolicyDetails.fromJson(json),
      );
}

/// How the cover compares with what the linked asset is worth; within 10%
/// is in line.
enum CoverPosition { inLine, overInsured, underInsured }

CoverPosition? _position(Object? value) => switch (value) {
      'in_line' => CoverPosition.inLine,
      'over_insured' => CoverPosition.overInsured,
      'under_insured' => CoverPosition.underInsured,
      _ => null,
    };

/// Mirrors `backend/app/savings/schemas.py`'s `PolicyCheck`: facts about
/// one premium, no verdict. A null fact means the data can't tell, never
/// zero, and the app hides it rather than show "R 0,00".
class PolicyCheck {
  const PolicyCheck({
    required this.policyId,
    required this.policyType,
    required this.monthlyPremium,
    required this.premiumPerYear,
    this.coverValue,
    this.premiumPctOfCover,
    this.assetValue,
    this.assetValuedOn,
    this.coverVsAsset,
    this.coverVsAssetPct,
    this.coverPosition,
    this.premiumNow,
    this.premiumYearAgo,
    this.premiumYearAgoOn,
    this.premiumIncreasePct,
    this.income,
    this.premiumPctOfIncome,
  });

  final String policyId;
  final PolicyType policyType;
  final Decimal monthlyPremium;
  final Decimal premiumPerYear;
  final Decimal? coverValue;
  final Decimal? premiumPctOfCover;
  final Decimal? assetValue;
  final DateTime? assetValuedOn;
  final Decimal? coverVsAsset;
  final Decimal? coverVsAssetPct;
  final CoverPosition? coverPosition;
  final Decimal? premiumNow;
  final Decimal? premiumYearAgo;
  final DateTime? premiumYearAgoOn;
  final Decimal? premiumIncreasePct;
  final Decimal? income;
  final Decimal? premiumPctOfIncome;

  factory PolicyCheck.fromJson(Map<String, dynamic> json) => PolicyCheck(
        policyId: json['policy_id'] as String,
        policyType: PolicyType.fromWire(json['policy_type'] as String),
        monthlyPremium: Decimal.parse(json['monthly_premium'].toString()),
        premiumPerYear: Decimal.parse(json['premium_per_year'].toString()),
        coverValue: _decimal(json['cover_value']),
        premiumPctOfCover: _decimal(json['premium_pct_of_cover']),
        assetValue: _decimal(json['asset_value']),
        assetValuedOn: _date(json['asset_valued_on']),
        coverVsAsset: _decimal(json['cover_vs_asset']),
        coverVsAssetPct: _decimal(json['cover_vs_asset_pct']),
        coverPosition: _position(json['cover_position']),
        premiumNow: _decimal(json['premium_now']),
        premiumYearAgo: _decimal(json['premium_year_ago']),
        premiumYearAgoOn: _date(json['premium_year_ago_on']),
        premiumIncreasePct: _decimal(json['premium_increase_pct']),
        income: _decimal(json['income']),
        premiumPctOfIncome: _decimal(json['premium_pct_of_income']),
      );
}
