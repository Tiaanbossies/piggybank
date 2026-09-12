import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/shared_preferences_provider.dart';

/// Backs the first-run Penny onboarding tour gate (see
/// `plans/piggybank-penny-onboarding-tour.md`). Tracks, per user id, whether
/// that account has an *unfinished* tour — set only by [AuthController.register]
/// right after a brand-new account is created, cleared only by
/// [AuthController.completeOnboarding]. A missing key means "not pending" for
/// every account that either existed before this feature shipped or already
/// finished the tour — there is deliberately no backfill/migration step.
///
/// A plain class, not a [StateNotifier]: [AuthController] needs synchronous
/// read and direct write access, not a watched provider (mirrors why
/// `AuthController` itself isn't a provider wrapping a notifier per field).
class OnboardingStore {
  OnboardingStore(this._prefs);
  final SharedPreferences _prefs;

  static const _keyPrefix = 'onboarding_pending_';

  /// True only between a successful [AuthController.register] and that
  /// account's next [AuthController.completeOnboarding] call — i.e. "this
  /// account has an unfinished tour."
  bool isPending(String userId) => _prefs.getBool('$_keyPrefix$userId') ?? false;

  Future<void> markPending(String userId) => _prefs.setBool('$_keyPrefix$userId', true);

  Future<void> clearPending(String userId) => _prefs.remove('$_keyPrefix$userId');
}

final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  return OnboardingStore(ref.watch(sharedPreferencesProvider));
});
