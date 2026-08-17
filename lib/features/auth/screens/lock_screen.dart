import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';

/// Shown when [AuthState.locked] is true — biometric/PIN app-lock, per the
/// locked v1-scope decision for a finance app. Auto-prompts on first build.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptUnlock());
  }

  Future<void> _attemptUnlock() async {
    setState(() => _prompting = true);
    await ref.read(authControllerProvider.notifier).unlockWithBiometrics();
    if (mounted) setState(() => _prompting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 16),
            Text('Piggybank is locked', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            if (_prompting)
              const CircularProgressIndicator()
            else
              ElevatedButton(onPressed: _attemptUnlock, child: const Text('Unlock')),
          ],
        ),
      ),
    );
  }
}
