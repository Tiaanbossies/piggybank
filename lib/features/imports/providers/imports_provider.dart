import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/imports_api.dart';
import '../models/import_job.dart';

final importsApiProvider = Provider<ImportsApi>((ref) => ImportsApi(ref.watch(apiClientProvider)));

final bankTemplatesProvider = FutureProvider.autoDispose<List<BankTemplate>>((ref) {
  return ref.watch(importsApiProvider).listTemplates();
});

final importHistoryProvider = FutureProvider.autoDispose<List<ImportJob>>((ref) {
  return ref.watch(importsApiProvider).listImports();
});
