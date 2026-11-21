import 'package:flutter/material.dart';

import '../../features/settings/screens/subscription_screen.dart';

/// Generic "Upgrade to PRO" prompt for a 402 [ApiError] (see
/// `ApiError.isPaywall`). Per `ui-ux-mockup-brief.md` §5.10 the backend
/// returns only a plain message string with no structured "which limit"
/// field, so this is deliberately generic rather than categorized.
/// "See Pro" opens the subscription screen; shared/ importing a feature
/// screen is deliberate (one file, no caller changes).
Future<void> showPaywallPrompt(BuildContext context, {required String message}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Upgrade to PRO'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            final navigator = Navigator.of(context); // outer context: the dialog's is gone after pop
            Navigator.of(dialogContext).pop();
            navigator.push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()));
          },
          child: const Text('See Pro'),
        ),
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK')),
      ],
    ),
  );
}
