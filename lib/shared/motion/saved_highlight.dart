import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_motion.dart';

/// The row a sheet just saved, so its list can show where it went (UX rework
/// spec §3.2, N3/N7). UI-only state.
typedef SavedRow = ({String id, DateTime at});

final savedRowProvider = StateProvider<SavedRow?>((ref) => null);

/// Called by a sheet after a successful save, before it closes.
void markSaved(WidgetRef ref, String id) =>
    ref.read(savedRowProvider.notifier).state = (id: id, at: DateTime.now());

/// How long a save stays worth pointing at. A row that only comes into view
/// later (saved from Home, say, then Transactions opened a minute after)
/// shouldn't flash.
const _fresh = Duration(seconds: 3);

/// The tint holds while the sheet slides away, then fades over 600 ms, so
/// the fade is what you actually see ("the sheet closes, then the row
/// highlights"). One controller, no timers.
const _hold = AppMotion.pageTransition;
const _fadeMs = 600;
final highlightDuration = _hold + const Duration(milliseconds: _fadeMs);

/// Tints its row, on top of it, and fades the tint out when [id] is the row
/// just saved. Skipped under reduced motion.
class SavedHighlight extends ConsumerStatefulWidget {
  const SavedHighlight({
    required this.id,
    required this.child,
    this.radius = 0,
    this.inset = EdgeInsets.zero,
    super.key,
  });

  final String id;
  final Widget child;

  /// The row's corner radius.
  final double radius;

  /// Keeps the tint off a card's outer margin.
  final EdgeInsets inset;

  @override
  ConsumerState<SavedHighlight> createState() => _SavedHighlightState();
}

class _SavedHighlightState extends ConsumerState<SavedHighlight> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: highlightDuration,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    // A row built after the save (a new one, or a list that refetched) checks
    // once on its first frame; a row already on screen hears it below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybePlay(ref.read(savedRowProvider));
    });
  }

  void _maybePlay(SavedRow? saved) {
    if (saved == null || saved.id != widget.id) return;
    if (DateTime.now().difference(saved.at) > _fresh) return;
    if (context.reducedMotion) return;
    ref.read(savedRowProvider.notifier).state = null;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(savedRowProvider, (_, saved) => _maybePlay(saved));
    final tint = Theme.of(context).colorScheme.primary;
    final holdFraction = _hold.inMilliseconds / highlightDuration.inMilliseconds;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          left: widget.inset.left,
          top: widget.inset.top,
          right: widget.inset.right,
          bottom: widget.inset.bottom,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final fade = t <= holdFraction ? 0.0 : (t - holdFraction) / (1 - holdFraction);
                final alpha = 0.16 * (1 - AppMotion.easeOut.transform(fade));
                if (alpha == 0) return const SizedBox.shrink();
                return DecoratedBox(
                  key: const Key('saved-highlight'),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: alpha),
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
