import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import 'accounts_provider.dart';

/// Mutation provider for account deactivation.
/// Usage: `ref.read(deactivateAccountProvider(accountId).future)`
final deactivateAccountProvider =
    FutureProvider.autoDispose.family<void, String>((ref, accountId) async {
  try {
    await ref.read(accountsApiProvider).deactivate(accountId);
    // Invalidate the accounts list to trigger a refresh
    ref.invalidate(accountsProvider);
  } on ApiError {
    rethrow; // Let the caller handle the error
  }
});
