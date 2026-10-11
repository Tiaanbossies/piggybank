import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/mascot_moment.dart';

/// The shared frame for login, register, lock and the password-reset pair
/// (visual spec §4.1): Penny at 140 dp, fading in once, then the wordmark in
/// primary, an optional line under it, then [card], then [footer] below the
/// card. Forgot and reset pass the thinking pose.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.card,
    this.pose = MascotMoment.welcoming,
    this.subtitle,
    this.footer = const [],
    super.key,
  });

  static const pennySize = 140.0;

  final String pose;
  final String? subtitle;
  final Widget card;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: MascotMoment(
                  key: const Key('auth-penny'),
                  asset: pose,
                  size: pennySize,
                  motion: MascotMotion.fadeIn,
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Text(
                'Piggybank',
                key: const Key('auth-wordmark'),
                textAlign: TextAlign.center,
                style: text.displaySmall?.copyWith(color: t.primary),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpace.s4),
                Text(subtitle!, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: t.muted)),
              ],
              const SizedBox(height: AppSpace.sectionGap),
              AppCard(child: card),
              if (footer.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s12),
                ...footer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
