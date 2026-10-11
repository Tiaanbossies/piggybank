import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../motion/chart_reveal.dart';

/// The chart ramp (visual spec §1.3): forest, ochre, clay and sage, then
/// the neutral family's ink for a fifth series.
List<Color> chartPalette(AppTokens t) => [...t.chartSeries, t.categoryIcon(CategoryFamily.neutral)];

/// A lighter step of a ramp colour, for when a chart needs more series than
/// the ramp has: the colour at half strength over the card.
Color chartTint(AppTokens t, Color c) => Color.alphaBlend(c.withValues(alpha: 0.5), t.surface);

/// Touch for a line chart (M24): an ink datatip over the touched point,
/// with one selection tick each time it moves to a new point. [label]
/// writes the tip; the y value as is by default.
LineTouchData chartTouch(BuildContext context, DatatipHaptics haptics, {String Function(double y)? label}) {
  final t = context.tokens;
  final style = Theme.of(context).textTheme.labelMedium?.copyWith(
        color: t.bg,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
  return LineTouchData(
    touchCallback: (event, response) => haptics.touched(
      event.isInterestedForInteractions ? response?.lineBarSpots?.firstOrNull?.spotIndex : null,
    ),
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (_) => t.ink,
      tooltipRoundedRadius: AppRadius.tile,
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipItems: (spots) => [
        for (final spot in spots)
          LineTooltipItem(label?.call(spot.y) ?? spot.y.toStringAsFixed(2), style ?? const TextStyle()),
      ],
    ),
  );
}
