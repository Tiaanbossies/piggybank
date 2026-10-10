import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:go_router/go_router.dart';

import '../../shared/motion/tab_retap.dart';
import '../theme/app_haptics.dart';
import '../theme/app_motion.dart';
import '../theme/app_tokens.dart';

/// The 5-tab bottom-nav shell: Home, Transactions, Plan, Invest, Penny
/// (UX rework spec §1.1). Settings is not a tab; the avatar opens it. `navigationShell`
/// preserves each tab's own stack (StatefulShellRoute), so pushing e.g. the
/// add-account sheet from Home doesn't disturb Settings' state.
///
/// A `StatefulWidget` so it can see `currentIndex` change and play the tab
/// switch (UX rework spec §3.1: fade-through, replacing the old 1 → 0 → 1
/// opacity dip). `navigationShell` is never re-keyed or swapped: its
/// `IndexedStack` must keep every branch mounted, or each tab would lose its
/// scroll position and open sheets on every switch. That same IndexedStack
/// swaps tabs instantly, so the outgoing tab is already gone when the switch
/// is seen; only the fade-through's incoming half can play: the new tab
/// fades in from 0.92 scale over 160 ms. Instant under reduced motion.
///
/// Visual rework (spec §3, M1/M2): the selected-tab pill slides between
/// destinations on [AppMotion.springSettle], every tab tap is a selection
/// click, and re-tapping the open tab at its root scrolls it to the top
/// (through [TabRetapScope]).
class AppShell extends StatefulWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  /// The fade-through's incoming half (spec §3.1: in 160 ms).
  static const _fadeIn = Duration(milliseconds: 160);

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  final _retaps = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // Starts settled, so the first frame shows the tab, not a blank.
    _controller = AnimationController(vsync: this, duration: _fadeIn, value: 1);
    final curved = CurvedAnimation(parent: _controller, curve: AppMotion.easeOut);
    _opacity = curved;
    _scale = Tween(begin: 0.92, end: 1.0).animate(curved);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final indexChanged = oldWidget.navigationShell.currentIndex != widget.navigationShell.currentIndex;
    if (indexChanged && !context.reducedMotion) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _retaps.dispose();
    super.dispose();
  }

  void _select(int index) {
    AppHaptics.selection();
    final current = widget.navigationShell.currentIndex;
    // Heard before the pop, so the tab's bar can tell "already at the root".
    if (index == current) _retaps.value++;
    widget.navigationShell.goBranch(index, initialLocation: index == current);
  }

  @override
  Widget build(BuildContext context) {
    return TabRetapScope(
      retaps: _retaps,
      child: Scaffold(
        body: FadeTransition(
          key: const ValueKey('appShellFade'),
          opacity: _opacity,
          child: ScaleTransition(scale: _scale, child: widget.navigationShell),
        ),
        bottomNavigationBar: _SlidingPillNav(
          index: widget.navigationShell.currentIndex,
          count: 5,
          child: NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: _select,
            // The pill is drawn by _SlidingPillNav so it can slide.
            backgroundColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Transactions',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline),
                selectedIcon: Icon(Icons.pie_chart),
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(Icons.trending_up_outlined),
                selectedIcon: Icon(Icons.trending_up),
                label: 'Invest',
              ),
              NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.smart_toy),
                label: 'Penny',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the nav bar's selected-tab pill behind [child] and slides it to
/// the new tab on a spring (M1), instead of Material's per-tab fade. It
/// lines up with the destination icons by measuring one after layout; the
/// destinations are equal-width, so x is just the index.
class _SlidingPillNav extends StatefulWidget {
  const _SlidingPillNav({required this.index, required this.count, required this.child});

  final int index;
  final int count;
  final Widget child;

  /// Material 3's indicator size.
  static const pill = Size(64, 32);

  @override
  State<_SlidingPillNav> createState() => _SlidingPillNavState();
}

class _SlidingPillNavState extends State<_SlidingPillNav> with SingleTickerProviderStateMixin {
  late final AnimationController _x = AnimationController.unbounded(vsync: this, value: widget.index.toDouble());
  final _stack = GlobalKey();

  /// The icons' vertical centre in the stack, once measured.
  double? _iconY;

  @override
  void didUpdateWidget(_SlidingPillNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final target = widget.index.toDouble();
    if (context.reducedMotion) {
      _x.value = target;
    } else {
      _x.animateWith(SpringSimulation(AppMotion.springSettle, _x.value, target, _x.velocity));
    }
  }

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    RenderBox? icon;
    void visit(Element e) {
      if (icon != null) return;
      if (e.widget is Icon) {
        icon = e.findRenderObject() as RenderBox?;
        return;
      }
      e.visitChildren(visit);
    }

    _stack.currentContext?.visitChildElements(visit);
    final found = icon;
    if (stack == null || found == null || !found.hasSize) return;
    final y = found.localToGlobal(found.size.center(Offset.zero), ancestor: stack).dy;
    if (y != _iconY) setState(() => _iconY = y);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final iconY = _iconY;
    return ColoredBox(
      color: t.surface,
      child: Stack(
        key: _stack,
        children: [
          if (iconY != null)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = constraints.maxWidth / widget.count;
                  return AnimatedBuilder(
                    animation: _x,
                    builder: (context, _) => Stack(
                      children: [
                        Positioned(
                          key: const Key('nav-pill'),
                          left: slot * (_x.value + 0.5) - _SlidingPillNav.pill.width / 2,
                          top: iconY - _SlidingPillNav.pill.height / 2,
                          width: _SlidingPillNav.pill.width,
                          height: _SlidingPillNav.pill.height,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: t.primaryContainer, borderRadius: AppRadius.pillAll),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}
