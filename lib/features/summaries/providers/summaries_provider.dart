import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/summaries_api.dart';
import '../models/summaries.dart';

final summariesApiProvider = Provider<SummariesApi>((ref) => SummariesApi(ref.watch(apiClientProvider)));

final netWorthProvider = FutureProvider.autoDispose<NetWorthSummary>((ref) {
  return ref.watch(summariesApiProvider).netWorth();
});

final cashflowProvider = FutureProvider.autoDispose<CashflowSummary>((ref) {
  return ref.watch(summariesApiProvider).cashflow();
});
