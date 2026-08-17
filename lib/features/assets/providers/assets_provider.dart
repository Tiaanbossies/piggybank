import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/assets_api.dart';
import '../models/asset.dart';

final assetsApiProvider = Provider<AssetsApi>((ref) => AssetsApi(ref.watch(apiClientProvider)));

final assetsProvider = FutureProvider.autoDispose<List<Asset>>((ref) {
  return ref.watch(assetsApiProvider).list();
});
