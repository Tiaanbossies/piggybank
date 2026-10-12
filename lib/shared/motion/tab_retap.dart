import 'package:flutter/widgets.dart';

/// Tells the active tab its nav destination was tapped again while it was
/// already showing (visual spec M2). The shell bumps the count; the tab's
/// [TabAppBar] hears it and scrolls its list to the top.
class TabRetapScope extends InheritedNotifier<ValueNotifier<int>> {
  const TabRetapScope({required ValueNotifier<int> retaps, required super.child, super.key})
      : super(notifier: retaps);

  static ValueNotifier<int>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabRetapScope>()?.notifier;
}
