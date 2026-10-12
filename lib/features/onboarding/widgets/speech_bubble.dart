import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/bubble_border.dart';

/// A surface bubble (radius 24, a 12 dp tail up toward `PennyAvatar`,
/// visual spec §3) carrying one tour page's title, body and optional tab
/// icon. Slides up and
/// fades in whenever its content changes. Stateless from the outside — no
/// Riverpod/go_router/`OnboardingScreen` dependency.
class SpeechBubble extends StatefulWidget {
  const SpeechBubble({required this.title, required this.body, this.icon, super.key});

  final String title;
  final String body;

  /// The tab this page is about, shown beside the title.
  final IconData? icon;

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.stateChange,
    value: 1,
  );
  late final Animation<double> _curved = CurvedAnimation(parent: _controller, curve: AppMotion.easeOut);

  @override
  void initState() {
    super.initState();
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(SpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.title != oldWidget.title || widget.body != oldWidget.body) &&
        !MediaQuery.of(context).disableAnimations) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) => Opacity(
        opacity: _curved.value,
        child: Transform.translate(offset: Offset(0, (1 - _curved.value) * 16), child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.cardPad),
        decoration: ShapeDecoration(
          color: t.surface,
          shape: const BubbleBorder(tail: BubbleTail.up),
          shadows: AppShadows.level1(Theme.of(context).brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: t.primary),
                  const SizedBox(width: AppSpace.s8),
                ],
                Expanded(child: Text(widget.title, style: text.titleLarge)),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            Text(widget.body, style: text.bodyLarge),
          ],
        ),
      ),
    );
  }
}
