import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/biometric_preference.dart';
import '../../settings/data/security_api.dart';

/// Shown when [AuthState.locked] is true — biometric/PIN app-lock, per the
/// locked v1-scope decision for a finance app.
///
/// State-aware (blueprint Step 5a): biometric is auto-prompted only when the
/// user preference is on AND the device actually supports it; otherwise PIN
/// entry is shown directly (never a silent unlock — see
/// `AuthController.unlockWithBiometrics`'s no-hardware fix). When biometric
/// IS attempted and a PIN exists, a "Use PIN instead" fallback is always
/// offered, covering cancel/failure without a second biometric retry loop.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _prompting = false;
  bool _showPinEntry = false;
  bool _pinSubmitting = false;
  String? _pinError;
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptInitialUnlock());
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  bool get _hasPin => ref.read(authControllerProvider).user?.hasPin ?? false;

  Future<void> _attemptInitialUnlock() async {
    final biometricEnabled = ref.read(biometricPreferenceProvider);
    if (!biometricEnabled) {
      setState(() => _showPinEntry = true);
      return;
    }
    await _attemptBiometric();
  }

  Future<void> _attemptBiometric() async {
    setState(() => _prompting = true);
    await ref.read(authControllerProvider.notifier).unlockWithBiometrics();
    // On failure/cancel/no-hardware, stay on the biometric retry button —
    // its "Use PIN instead" link (shown whenever hasPin) is the deliberate,
    // user-driven way to switch, not an automatic one.
    if (mounted) setState(() => _prompting = false);
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text;
    setState(() {
      _pinSubmitting = true;
      _pinError = null;
    });
    final ok = await ref.read(authControllerProvider.notifier).unlockWithPin(
          pin,
          verifyPin: ref.read(securityApiProvider).verifyPin,
        );
    if (!mounted) return;
    setState(() {
      _pinSubmitting = false;
      if (!ok) _pinError = 'Incorrect PIN';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text('Piggybank is locked', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              if (_showPinEntry) ...[
                TextField(
                  controller: _pinController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(labelText: 'PIN', errorText: _pinError, counterText: ''),
                  onSubmitted: (_) => _pinSubmitting ? null : _submitPin(),
                ),
                const SizedBox(height: 12),
                if (_pinSubmitting)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(onPressed: _submitPin, child: const Text('Unlock')),
                if (ref.read(biometricPreferenceProvider)) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _showPinEntry = false),
                    child: const Text('Use biometrics instead'),
                  ),
                ],
              ] else if (_prompting)
                const CircularProgressIndicator()
              else ...[
                ElevatedButton(onPressed: _attemptBiometric, child: const Text('Unlock')),
                if (_hasPin) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _showPinEntry = true),
                    child: const Text('Use PIN instead'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
