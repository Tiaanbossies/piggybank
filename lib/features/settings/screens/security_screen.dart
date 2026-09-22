import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/biometric_preference.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/group_card.dart';
import '../data/account_api.dart';
import '../data/security_api.dart';

/// Settings > Security (blueprint Step 5a). Enforces the never-zero-unlock-
/// methods invariant against live state on every toggle/removal, never a
/// cached belief: turning biometric off requires `user.hasPin`; removing the
/// PIN requires biometric to be on AND the device to actually support it.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _busy = false;
  String? _error;

  bool get _hasPin => ref.read(authControllerProvider).user?.hasPin ?? false;

  Future<void> _toggleBiometric(bool enabled) async {
    setState(() => _error = null);
    if (!enabled && !_hasPin) {
      setState(() => _error = 'Set a PIN before turning off biometric unlock — the app must always have a working unlock method.');
      return;
    }
    await ref.read(biometricPreferenceProvider.notifier).setEnabled(enabled);
  }

  Future<void> _attemptRemovePin() async {
    final biometricEnabled = ref.read(biometricPreferenceProvider);
    final deviceSupported = await ref.read(localAuthProvider).isDeviceSupported();
    if (!biometricEnabled || !deviceSupported) {
      setState(() => _error = 'Turn on biometric unlock before removing your PIN — the app must always have a working unlock method.');
      return;
    }
    if (!mounted) return;
    final password = await _promptForPassword(title: 'Remove PIN', confirmLabel: 'Remove');
    if (password == null) return;
    await _run(() async {
      await ref.read(securityApiProvider).removePin(password);
      await ref.read(authControllerProvider.notifier).refreshUser();
    });
  }

  Future<void> _showSetPinDialog() async {
    final result = await showDialog<(String password, String pin)>(
      context: context,
      builder: (context) => const _SetPinDialog(),
    );
    if (result == null) return;
    await _run(() async {
      await ref.read(securityApiProvider).setPin(currentPassword: result.$1, pin: result.$2);
      await ref.read(authControllerProvider.notifier).refreshUser();
    });
  }

  Future<String?> _promptForPassword({required String title, required String confirmLabel}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _openDataExport() => context.push('/settings/data-export');

  Future<void> _attemptDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account and all your data — accounts, transactions, '
          'budgets, goals, everything. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final password = await _promptForPassword(title: 'Confirm your password', confirmLabel: 'Delete account');
    if (password == null) return;
    await _run(() async {
      await ref.read(accountApiProvider).deleteAccount(password);
      await ref.read(authControllerProvider.notifier).logout();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = ref.watch(biometricPreferenceProvider);
    final hasPin = ref.watch(authControllerProvider).user?.hasPin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
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
                GroupRow(
                  leadingIcon: Icons.fingerprint,
                  title: 'Biometric unlock',
                  subtitle: 'Use Face ID or Fingerprint',
                  trailing: Switch(
                    value: biometricEnabled,
                    onChanged: _busy ? null : _toggleBiometric,
                  ),
                ),
                GroupRow(
                  leadingIcon: Icons.pin_outlined,
                  title: hasPin ? 'Change PIN' : 'Set PIN',
                  onTap: _busy ? null : _showSetPinDialog,
                ),
                if (hasPin)
                  GroupRow(
                    leadingIcon: Icons.remove_circle_outline,
                    leadingDanger: true,
                    title: 'Remove PIN',
                    onTap: _busy ? null : _attemptRemovePin,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Your biometric data is encrypted and stored locally on your device. We never send it to our servers.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).extension<AppSemanticColors>()?.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 24),
            GroupCard(
              children: [
                GroupRow(
                  leadingIcon: Icons.download_outlined,
                  title: 'Export my data',
                  subtitle: 'Download a copy of everything in your account',
                  onTap: _busy ? null : _openDataExport,
                ),
                GroupRow(
                  leadingIcon: Icons.delete_forever_outlined,
                  leadingDanger: true,
                  title: 'Delete my account',
                  subtitle: 'Permanently deletes your data',
                  onTap: _busy ? null : _attemptDeleteAccount,
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

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: '4–6 digit PIN', counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_passwordController.text, _pinController.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
