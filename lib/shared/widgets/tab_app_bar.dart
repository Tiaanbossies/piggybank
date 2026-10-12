import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';
import '../motion/tab_retap.dart';

/// The one app bar every tab root uses (UX rework spec §1.2, visual spec
/// §3): the avatar, which opens Settings, then the title, then at most two
/// labelled actions plus an optional overflow menu.
///
/// Flat on `bg` until content scrolls under it; then it takes `surface` and
/// a hairline (M42, 150 ms). When its tab is tapped again at the root, it
/// scrolls the list to the top and flashes a 6 dp shadow (M2).
///
/// There's no notification bell. It had no feature behind it, and a control
/// that looks tappable and does nothing breaks the "signifiers must be true"
/// rule (principles N1, K1).
class TabAppBar extends StatefulWidget implements PreferredSizeWidget {
  const TabAppBar({
    required this.title,
    this.subtitle,
    this.titleLeading,
    this.actions = const [],
    this.bottom,
    super.key,
  });

  final String title;

  /// A muted second line under [title] (Penny's "Ask me anything…").
  final String? subtitle;

  /// A small mark before the title (Penny's avatar chip).
  final Widget? titleLeading;

  /// Two labelled actions, plus an optional overflow menu as the last item.
  final List<Widget> actions;

  /// A strip under the title row, such as Plan's month switcher.
  final PreferredSizeWidget? bottom;

  /// The avatar's route. Settings sits above the shell, not in it.
  static const settingsLocation = '/settings';

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  State<TabAppBar> createState() => _TabAppBarState();
}

class _TabAppBarState extends State<TabAppBar> with SingleTickerProviderStateMixin {
  ScrollNotificationObserverState? _observer;
  ValueNotifier<int>? _retaps;
  bool _scrolledUnder = false;

  /// The M2 shadow flash: up and back down over one page transition.
  late final AnimationController _flash = AnimationController(vsync: this, duration: AppMotion.pageTransition);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context)?..addListener(_onScroll);
    _retaps?.removeListener(_onRetap);
    _retaps = TabRetapScope.maybeOf(context)?..addListener(_onRetap);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    _retaps?.removeListener(_onRetap);
    _flash.dispose();
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification || !defaultScrollNotificationPredicate(notification)) return;
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return;
    final under = metrics.extentBefore > 0;
    if (under != _scrolledUnder) setState(() => _scrolledUnder = under);
  }

  void _onRetap() {
    // Every tab keeps its bar mounted; only the visible one, at its root,
    // answers.
    if (!TickerMode.valuesOf(context).enabled || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final controller = PrimaryScrollController.maybeOf(context);
    if (controller == null || !controller.hasClients) return;
    if (context.reducedMotion) {
      controller.jumpTo(0);
      return;
    }
    controller.animateTo(0, duration: AppMotion.pageTransition, curve: AppMotion.easeOut);
    _flash.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.actions.length <= 3, 'TabAppBar takes two actions plus an optional overflow menu.');
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final shadow = Theme.of(context).colorScheme.shadow;
    final bar = AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        key: const Key('tab-app-bar-avatar'),
        tooltip: 'Settings',
        onPressed: () => context.push(TabAppBar.settingsLocation),
        icon: CircleAvatar(
          radius: 20,
          backgroundColor: t.primaryContainer,
          foregroundColor: t.onPrimaryContainer,
          child: const Icon(Icons.person_outline, size: 20),
        ),
      ),
      titleTextStyle: text.headlineSmall,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.titleLeading != null) ...[widget.titleLeading!, const SizedBox(width: 10)],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title, overflow: TextOverflow.ellipsis),
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(fontSize: 12, color: t.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [...widget.actions, const SizedBox(width: 4)],
      bottom: widget.bottom,
    );
    return AnimatedBuilder(
      animation: _flash,
      child: AnimatedContainer(
        key: const Key('tab-app-bar-surface'),
        duration: context.reducedMotion ? Duration.zero : AppMotion.feedback,
        decoration: BoxDecoration(color: _scrolledUnder ? t.surface : t.bg),
        // Painted over the bar, so the hairline never takes height from it.
        foregroundDecoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: t.outline.withValues(alpha: _scrolledUnder ? 0.3 : 0)),
          ),
        ),
        child: bar,
      ),
      builder: (context, child) {
        final k = _flash.isAnimating ? math.sin(_flash.value * math.pi) : 0.0;
        return DecoratedBox(
          key: const Key('tab-app-bar-flash'),
          decoration: BoxDecoration(
            boxShadow: k <= 0
                ? null
                : [BoxShadow(color: shadow.withValues(alpha: 0.16 * k), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: child,
        );
      },
    );
  }
}
