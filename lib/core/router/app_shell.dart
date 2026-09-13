import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_motion.dart';

/// The 5-tab bottom-nav shell per DESIGN.md § Navigation. `navigationShell`
/// preserves each tab's own stack (StatefulShellRoute), so pushing e.g. the
/// add-account sheet from Home doesn't disturb Settings' state.
///
/// A `StatefulWidget` (not `StatelessWidget`, as before) so it can detect
/// `currentIndex` changes across rebuilds and drive a brief opacity pulse on
/// tab switch — a `ThemeData.pageTransitionsTheme` override doesn't reach
/// here, since that only applies to push/pop route navigation, and
/// `navigationShell`'s own `IndexedStack` has no transition mechanism at all
/// (it swaps its visible child by index instantly). Deliberately does NOT
/// re-key or swap `navigationShell` itself (e.g. via `AnimatedSwitcher` with
/// a per-index key) — doing so would force Flutter to unmount and remount
/// its entire subtree on every tab switch, destroying the very per-branch
/// navigator state (scroll position, in-progress sheets) this widget's own
/// doc comment above says must survive. `navigationShell` is instead kept as
/// a single, never-rekeyed child throughout, wrapped only in a `FadeTransition`
/// whose opacity briefly dips and recovers — this preserves every branch's
/// state exactly as before, while still giving the tab switch a visible,
/// non-instant transition.
class AppShell extends StatefulWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.pageTransition);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(weight: 1, tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: AppMotion.easeOut))),
      TweenSequenceItem(weight: 1, tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: AppMotion.easeOut))),
    ]).animate(_controller);
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
      body: FadeTransition(key: const ValueKey('appShellFade'), opacity: _opacity, child: widget.navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: 'Invest'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Budgets'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'Assistant'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
