import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/submit_button.dart';
import '../widgets/auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;
  Map<String, String>? _fieldErrors;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
      _fieldErrors = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim().isEmpty ? null : _fullNameController.text.trim(),
          );
      unawaited(AppHaptics.light());
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // QA_PRODUCTION_AUDIT_2026-09-11.md M4: a server-side field error (e.g.
  // "String should have at least 8 characters") previously stayed on screen
  // until the next _submit() call, even after the user had already fixed the
  // field -- clear it live as soon as the user edits that field again.
  void _clearFieldError(String field) {
    if (_fieldErrors?[field] == null) return;
    setState(() {
      _fieldErrors = {..._fieldErrors!}..remove(field);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: AuthLayout(
        subtitle: "Let's get you started",
        card: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full name (optional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpace.s16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _clearFieldError('email'),
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: _fieldErrors?['email'],
              ),
            ),
            const SizedBox(height: AppSpace.s16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => _clearFieldError('password'),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                errorText: _fieldErrors?['password'],
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            // Helper text per assets/register.jpeg.
            Text(
              'Use at least 8 characters with a mix of letters, numbers & symbols.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.s16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppSpace.s20),
            SubmitButton(label: 'Create account', busy: _submitting, onPressed: _submit),
          ],
        ),
        // The reciprocal toggle link back to Login (DESIGN.md §1).
        footer: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ),
    );
  }
}
