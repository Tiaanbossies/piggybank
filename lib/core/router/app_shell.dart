import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_motion.dart';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        key: const ValueKey('appShellFade'),
        opacity: _opacity,
        child: ScaleTransition(scale: _scale, child: widget.navigationShell),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: 'Invest'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'Penny'),
        ],
      ),
    );
  }
}
