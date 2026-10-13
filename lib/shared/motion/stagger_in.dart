import 'package:flutter/widgets.dart';

import '../../core/theme/app_motion.dart';

/// The first rows of a list arriving after its skeleton (visual spec M11,
/// the `stagger` token): each fades in and rises 8 dp over 200 ms, starting
/// 30 ms after the one above it. Only the first [AppMotion.staggerMax] rows
/// take part; the rest are on screen at once.
///
/// It plays once, when the row first mounts, so a refresh or a rebuild of
/// the same list doesn't replay it. Under reduced motion the row is simply
/// there.
class StaggerIn extends StatefulWidget {
  const StaggerIn({required this.index, required this.child, super.key});

  /// The row's position in the list, from 0.
  final int index;
  final Widget child;

  /// How far a row rises, in logical pixels.
  static const rise = 8.0;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final Animation<double> _t;

  bool get _staggers => widget.index < AppMotion.staggerMax;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || !_staggers || context.reducedMotion) return;
    final delay = AppMotion.stagger * widget.index;
    final total = delay + AppMotion.stateChange;
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    _t = CurvedAnimation(
      parent: controller,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: AppMotion.easeOut),
    );
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || context.reducedMotion) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, StaggerIn.rise * (1 - _t.value)), child: child),
      ),
    );
  }
}
