import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// history) — none of those sub-screens exist yet (tracked as new gaps in
/// `docs/ui-ux-mockup-brief.md` §12/§13). Restyled to the new card language,
/// but only the two rows that are actually real today (profile, logout) are
/// shown — adding non-functional rows for the rest would be exactly the
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
