import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/savings_api.dart';
import '../models/policy.dart';
import '../models/savings.dart';

final savingsApiProvider = Provider<SavingsApi>((ref) => SavingsApi(ref.watch(apiClientProvider)));

/// Target vs left over — the Savings plan screen's top card and the Home card.
final savingsOverviewProvider = FutureProvider.autoDispose<SavingsOverview>((ref) {
  return ref.watch(savingsApiProvider).overview();
});

final recurringCostsProvider = FutureProvider.autoDispose<List<RecurringCost>>((ref) {
  return ref.watch(savingsApiProvider).listRecurring();
});

/// The policy details on one insurance cost, keyed by the cost's id.
final policyProvider = FutureProvider.autoDispose.family<InsurancePolicy?, String>((ref, costId) {
  return ref.watch(savingsApiProvider).getPolicy(costId);
});

/// The facts-only check on one policy, keyed by the policy's id.
final policyCheckProvider = FutureProvider.autoDispose.family<PolicyCheck, String>((ref, policyId) {
  return ref.watch(savingsApiProvider).checkPolicy(policyId);
});

/// Every write changes the overview too (a new cost moves fixed costs, a
/// cut moves left over), so both are refetched together.
void refreshSavings(WidgetRef ref) {
  ref.invalidate(savingsOverviewProvider);
  ref.invalidate(recurringCostsProvider);
}
