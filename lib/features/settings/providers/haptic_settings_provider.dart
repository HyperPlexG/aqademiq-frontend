import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/haptics/haptic_governor.dart';
import '../../../services/haptics/haptic_settings_service.dart';

/// The user's haptics level (Settings → Prism → Haptics), spec §6.5.
///
/// Persisted via [HapticSettingsService], exactly as the Prism volumes are.
/// `RealHapticsService` reads this on every event rather than watching it, so
/// a change takes effect on the next haptic with no rebuild anywhere.
final hapticSettingProvider =
    NotifierProvider<HapticSettingController, HapticSetting>(
  HapticSettingController.new,
);

class HapticSettingController extends Notifier<HapticSetting> {
  @override
  HapticSetting build() => HapticSettingsService.instance.setting;

  void set(HapticSetting value) {
    state = value;
    unawaited(HapticSettingsService.instance.setSetting(value));
  }
}
