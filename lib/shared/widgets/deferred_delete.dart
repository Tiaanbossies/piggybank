import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_motion.dart';

/// Ids hidden from their list while an Undo window is open or the delete is
/// in flight (UX rework spec §5, approval A4). UI-only state: lists filter
/// it out of what their providers return.
///
/// A committed id is never removed: the refetch that follows no longer
/// contains it, and un-hiding it early would flash the row back while that
/// refetch is still loading.
final pendingDeletesProvider = StateProvider<Set<String>>((ref) => const {});

/// Undo instead of a confirm dialog, for a single-row delete. Copies the
/// review queue's deferred commit: the row hides now, an Undo snackbar shows
/// for 4 s, and [commit] runs only once it closes without Undo. On failure
/// the row comes back and the error shows in a snackbar.
///
/// Everything it needs is captured before the first await, so the caller can
/// pop its sheet straight after calling this. Killing the app inside the
/// window means nothing is deleted.
Future<void> deferDelete(
  BuildContext context, {
  required String id,
  required String message,
  required Future<void> Function(ProviderContainer container) commit,
}) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final pending = container.read(pendingDeletesProvider.notifier);

  void restore() => pending.state = {...pending.state}..remove(id);

  pending.state = {...pending.state, id};
  // The row leaves (M15): a medium tap marks it.
  unawaited(AppHaptics.medium());
  // Closing the previous snackbar commits its delete now rather than
  // queueing this one behind it.
  messenger.hideCurrentSnackBar();
  final reason = await messenger
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          // An action snackbar persists by default (Flutter 3.29+), which would
          // hold the delete back until the next action.
          persist: false,
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ),
      )
      .closed;

  if (reason == SnackBarClosedReason.action) {
    restore();
    // The row comes back (M16): a light tap.
    unawaited(AppHaptics.light());
    return;
  }
  try {
    await commit(container);
  } catch (e) {
    restore();
    messenger.showSnackBar(
      SnackBar(content: Text(e is ApiError ? e.message : "Couldn't delete it. It's back in the list.")),
    );
  }
}

/// A row that leaves with its delete and comes back with its Undo (visual
/// spec M15, M16). The list keeps building a row whose id is in
/// [pendingDeletesProvider]; this slides it 24 dp left and fades it over
/// 180 ms, then closes the gap over 200 ms. Undo grows it back and fades it
/// in over 200 ms. Under reduced motion it simply goes and returns.
class DeleteExit extends ConsumerWidget {
  const DeleteExit({required this.id, required this.child, super.key});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CollapseOut(gone: ref.watch(pendingDeletesProvider).contains(id), child: child);
  }
}

/// Collapses [child] away when [gone], and back when it isn't. With [slide]
/// the child first slides 24 dp left and fades (a row); without, it fades as
/// it collapses (a header that goes with its last row). A child that starts
/// out gone is simply not there.
class CollapseOut extends StatefulWidget {
  const CollapseOut({required this.gone, required this.child, this.slide = true, super.key});

  final bool gone;
  final Widget child;
  final bool slide;

  /// How far a leaving row slides.
  static const slideDistance = 24.0;

  /// The slide-and-fade before the gap closes.
  static const exit = Duration(milliseconds: 180);

  @override
  State<CollapseOut> createState() => _CollapseOutState();
}

class _CollapseOutState extends State<CollapseOut> with TickerProviderStateMixin {
  /// 0 in place, 1 slid out and faded.
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: CollapseOut.exit,
    reverseDuration: AppMotion.stateChange,
    value: widget.gone ? 1 : 0,
  );

  /// 1 full height, 0 collapsed.
  late final AnimationController _size = AnimationController(
    vsync: this,
    duration: AppMotion.stateChange,
    value: widget.gone ? 0 : 1,
  );

  @override
  void didUpdateWidget(CollapseOut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gone == widget.gone) return;
    if (context.reducedMotion) {
      _exit.value = widget.gone ? 1 : 0;
      _size.value = widget.gone ? 0 : 1;
    } else if (widget.gone) {
      if (widget.slide) {
        _exit.forward().whenComplete(() {
          if (mounted && widget.gone) _size.reverse();
        });
      } else {
        _exit.forward();
        _size.reverse();
      }
    } else {
      _exit.reverse();
      _size.forward();
    }
  }

  @override
  void dispose() {
    _exit.dispose();
    _size.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exit = CurvedAnimation(parent: _exit, curve: AppMotion.easeOut);
    return AnimatedBuilder(
      animation: Listenable.merge([_exit, _size]),
      child: widget.child,
      builder: (context, child) {
        final gone = _size.value == 0;
        return IgnorePointer(
          ignoring: widget.gone,
          child: ExcludeSemantics(
            excluding: widget.gone,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: AppMotion.easeInOut.transform(_size.value),
                child: gone
                    ? null
                    : Opacity(
                        key: const Key('delete-exit'),
                        opacity: 1 - exit.value,
                        child: Transform.translate(
                          offset: Offset(widget.slide ? -CollapseOut.slideDistance * exit.value : 0, 0),
                          child: child,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
