import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/assets/data/assets_api.dart';
import 'package:piggybank/features/assets/models/asset.dart';
import 'package:piggybank/features/assets/providers/assets_provider.dart';
import 'package:piggybank/features/chatbot/data/chatbot_api.dart';
import 'package:piggybank/features/chatbot/models/policy_research.dart';
import 'package:piggybank/features/savings/data/savings_api.dart';
import 'package:piggybank/features/savings/models/policy.dart';
import 'package:piggybank/features/savings/models/savings.dart';
import 'package:piggybank/features/savings/providers/savings_provider.dart';
import 'package:piggybank/features/savings/screens/policy_screen.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../test_helpers/pump_app.dart';

class _MockSavingsApi extends Mock implements SavingsApi {}

class _MockAssetsApi extends Mock implements AssetsApi {}

class _MockChatbotApi extends Mock implements ChatbotApi {}

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final launched = <String>[];

  @override
  // ignore: override_on_non_overriding_member
  get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

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
  late _MockChatbotApi chatApi;

  setUpAll(() {
    registerFallbackValue(const PolicyDetails(type: PolicyType.life));
  });

  setUp(() {
    api = _MockSavingsApi();
    assetsApi = _MockAssetsApi();
    chatApi = _MockChatbotApi();
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
        chatbotApiProvider.overrideWithValue(chatApi),
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
      expect(find.textContaining('Facts from your own figures, not advice'), findsOneWidget);
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

  group('Ask Penny', () {
    setUp(() {
      when(() => api.getPolicy('c1')).thenAnswer((_) async => _policy);
      when(() => api.checkPolicy('p1')).thenAnswer((_) async => PolicyCheck(
            policyId: 'p1',
            policyType: PolicyType.car,
            monthlyPremium: Decimal.parse('500'),
            premiumPerYear: Decimal.parse('6000'),
          ));
    });

    final checked = DateTime.utc(2026, 10, 1, 9);

    PolicyResearch answer({String reply = 'Published figures suggest R400 to R700 a month.'}) => PolicyResearch(
          policyId: 'p1',
          status: ResearchStatus.ok,
          reply: reply,
          checkedOn: DateTime(2026, 10, 1),
          sources: [
            ResearchSource(
              title: 'Car insurance costs in 2026',
              domain: 'example.co.za',
              url: 'https://example.co.za/car-insurance',
              retrievedAt: checked,
            ),
            ResearchSource(
              title: 'A page with a bad link',
              domain: 'bad.example',
              url: 'javascript:alert(1)',
              retrievedAt: checked,
            ),
          ],
        );

    Future<void> ask(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('ask-penny-button')));
      await tester.pumpAndSettle();
    }

    testWidgets('asks only on a tap, and the footnote is there before asking', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('ask-penny-button')), findsOneWidget);
      expect(find.text(researchFootnote), findsOneWidget);
      verifyNever(() => chatApi.researchPolicy(any()));
    });

    testWidgets('shows the reply as plain text, the sources with their dates, and the footnote', (tester) async {
      final launcher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
      when(() => chatApi.researchPolicy('p1')).thenAnswer((_) async => answer());
      await pump(tester);
      await ask(tester);

      final reply = tester.widget<SelectableText>(find.byKey(const Key('research-reply')));
      expect(reply.data, 'Published figures suggest R400 to R700 a month.');
      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('Car insurance costs in 2026'), findsOneWidget);
      expect(find.textContaining('example.co.za · checked on 1 Oct 2026'), findsOneWidget);
      expect(find.text(researchFootnote), findsOneWidget);
      // One answer per tap: no button to spend another of the day's five.
      expect(find.byKey(const Key('ask-penny-button')), findsNothing);

      await tester.tap(find.byKey(const Key('source-example.co.za')));
      await tester.pumpAndSettle();
      expect(launcher.launched, ['https://example.co.za/car-insurance']);

      // A link that isn't http(s) is shown but never opened.
      await tester.tap(find.byKey(const Key('source-bad.example')));
      await tester.pumpAndSettle();
      expect(launcher.launched, hasLength(1));
    });

    testWidgets('a link inside the reply is not made tappable', (tester) async {
      when(() => chatApi.researchPolicy('p1'))
          .thenAnswer((_) async => answer(reply: 'See https://evil.example/login for cheaper cover.'));
      await pump(tester);
      await ask(tester);

      final reply = tester.widget<SelectableText>(find.byKey(const Key('research-reply')));
      expect(reply.data, contains('https://evil.example/login'));
      expect(reply.textSpan, isNull);
    });

    testWidgets('paused research says until when, and offers no second ask', (tester) async {
      when(() => chatApi.researchPolicy('p1')).thenAnswer((_) async => PolicyResearch(
            policyId: 'p1',
            status: ResearchStatus.paused,
            pausedUntil: DateTime(2026, 11, 1),
          ));
      await pump(tester);
      await ask(tester);

      expect(find.textContaining('paused until 1 Nov 2026'), findsOneWidget);
      expect(find.byKey(const Key('ask-penny-button')), findsNothing);
      expect(find.text(researchFootnote), findsOneWidget);
    });

    testWidgets('no published figures says so and suggests quotes', (tester) async {
      when(() => chatApi.researchPolicy('p1'))
          .thenAnswer((_) async => const PolicyResearch(policyId: 'p1', status: ResearchStatus.noResults));
      await pump(tester);
      await ask(tester);

      expect(find.textContaining('no published figures'), findsOneWidget);
      expect(find.textContaining('2 or 3 quotes'), findsOneWidget);
      expect(find.text(researchFootnote), findsOneWidget);
    });

    testWidgets('a free account gets the upgrade prompt', (tester) async {
      when(() => chatApi.researchPolicy('p1'))
          .thenThrow(const ApiError(statusCode: 402, message: 'Penny research is a Pro feature'));
      await pump(tester);
      await ask(tester);

      expect(find.text('Upgrade to PRO'), findsOneWidget);
      expect(find.text('Penny research is a Pro feature'), findsOneWidget);
    });

    testWidgets('the sixth ask in a day says to come back tomorrow', (tester) async {
      when(() => chatApi.researchPolicy('p1')).thenThrow(const ApiError(statusCode: 429, message: 'x'));
      await pump(tester);
      await ask(tester);

      expect(find.textContaining('5 times today'), findsOneWidget);
    });
  });

  test('checkedLabel reads naturally', () {
    final now = DateTime(2026, 10, 8, 12);
    expect(checkedLabel(DateTime(2026, 10, 8, 7), now: now), 'checked today');
    expect(checkedLabel(DateTime(2026, 10, 7, 7), now: now), 'checked yesterday');
    expect(checkedLabel(DateTime(2026, 10, 1, 7), now: now), 'checked on 1 Oct 2026');
  });
}
