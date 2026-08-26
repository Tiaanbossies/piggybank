import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/liabilities/data/liabilities_api.dart';
import 'package:piggybank/features/liabilities/models/liability.dart';
import 'package:piggybank/features/liabilities/models/liability_payment.dart';
import 'package:piggybank/features/liabilities/providers/liabilities_provider.dart';

class MockLiabilitiesApi extends Mock implements LiabilitiesApi {}

Liability _liability({String id = 'l1', LiabilityType type = LiabilityType.personalLoan}) => Liability(
      id: id,
      liabilityType: type,
      name: 'Car loan',
      outstandingAmount: Decimal.fromInt(50000),
      originalBalance: null,
      interestRate: null,
      termMonths: null,
      startDate: null,
    );

LiabilityPayment _payment({String id = 'pay1', String liabilityId = 'l1'}) => LiabilityPayment(
      id: id,
      liabilityId: liabilityId,
      paymentDate: DateTime(2026, 5, 1),
      amount: Decimal.fromInt(2500),
      principalPortion: Decimal.fromInt(2000),
      interestPortion: Decimal.fromInt(500),
      notes: null,
      createdAt: DateTime(2026, 5, 1),
    );

LiabilityProgress _progress({String liabilityId = 'l1'}) => LiabilityProgress(
      liabilityId: liabilityId,
      originalBalance: Decimal.fromInt(60000),
      currentBalance: Decimal.fromInt(50000),
      totalPrincipalPaid: Decimal.fromInt(10000),
      totalInterestPaid: Decimal.fromInt(1200),
      percentPaid: Decimal.fromInt(17),
      paymentCount: 4,
      projectedPayoffDate: DateTime(2030, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(LiabilityType.personalLoan);
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  late MockLiabilitiesApi mockApi;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockLiabilitiesApi();
    container = ProviderContainer(overrides: [liabilitiesApiProvider.overrideWithValue(mockApi)]);
  });

  tearDown(() => container.dispose());

  group('liabilitiesProvider', () {
    test('fetches the liability list', () async {
      when(() => mockApi.list()).thenAnswer((_) async => [_liability()]);
      final result = await container.read(liabilitiesProvider.future);
      expect(result, hasLength(1));
      verify(() => mockApi.list()).called(1);
    });
  });

  group('liabilityProgressProvider (family keyed by liabilityId)', () {
    test('fetches progress for the given liabilityId and separates by key', () async {
      when(() => mockApi.getProgress('l1')).thenAnswer((_) async => _progress(liabilityId: 'l1'));
      when(() => mockApi.getProgress('l2')).thenAnswer((_) async => _progress(liabilityId: 'l2'));

      final r1 = await container.read(liabilityProgressProvider('l1').future);
      final r2 = await container.read(liabilityProgressProvider('l2').future);

      expect(r1.liabilityId, 'l1');
      expect(r2.liabilityId, 'l2');
      verify(() => mockApi.getProgress('l1')).called(1);
      verify(() => mockApi.getProgress('l2')).called(1);
    });
  });

  group('liabilityPaymentsProvider (family keyed by liabilityId)', () {
    test('fetches the payment ledger for the given liability', () async {
      when(() => mockApi.listPayments('l1')).thenAnswer((_) async => [_payment()]);
      final result = await container.read(liabilityPaymentsProvider('l1').future);
      expect(result, hasLength(1));
      expect(result.single.liabilityId, 'l1');
    });
  });

  group('liability CRUD wiring', () {
    test('create (amount-owed mode) forwards outstandingAmount, no loan params', () async {
      when(() => mockApi.create(
            liabilityType: any(named: 'liabilityType'),
            name: any(named: 'name'),
            outstandingAmount: any(named: 'outstandingAmount'),
            originalBalance: any(named: 'originalBalance'),
            interestRate: any(named: 'interestRate'),
            termMonths: any(named: 'termMonths'),
            monthlyAmount: any(named: 'monthlyAmount'),
            startDate: any(named: 'startDate'),
          )).thenAnswer((_) async => _liability());

      final api = container.read(liabilitiesApiProvider);
      await api.create(liabilityType: LiabilityType.creditCard, name: 'Card', outstandingAmount: '5000');

      verify(() => mockApi.create(
            liabilityType: LiabilityType.creditCard,
            name: 'Card',
            outstandingAmount: '5000',
            originalBalance: null,
            interestRate: null,
            termMonths: null,
            monthlyAmount: null,
            startDate: null,
          )).called(1);
    });

    test('create (loan-details mode) forwards originalBalance/interestRate/termMonths/startDate, no outstandingAmount',
        () async {
      when(() => mockApi.create(
            liabilityType: any(named: 'liabilityType'),
            name: any(named: 'name'),
            outstandingAmount: any(named: 'outstandingAmount'),
            originalBalance: any(named: 'originalBalance'),
            interestRate: any(named: 'interestRate'),
            termMonths: any(named: 'termMonths'),
            monthlyAmount: any(named: 'monthlyAmount'),
            startDate: any(named: 'startDate'),
          )).thenAnswer((_) async => _liability());

      final api = container.read(liabilitiesApiProvider);
      final start = DateTime(2024, 1, 1);
      await api.create(
        liabilityType: LiabilityType.vehicleLoan,
        name: 'Car loan',
        originalBalance: '200000',
        interestRate: '11.5',
        termMonths: 60,
        startDate: start,
      );

      verify(() => mockApi.create(
            liabilityType: LiabilityType.vehicleLoan,
            name: 'Car loan',
            outstandingAmount: null,
            originalBalance: '200000',
            interestRate: '11.5',
            termMonths: 60,
            monthlyAmount: null,
            startDate: start,
          )).called(1);
    });

    test('update forwards the liabilityId and changed fields', () async {
      when(() => mockApi.update(any(),
              liabilityType: any(named: 'liabilityType'), name: any(named: 'name'),
              outstandingAmount: any(named: 'outstandingAmount')))
          .thenAnswer((_) async => _liability());

      final api = container.read(liabilitiesApiProvider);
      await api.update('l1', name: 'Renamed', outstandingAmount: '4500');

      verify(() => mockApi.update('l1',
          liabilityType: any(named: 'liabilityType'), name: 'Renamed', outstandingAmount: '4500')).called(1);
    });

    test('delete forwards the liabilityId', () async {
      when(() => mockApi.delete(any())).thenAnswer((_) async {});
      final api = container.read(liabilitiesApiProvider);
      await api.delete('l1');
      verify(() => mockApi.delete('l1')).called(1);
    });
  });

  group('liability payment CRUD wiring', () {
    test('createPayment forwards liabilityId/date/amount/principal/interest', () async {
      when(() => mockApi.createPayment(
            any(),
            paymentDate: any(named: 'paymentDate'),
            amount: any(named: 'amount'),
            principalPortion: any(named: 'principalPortion'),
            interestPortion: any(named: 'interestPortion'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => _payment());

      final api = container.read(liabilitiesApiProvider);
      final date = DateTime(2026, 5, 1);
      await api.createPayment('l1',
          paymentDate: date, amount: '2500', principalPortion: '2000', interestPortion: '500');

      verify(() => mockApi.createPayment(
            'l1',
            paymentDate: date,
            amount: '2500',
            principalPortion: '2000',
            interestPortion: '500',
            notes: any(named: 'notes'),
          )).called(1);
    });

    test('deletePayment forwards liabilityId and paymentId', () async {
      when(() => mockApi.deletePayment(any(), any())).thenAnswer((_) async {});
      final api = container.read(liabilitiesApiProvider);
      await api.deletePayment('l1', 'pay1');
      verify(() => mockApi.deletePayment('l1', 'pay1')).called(1);
    });
  });
}
