import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/core/theme/app_theme.dart';
import 'package:piggybank/core/theme/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [child] inside a [ProviderScope] + [MaterialApp], with
/// [sharedPreferencesProvider] pre-overridden to an in-memory instance (most
/// screens sit behind providers that transitively read it via
/// `theme_mode_provider.dart`, and it throws `UnimplementedError` if left
/// unoverridden per its own doc comment — every widget test needs this, not
/// just theme-specific ones).
///
/// [overrides] should supply a mocktail mock for whatever `*ApiProvider`
/// the screen under test depends on (e.g.
/// `transactionsApiProvider.overrideWithValue(mockApi)`) — this app has no
/// shared `ApiClient` fake; each feature's `*Api` class (e.g.
/// `TransactionsApi`) is a plain concrete class, so mock it directly with
/// `class MockTransactionsApi extends Mock implements TransactionsApi {}`
/// rather than faking Dio/ApiClient underneath it.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  bool useAppTheme = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: MaterialApp(
        theme: useAppTheme ? AppTheme.light() : null,
        home: child,
      ),
    ),
  );
}
