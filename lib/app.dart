import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/detection/services/notification_capture_service.dart';

class PiggybankApp extends ConsumerStatefulWidget {
  const PiggybankApp({super.key});

  @override
  ConsumerState<PiggybankApp> createState() => _PiggybankAppState();
}

class _PiggybankAppState extends ConsumerState<PiggybankApp> with WidgetsBindingObserver {
  Timer? _detectionFlushTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Notification/email detection (plan §3, Phase D): flush the native
    // notification queue on launch, on every resume, and on a 15-minute
    // foreground timer — see NotificationCaptureService's doc comment for
    // why this isn't a true background WorkManager task.
    _flushDetectionQueue();
    _detectionFlushTimer = Timer.periodic(const Duration(minutes: 15), (_) => _flushDetectionQueue());
  }

  @override
  void dispose() {
    _detectionFlushTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _flushDetectionQueue();
  }

  void _flushDetectionQueue() {
    // Fire-and-forget: a logged-out user has no valid bearer token, so a
    // failed upload here just leaves items queued natively for the next
    // attempt (NotificationCaptureService.flush already treats any
    // ApiError this way) — never worth blocking app startup on.
    unawaited(ref.read(notificationCaptureServiceProvider).flush());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Piggybank',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final clampedScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: clampedScaler),
          child: child!,
        );
      },
    );
  }
}
