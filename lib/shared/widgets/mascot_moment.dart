import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/shared_preferences_provider.dart';
import '../motion/once_per_day.dart';

/// How a mascot moment moves (UX rework spec §3.3, visual spec M31/M39).
enum MascotMotion {
  /// Scale 0.8 → 1 on [AppMotion.springPop], overshoot capped at 6 %.
  /// Rate-limited by [MascotMoment.kind]; otherwise the pose shows static.
  pop,

  /// A gentle 2 px bob for as long as it's on screen (Penny thinking).
  bob,

  /// A fade-in (empty states).
  fadeIn,

  /// None (Nothing spent today).
  none,
}

/// One Penny cutout, straight on the surface: no clip, no box, no ring
/// (visual spec §2). Decoded at the size it's drawn, since the cutouts are
/// up to 1024 px and Penny is usually 44–180 dp.
class PennyImage extends StatelessWidget {
  const PennyImage(this.asset, {required this.size, super.key});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: (size * dpr).round(),
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Penny, as a transparent cutout, for the moments that reward finishing
/// something (spec §3.3). Never used on over-budget, missed-target or error
/// states: those get plain numbers.
class MascotMoment extends ConsumerStatefulWidget {
  const MascotMoment({
    required this.asset,
    this.size = 44,
    this.motion = MascotMotion.none,
    this.kind,
    this.daily = true,
    super.key,
  });

  // The four poses (visual spec §2). The old default pose is retired.
  static const celebrating = 'assets/penny/celebrating.png';
  static const thinking = 'assets/penny/thinking.png';
  static const sleeping = 'assets/penny/sleeping.png';
  static const welcoming = 'assets/penny/welcoming.png';

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

/// Scale for a [MascotMotion.pop] at spring position [x] (0 → 1): 0.8 → 1,
/// never more than [AppMotion.popOvershootCap] past 1. Shared with the
/// onboarding [PennyAvatar] entrance.
double popScale(double x) => math.min(0.8 + 0.2 * x, 1 + AppMotion.popOvershootCap);

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
          _controller = AnimationController.unbounded(vsync: this)
            ..animateWith(SpringSimulation(AppMotion.springPop, 0, 1, 0));
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
    final image = PennyImage(widget.asset, size: widget.size);
    final controller = _controller;
    if (controller == null) return image;
    return AnimatedBuilder(
      animation: controller,
      child: image,
      builder: (context, child) {
        final t = controller.value;
        return switch (widget.motion) {
          MascotMotion.pop => Transform.scale(key: const Key('mascot-pop'), scale: popScale(t), child: child),
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
