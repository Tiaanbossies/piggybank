import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/shared_preferences_provider.dart';
import '../motion/once_per_day.dart';

/// How a mascot moment moves (UX rework spec §3.3).
enum MascotMotion {
  /// Scale 0.8 → 1 with a slight overshoot, 300 ms. Rate-limited by
  /// [MascotMoment.kind]; otherwise the pose shows static.
  pop,

  /// A gentle 2 px bob for as long as it's on screen (Penny thinking).
  bob,

  /// A fade-in (empty states).
  fadeIn,

  /// None (Nothing spent today).
  none,
}

/// Penny, clipped to a circle as the app already shows her, for the moments
/// that reward finishing something (spec §3.3). Never used on over-budget,
/// missed-target or error states: those get plain numbers.
///
/// Uses the existing jpg poses only; new or transparent poses would need
/// image generation, which waits for Tiaan's go-ahead.
class MascotMoment extends ConsumerStatefulWidget {
  const MascotMoment({
    required this.asset,
    this.size = 44,
    this.motion = MascotMotion.none,
    this.kind,
    this.daily = true,
    super.key,
  });

  static const celebrating = 'assets/mascot_celebrating.jpg';
  static const thinking = 'assets/mascot_thinking.jpg';
  static const sleeping = 'assets/mascot_sleeping.jpg';
  static const welcoming = 'assets/mascot_welcoming.jpg';

  final String asset;
  final double size;
  final MascotMotion motion;

  /// For [MascotMotion.pop]: which moment this is, so it plays at most once
  /// a day (or once ever, with [daily] false).
  final String? kind;
  final bool daily;

  @override
  ConsumerState<MascotMoment> createState() => _MascotMomentState();
}

class _MascotMomentState extends ConsumerState<MascotMoment> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reducedMotion) return;
    switch (widget.motion) {
      case MascotMotion.pop:
        if (_claim()) {
          _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
        }
      case MascotMotion.bob:
        _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
      case MascotMotion.fadeIn:
        _controller = AnimationController(vsync: this, duration: AppMotion.stateChange)..forward();
      case MascotMotion.none:
        break;
    }
  }

  bool _claim() {
    final kind = widget.kind;
    if (kind == null) return true;
    try {
      return claimMoment(ref.read(sharedPreferencesProvider), kind, daily: widget.daily);
    } catch (_) {
      // No preferences (a bare test harness): show the pose, skip the pop.
      return false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = ExcludeSemantics(
      child: ClipOval(
        child: Image.asset(widget.asset, width: widget.size, height: widget.size, fit: BoxFit.cover),
      ),
    );
    final controller = _controller;
    if (controller == null) return image;
    return AnimatedBuilder(
      animation: controller,
      child: image,
      builder: (context, child) {
        final t = controller.value;
        return switch (widget.motion) {
          MascotMotion.pop => Transform.scale(
              key: const Key('mascot-pop'),
              scale: 0.8 + 0.2 * Curves.easeOutBack.transform(t),
              child: child,
            ),
          MascotMotion.bob => Transform.translate(
              offset: Offset(0, -2 * math.sin(t * 2 * math.pi).abs()),
              child: child,
            ),
          MascotMotion.fadeIn => Opacity(opacity: AppMotion.easeOut.transform(t), child: child),
          MascotMotion.none => child!,
        };
      },
    );
  }
}
