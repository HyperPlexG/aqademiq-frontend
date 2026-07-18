import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/sound_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prism sound settings back the settings/picker providers synchronously.
  await SoundSettingsService.instance.init();
  runApp(const ProviderScope(child: AqademiqApp()));
}
