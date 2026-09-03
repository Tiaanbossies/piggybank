import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/widgets/group_card.dart';
import '../data/profile_api.dart';

/// Settings > Personal Profile — closes the gap flagged in the Stitch
/// parity sweep (`plans/stitch-live-verification.md`, Bucket 2). Editable
/// fields are limited to what `PATCH /auth/me` actually accepts
/// (`full_name`, `salary_day`) — email isn't editable via this endpoint, so
/// it's shown read-only rather than offered as a field that would silently
/// no-op.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _salaryDayController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _salaryDayController = TextEditingController(text: user?.salaryDay?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _salaryDayController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final salaryDayText = _salaryDayController.text.trim();
    final salaryDay = salaryDayText.isEmpty ? null : int.tryParse(salaryDayText);
    if (salaryDayText.isNotEmpty && (salaryDay == null || salaryDay < 1 || salaryDay > 28)) {
      setState(() => _error = 'Salary day must be a number between 1 and 28.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileApiProvider).updateProfile(
            fullName: _nameController.text.trim(),
            salaryDay: salaryDay,
          );
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authControllerProvider).user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Personal profile')),
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
                GroupRow(leadingIcon: Icons.email_outlined, title: 'Email', subtitle: email),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _salaryDayController,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Salary day (optional)',
                helperText: 'Day of the month your salary lands, 1–28',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
