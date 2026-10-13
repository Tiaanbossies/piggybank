import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';

/// An app-bar action for copy, share or export (M37). After [onPressed]
/// succeeds, a tick replaces the icon for [tickFor] with one light tap; the
/// caller still shows its snackbar. Under reduced motion the tick swaps in
/// without the fade.
class TickIconButton extends StatefulWidget {
  const TickIconButton({required this.icon, required this.tooltip, required this.onPressed, super.key});

  final IconData icon;
  final String tooltip;

  /// The action itself. The tick shows once it completes without throwing.
  final Future<void> Function() onPressed;

  static const tickFor = AppMotion.tickHold;

  @override
  State<TickIconButton> createState() => _TickIconButtonState();
}

class _TickIconButtonState extends State<TickIconButton> {
  Timer? _timer;
  bool _ticked = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _press() async {
    await widget.onPressed();
    if (!mounted) return;
    unawaited(AppHaptics.light());
    setState(() => _ticked = true);
    _timer?.cancel();
    _timer = Timer(TickIconButton.tickFor, () {
      if (mounted) setState(() => _ticked = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _press,
      icon: AnimatedSwitcher(
        duration: context.reducedMotion ? Duration.zero : AppMotion.feedback,
        switchInCurve: AppMotion.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(animation), child: child),
        ),
        child: _ticked
            ? Icon(Icons.check, key: const Key('action-tick'), color: context.tokens.primary)
            : Icon(widget.icon, key: const Key('action-icon')),
      ),
    );
  }
}
