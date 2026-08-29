import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/auth/session_reset.dart';
import 'data/realtime/revision_sync.dart';
import 'features/focus/providers/prism_audio_provider.dart';
import 'services/ambient/ambient_service.dart';
import 'services/push_service.dart';
import 'services/reminder_scheduler.dart';

/// Root widget: wires the router, the light/dark themes (rebuilt on accent
/// change), and the Light/Dark/System mode.
class AqademiqApp extends ConsumerWidget {
  const AqademiqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    final mode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    // Keep the realtime revision→refetch loop alive (no-op under mocks) and
    // the Prism audio bridge alive so focus-session transitions drive the
    // soundscape from any tab.
    // Keep push registration alive too — the service listens to auth internally
    // and registers this device once signed in (no-op under mocks) — and the
    // reminder scheduler, which keeps the device's own notification schedule in
    // step with the task list.
    // The ambient service belongs here for the same reason: a focus session
    // keeps running with the app closed, and the lock screen, the Island and
    // the widgets are that session drawn somewhere else.
    ref
      ..watch(revisionSyncProvider)
      ..watch(sessionResetProvider)
      ..watch(prismAudioControllerProvider)
      ..watch(pushServiceProvider)
      ..watch(reminderSchedulerProvider)
      ..watch(ambientServiceProvider);

    return MaterialApp.router(
      title: 'Aqademiq',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light, accent: accent),
      darkTheme: buildAppTheme(brightness: Brightness.dark, accent: accent),
      themeMode: mode,
      routerConfig: router,
    );
  }
}
