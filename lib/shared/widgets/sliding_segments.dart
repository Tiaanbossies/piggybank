import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';

/// The segmented control (visual spec §3, M25): a pill track in `sunk` with
/// a `surface` thumb at level 1 that slides to the chosen segment on
/// [AppMotion.springSettle]. A change gives one selection tick. Under
/// reduced motion the thumb cuts straight across.
class SlidingSegments<T> extends StatefulWidget {
  const SlidingSegments({required this.segments, required this.selected, required this.onChanged, super.key});

  /// Each value with its label, in order.
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  static const height = 48.0;
  static const _inset = 4.0;

  @override
  State<SlidingSegments<T>> createState() => _SlidingSegmentsState<T>();
}

class _SlidingSegmentsState<T> extends State<SlidingSegments<T>> with SingleTickerProviderStateMixin {
  /// The thumb's position, in segments from the left.
  late final AnimationController _thumb = AnimationController.unbounded(vsync: this, value: _index.toDouble());

  int get _index => widget.segments.indexWhere((s) => s.$1 == widget.selected).clamp(0, widget.segments.length - 1);

  @override
  void didUpdateWidget(SlidingSegments<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _index.toDouble();
    if (_thumb.value == target && !_thumb.isAnimating) return;
    if (context.reducedMotion) {
      _thumb.value = target;
    } else {
      _thumb.animateWith(SpringSimulation(AppMotion.springSettle, _thumb.value, target, _thumb.velocity));
    }
  }

  @override
  void dispose() {
    _thumb.dispose();
    super.dispose();
  }

  void _tap(T value) {
    if (value == widget.selected) return;
    unawaited(AppHaptics.selection());
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme.labelLarge;
    const inset = SlidingSegments._inset;
    return Container(
      height: SlidingSegments.height,
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(color: t.sunk, borderRadius: AppRadius.pillAll),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / widget.segments.length;
          return Stack(
            children: [
              AnimatedBuilder(
                animation: _thumb,
                builder: (context, _) => Positioned(
                  key: const Key('segment-thumb'),
                  left: _thumb.value * width,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: AppRadius.pillAll,
                      boxShadow: AppShadows.level1(Theme.of(context).brightness),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (value, label) in widget.segments)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: value == widget.selected,
                        child: InkWell(
                          key: Key('segment-$label'),
                          borderRadius: AppRadius.pillAll,
                          onTap: () => _tap(value),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: context.reducedMotion ? Duration.zero : AppMotion.feedback,
                              style: (text ?? const TextStyle()).copyWith(
                                color: value == widget.selected ? t.ink : t.muted,
                              ),
                              child: Text(label),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
