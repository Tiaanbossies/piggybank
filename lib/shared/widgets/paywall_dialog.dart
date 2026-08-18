import 'package:flutter/material.dart';

/// Generic "Upgrade to PRO" prompt for a 402 [ApiError] (see
/// `ApiError.isPaywall`). Per `ui-ux-mockup-brief.md` §5.10 the backend
/// returns only a plain message string with no structured "which limit"
/// field, so this is deliberately generic rather than categorized — and
/// dismiss-only, since upgrade/cancel have no real payment flow behind them
/// yet ("currently mocked" per the brief).
Future<void> showPaywallPrompt(BuildContext context, {required String message}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Upgrade to PRO'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
      ],
    ),
  );
}
