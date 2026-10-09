import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// A row that grows into the screen it opens (UX rework spec §3.1:
/// container transform), from the first-party `animations` package (A1).
/// Under reduced motion it's a plain push, the same as before.
///
/// [closedBuilder] gets the callback that opens the screen; wire it to the
/// row's own onTap so its ink, keys and long-press stay as they were.
class ContainerTransform extends StatelessWidget {
  const ContainerTransform({required this.closedBuilder, required this.openBuilder, this.radius = 0, super.key});

  final Widget Function(BuildContext context, VoidCallback open) closedBuilder;
  final WidgetBuilder openBuilder;

  /// The row's corner radius, so the shape morphs from it.
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (context.reducedMotion) {
      return closedBuilder(
        context,
        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: openBuilder)),
      );
    }
    return OpenContainer<void>(
      transitionDuration: AppMotion.pageTransition,
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      middleColor: Theme.of(context).colorScheme.surface,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      tappable: false,
      // Mid-transform the row is drawn in the overlay, outside its card, so
      // its InkWell needs a Material of its own.
      closedBuilder: (context, open) =>
          Material(type: MaterialType.transparency, child: closedBuilder(context, open)),
      openBuilder: (context, _) => openBuilder(context),
    );
  }
}
