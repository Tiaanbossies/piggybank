import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_motion.dart';

/// The extended pill FAB that folds to its icon while the list under it
/// scrolls down, and opens again on the way back up (visual spec §3, M42:
/// 150 ms). Instant under reduced motion. Screens hand it the list's
/// [controller].
class ShrinkingFab extends StatefulWidget {
  const ShrinkingFab({
    required this.controller,
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final ScrollController controller;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<ShrinkingFab> createState() => _ShrinkingFabState();
}

class _ShrinkingFabState extends State<ShrinkingFab> {
  bool _extended = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ShrinkingFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    final extended = switch (position.userScrollDirection) {
      ScrollDirection.reverse => position.pixels <= 0,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _extended,
    };
    if (extended != _extended) setState(() => _extended = extended);
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: widget.onPressed,
      tooltip: widget.label,
      isExtended: _extended,
      icon: Icon(widget.icon),
      label: AnimatedSize(
        duration: context.reducedMotion ? Duration.zero : AppMotion.feedback,
        curve: AppMotion.easeOut,
        child: _extended ? Text(widget.label) : const SizedBox.shrink(),
      ),
    );
  }
}
