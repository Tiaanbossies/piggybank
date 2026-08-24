import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/shared_preferences_provider.dart';

const _biometricEnabledKey = 'biometric_enabled';

/// Whether the user wants biometric unlock offered on the lock screen
/// (blueprint Step 5a). Defaults to `true` — matches the app's existing
/// implicit behaviour before this preference existed. The other half of the
/// lock method — whether a PIN is set — is never cached locally; it's read
/// fresh from `User.hasPin` (see Step 5a's plan notes on why a local flag
/// for PIN existence would risk a real lockout across devices/reinstalls).
class BiometricPreferenceNotifier extends StateNotifier<bool> {
  BiometricPreferenceNotifier(this._prefs) : super(_prefs.getBool(_biometricEnabledKey) ?? true);
  final SharedPreferences _prefs;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _prefs.setBool(_biometricEnabledKey, enabled);
  }
}

final biometricPreferenceProvider = StateNotifierProvider<BiometricPreferenceNotifier, bool>((ref) {
  return BiometricPreferenceNotifier(ref.watch(sharedPreferencesProvider));
});
