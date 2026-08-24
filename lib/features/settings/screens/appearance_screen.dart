import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_mode_provider.dart';
import '../../../shared/widgets/group_card.dart';

String _themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
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
                      title: _themeModeLabel(option),
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
