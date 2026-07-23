import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env/env.dart';
import 'services/push_service.dart';
import 'services/sound_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prism sound settings back the settings/picker providers synchronously.
  await SoundSettingsService.instance.init();

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

  runApp(const ProviderScope(child: AqademiqApp()));
}
