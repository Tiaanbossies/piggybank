import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_tokens.dart';

/// Pull to refresh (visual spec M12): the indicator in primary on
/// `surface`, and one light tap at the moment the pull triggers.
class AppRefresh extends StatelessWidget {
  const AppRefresh({required this.onRefresh, required this.child, super.key});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RefreshIndicator(
      color: t.primary,
      backgroundColor: t.surface,
      onRefresh: () {
        unawaited(AppHaptics.light());
        return onRefresh();
      },
      child: child,
    );
  }
}

/// A switch that gives one selection tick when it toggles (visual spec
/// M28). Its colours come from the theme's `switchTheme`.
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Switch(
      value: value,
      onChanged: onChanged == null
          ? null
          : (v) {
              unawaited(AppHaptics.selection());
              onChanged(v);
            },
    );
  }
}
