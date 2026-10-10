import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';

/// The pill banner for "you have something waiting" (visual spec §3: the
/// review and update banners): primaryContainer, a leading icon, the
/// message and a chevron. It arrives by sliding down 8 dp and fading in
/// (M41: 200 ms ease-out); under reduced motion it's just there.
class AppBanner extends StatefulWidget {
  const AppBanner({required this.message, required this.onTap, this.icon, super.key});

  final String message;
  final VoidCallback onTap;
  final IconData? icon;

  /// How far the banner slides in from.
  static const slide = 8.0;

  @override
  State<AppBanner> createState() => _AppBannerState();
}

class _AppBannerState extends State<AppBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: AppMotion.stateChange);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reducedMotion) {
      _in.value = 1;
    } else {
      _in.forward();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final banner = Material(
      color: t.primaryContainer,
      borderRadius: AppRadius.pillAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20, color: t.onPrimaryContainer),
                  const SizedBox(width: AppSpace.s12),
                ],
                Expanded(
                  child: Text(
                    widget.message,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: t.onPrimaryContainer),
                  ),
                ),
                Icon(Icons.chevron_right, color: t.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
    final curved = CurvedAnimation(parent: _in, curve: AppMotion.easeOut);
    return AnimatedBuilder(
      animation: curved,
      child: banner,
      builder: (context, child) => Opacity(
        key: const Key('app-banner-in'),
        opacity: curved.value,
        child: Transform.translate(offset: Offset(0, -AppBanner.slide * (1 - curved.value)), child: child),
      ),
    );
  }
}
