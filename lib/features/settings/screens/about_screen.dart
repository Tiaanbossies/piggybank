import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/app/app_build.dart';
import '../../../shared/widgets/app_skeleton.dart';

/// Settings > About — closes the "Support" gap flagged in the Stitch parity
/// sweep (`plans/stitch-live-verification.md`, Bucket 2). Only the app name,
/// the version and the build date are shown: Help Center and Contact Us were
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
                        aboutVersionLine(info),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      const AppSkeleton(child: Text('Version 0.0.0 · built 00 Mmm 0000')),
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

/// "Version 1.0.9 · built 12 Oct 2026". The build date replaced the raw
/// build number, which a split-per-ABI APK reports as 2009 (QA pass 1).
String aboutVersionLine(PackageInfo info) {
  final built = AppBuild.builtLabel(installed: info.updateTime);
  return built == null ? 'Version ${info.version}' : 'Version ${info.version} · $built';
}
