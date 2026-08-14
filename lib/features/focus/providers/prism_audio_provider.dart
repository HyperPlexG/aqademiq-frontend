import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/focus_session.dart';
import '../../../data/repositories/focus_repository.dart';
import '../../../services/focus_keepalive_service.dart';
import '../../../services/sound_settings_service.dart';
import '../../../sound_engine/sound_engine.dart';
import '../../settings/providers/prism_settings_provider.dart';

/// UI Prism mode label for "audio off".
const String kPrismNoSound = 'No sound';

/// What the Prism engine is doing right now (for pills / pickers).
@immutable
class PrismAudioState {
  const PrismAudioState({this.playing = false, this.activeMode});

  /// Whether the soundscape is currently audible.
  final bool playing;

  /// The UI mode label currently sounding (null when silent).
  final String? activeMode;

  PrismAudioState copyWith({bool? playing, String? activeMode}) {
    return PrismAudioState(
      playing: playing ?? this.playing,
      activeMode: activeMode ?? this.activeMode,
    );
  }
}

/// Bridges the focus-session lifecycle to the [AdaptiveSoundEngine]
/// (PRISM_SOUND_ENGINE_ARCHITECTURE §12.2): start/freeze/resume/end drive
/// the soundscape, and live Prism-mode switches crossfade mid-session.
///
/// Kept alive from `app.dart` so transitions fire regardless of which tab is
/// on screen.
final prismAudioControllerProvider =
    NotifierProvider<PrismAudioController, PrismAudioState>(
        PrismAudioController.new);

class PrismAudioController extends Notifier<PrismAudioState> {
  AdaptiveSoundEngine get _engine => AdaptiveSoundEngine.instance;
  SoundSettingsService get _settings => SoundSettingsService.instance;

  /// True while this controller owns a running (or frozen) soundscape.
  bool _audioActive = false;

  /// A mode explicitly picked while the session was frozen with audio off —
  /// honoured (autoplay-independent) on the next resume.
  String? _pendingStartLabel;

  @override
  PrismAudioState build() {
    // A mid-session change of the Settings default mode must reach the
    // engine too: sessions without an explicit pick follow the default live.
    ref
      ..listen(focusControllerProvider, _onFocusChanged)
      ..listen(prismDefaultModeProvider, (_, next) {
        final session = ref.read(focusControllerProvider);
        final inSession = session.status == FocusStatus.running ||
            session.status == FocusStatus.paused;
        if (inSession && session.prismMode == null) {
          unawaited(
            _switchMode(next,
                whileFrozen: session.status == FocusStatus.paused),
          );
        }
      });
    return const PrismAudioState();
  }

  /// UI label → engine preset (+ optional param variant).
  ///
  /// * Deep Work — Focus preset as specced: bright, dense low-freq pulses.
  /// * Flow — Focus stems with a calmer surface: quarter-note pulses only,
  ///   softer rhythm, half-closed LPF, sparser sparks.
  /// * Review — Break preset: steady 60 BPM midtempo, rain texture.
  /// * Wind-down — Relax/Mellow preset: choir pad + sea, no rhythm.
  static (PresetMode, ParamsTransform?) mapMode(String label) {
    return switch (label) {
      'Flow' => (PresetMode.focus, _flowTransform),
      'Review' => (PresetMode.breakMode, null),
      'Wind-down' => (PresetMode.relax, null),
      _ => (PresetMode.focus, null), // Deep Work + fallback.
    };
  }

  static SoundscapeParams _flowTransform(SoundscapeParams p) => p.copyWith(
        pulseDensity: 1,
        pulseVolume: p.pulseVolume * 0.6,
        masterLpfCutoff: 8000,
        sparkTriggerProb: 0.15,
      );

  String _effectiveLabel(FocusSession session) =>
      session.prismMode ?? ref.read(prismDefaultModeProvider);

  /// This session is in the Prism holdout, so the soundscape stays silent.
  ///
  /// The arm is assigned server-side and arrives on the session; the client is
  /// told, never asked. It is checked at every point audio could start —
  /// including an explicit mode pick — because a held-out user tapping the
  /// Prism pill would otherwise quietly re-enter the treatment arm and spoil
  /// their own data. Nothing is shown about it: §4.3 requires the holdout be
  /// silent, or awareness becomes the confound it was meant to remove.
  bool _heldOut(FocusSession session) => session.controlArm;

