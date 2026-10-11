import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/biometric_preference.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/icon_chip.dart';
import '../../../shared/widgets/submit_button.dart';
import '../../settings/data/security_api.dart';
import '../widgets/auth_layout.dart';

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
    final ok = await ref.read(authControllerProvider.notifier).unlockWithBiometrics();
    // Unlocked: the router rises into the shell (M34).
    if (ok) unawaited(AppHaptics.light());
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
    if (ok) unawaited(AppHaptics.light());
    if (!mounted) return;
    setState(() {
      _pinSubmitting = false;
      if (!ok) _pinError = 'Incorrect PIN';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final biometricPreferred = ref.read(biometricPreferenceProvider);
    final logOut = TextButton(
      onPressed: () => ref.read(authControllerProvider.notifier).logout(),
      child: const Text('Log out'),
    );
    return Scaffold(
      body: AuthLayout(
        subtitle: 'Piggybank is locked',
        card: _showPinEntry
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PinBoxes(controller: _pinController, hasError: _pinError != null),
                  if (_pinError != null) ...[
                    const SizedBox(height: AppSpace.s12),
                    Text(
                      _pinError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s20),
                  SubmitButton(
                    key: const Key('unlock-submit'),
                    label: 'Unlock',
                    busy: _pinSubmitting,
                    onPressed: _submitPin,
                  ),
                ],
              )
            : Column(
                children: [
                  if (_prompting)
                    const SizedBox.square(dimension: 72, child: Center(child: CircularProgressIndicator()))
                  else
                    Semantics(
                      button: true,
                      label: 'Unlock with biometrics',
                      child: GestureDetector(
                        onTap: _attemptBiometric,
                        child: const IconChip(icon: Icons.fingerprint, size: 72),
                      ),
                    ),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    'Tap to unlock with biometrics',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted),
                  ),
                ],
              ),
        footer: [
          if (_showPinEntry && biometricPreferred)
            TextButton(
              onPressed: () => setState(() => _showPinEntry = false),
              child: const Text('Use biometrics instead'),
            ),
          if (!_showPinEntry && !_prompting && _hasPin)
            TextButton(
              onPressed: () => setState(() => _showPinEntry = true),
              child: const Text('Use PIN instead'),
            ),
          logOut,
        ],
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
  Timer? _flashTimer;
  bool _flash = false;

  /// How long the dots stay danger after a wrong PIN (M33).
  static const flashFor = AppMotion.dangerFlash;

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
    if (widget.hasError && !oldWidget.hasError) {
      // Errors are visual only: no haptic (spec §1.8).
      if (!context.reducedMotion) _shakeController.forward(from: 0);
      _flashTimer?.cancel();
      _flash = true;
      _flashTimer = Timer(flashFor, () {
        if (mounted) setState(() => _flash = false);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _flashTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final value = widget.controller.text;
    final colour = _flash ? t.danger : t.outline;
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
                    key: Key('pin-box-$i'),
                    width: 40,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.sunk,
                      borderRadius: AppRadius.tileAll,
                      border: Border.all(color: colour, width: _flash ? 1.5 : 1),
                    ),
                    child: Text(
                      i < value.length ? '•' : '',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: _flash ? t.danger : t.ink),
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
