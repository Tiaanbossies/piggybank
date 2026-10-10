import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../motion/press_scale.dart';

/// The one card shape (visual spec §3): `surface`, radius 24, padding 20,
/// a forest-tinted level-1 shadow in light and a tonal surface in dark.
/// With [onTap] the whole card is a button: it presses down on a spring
/// (M4) and ripples in primary at 8 %.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.cardPad),
    this.margin = EdgeInsets.zero,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// Fill override for the cards that carry their own tone (the hero).
  final Color? color;

  /// Read for the whole card when it's tappable.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fill = color ?? t.surface;
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        boxShadow: AppShadows.level1(Theme.of(context).brightness),
      ),
      child: Material(
        color: fill,
        borderRadius: AppRadius.cardAll,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                splashColor: t.primary.withValues(alpha: 0.08),
                highlightColor: Colors.transparent,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
    if (onTap != null) {
      card = PressScale(child: Semantics(button: true, label: semanticLabel, child: card));
    }
    return Padding(padding: margin, child: card);
  }
}
