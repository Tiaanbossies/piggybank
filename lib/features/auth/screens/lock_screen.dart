import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/biometric_preference.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/icon_chip.dart';
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
///
/// A "Log out" action is always available in both branches — the escape
/// hatch for a device with no working unlock method (no biometric hardware/
/// enrollment and no PIN set, or a forgotten PIN), which the "never silently
/// unlock" invariant above would otherwise turn into a permanent lockout.
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Same mascot image as Login, smaller — this is a
                // returning-user screen, not a first impression.
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/mascot.jpg', width: 80, height: 80, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
                Text(
                  'Piggybank is locked',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 32),
                if (_showPinEntry) ...[
                  _PinBoxes(controller: _pinController, hasError: _pinError != null),
                  if (_pinError != null) ...[
                    const SizedBox(height: 12),
                    Text(_pinError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  if (_pinSubmitting)
                    const CircularProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(onPressed: _submitPin, child: const Text('Unlock')),
                    ),
                  if (ref.read(biometricPreferenceProvider)) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _showPinEntry = false),
                      child: const Text('Use biometrics instead'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                    child: const Text('Log out'),
                  ),
                ] else if (_prompting)
                  const CircularProgressIndicator()
                else ...[
                  GestureDetector(
                    onTap: _attemptBiometric,
                    child: const IconChip(icon: Icons.fingerprint, size: 72),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to unlock with biometrics',
                    style: TextStyle(color: Theme.of(context).extension<AppSemanticColors>()?.textMuted, fontSize: 13),
                  ),
                  if (_hasPin) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _showPinEntry = true),
                      child: const Text('Use PIN instead'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                    child: const Text('Log out'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 6-digit PIN entry rendered as individual boxes rather than one text field,
/// per DESIGN.md's Signature-components discipline (row-card shell aside,
/// this is the one purpose-built input the Lock screen needs — no delivered
/// mockup covers it). A hidden [TextField] drives real input (keyboard +
/// paste); the boxes are a visual overlay reflecting its value.
class _PinBoxes extends StatefulWidget {
  const _PinBoxes({required this.controller, required this.hasError});
  final TextEditingController controller;
  final bool hasError;

  @override
  State<_PinBoxes> createState() => _PinBoxesState();
}

class _PinBoxesState extends State<_PinBoxes> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _shakeController = AnimationController(vsync: this, duration: AppMotion.feedback);
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: AppMotion.easeOut));
  }

  @override
  void didUpdateWidget(_PinBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError && !MediaQuery.of(context).disableAnimations) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _shakeController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final border = Theme.of(context).colorScheme.outline;
    final danger = semantic?.danger ?? Theme.of(context).colorScheme.error;
    final value = widget.controller.text;
    return AnimatedBuilder(
      animation: _shakeOffset,
      builder: (context, child) => Transform.translate(offset: Offset(_shakeOffset.value, 0), child: child),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i != 0) const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.hasError ? danger : border, width: widget.hasError ? 1.5 : 1),
                    ),
                    child: Text(
                      i < value.length ? '•' : '',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ],
            ),
            Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                onSubmitted: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
