import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/liabilities_api.dart';
import '../models/liability.dart';
import '../models/liability_payment.dart';

final liabilitiesApiProvider = Provider<LiabilitiesApi>((ref) => LiabilitiesApi(ref.watch(apiClientProvider)));

final liabilitiesProvider = FutureProvider.autoDispose<List<Liability>>((ref) {
  return ref.watch(liabilitiesApiProvider).list();
});

final liabilityProgressProvider =
    FutureProvider.autoDispose.family<LiabilityProgress, String>((ref, liabilityId) {
  return ref.watch(liabilitiesApiProvider).getProgress(liabilityId);
});

final liabilityPaymentsProvider =
    FutureProvider.autoDispose.family<List<LiabilityPayment>, String>((ref, liabilityId) {
  return ref.watch(liabilitiesApiProvider).listPayments(liabilityId);
});
