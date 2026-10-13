import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/submit_button.dart';
import '../widgets/auth_layout.dart';

/// The server answers a wrong login with a bare "invalid credentials", and a
/// malformed one with the validator's own words ("password: String should
/// have at least 8 characters"). Neither reads well on the login screen.
/// A password too short to be valid is still just a wrong password, so it
/// gets the same message; any other error keeps the server's wording.
String loginErrorMessage(ApiError error) {
  const wrong = 'Incorrect email or password.';
  if (error.isUnauthorized) return wrong;
  if (error.isValidation) {
    return (error.fieldErrors?.keys.any((field) => field.endsWith('email')) ?? false)
        ? 'Enter a valid email address.'
        : wrong;
  }
  return error.message;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // Signed in: the router rises into the shell (M35).
      unawaited(AppHaptics.light());
    } on ApiError catch (e) {
      setState(() => _error = loginErrorMessage(e));
      if (mounted && !context.reducedMotion) _shakeController.forward(from: 0);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: AuthLayout(
        subtitle: 'All your wealth in one place',
        card: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: _shakeOffset,
              builder: (context, child) => Transform.translate(offset: Offset(_shakeOffset.value, 0), child: child),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
                    curve: AppMotion.easeOut,
                    alignment: Alignment.topCenter,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: AppSpace.s16),
                            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s20),
            SubmitButton(key: const Key('login-submit'), label: 'Log in', busy: _submitting, onPressed: _submit),
            const SizedBox(height: AppSpace.s4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
          ],
        ),
        footer: [
          TextButton(
            onPressed: () => context.push('/register'),
            child: const Text("Don't have an account? Register"),
          ),
          const SizedBox(height: AppSpace.s12),
          // Reassurance line per DESIGN.md § 1 / assets/login.jpeg.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: t.primary),
              const SizedBox(width: AppSpace.s8),
              Flexible(
                child: Text(
                  'Your data is secure and private. Piggybank is protected with bank-level security.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: t.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
