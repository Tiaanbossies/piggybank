import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_motion.dart';

/// A money figure that counts to its new value when it changes (UX rework
/// spec §3.2), instead of snapping. The first build shows [text] as is: only
/// a change animates. Tabular figures keep the digits from jittering while
/// they roll.
///
/// The last frame always shows [text] itself, so the settled figure is
/// exactly what the caller formatted, never a re-formatted double.
class CountUpText extends StatefulWidget {
  const CountUpText({required this.text, required this.amount, this.style, super.key});

  /// The settled, formatted figure.
  final String text;

  /// The same figure as a number, to animate between.
  final double amount;
  final TextStyle? style;

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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.amount),
      duration: AppMotion.valueTransition,
      curve: AppMotion.easeOut,
      onEnd: () => setState(() => _from = widget.amount),
      builder: (context, value, _) =>
          Text(value == widget.amount ? widget.text : formatZAR(value), style: style),
    );
  }
}
