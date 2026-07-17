import 'package:shared_preferences/shared_preferences.dart';

/// Persisted Prism sound settings (PRISM_SOUND_ENGINE_ARCHITECTURE §7.2 /
/// §12.5), stored in SharedPreferences.
///
/// | Key                        | Meaning                        | Default |
/// |----------------------------|--------------------------------|---------|
/// | `sound_master_volume`      | SoLoud global volume           | 0.8     |
/// | `sound_environment_volume` | texture-layer multiplier       | 0.6     |
/// | `sound_system_volume`      | pulse-layer multiplier         | 0.4     |
/// | `sound_preferred_mode`     | default Prism mode (UI label)  | Deep Work |
/// | `sound_autoplay_focus`     | auto-start audio with sessions | true    |
class SoundSettingsService {
  SoundSettingsService._();

  static final SoundSettingsService instance = SoundSettingsService._();

  static const _kMasterVolume = 'sound_master_volume';
  static const _kEnvironmentVolume = 'sound_environment_volume';
  static const _kSystemVolume = 'sound_system_volume';
  static const _kPreferredMode = 'sound_preferred_mode';
  static const _kAutoplay = 'sound_autoplay_focus';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  double get masterVolume => _prefs?.getDouble(_kMasterVolume) ?? 0.8;
  double get environmentVolume =>
      _prefs?.getDouble(_kEnvironmentVolume) ?? 0.6;
  double get systemVolume => _prefs?.getDouble(_kSystemVolume) ?? 0.4;
  String get preferredMode =>
      _prefs?.getString(_kPreferredMode) ?? 'Deep Work';
  bool get autoplayFocusMusicEnabled => _prefs?.getBool(_kAutoplay) ?? true;

  Future<void> setMasterVolume(double v) async =>
      _prefs?.setDouble(_kMasterVolume, v.clamp(0.0, 1.0));
  Future<void> setEnvironmentVolume(double v) async =>
      _prefs?.setDouble(_kEnvironmentVolume, v.clamp(0.0, 1.0));
  Future<void> setSystemVolume(double v) async =>
      _prefs?.setDouble(_kSystemVolume, v.clamp(0.0, 1.0));
  Future<void> setPreferredMode(String mode) async =>
      _prefs?.setString(_kPreferredMode, mode);
  // ignore: avoid_positional_boolean_parameters — symmetric with the getters.
  Future<void> setAutoplayFocusMusicEnabled(bool v) async =>
      _prefs?.setBool(_kAutoplay, v);
}
