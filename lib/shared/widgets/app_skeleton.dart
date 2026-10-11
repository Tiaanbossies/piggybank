import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';
import 'group_card.dart';
import 'hero_metric_card.dart';
import 'progress_card.dart';

/// The initial-load view (visual spec M11, S7): the real layout with its
/// text and icons drawn as `sunk` bones, instead of a lone spinner. Cards
/// keep their own surface and shape, so the page doesn't jump when the data
/// lands. The bones shimmer; under reduced motion they hold still.
///
/// Wrap the screen's own widgets fed placeholder strings, or one of the
/// presets below, which are built from the shared cards and rows. The
/// crossfade to the content is the caller's `AnimatedSwitcher` (200 ms).
/// Bones ignore taps.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({required this.child, this.enabled = true, super.key});

  final Widget child;

  /// False shows [child] as is, for a widget that is its own skeleton.
  final bool enabled;

  /// One sweep of the shimmer.
  static const shimmerPeriod = AppMotion.shimmerPeriod;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final PaintingEffect effect = context.reducedMotion
        ? SolidColorEffect(color: t.sunk)
        : ShimmerEffect(
            baseColor: t.sunk,
            highlightColor: Color.lerp(t.sunk, t.surface, 0.7)!,
            duration: shimmerPeriod,
          );
    return Skeletonizer(
      enabled: enabled,
      effect: effect,
      textBoneBorderRadius: const TextBoneBorderRadius(AppRadius.pillAll),
      child: child,
    );
  }
}

/// A card of [count] list rows: icon tile, title, subtitle, amount. The
/// shape of every grouped list (transactions, accounts, holdings, ledgers).
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({this.count = 6, this.subtitle = true, this.trailing = true, super.key});

  final int count;
  final bool subtitle;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: GroupCard(
        children: [
          for (var i = 0; i < count; i++)
            GroupRow(
              leadingIcon: Icons.circle,
              title: i.isEven ? 'Placeholder name' : 'Placeholder',
              subtitle: subtitle ? 'Placeholder detail' : null,
              trailing: trailing ? const Text('R 0 000,00') : null,
            ),
        ],
      ),
    );
  }
}

/// The hero panel with a label, figure and line.
class SkeletonHero extends StatelessWidget {
  const SkeletonHero({this.progress = false, super.key});

  final bool progress;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: HeroMetricCard(
        label: 'Placeholder',
        value: 'R 00 000',
        progress: progress ? 0 : null,
        deltaText: 'Placeholder line under the figure',
      ),
    );
  }
}

/// [count] progress cards: the shape of Budgets and Goals.
class SkeletonProgressCards extends StatelessWidget {
  const SkeletonProgressCards({this.count = 4, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            const ProgressCard(
              title: 'Placeholder',
              pct: 0,
              footnote: 'R 0 000,00 of R 0 000,00',
              icon: Icons.circle,
            ),
        ],
      ),
    );
  }
}

/// One solid block the size of a chart or a figure that isn't text.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({this.height = 140, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Bone(width: double.infinity, height: height, borderRadius: AppRadius.cardAll),
    );
  }
}

/// A whole loading page: an optional hero over a card of rows, scrollable
/// so pull-to-refresh still works while it loads.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({this.hero = false, this.rows = 6, this.progressCards = false, this.padding, super.key});

  final bool hero;
  final int rows;

  /// Progress cards (Budgets, Goals) in place of the rows.
  final bool progressCards;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding ?? const EdgeInsets.all(AppSpace.gutter),
      children: [
        if (hero) ...[const SkeletonHero(), const SizedBox(height: AppSpace.sectionGap)],
        if (progressCards) const SkeletonProgressCards() else SkeletonRows(count: rows),
      ],
    );
  }
}

/// Crossfades a section from its skeleton (or error) to its content over
/// 200 ms (M11); instant under reduced motion. Children line up at the top,
/// so a short skeleton and a long list share an edge while they fade.
class SkeletonSwitcher extends StatelessWidget {
  const SkeletonSwitcher({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.reducedMotion ? Duration.zero : AppMotion.stateChange,
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      child: child,
    );
  }
}
