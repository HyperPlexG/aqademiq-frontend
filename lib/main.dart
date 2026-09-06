import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env/env.dart';
import 'core/error/global_error_handler.dart';
import 'features/report/report_optout.dart';
import 'services/deep_link_service.dart';
import 'services/haptics/haptic_settings_service.dart';
import 'services/ice_breakers_service.dart';
import 'services/push_service.dart';
import 'services/sound_settings_service.dart';

// Everything runs inside the guarded zone, including binding initialisation —
// `runZonedGuarded` only catches errors raised in the zone it owns, and a
// binding created outside it schedules its callbacks outside it too.
/// Owned here rather than created by the provider so the link that launched
/// the app is captured before the first frame, not after the first `ref.read`.
final _deepLinks = DeepLinkService();

Future<void> main() => runGuardedApp(_start);

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prism sound settings back the settings/picker providers synchronously.
  await SoundSettingsService.instance.init();
  // Same deal for the haptics level: the governor reads it on every event and
  // must not have to wait on a future to know whether it may fire.
  await HapticSettingsService.instance.init();
  await IceBreakersService.instance.init();
  // Read synchronously during build by the Stats tab, so it has to be warm
  // before the first frame or the entry point flashes in for a student who
  // has already turned the report off.
  await ReportSettingsService.instance.init();
  // Started here so a cold start *from* a referral link has the code in hand
  // before onboarding renders. Best-effort inside: it never blocks startup.
  await _deepLinks.start();

  // Live builds use Supabase Auth (identity) + Firebase (FCM push). Mock builds
  // skip both so the app runs entirely offline on fixtures.
  if (!Env.useMocks && Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    // Firebase (FCM push) is best-effort — a missing/misconfigured
    // GoogleService-Info.plist must never blank the app. If init fails, push is
    // simply unavailable and the rest of the app runs normally.
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } on Object catch (e) {
      debugPrint('Firebase init failed — push disabled: $e');
    }
  }

  runApp(
    ProviderScope(
      // The same instance that already captured the launch link, rather than a
      // second one the provider would build too late to see it.
      overrides: [deepLinkServiceProvider.overrideWithValue(_deepLinks)],
      child: const AqademiqApp(),
    ),
  );
}
