import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/app_motion.dart';

/// Presses a tappable card down to 0.97 while a finger is on it and lets it
/// spring back on release (visual spec M4, [AppMotion.springPress]), so a
/// press reads as heard before the screen changes. The scale starts on
/// pointer-down, not on the tap. It only listens to the pointer and never
/// claims the tap, so the child's own InkWell or GestureDetector still
/// handles it. Under reduced motion there's no scale; the child's ripple is
/// the feedback.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, super.key});
  final Widget child;

  /// How far down a press goes.
  static const pressedScale = 0.97;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: 1);

  void _springTo(double target) {
    _scale.animateWith(SpringSimulation(AppMotion.springPress, _scale.value, target, _scale.velocity));
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reducedMotion) return widget.child;
    return Listener(
      onPointerDown: (_) => _springTo(PressScale.pressedScale),
      onPointerUp: (_) => _springTo(1),
      onPointerCancel: (_) => _springTo(1),
      child: AnimatedBuilder(
        animation: _scale,
        child: widget.child,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
      ),
    );
  }
}
