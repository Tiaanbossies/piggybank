import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/shared_preferences_provider.dart';
import '../models/transaction.dart';
import 'transactions_provider.dart';

/// The categories this user has actually used for [type], most-used first —
/// the add sheet's one-tap chips (UX plan items 2–3). Its own query rather
/// than [transactionCategoriesProvider], which only knows what the
/// Transactions list has paged in and so is empty when the sheet opens
/// from Home. 200 rows (the backend's page maximum) is plenty to rank by.
final categoryUsageProvider = FutureProvider.autoDispose.family<List<String>, TransactionType>((ref, type) async {
  final page = await ref.watch(transactionsApiProvider).list(transactionType: type, limit: 200);
  final counts = <String, int>{};
  for (final t in page.items) {
    final category = t.category.trim();
    if (category.isEmpty) continue;
    counts[category] = (counts[category] ?? 0) + 1;
  }
  return counts.keys.toList()
    ..sort((a, b) {
      final byUse = counts[b]!.compareTo(counts[a]!);
      return byUse != 0 ? byUse : a.compareTo(b);
    });
});

const _lastAccountKey = 'quick_add_last_account_id';

/// The account the last added transaction went to, pre-selected on the
/// next add — most manual entries are cash or the one everyday card, so
/// remembering it saves opening the dropdown every time. Device-local,
/// like the theme choice: a convenience, not account data.
class LastUsedAccountNotifier extends StateNotifier<String?> {
  LastUsedAccountNotifier(this._prefs) : super(_prefs.getString(_lastAccountKey));
  final SharedPreferences _prefs;

  Future<void> remember(String? accountId) async {
    state = accountId;
    if (accountId == null) {
      await _prefs.remove(_lastAccountKey);
    } else {
      await _prefs.setString(_lastAccountKey, accountId);
    }
  }
}

final lastUsedAccountProvider = StateNotifierProvider<LastUsedAccountNotifier, String?>((ref) {
  return LastUsedAccountNotifier(ref.watch(sharedPreferencesProvider));
});
