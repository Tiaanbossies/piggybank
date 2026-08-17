import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/goals_api.dart';
import '../models/goal.dart';

final goalsApiProvider = Provider<GoalsApi>((ref) => GoalsApi(ref.watch(apiClientProvider)));

final goalsProvider = FutureProvider.autoDispose<List<Goal>>((ref) {
  return ref.watch(goalsApiProvider).list();
});
