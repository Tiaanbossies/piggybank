import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/savings_api.dart';
import '../models/savings.dart';

final savingsApiProvider = Provider<SavingsApi>((ref) => SavingsApi(ref.watch(apiClientProvider)));

/// Target vs left over — the Savings plan screen's top card and the Home card.
final savingsOverviewProvider = FutureProvider.autoDispose<SavingsOverview>((ref) {
  return ref.watch(savingsApiProvider).overview();
});

final recurringCostsProvider = FutureProvider.autoDispose<List<RecurringCost>>((ref) {
  return ref.watch(savingsApiProvider).listRecurring();
});

/// Every write changes the overview too (a new cost moves fixed costs, a
/// cut moves left over), so both are refetched together.
void refreshSavings(WidgetRef ref) {
  ref.invalidate(savingsOverviewProvider);
  ref.invalidate(recurringCostsProvider);
}
