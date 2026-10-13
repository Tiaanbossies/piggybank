import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/group_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../detection/widgets/review_banner.dart';
import '../../plan/screens/plan_screen.dart';
import '../data/notifications_api.dart';

/// The Home bell (QA pass 1, C12): the icon with an unread badge, shown
/// while any notification kind is switched on in Settings → Notifications.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(notificationsEnabledProvider)) return const SizedBox.shrink();
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    return IconButton(
      key: const Key('home-bell'),
      tooltip: unread == 0 ? 'Notifications' : 'Notifications, $unread unread',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(unread > 0 ? Icons.notifications : Icons.notifications_none),
      ),
      onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsInboxScreen()));
        ref.invalidate(unreadNotificationsProvider);
      },
    );
  }
}

class NotificationsInboxScreen extends ConsumerWidget {
  const NotificationsInboxScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    if (n.unread) {
      try {
        await ref.read(notificationsApiProvider).markRead(n.id);
      } on ApiError {
        // Opening it still helps; it shows unread again next time.
      }
      ref
        ..invalidate(notificationsProvider)
        ..invalidate(unreadNotificationsProvider);
    }
    if (!context.mounted) return;
    switch (n.targetRoute) {
      case 'review':
        openPendingReview(context);
      case 'budget' || 'goal':
        ref.read(planSegmentProvider.notifier).state =
            n.targetRoute == 'goal' ? PlanSegment.goals : PlanSegment.budgets;
        final router = GoRouter.maybeOf(context);
        Navigator.of(context).pop();
        router?.go('/plan');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(notificationsProvider);
    final hasUnread = inbox.valueOrNull?.any((n) => n.unread) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              key: const Key('notifications-read-all'),
              onPressed: () async {
                await ref.read(notificationsApiProvider).markAllRead();
                ref
                  ..invalidate(notificationsProvider)
                  ..invalidate(unreadNotificationsProvider);
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: SafeArea(
        child: AppRefresh(
          onRefresh: () => ref.refresh(notificationsProvider.future),
          child: SkeletonSwitcher(
            child: inbox.when(
              loading: () => const SkeletonRows(count: 4),
              error: (err, _) => ListView(children: [
                InlineError(
                  message: err is ApiError ? err.message : "Couldn't load your notifications",
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
              ]),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(children: const [
                    EmptyState(
                      icon: Icons.notifications_none,
                      title: "You're all caught up.",
                      hint: 'Budgets nearing their limit, goal milestones and transactions to review show up here.',
                    ),
                  ]);
                }
                final t = context.tokens;
                return ListView(
                  padding: const EdgeInsets.all(AppSpace.gutter),
                  children: [
                    GroupCard(
                      children: [
                        for (final n in items)
                          GroupRow(
                            key: ValueKey('notification-${n.id}'),
                            leadingIcon: switch (n.targetRoute) {
                              'review' => Icons.fact_check_outlined,
                              'goal' => Icons.flag_outlined,
                              _ => Icons.pie_chart_outline,
                            },
                            title: n.title,
                            subtitle: '${n.body} · ${dayLabel(n.createdAt.toLocal())}',
                            trailing: n.unread
                                ? Container(
                                    key: const Key('notification-unread-dot'),
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                                  )
                                : null,
                            onTap: () => _open(context, ref, n),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
