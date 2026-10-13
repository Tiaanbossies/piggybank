import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/core/api/api_error.dart';
import 'package:piggybank/features/accounts/data/accounts_api.dart';
import 'package:piggybank/features/accounts/models/account.dart';
import 'package:piggybank/features/accounts/providers/accounts_provider.dart';
import 'package:piggybank/features/accounts/screens/accounts_context_menu.dart';

import '../../../test_helpers/pump_app.dart';

class _MockAccountsApi extends Mock implements AccountsApi {}

final _inactive = Account(
  id: 'acc-old',
  name: 'Old cheque',
  accountType: 'bank',
  currency: 'ZAR',
  balance: Decimal.fromInt(120),
  isActive: false,
);

/// Opens the long-press menu the way the Accounts list does.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => AccountContextMenu(account: _inactive),
            ),
            child: const Text('Open'),
          ),
        ),
      );
}

void main() {
  late _MockAccountsApi api;

  setUp(() {
    api = _MockAccountsApi();
    when(() => api.list(includeInactive: any(named: 'includeInactive'))).thenAnswer((_) async => [_inactive]);
  });

  Future<void> openMenu(WidgetTester tester) async {
    await pumpApp(tester, const _Host(), overrides: [accountsApiProvider.overrideWithValue(api)]);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('an inactive account can be restored from its menu (QA D2a)', (tester) async {
    when(() => api.update('acc-old', isActive: true)).thenAnswer((_) async => _inactive);
    await openMenu(tester);

    expect(find.textContaining('Contact support'), findsNothing);
    await tester.tap(find.text('Restore account'));
    await tester.pumpAndSettle();

    verify(() => api.update('acc-old', isActive: true)).called(1);
    expect(find.text('Old cheque restored'), findsOneWidget);
  });

  testWidgets('a restore over the account limit opens the paywall', (tester) async {
    when(() => api.update('acc-old', isActive: true)).thenThrow(
      const ApiError(statusCode: 402, message: 'Free plan allows 3 accounts'),
    );
    await openMenu(tester);

    await tester.tap(find.text('Restore account'));
    await tester.pumpAndSettle();

    expect(find.text('Free plan allows 3 accounts'), findsOneWidget);
    expect(find.text('Upgrade to PRO'), findsOneWidget);
  });
}
