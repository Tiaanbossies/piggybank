import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/tour_page.dart';
import '../widgets/penny_avatar.dart';
import '../widgets/speech_bubble.dart';

/// The Penny onboarding tour (Step 3 of
/// `plans/piggybank-penny-onboarding-tour.md`), shown once after
/// registration per the `onboardingRequired` gate in `app_router.dart`.
///
/// Slide order deliberately mirrors `app_shell.dart`'s five bottom-nav
/// destinations (Home, Invest, Budgets, Assistant, Settings), bookended by a
/// welcome and a closing slide — if the real tab order ever changes, update
/// [_pages] to match.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const pennySize = 180.0;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = <TourPage>[
    TourPage(
      title: "Hi, I'm Penny!",
      body: "I'll be your guide to your money — let's take a quick look around.",
    ),
    // One page per tab, in tab order (UX rework spec §2, A7), then Settings.
    TourPage(
      icon: Icons.home_outlined,
      title: 'Your day at a glance',
      body: "Home shows what's left to spend this month, what you've spent today, and the one thing worth a look.",
    ),
    TourPage(
      icon: Icons.receipt_long_outlined,
      title: 'Every rand in one place',
      body: 'Bank notifications fill in your transactions. Review what was picked up and file it with a tap.',
    ),
    TourPage(
      icon: Icons.pie_chart_outline,
      title: 'Plan ahead',
      body: 'Budgets, goals and your savings plan live together under Plan.',
    ),
    TourPage(
      icon: Icons.trending_up_outlined,
      title: 'Grow it, and ask me',
      body: "Track your portfolios, TFSA and RA under Invest. Got a question? I'm one tab over.",
    ),
    TourPage(
      icon: Icons.settings_outlined,
      title: 'Your data, secured',
      body: 'Tap your avatar for Settings: lock the app with a PIN or biometrics, manage privacy, and export your data.',
    ),
    TourPage(
      title: "You're all set",
      body: "Time to take control of your money. Let's get started.",
    ),
  ];

  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() {
    return ref.read(authControllerProvider.notifier).completeOnboarding();
  }

  /// Skip (M36): a selection tick, then the tour ends.
  Future<void> _skip() {
    unawaited(AppHaptics.selection());
    return _complete();
  }

  /// Next (M36): a selection tick and the page slides over 250 ms; under
  /// reduced motion it cuts.
  void _next() {
    unawaited(AppHaptics.selection());
    if (context.reducedMotion) {
      _pageController.jumpToPage(_page + 1);
    } else {
      _pageController.animateToPage(_page + 1, duration: AppMotion.pageTransition, curve: AppMotion.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: isLast
                      ? null
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextButton(onPressed: _skip, child: const Text('Skip')),
                        ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    final isWelcome = index == 0;
                    // Center content vertically when it fits the viewport
                    // (the common case); ConstrainedBox's minHeight still
                    // lets SingleChildScrollView scroll on short screens or
                    // large text-scale factors instead of overflowing.
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Welcoming Penny at 180 dp on every page;
                                  // her entrance plays on the first only.
                                  PennyAvatar(size: OnboardingScreen.pennySize, entrance: isWelcome),
                                  const SizedBox(height: AppSpace.s12),
                                  SpeechBubble(title: page.title, body: page.body, icon: page.icon),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              _PageDots(count: _pages.length, page: _page),
              const SizedBox(height: AppSpace.s24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLast ? _complete : _next,
                    child: Text(isLast ? 'Get Started' : 'Next'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s24),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page dots (M36): the active one is an elongated pill. When the page
/// changes the pill stretches across on [AppMotion.springSettle]; under
/// reduced motion it jumps.
class _PageDots extends StatefulWidget {
  const _PageDots({required this.count, required this.page});

  final int count;
  final int page;

  static const dot = 8.0;
  static const active = 24.0;

  @override
  State<_PageDots> createState() => _PageDotsState();
}

class _PageDotsState extends State<_PageDots> with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(vsync: this, value: widget.page.toDouble());

  @override
  void didUpdateWidget(_PageDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page == oldWidget.page) return;
    final target = widget.page.toDouble();
    if (context.reducedMotion) {
      _position.value = target;
    } else {
      _position.animateWith(SpringSimulation(AppMotion.springSettle, _position.value, target, _position.velocity));
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'Page ${widget.page + 1} of ${widget.count}',
      child: AnimatedBuilder(
        animation: _position,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.count; i++)
              Builder(
                builder: (context) {
                  // How "active" this dot is as the pill passes over it.
                  final near = (1 - (_position.value - i).abs()).clamp(0.0, 1.0);
                  return Container(
                    key: Key('page-dot-$i'),
                    margin: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                    width: _PageDots.dot + (_PageDots.active - _PageDots.dot) * near,
                    height: _PageDots.dot,
                    decoration: BoxDecoration(
                      color: Color.lerp(t.outline, t.primary, near),
                      borderRadius: AppRadius.pillAll,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
