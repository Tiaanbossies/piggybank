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

/// Restores a deactivated account, with its transactions and history
/// untouched (deactivation only ever set a flag).
/// Usage: `ref.read(reactivateAccountProvider(accountId).future)`
final reactivateAccountProvider =
    FutureProvider.autoDispose.family<void, String>((ref, accountId) async {
  await ref.read(accountsApiProvider).update(accountId, isActive: true);
  ref.invalidate(accountsProvider);
});
