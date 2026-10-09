import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The one app bar every tab root uses (UX rework spec §1.2): the avatar,
/// which opens Settings, then the title, then at most two actions plus an
/// optional overflow menu.
///
/// There's no notification bell. It had no feature behind it, and a control
/// that looks tappable and does nothing breaks the "signifiers must be true"
/// rule (principles N1, K1).
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabAppBar({
    required this.title,
    this.subtitle,
    this.titleLeading,
    this.actions = const [],
    this.bottom,
    super.key,
  });

  final String title;

  /// A muted second line under [title] (Penny's "Ask me anything…").
  final String? subtitle;

  /// A small mark before the title (Penny's avatar chip).
  final Widget? titleLeading;

  /// Two labelled actions, plus an optional overflow menu as the last item.
  final List<Widget> actions;

  /// A strip under the title row, such as Plan's month switcher.
  final PreferredSizeWidget? bottom;

  /// The avatar's route. Settings sits above the shell, not in it.
  static const settingsLocation = '/settings';

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    assert(actions.length <= 3, 'TabAppBar takes two actions plus an optional overflow menu.');
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppBar(
      leading: IconButton(
        key: const Key('tab-app-bar-avatar'),
        tooltip: 'Settings',
        onPressed: () => context.push(settingsLocation),
        icon: const CircleAvatar(radius: 16, child: Icon(Icons.person_outline, size: 18)),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titleLeading != null) ...[titleLeading!, const SizedBox(width: 10)],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.normal),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [...actions, const SizedBox(width: 4)],
      bottom: bottom,
    );
  }
}
