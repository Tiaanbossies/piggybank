import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/consent/screens/consent_screen.dart';
import '../../features/detection/screens/detection_settings_screen.dart';
import '../../features/settings/screens/about_screen.dart';
import '../../features/settings/screens/appearance_screen.dart';
import '../../features/settings/screens/notifications_screen.dart';
import '../../features/settings/screens/profile_screen.dart';
import '../../features/settings/screens/security_screen.dart';
import '../../features/settings/screens/subscription_screen.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/group_card.dart';
import '../auth/auth_controller.dart';

/// Stub tabs for domains not yet built at the time this was written
/// (Invest/Budgets landed in later phases per the migration plan's parity
/// matrix; an "Insights" Q&A-history tab was also built later but has since
/// been deleted — see `chatbot_screen.dart`'s doc comment). Settings includes
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
/// history) — tracked as gaps in `docs/stitch-design-brief.md` §8, the
/// authoritative design reference going forward — not
/// `docs/ui-ux-mockup-brief.md`, which predates it and isn't kept in sync).
/// Restyled to the new card language; only rows backed by a real feature are
/// shown — Notifications joined that list once Step 4b/5b landed the backend
/// field and this screen. Adding a non-functional row would be exactly the
/// "template artefact" this project's quality bar rules out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    // Pushed above the shell from the tab-root avatar (UX rework spec §2.6),
    // so it has a back arrow and no bottom bar.
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null)
              GroupCard(
                children: [
                  GroupRow(
                    leadingIcon: Icons.person_outline,
                    title: user.fullName ?? user.email,
                    subtitle: user.email,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                  ),
                ],
              ),
            const _SectionLabel('Account'),
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
                  leadingIcon: Icons.lock_outline,
                  title: 'Security',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SecurityScreen()),
                  ),
                ),
                GroupRow(
                  leadingIcon: Icons.privacy_tip_outlined,
                  title: 'Privacy & consent',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConsentScreen()),
                  ),
                ),
              ],
            ),
            const _SectionLabel('Preferences'),
            GroupCard(
              children: [
                GroupRow(
                  leadingIcon: Icons.palette_outlined,
                  title: 'Appearance',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AppearanceScreen()),
                  ),
                ),
                GroupRow(
                  leadingIcon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
              ],
            ),
            const _SectionLabel('Data sources'),
            GroupCard(
              children: [
                GroupRow(
                  leadingIcon: Icons.auto_awesome_outlined,
                  title: 'Bank notifications & email',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DetectionSettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GroupCard(
              children: [
                GroupRow(
                  leadingIcon: Icons.info_outline,
                  title: 'About',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GroupCard(
              children: [
                GroupRow(
                  key: const Key('settings-log-out'),
                  leadingIcon: Icons.logout,
                  leadingDanger: true,
                  title: 'Log out',
                  onTap: () async {
                    final confirmed = await confirmDestroy(
                      context,
                      title: 'Log out?',
                      message: "You'll need your password to sign back in.",
                      confirmLabel: 'Log out',
                    );
                    if (confirmed) await ref.read(authControllerProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small heading above each Settings group (spec §2.6).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
