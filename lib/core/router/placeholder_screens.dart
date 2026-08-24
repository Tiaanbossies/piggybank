import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/consent/screens/consent_screen.dart';
import '../../features/settings/screens/import_history_screen.dart';
import '../../features/settings/screens/subscription_screen.dart';
import '../../shared/widgets/group_card.dart';
import '../auth/auth_controller.dart';

/// Stub tabs for domains not yet built (Invest/Budgets/Insights land in
/// later phases per the migration plan's parity matrix). Settings includes
/// the working Logout action so Phase 1's auth loop is fully testable.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(child: Text('$title — coming soon', style: Theme.of(context).textTheme.titleMedium)),
      ),
    );
  }
}

/// Settings mockup shows a fully fleshed screen (Profile, Security,
/// Notifications, Appearance, Subscription, Privacy & consent, Import
/// history) — most of those sub-screens don't exist yet (tracked as gaps in
/// `docs/stitch-design-brief.md` §8, the authoritative design reference
/// going forward — not `docs/ui-ux-mockup-brief.md`, which predates it and
/// isn't kept in sync). Restyled to the new card language; only the rows
/// that are actually real today (profile, privacy & consent, subscription,
/// import history, logout) are shown — adding non-functional rows for the
/// rest (Security, Notifications, Appearance) would be exactly the
/// "template artefact" this project's quality bar rules out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            if (user != null)
              GroupCard(
                children: [
                  GroupRow(
                    leadingIcon: Icons.person_outline,
                    title: user.fullName ?? user.email,
                    subtitle: user.email,
                  ),
                ],
              ),
            const SizedBox(height: 12),
            GroupCard(
              children: [
                GroupRow(
                  leadingIcon: Icons.privacy_tip_outlined,
                  title: 'Privacy & consent',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConsentScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GroupCard(
              children: [
                GroupRow(
                  leadingIcon: Icons.workspace_premium_outlined,
                  title: 'Subscription',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  ),
                ),
                GroupRow(
                  leadingIcon: Icons.description_outlined,
                  title: 'Import history',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImportHistoryScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GroupCard(
              children: [
                GroupRow(
                  leadingIcon: Icons.logout,
                  leadingDanger: true,
                  title: 'Log out',
                  onTap: () => ref.read(authControllerProvider.notifier).logout(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
