import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Settings > About — closes the "Support" gap flagged in the Stitch parity
/// sweep (`plans/stitch-live-verification.md`, Bucket 2). Only the app name
/// and version/build number are shown: Help Center and Contact Us were
/// deliberately dropped from this build — no support email or help content
/// exists anywhere in the project, and this codebase's own convention (see
/// `placeholder_screens.dart`'s `SettingsScreen` doc comment) is to never
/// ship a row with no real content behind it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Piggybank', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (info != null)
                      Text(
                        'Version ${info.version} (${info.buildNumber})',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
