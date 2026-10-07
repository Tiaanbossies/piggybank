import 'package:flutter/material.dart';

/// What sits behind a card while it's swiped: a coloured slab with the
/// action's icon and name on the side the swipe reveals. Extracted from
/// `pending_review_screen.dart` so the Savings plan's suggestions can
/// swipe the same way.
class SwipeBackground extends StatelessWidget {
  const SwipeBackground({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.alignment,
    this.bottomMargin = 12,
    super.key,
  });
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final Alignment alignment;

  /// Matches the card's own bottom margin, so the slab lines up with it.
  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
