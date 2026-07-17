import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/sound_settings_service.dart';

/// The selectable Prism focus modes (matches the fc-prism picker order).
const prismModes = <String>['Deep Work', 'Flow', 'Review', 'Wind-down', 'No sound'];

/// The user's default Prism mode (Settings → Prism). Shown in the Settings hub
/// and as the Focus session default. Persisted via [SoundSettingsService].
final prismDefaultModeProvider =
    NotifierProvider<PrismDefaultModeController, String>(PrismDefaultModeController.new);

class PrismDefaultModeController extends Notifier<String> {
  @override
  String build() => SoundSettingsService.instance.preferredMode;

  void set(String mode) {
    state = mode;
    unawaited(SoundSettingsService.instance.setPreferredMode(mode));
  }
}

/// Whether Prism audio auto-starts with a focus session ("Autoplay Prism" in
/// the fc-prism picker / "Play Prism in Focus" in Settings → Prism).
final prismAutoplayProvider =
    NotifierProvider<PrismAutoplayController, bool>(PrismAutoplayController.new);

class PrismAutoplayController extends Notifier<bool> {
  @override
  bool build() => SoundSettingsService.instance.autoplayFocusMusicEnabled;

  // ignore: avoid_positional_boolean_parameters — matches the app's `set(...)` controller API.
  void set(bool enabled) {
    state = enabled;
    unawaited(
      SoundSettingsService.instance.setAutoplayFocusMusicEnabled(enabled),
    );
  }
}
