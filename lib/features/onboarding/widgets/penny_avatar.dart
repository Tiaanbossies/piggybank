import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// Penny the mascot, presented for the onboarding tour with a continuous
/// subtle idle "bob". Reuses the `ClipRRect` + `Image.asset` presentation
/// already established in `login_screen.dart`, parameterized by size.
/// Stateless from the outside — no Riverpod/go_router dependency.
class PennyAvatar extends StatefulWidget {
  const PennyAvatar({this.size = 120, super.key});

  final double size;

  @override
  State<PennyAvatar> createState() => _PennyAvatarState();
}

class _PennyAvatarState extends State<PennyAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.valueTransition,
  );
  late final Animation<double> _bob = Tween<double>(
    begin: -4,
    end: 4,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.easeInOut));

  @override
  void initState() {
    super.initState();
    // MediaQuery isn't reliably available yet in initState, so this checks
    // the platform accessibility flag directly (same underlying signal
    // MediaQuery.disableAnimations reads from).
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(offset: Offset(0, _bob.value), child: child),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset('assets/mascot.jpg', width: widget.size, height: widget.size, fit: BoxFit.cover),
      ),
    );
  }
}
