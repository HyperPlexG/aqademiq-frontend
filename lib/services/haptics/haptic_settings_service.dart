import 'package:shared_preferences/shared_preferences.dart';

import 'haptic_governor.dart';

/// Persisted haptics setting (spec §6.5), stored in SharedPreferences beside
/// the Prism volumes — same pattern as `services/sound_settings_service.dart`,
/// so the settings screen can read it synchronously during `build`.
///
/// | Key                       | Meaning                          | Default |
/// |---------------------------|----------------------------------|---------|
/// | `haptics_level`           | Off / Essential / Full           | Full    |
/// | `haptics_streak_mark`     | Highest streak already accounted | 0       |
///
/// Full is the default because restraint is built into the vocabulary rather
/// than the setting: there are only 22 events in the whole app, and the two
/// that matter most are the reason the other ~148 taps stay inert.
class HapticSettingsService {
  HapticSettingsService._();

  static final HapticSettingsService instance = HapticSettingsService._();

  static const _kLevel = 'haptics_level';
  static const _kStreakMark = 'haptics_streak_mark';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  HapticSetting get setting =>
      HapticSetting.fromStorageKey(_prefs?.getString(_kLevel));

  Future<void> setSetting(HapticSetting value) async =>
      _prefs?.setString(_kLevel, value.storageKey);

  /// Highest day-streak the milestone haptic has already accounted for.
  ///
  /// Persisted because spec §4.5 says a streak fires "the instant it is
  /// crossed, never each time it is displayed" — and `streakProvider` is a
  /// derived read that recomputes on every mood log and every cold start, so
  /// without a watermark on disk the crossing would repeat forever.
  int get streakMark => _prefs?.getInt(_kStreakMark) ?? 0;

  Future<void> setStreakMark(int value) async =>
      _prefs?.setInt(_kStreakMark, value);
}
