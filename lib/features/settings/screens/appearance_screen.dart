import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_mode_provider.dart';
import '../../../shared/widgets/group_card.dart';

String _themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

String _themeModeSubtitle(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Always use the light palette',
      ThemeMode.dark => 'Always use the dark palette',
      ThemeMode.system => 'Match your device setting',
    };

IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };

/// Three-way theme selector (blueprint Step 3), row-card/radio pattern
/// matching `GroupCard`/`GroupRow`'s existing vocabulary elsewhere in
/// Settings.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: mode,
          onChanged: (value) {
            if (value != null) ref.read(themeModeProvider.notifier).setThemeMode(value);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GroupCard(
                children: [
                  for (final option in ThemeMode.values)
                    GroupRow(
                      leadingIcon: _themeModeIcon(option),
                      title: _themeModeLabel(option),
                      subtitle: _themeModeSubtitle(option),
                      trailing: Radio<ThemeMode>(value: option),
                      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(option),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
