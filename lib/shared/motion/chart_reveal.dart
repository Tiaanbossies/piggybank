import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_motion.dart';

/// How a chart draws itself in (visual spec M24).
enum ChartRevealStyle {
  /// Left to right: a line chart or a stacked bar.
  wipe,

  /// Clockwise from twelve o'clock: a donut.
  sweep,
}

/// Draws [child] in over [AppMotion.chartDraw] ease-out when it first
/// appears, and again whenever [revealKey] changes (new data, a new period).
/// Under reduced motion the chart is simply there.
class ChartReveal extends StatefulWidget {
  const ChartReveal({required this.child, this.style = ChartRevealStyle.wipe, this.revealKey, super.key});

  final Widget child;
  final ChartRevealStyle style;

  /// A change replays the draw.
  final Object? revealKey;

  @override
  State<ChartReveal> createState() => _ChartRevealState();
}

class _ChartRevealState extends State<ChartReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: AppMotion.chartDraw);
  late final Animation<double> _progress = CurvedAnimation(parent: _draw, curve: AppMotion.easeOut);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(ChartReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealKey != widget.revealKey) _play();
  }

  void _play() {
    if (context.reducedMotion) {
      _draw.value = 1;
    } else {
      _draw.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) {
        final v = _progress.value;
        if (v >= 1) return child!;
        return switch (widget.style) {
          ChartRevealStyle.wipe => ClipRect(
              key: const Key('chart-reveal'),
              clipper: _WipeClipper(v),
              child: child,
            ),
          ChartRevealStyle.sweep => ClipPath(
              key: const Key('chart-reveal'),
              clipper: _SweepClipper(v),
              child: child,
            ),
        };
      },
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(_WipeClipper old) => old.progress != progress;
}

class _SweepClipper extends CustomClipper<Path> {
  const _SweepClipper(this.progress);
  final double progress;

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    // Past the corners, so the wedge covers the whole box at the end.
    final radius = size.longestSide;
    return Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false)
      ..close();
  }

  @override
  bool shouldReclip(_SweepClipper old) => old.progress != progress;
}

/// Calls [AppHaptics.selection] once each time a touched chart's datatip
/// moves to a new point (M24), not on every drag frame.
class DatatipHaptics {
  Object? _last;

  /// [spot] identifies the point under the finger; null when the finger
  /// lifts or leaves the data.
  void touched(Object? spot) {
    if (spot != null && spot != _last) unawaited(AppHaptics.selection());
    _last = spot;
  }
}
