import 'package:flutter/widgets.dart';

import '../../core/theme/app_motion.dart';

/// Shrinks a tappable card to 0.97 while a finger is on it (UX rework spec
/// §3.2), so a press reads as heard before the screen changes. It only
/// listens to the pointer and never claims the tap, so the child's own
/// InkWell or GestureDetector still handles it. Off under reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, super.key});
  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    if (context.reducedMotion) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppMotion.feedback,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}
