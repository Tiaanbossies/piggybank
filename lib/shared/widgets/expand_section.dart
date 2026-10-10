import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';

/// A header that opens and closes the section under it (visual spec M29):
/// the body grows with a size transition and the chevron turns 180°, both
/// 200 ms emphasized. Instant under reduced motion.
class ExpandSection extends StatefulWidget {
  const ExpandSection({required this.title, required this.child, this.initiallyExpanded = false, super.key});

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<ExpandSection> createState() => _ExpandSectionState();
}

class _ExpandSectionState extends State<ExpandSection> with SingleTickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: AppMotion.stateChange,
    value: widget.initiallyExpanded ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _open, curve: AppMotion.easeInOut);

  bool get _expanded => _open.status == AnimationStatus.completed || _open.status == AnimationStatus.forward;

  void _toggle() {
    final opening = !_expanded;
    if (context.reducedMotion) {
      _open.value = opening ? 1 : 0;
    } else if (opening) {
      _open.forward();
    } else {
      _open.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: InkWell(
            onTap: _toggle,
            borderRadius: AppRadius.tileAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleSmall)),
                  RotationTransition(
                    key: const Key('expand-chevron'),
                    turns: Tween(begin: 0.0, end: 0.5).animate(_curve),
                    child: Icon(Icons.expand_more, color: t.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizeTransition(
          key: const Key('expand-body'),
          sizeFactor: _curve,
          alignment: Alignment.topCenter,
          child: widget.child,
        ),
      ],
    );
  }
}
