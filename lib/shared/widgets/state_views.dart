import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';
import '../motion/press_scale.dart';
import 'icon_chip.dart';
import 'mascot_moment.dart';

/// Shared "nothing to show yet" treatment — an accent [IconChip], a title,
/// and an optional hint line. Standardizes what used to be several
/// different ad-hoc empty-state treatments across the app (bare text on
/// Goals and the Dashboard's recent-transactions preview; a plain grey
/// icon + text on Budgets; the richest of the bunch on the Chatbot, whose
/// pattern this widget generalizes).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.hint,
    this.topPadding = 48,
    this.mascot = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final double topPadding;

  /// Penny welcoming, faded in, in place of the icon: for the lists a new
  /// user starts empty (Transactions, Goals, Savings; spec §3.3).
  final bool mascot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mascot)
              const MascotMoment(asset: MascotMoment.welcoming, size: 72, motion: MascotMotion.fadeIn)
            else
              IconChip(icon: icon, size: 56),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared "something went wrong" inline treatment — a small danger icon
/// plus muted-danger text, distinct from both an empty state and a silent
/// blank gap. Several async sections previously rendered `SizedBox.shrink()`
/// on error (e.g. the Dashboard's cashflow strip and budget-progress
/// block), giving no feedback at all when a fetch failed.
///
/// [onRetry] adds a Retry button (UX plan item 5): without one, a failed
/// load on a bad-signal moment was a dead end until the user left the
/// screen and came back. Callers pass a provider invalidate.
///
/// Visual spec M14: it fades in over 200 ms; Retry presses on the spring
/// and then shows a 16 dp ring until the next result arrives.
class InlineError extends StatefulWidget {
  const InlineError({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  /// The ring outlasts a fast failure by at least this long, so it reads
  /// as "tried again" rather than a flicker.
  static const minRetry = Duration(milliseconds: 400);

  /// Back to "Retry" after this even if nothing rebuilds the error.
  static const maxRetry = Duration(seconds: 10);

  @override
  State<InlineError> createState() => _InlineErrorState();
}

class _InlineErrorState extends State<InlineError> {
  bool _retrying = false;

  /// The ring has shown for [InlineError.minRetry].
  bool _minShown = false;

  /// Rebuilds since the tap. A retry rebuilds the error twice: once into
  /// "refreshing", once with the new result.
  int _updates = 0;
  Timer? _timer;
  Timer? _giveUp;

  void _retry() {
    setState(() {
      _retrying = true;
      _minShown = false;
      _updates = 0;
    });
    _timer?.cancel();
    _timer = Timer(InlineError.minRetry, () {
      _minShown = true;
      if (_updates >= 2) _done();
    });
    _giveUp?.cancel();
    _giveUp = Timer(InlineError.maxRetry, _done);
    widget.onRetry?.call();
  }

  void _done() {
    if (mounted && _retrying) setState(() => _retrying = false);
  }

  @override
  void didUpdateWidget(InlineError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_retrying) return;
    _updates++;
    if (_minShown) _retrying = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _giveUp?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 18, color: t.danger),
          const SizedBox(width: 8),
          Flexible(child: Text(widget.message, style: TextStyle(color: t.danger))),
          if (widget.onRetry != null) ...[
            const SizedBox(width: 4),
            PressScale(
              child: TextButton(
                onPressed: _retrying ? null : _retry,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_retrying) ...[
                      const SizedBox(
                        key: Key('retry-ring'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Text('Retry'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
    if (context.reducedMotion) return row;
    return TweenAnimationBuilder<double>(
      key: const Key('inline-error-in'),
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.stateChange,
      curve: AppMotion.easeOut,
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: row,
    );
  }
}
