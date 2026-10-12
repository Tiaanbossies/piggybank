import 'package:flutter/material.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_motion.dart';

/// A [FilterChip] that answers a selection with a selection click and a
/// check that grows in (visual spec M27: 150 ms ease-out, instant under
/// reduced motion). Colours and the pill shape come from the chip theme.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({required this.label, required this.selected, required this.onSelected, super.key});

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduced = context.reducedMotion;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      avatar: AnimatedScale(
        key: const Key('filter-chip-check'),
        scale: selected ? 1 : 0,
        duration: reduced ? Duration.zero : AppMotion.feedback,
        curve: AppMotion.easeOut,
        child: const Icon(Icons.check, size: 18),
      ),
      avatarBoxConstraints: selected ? null : const BoxConstraints.tightFor(width: 0),
      onSelected: (value) {
        AppHaptics.selection();
        onSelected(value);
      },
    );
  }
}
