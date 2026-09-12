import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// A rounded card with a small triangular tail pointing up toward
/// `PennyAvatar`, carrying one tour page's title + body. Slides up and
/// fades in whenever its content changes. Stateless from the outside — no
/// Riverpod/go_router/`OnboardingScreen` dependency.
class SpeechBubble extends StatefulWidget {
  const SpeechBubble({required this.title, required this.body, super.key});

  final String title;
  final String body;

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
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) => Opacity(
        opacity: _curved.value,
        child: Transform.translate(offset: Offset(0, (1 - _curved.value) * 16), child: child),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(16, 8),
            painter: _TailPainter(
              color: Theme.of(context).cardColor,
              borderColor: Theme.of(context).colorScheme.outline,
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(widget.body, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    // Card's own border comes from CardThemeData; the tail needs its own
    // stroke on the two visible edges — its fill otherwise matches the
    // background exactly in light mode, making it disappear entirely.
    canvas.drawLine(Offset(size.width / 2, 0), Offset(0, size.height), Paint()..color = borderColor);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width, size.height), Paint()..color = borderColor);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}
