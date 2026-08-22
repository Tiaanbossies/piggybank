import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/ra_api.dart';
import '../models/ra_contribution.dart';
import '../models/ra_summary.dart';

final raApiProvider = Provider<RaApi>((ref) => RaApi(ref.watch(apiClientProvider)));

final raContributionsProvider = FutureProvider.autoDispose<List<RaContribution>>((ref) {
  return ref.watch(raApiProvider).listContributions();
});

final raSummaryProvider = FutureProvider.autoDispose<RaSummary>((ref) {
  return ref.watch(raApiProvider).getSummary();
});
