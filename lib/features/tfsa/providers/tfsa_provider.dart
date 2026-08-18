import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/tfsa_api.dart';
import '../models/tfsa_contribution.dart';
import '../models/tfsa_summary.dart';

final tfsaApiProvider = Provider<TfsaApi>((ref) => TfsaApi(ref.watch(apiClientProvider)));

final tfsaContributionsProvider = FutureProvider.autoDispose<List<TfsaContribution>>((ref) {
  return ref.watch(tfsaApiProvider).listContributions();
});

final tfsaSummaryProvider = FutureProvider.autoDispose<TfsaSummary>((ref) {
  return ref.watch(tfsaApiProvider).getSummary();
});
