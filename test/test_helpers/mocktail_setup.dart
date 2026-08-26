import 'package:mocktail/mocktail.dart';

import 'package:piggybank/features/transactions/models/transaction.dart';

/// Registers mocktail fallback values for enums/value types used as named
/// arguments in `when(() => mock.method(any(named: '...')))` matchers across
/// feature API mocks. Mocktail requires a fallback value be registered for
/// any non-primitive type passed to `any()`/`captureAny()` before first use,
/// or it throws at test-run time with a confusing "type not registered"
/// error — call this once per test file's `setUpAll` (or a shared
/// `setUpAll` in a test suite file) rather than per-test.
///
/// Add to this list as later domain test steps discover more enums/value
/// types needing `any()` matching (e.g. asset/liability type pickers).
void registerCommonFallbackValues() {
  registerFallbackValue(TransactionType.expense);
}
