import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/liabilities_api.dart';
import '../models/liability.dart';

final liabilitiesApiProvider = Provider<LiabilitiesApi>((ref) => LiabilitiesApi(ref.watch(apiClientProvider)));

final liabilitiesProvider = FutureProvider.autoDispose<List<Liability>>((ref) {
  return ref.watch(liabilitiesApiProvider).list();
});
