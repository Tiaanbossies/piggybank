import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/accounts_api.dart';
import '../models/account.dart';

final accountsApiProvider = Provider<AccountsApi>((ref) => AccountsApi(ref.watch(apiClientProvider)));

final accountsProvider = FutureProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountsApiProvider).list(includeInactive: true);
});
