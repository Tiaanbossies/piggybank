import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_motion.dart';

/// A card swiped sideways to act on it (visual spec M18, M19): it follows
/// the finger over its [background] (swiping right) or
/// [secondaryBackground] (swiping left). Past [threshold] of its width it
/// gives one light tap; let go there and it slides off and closes its gap,
/// then [onSwiped] runs. Let go short of it and it springs back on
/// [AppMotion.springSettle]; under reduced motion it eases back with no
/// overshoot, and a committed swipe leaves at once.
///
/// [direction] works as on [Dismissible]: horizontal, startToEnd (right
/// only) or endToStart (left only).
class SpringSwipe extends StatefulWidget {
  const SpringSwipe({
    required this.child,
    required this.onSwiped,
    this.background,
    this.secondaryBackground,
    this.direction = DismissDirection.horizontal,
    this.threshold = 0.4,
    super.key,
  });

  final Widget child;
  final ValueChanged<DismissDirection> onSwiped;
  final Widget? background;
  final Widget? secondaryBackground;
  final DismissDirection direction;

  /// The share of the width a swipe has to pass to commit.
  final double threshold;

  /// A fling this fast commits whatever the distance (logical px/s).
  static const flingVelocity = 700.0;

  @override
  State<SpringSwipe> createState() => _SpringSwipeState();
}

class _SpringSwipeState extends State<SpringSwipe> with TickerProviderStateMixin {
  /// The card's offset in logical pixels; positive is to the right.
  late final AnimationController _dx = AnimationController.unbounded(vsync: this);

  /// 1 full height, 0 collapsed after a committed swipe.
  late final AnimationController _size = AnimationController(vsync: this, duration: AppMotion.stateChange, value: 1);

  double _width = 1;
  bool _pastThreshold = false;
  bool _committed = false;

  bool get _allowsRight => widget.direction != DismissDirection.endToStart;
  bool get _allowsLeft => widget.direction != DismissDirection.startToEnd;

  @override
  void dispose() {
    _dx.dispose();
    _size.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_committed) return;
    _dx.stop();
    var next = _dx.value + details.primaryDelta!;
    if (next > 0 && !_allowsRight) next = 0;
    if (next < 0 && !_allowsLeft) next = 0;
    _dx.value = next;
    final past = next.abs() >= _width * widget.threshold;
    if (past && !_pastThreshold) unawaited(AppHaptics.light());
    _pastThreshold = past;
  }

  Future<void> _onEnd(DragEndDetails details) async {
    if (_committed) return;
    final velocity = details.primaryVelocity ?? 0;
    final value = _dx.value;
    final fling = velocity.abs() >= SpringSwipe.flingVelocity &&
        ((velocity > 0 && _allowsRight && value >= 0) || (velocity < 0 && _allowsLeft && value <= 0));
    if (value.abs() >= _width * widget.threshold || fling) {
      await _commit(value != 0 ? value.sign : velocity.sign);
    } else {
      _settleBack(velocity);
    }
  }

  void _settleBack(double velocity) {
    _pastThreshold = false;
    if (context.reducedMotion) {
      _dx.animateTo(0, duration: AppMotion.feedback, curve: AppMotion.easeOut);
    } else {
      _dx.animateWith(SpringSimulation(AppMotion.springSettle, _dx.value, 0, velocity));
    }
  }

  Future<void> _commit(double sign) async {
    _committed = true;
    final direction = sign > 0 ? DismissDirection.startToEnd : DismissDirection.endToStart;
    if (context.reducedMotion) {
      _dx.value = sign * _width;
      _size.value = 0;
    } else {
      await _dx.animateTo(sign * _width, duration: AppMotion.stateChange, curve: AppMotion.easeOut);
      if (!mounted) return;
      await _size.reverse();
    }
    if (mounted) widget.onSwiped(direction);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 1;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          child: AnimatedBuilder(
            animation: Listenable.merge([_dx, _size]),
            child: widget.child,
            builder: (context, child) {
              final dx = _dx.value;
              final background = dx > 0 ? widget.background : (dx < 0 ? widget.secondaryBackground : null);
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: AppMotion.easeInOut.transform(_size.value.clamp(0.0, 1.0)),
                  child: Stack(
                    children: [
                      if (background != null) Positioned.fill(child: background),
                      Transform.translate(key: const Key('spring-swipe-card'), offset: Offset(dx, 0), child: child),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
