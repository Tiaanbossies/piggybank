import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_motion.dart';

/// A money figure that counts to its new value when it changes (visual spec
/// M21: 400 ms ease-out), instead of snapping. The first build shows [text]
/// as is: only a change animates. Tabular figures keep the digits from
/// jittering while they roll.
///
/// The last frame always shows [text] itself, so the settled figure is
/// exactly what the caller formatted, never a re-formatted double. Under
/// reduced motion it's the final value at once.
class CountUpText extends StatefulWidget {
  const CountUpText({required this.text, required this.amount, this.style, this.format, super.key});

  /// The settled, formatted figure.
  final String text;

  /// The same figure as a number, to animate between.
  final double amount;
  final TextStyle? style;

  /// How an in-between value reads; [formatZAR] by default.
  final String Function(double value)? format;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> {
  late double _from = widget.amount;

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) _from = oldWidget.amount;
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    if (context.reducedMotion || _from == widget.amount) return Text(widget.text, style: style);
    final format = widget.format ?? formatZAR;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.amount),
      duration: AppMotion.valueTransition,
      curve: AppMotion.easeOut,
      onEnd: () => setState(() => _from = widget.amount),
      builder: (context, value, _) => Text(value == widget.amount ? widget.text : format(value), style: style),
    );
  }
}

/// A secondary figure that crossfades to its new text with a 4 dp slide in
/// the direction of change (visual spec M22: 150 ms): up when [amount] rose,
/// down when it fell. Instant under reduced motion.
class CrossfadeDigits extends StatefulWidget {
  const CrossfadeDigits({required this.text, required this.amount, this.style, super.key});

  final String text;
  final double amount;
  final TextStyle? style;

  /// How far the figure slides, in logical pixels.
  static const slide = 4.0;

  @override
  State<CrossfadeDigits> createState() => _CrossfadeDigitsState();
}

class _CrossfadeDigitsState extends State<CrossfadeDigits> {
  /// 1 when the last change went up, -1 when it went down.
  double _direction = 1;

  @override
  void didUpdateWidget(CrossfadeDigits oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.amount != oldWidget.amount) _direction = widget.amount > oldWidget.amount ? 1 : -1;
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final text = Text(widget.text, key: ValueKey(widget.text), style: style);
    if (context.reducedMotion) return text;
    return AnimatedSwitcher(
      duration: AppMotion.feedback,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(widget.text);
        // A rise enters from below and leaves upward; a fall the reverse.
        final from = (incoming ? 1 : -1) * _direction * CrossfadeDigits.slide;
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Opacity(
            opacity: animation.value,
            child: Transform.translate(offset: Offset(0, from * (1 - animation.value)), child: child),
          ),
        );
      },
      child: text,
    );
  }
}
