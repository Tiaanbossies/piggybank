import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Full-width green-gradient hero card per DESIGN.md § Signature components —
/// used once per screen, at the top, for Net Worth (Dashboard) and Total
/// balance (Accounts). Never repeated as a pattern for lesser numbers.
class HeroMetricCard extends StatelessWidget {
  const HeroMetricCard({required this.label, required this.value, this.deltaText, super.key});

  final String label;
  final String value;
  final String? deltaText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          if (deltaText != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                deltaText!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
