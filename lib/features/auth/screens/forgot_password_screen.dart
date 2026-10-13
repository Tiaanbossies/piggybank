import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/mascot_moment.dart';
import '../../../shared/widgets/submit_button.dart';
import '../widgets/auth_layout.dart';

/// Step 1 of the self-service password-reset flow: collect an email and
/// request a reset code. Always succeeds from the user's point of view
/// (the backend returns 204 whether or not the email is registered, to
/// avoid leaking account existence), so the UI shows the same "check your
/// email" confirmation regardless.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).requestPasswordReset(email);
      if (mounted) setState(() => _sent = true);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailController.text.trim();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: AuthLayout(
        pose: MascotMoment.thinking,
        card: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_sent) ...[
              Text(
                "Enter your account's email address and we'll send you a code to reset your password.",
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpace.s20),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.s16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpace.s20),
              SubmitButton(label: 'Send reset code', busy: _submitting, onPressed: _submit),
            ] else ...[
              Icon(Icons.mark_email_read_outlined, size: 56, color: context.tokens.primary),
              const SizedBox(height: AppSpace.s16),
              Text(
                'If an account exists for that email, a reset code is on its way.',
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpace.s20),
              ElevatedButton(
                onPressed: () => context.push('/reset-password', extra: email),
                child: const Text('I have my code'),
              ),
            ],
          ],
        ),
        footer: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Back to log in'),
          ),
        ],
      ),
    );
  }
}
