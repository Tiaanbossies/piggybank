import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/theme/app_motion.dart';
import '../../../shared/widgets/mascot_moment.dart';

/// Penny for the onboarding tour, as a cutout straight on the surface
/// (visual spec §2). With [entrance] she fades in and springs up once
/// ([AppMotion.springPop]); otherwise, and always under reduced motion, she's
/// static. No looping idle motion: the old bob ran for the whole tour.
/// Stateless from the outside — no Riverpod/go_router dependency.
class PennyAvatar extends StatefulWidget {
  const PennyAvatar({this.size = 120, this.assetPath = MascotMoment.welcoming, this.entrance = false, super.key});

  final double size;
  final String assetPath;

  /// Play the one-off fade + spring when first shown (the tour's first page).
  final bool entrance;

  @override
  State<PennyAvatar> createState() => _PennyAvatarState();
}

class _PennyAvatarState extends State<PennyAvatar> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.entrance || context.reducedMotion) return;
    _controller = AnimationController.unbounded(vsync: this)
      ..addStatusListener(_onStatus)
      ..animateWith(SpringSimulation(AppMotion.springPop, 0, 1, 0));
  }

  /// Once the spring rests, drop the wrapper so no Opacity layer lingers at
  /// 0.9999.
  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      _controller?.dispose();
      _controller = null;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = PennyImage(widget.assetPath, size: widget.size);
    final controller = _controller;
    if (controller == null) return image;
    return AnimatedBuilder(
      animation: controller,
      child: image,
      builder: (context, child) => Opacity(
        key: const Key('penny-entrance'),
        opacity: controller.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: popScale(controller.value), child: child),
      ),
    );
  }
}
