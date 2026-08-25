import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/widgets/group_card.dart';
import '../data/notification_prefs_api.dart';

/// Settings > Notifications (blueprint Step 5b). Preference *storage* only —
/// per Step 4b's context brief, no push-delivery (FCM/APNs) exists anywhere
/// in the backend, so these toggles don't yet trigger any notification; they
/// persist the user's choice for when delivery is built. Key names match the
/// backend's own test fixtures (`test_notification_preferences_round_trip_via_patch_me`
/// in `finance-app.v3-main/backend/tests/test_auth.py`) rather than being
/// invented here.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

/// (key, title, subtitle) — the fixed preference set. Add here if the
/// backend ever grows more keys; nothing else needs to change.
const _preferenceRows = [
  (key: 'budget_alerts', title: 'Budget alerts', subtitle: 'When a budget category is close to its limit'),
  (key: 'weekly_summary', title: 'Weekly summary', subtitle: 'A weekly recap of spending and progress'),
];

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _busy = false;
  String? _error;

  /// The backend's PATCH replaces the whole dict (not a merge — see
  /// `NotificationPrefsApi.updatePreferences`), so every toggle must send
  /// the complete current state, not just the key that changed.
  Map<String, bool> get _current {
    final saved = ref.read(authControllerProvider).user?.notificationPreferences;
    return {for (final row in _preferenceRows) row.key: saved?[row.key] ?? true};
  }

  /// Absent key (never saved, or a preference added after the user last
  /// saved) defaults to on — an opt-out model, not opt-in.
  bool _valueFor(String key) {
    final saved = ref.watch(authControllerProvider).user?.notificationPreferences;
    return saved?[key] ?? true;
  }

  Future<void> _toggle(String key, bool value) async {
    final next = _current..[key] = value;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(notificationPrefsApiProvider).updatePreferences(next);
      await ref.read(authControllerProvider.notifier).refreshUser();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            GroupCard(
              children: [
                for (final row in _preferenceRows)
                  GroupRow(
                    title: row.title,
                    subtitle: row.subtitle,
                    trailing: Switch(
                      value: _valueFor(row.key),
                      onChanged: _busy ? null : (v) => _toggle(row.key, v),
                    ),
                  ),
              ],
            ),
            if (_busy) ...[const SizedBox(height: 16), const Center(child: CircularProgressIndicator())],
          ],
        ),
      ),
    );
  }
}
