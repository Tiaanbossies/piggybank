import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/auth/biometric_preference.dart';
import 'package:piggybank/core/theme/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('biometricPreferenceProvider', () {
    test('defaults to true when no preference has been saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);

      expect(container.read(biometricPreferenceProvider), true);
    });

    test('setEnabled(false) persists and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);

      await container.read(biometricPreferenceProvider.notifier).setEnabled(false);

      expect(container.read(biometricPreferenceProvider), false);
      expect(prefs.getBool('biometric_enabled'), false);
    });

    test('a previously saved false value is read back on construction', () async {
      SharedPreferences.setMockInitialValues({'biometric_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);

      expect(container.read(biometricPreferenceProvider), false);
    });
  });
}
