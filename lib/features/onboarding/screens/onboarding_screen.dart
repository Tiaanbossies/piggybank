import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_motion.dart';
import '../../../shared/widgets/icon_chip.dart';
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

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = <TourPage>[
    TourPage(
      title: "Hi, I'm Penny!",
      body: "I'll be your guide to your money — let's take a quick look around.",
    ),
    TourPage(
      icon: Icons.home_outlined,
      title: 'Your home base',
      body: 'See your net worth, all your accounts, and quick actions at a glance.',
    ),
    TourPage(
      icon: Icons.trending_up_outlined,
      title: 'Grow what you have',
      body: 'Track your portfolios, TFSA and RA, and watch your investments grow over time.',
    ),
    TourPage(
      icon: Icons.pie_chart_outline,
      title: 'Stay on track',
      body: 'Set budgets and goals, and see exactly where your money is going.',
    ),
    TourPage(
      icon: Icons.smart_toy_outlined,
      title: 'Ask me anything',
      body: "Have a question about your finances? I'm always here to help.",
    ),
    TourPage(
      icon: Icons.settings_outlined,
      title: 'Your data, secured',
      body: 'Lock the app with a PIN or biometrics, manage privacy, and export your data any time.',
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

  void _next() {
    _pageController.animateToPage(_page + 1, duration: AppMotion.stateChange, curve: AppMotion.easeOut);
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
                          child: TextButton(onPressed: _complete, child: const Text('Skip')),
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
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (page.icon != null) ...[
                                    IconChip(icon: page.icon!),
                                    const SizedBox(height: 12),
                                  ],
                                  PennyAvatar(size: isWelcome ? 160 : 96),
                                  const SizedBox(height: 24),
                                  SpeechBubble(title: page.title, body: page.body),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: AppMotion.stateChange,
                      curve: AppMotion.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLast ? _complete : _next,
                    child: Text(isLast ? 'Get Started' : 'Next'),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
