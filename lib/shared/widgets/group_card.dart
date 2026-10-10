import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';
import 'app_card.dart';
import 'icon_chip.dart';

/// One card per *group* (visual spec §1.6): Accounts, Transactions per date,
/// Settings sections, Invest holdings. Rows inside share the card and are
/// separated by space, not dividers. Contrast with [ProgressCard]
/// (Budgets/Goals), which genuinely is one card per item.
class GroupCard extends StatelessWidget {
  const GroupCard({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.rowGap),
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      child: Column(children: children),
    );
  }
}

/// A single row inside a [GroupCard] — no card/margin of its own, just an
/// optional leading [IconChip] (or category tile, with [family]),
/// title/subtitle, and trailing content. At least 64 dp tall. A press
/// tints it `sunk` at 60 % (M5: 100 ms in, 150 ms out), also under reduced
/// motion, since it's a colour change rather than movement.
class GroupRow extends StatefulWidget {
  const GroupRow({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingDanger = false,
    this.muted = false,
    this.family,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final bool leadingDanger;
  final bool muted;
  final CategoryFamily? family;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Shortest a row may be (spec §3, list group).
  static const minHeight = 64.0;

  @override
  State<GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<GroupRow> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (widget.onTap != null && _pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedContainer(
        key: const Key('group-row-highlight'),
        duration: _pressed ? const Duration(milliseconds: 100) : AppMotion.feedback,
        color: t.sunk.withValues(alpha: _pressed ? 0.6 : 0),
        child: InkWell(
          onTap: widget.onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GroupRow.minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.cardPad, vertical: AppSpace.s12),
              child: Row(
                children: [
                  if (widget.leadingIcon != null) ...[
                    IconChip(
                      icon: widget.leadingIcon!,
                      danger: widget.leadingDanger,
                      muted: widget.muted,
                      family: widget.family,
                      size: 40,
                    ),
                    const SizedBox(width: AppSpace.s12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: text.bodySmall?.copyWith(color: t.muted, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[const SizedBox(width: AppSpace.s12), widget.trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