  void _onFocusChanged(FocusSession? prev, FocusSession next) {
    final prevStatus = prev?.status ?? FocusStatus.idle;
    final label = _effectiveLabel(next);

    if (prevStatus == next.status) {
      // Same lifecycle state — check for a mode switch mid-session (the
      // Prism pill is tappable while running AND while frozen).
      final prevLabel = prev == null ? null : _effectiveLabel(prev);
      final inSession = next.status == FocusStatus.running ||
          next.status == FocusStatus.paused;
      if (inSession && prevLabel != label && !_heldOut(next)) {
        unawaited(
          _switchMode(label,
              whileFrozen: next.status == FocusStatus.paused),
        );
      }
      return;
    }

    switch (next.status) {
      case FocusStatus.running:
        // Foreground service (Android) so timer + audio survive screen-off.
        unawaited(FocusKeepaliveService.instance.start());
        if (prevStatus == FocusStatus.paused) {
          final pending = _pendingStartLabel;
          _pendingStartLabel = null;
          if (_audioActive) {
            unawaited(_resume(label));
          } else if (pending != null && pending == label) {
            // Mode explicitly picked while frozen with audio off.
            unawaited(_start(pending));
          }
        } else {
          final autoplay = ref.read(prismAutoplayProvider);
          if (autoplay && label != kPrismNoSound && !_heldOut(next)) {
            unawaited(_start(label));
          }
        }
      case FocusStatus.paused:
        // Keepalive stays up while frozen so resume works from a locked
        // phone and the frozen state isn't killed by the OS.
        if (_audioActive) unawaited(_pauseEngine());
      case FocusStatus.completed || FocusStatus.idle:
        _pendingStartLabel = null;
        unawaited(FocusKeepaliveService.instance.stop());
        unawaited(_stop());
    }
  }

  Future<void> _start(String label) async {
    _audioActive = true;
    try {
      final (mode, transform) = PrismAudioController.mapMode(label);
      // Mode first: before init this is just a field write, and it makes
      // init load only this mode's stem manifest (not all of Focus).
      await _engine.setPresetMode(mode, transform: transform);
      await _ensureEngine();
      // The stem load can take a moment — bail if the session ended meanwhile.
      if (!_audioActive) return;
      if (ref.read(focusControllerProvider).status == FocusStatus.paused) {
        // The session froze during engine init: create the voices, then park
        // them silent immediately so resume can fade them back in. (They
        // start at volume 0, so this is inaudible.)
        await _engine.start();
        await _engine.pause();
        state = PrismAudioState(activeMode: label);
        return;
      }
      await _engine.start();
      state = PrismAudioState(playing: true, activeMode: label);
    } on Exception catch (e) {
      debugPrint('Prism: could not start audio: $e');
      _audioActive = false;
    }
  }

  Future<void> _switchMode(String label, {bool whileFrozen = false}) async {
    if (label == kPrismNoSound) {
      _pendingStartLabel = null;
      await _stop();
      return;
    }
    if (whileFrozen) {
      // Voices are already faded to silence, so swap without a crossfade:
      // drop the old soundscape now and start the new one on resume. An
      // explicit pick overrides the autoplay gate.
      if (_audioActive) {
        _audioActive = false;
        _engine.forceStop();
        state = const PrismAudioState();
      }
      _pendingStartLabel = label;
      return;
    }
    if (!_audioActive) {
      // Audio was off (No sound / autoplay off) — an explicit pick is a
      // direct request to hear this mode, so start regardless of autoplay.
      await _start(label);
      return;
    }
    final (mode, transform) = PrismAudioController.mapMode(label);
    await _engine.setPresetMode(mode, transform: transform);
    state = state.copyWith(activeMode: label);
  }

  Future<void> _pauseEngine() async {
    await _engine.pause();
    // Read back from the engine: a resume tapped during the 3 s pause fade
    // must not be overwritten with playing: false.
    state = state.copyWith(playing: _engine.isPlaying);
  }

  Future<void> _resume(String label) async {
    if (label == kPrismNoSound) {
      await _stop();
      return;
    }
    await _engine.resume();
    state = PrismAudioState(playing: true, activeMode: label);
  }

  Future<void> _stop() async {
    if (!_audioActive && !_engine.isPlaying) return;
    _audioActive = false;
    await _engine.stop();
    state = const PrismAudioState();
  }

  Future<void> _ensureEngine() async {
    await _settings.init();
    await _engine.init();
    _engine.setUserVolumes(
      master: _settings.masterVolume,
      environment: _settings.environmentVolume,
      pulse: _settings.systemVolume,
    );
  }

  // ---- Preview (onboarding "Meet Prism" / settings) --------------------

  /// Starts (or crossfades to) a soundscape outside a focus session so the
  /// user can hear a mode before choosing it.
  Future<void> previewMode(String label) async {
    if (label == kPrismNoSound) {
      await stopPreview();
      return;
    }
    if (_audioActive) {
      await _switchMode(label);
    } else {
      await _start(label);
    }
  }

  /// Ends a preview started with [previewMode] (3 s fade).
  Future<void> stopPreview() => _stop();

  // ---- User volumes (settings screen) ----------------------------------

  Future<void> setMasterVolume(double v) async {
    await _settings.init();
    await _settings.setMasterVolume(v);
    _engine.setUserVolumes(master: v);
  }

  Future<void> setEnvironmentVolume(double v) async {
    await _settings.init();
    await _settings.setEnvironmentVolume(v);
    _engine.setUserVolumes(environment: v);
  }

  Future<void> setSystemVolume(double v) async {
    await _settings.init();
    await _settings.setSystemVolume(v);
    _engine.setUserVolumes(pulse: v);
  }
}
