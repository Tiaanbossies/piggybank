import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the instance loaded before `runApp` —
/// synchronous access is required so [themeModeProvider] (see
/// `theme_mode_provider.dart`) can supply an initial `ThemeMode` on first
/// frame, which an async `FutureProvider` couldn't do without a loading
/// flash on every app start.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});
