import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:piggybank/features/notifications/data/notifications_api.dart';
import 'package:piggybank/features/notifications/screens/notifications_inbox_screen.dart';

import '../../test_helpers/pump_app.dart';

class _MockNotificationsApi extends Mock implements NotificationsApi {}

final _now = DateTime(2026, 10, 15, 10);

AppNotification _n(String id, String title, {String route = 'budget', bool read = false}) => AppNotification(
      id: id,
      kind: route == 'budget' ? 'budget_80' : 'goal_50',
      title: title,
      body: 'Details',
      targetRoute: route,
      createdAt: _now,
      readAt: read ? _now : null,
    );

void main() {
  late _MockNotificationsApi api;

  setUp(() {
    api = _MockNotificationsApi();
    when(() => api.unreadCount()).thenAnswer((_) async => 1);
    when(() => api.markRead(any())).thenAnswer((_) async {});
    when(() => api.markAllRead()).thenAnswer((_) async {});
  });

  testWidgets('lists the inbox with unread marked (QA C12)', (tester) async {
    when(() => api.list()).thenAnswer((_) async => [
          _n('n1', 'Groceries is at 80%'),
          _n('n2', 'Holiday is 50% there', route: 'goal', read: true),
        ]);
    await pumpApp(tester, const NotificationsInboxScreen(), overrides: [notificationsApiProvider.overrideWithValue(api)]);
    await tester.pumpAndSettle();

    expect(find.text('Groceries is at 80%'), findsOneWidget);
    expect(find.text('Holiday is 50% there'), findsOneWidget);
    expect(find.byKey(const Key('notification-unread-dot')), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('Mark all read goes to the API', (tester) async {
    when(() => api.list()).thenAnswer((_) async => [_n('n1', 'Groceries is at 80%')]);
    await pumpApp(tester, const NotificationsInboxScreen(), overrides: [notificationsApiProvider.overrideWithValue(api)]);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notifications-read-all')));
    await tester.pumpAndSettle();
    verify(() => api.markAllRead()).called(1);
  });

  testWidgets('an empty inbox says so', (tester) async {
    when(() => api.list()).thenAnswer((_) async => []);
    await pumpApp(tester, const NotificationsInboxScreen(), overrides: [notificationsApiProvider.overrideWithValue(api)]);
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up."), findsOneWidget);
  });
}
