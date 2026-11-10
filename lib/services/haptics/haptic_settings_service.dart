import 'package:shared_preferences/shared_preferences.dart';

import 'haptic_governor.dart';

/// Persisted haptics setting (spec §6.5), stored in SharedPreferences beside
/// the Prism volumes — same pattern as `services/sound_settings_service.dart`,
/// so the settings screen can read it synchronously during `build`.
///
/// | Key                       | Meaning                          | Default |
/// |---------------------------|----------------------------------|---------|
/// | `haptics_level`           | Off / Essential / Full           | Essential |
///
/// Essential is the default (haptic architecture principle 6): the sessions,
/// freezing and thawing, about ten moments a day. Full is opt-in.
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

  /// Highest day-streak the milestone haptic has already accounted for, so a
  /// crossing fires once, never each time the streak is recomputed.
  int get streakMark => _prefs?.getInt(_kStreakMark) ?? 0;

  Future<void> setStreakMark(int value) async =>
      _prefs?.setInt(_kStreakMark, value);
}
