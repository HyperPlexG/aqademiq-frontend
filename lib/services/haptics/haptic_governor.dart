import 'dart:async';
import 'dart:math' as math;

import 'haptic_lexicon.dart';
import 'haptic_moments.dart';

/// The user-facing setting — spec §3, "Tiers and budget".
enum HapticSetting {
  /// Nothing in the app. Apple Watch and system surfaces keep their own
  /// feedback.
  off,

  /// Sessions, freezing and thawing; deep freeze holding; system success and
  /// error. About ten moments a day. **The default.**
  essential,

  /// Everything: ticks, toggles, wheels, swipes, Ada, the Core, Prism
  /// previews.
  full;

  /// Stable key for SharedPreferences; a bare `name` would silently change
  /// meaning if a value were ever renamed.
  String get storageKey => switch (this) {
        HapticSetting.off => 'off',
        HapticSetting.essential => 'essential',
        HapticSetting.full => 'full',
      };

  /// Unset means Essential (principle 6, "Essential by default"). A student
  /// who picked Full or Off keeps their pick.
  static HapticSetting fromStorageKey(String? key) => switch (key) {
        'off' => HapticSetting.off,
        'full' => HapticSetting.full,
        _ => HapticSetting.essential,
      };

  String get label => switch (this) {
        HapticSetting.off => 'Off',
        HapticSetting.essential => 'Essential',
        HapticSetting.full => 'Full',
      };

  /// The haptics sheet's subtitles. Essential now covers freezing too, so it
  /// reads "Sessions, freezing and thawing" (§3).
  String get description => switch (this) {
        HapticSetting.off => 'No vibration anywhere',
        HapticSetting.essential => 'Sessions, freezing and thawing',
        HapticSetting.full => 'Every tap and toggle',
      };
}

/// One pattern the governor let through.
class AdmittedHaptic {
  const AdmittedHaptic({required this.id, required this.spec, this.faceDownAlt});

  /// Lets a later signature stop this one, and a hold be released.
  final int id;
  final HapticSpec spec;

  /// Played instead of [spec] if the phone is lying face down (bloom).
  final HapticSpec? faceDownAlt;
}

/// Everything between a moment and the motor (§3, "Budget rules").
///
/// A plain class that takes the setting, the focus status and the device
/// state as inputs, so every rule is unit-tested with no widget tree and no
/// platform channel (`test/haptics_governor_test.dart`). The rules:
///
///  1. **Setting** — Off / Essential / Full. Low Power Mode, a phone running
///     hot, or the OS reduce-motion switch drops Full to Essential.
///  2. **Running session** — no vibration the student didn't trigger.
///  3. **Wheels** — at most one tick per 40 ms; faster than 25 steps a second
///     plays at half strength; the landing tick at full strength.
///  4. **One frame, one haptic** — the higher tier wins; a tie, the later.
///  5. **Signatures** — crystallise, melt, bloom, drill and crack are kept
///     2 s apart: if two collide, the earlier is stopped and the later plays.
///  6. **Repetition** — the same pattern again within 10 minutes plays at 85%
///     of its last strength, never below 50%; 10 idle minutes reset it.
class HapticGovernor {
  HapticGovernor({
    required this.play,
    required this.stop,
    DateTime Function()? clock,
    void Function(void Function() flush)? schedule,
  })  : _clock = clock ?? DateTime.now,
        _schedule = schedule ?? scheduleMicrotask;

  final void Function(AdmittedHaptic haptic) play;
  final void Function(int id) stop;
  final DateTime Function() _clock;
  final void Function(void Function() flush) _schedule;

  static const Duration wheelGap = Duration(milliseconds: 40);
  static const Duration signatureGap = Duration(seconds: 2);
  static const Duration repetitionWindow = Duration(minutes: 10);
  static const double repetitionDecay = 0.85;
  static const double repetitionFloor = 0.5;

  int _nextId = 1;

  DateTime? _lastStreamSubmit;
  DateTime? _lastStreamPlay;

  DateTime? _lastSignatureAt;
  int? _lastSignatureId;

  final Map<String, (DateTime, double)> _repeats = {};

  _Pending? _pending;
  bool _flushScheduled = false;

  /// Whether [tier] plays under [setting]. [constrained] is Low Power Mode, a
  /// hot phone or reduce-motion: each drops Full to Essential, never lower.
  static bool admits(HapticSetting setting, HapticTier tier, {bool constrained = false}) {
    if (tier == HapticTier.preview) return true;
    final effective = constrained && setting == HapticSetting.full ? HapticSetting.essential : setting;
    return switch (effective) {
      HapticSetting.off => false,
      HapticSetting.essential => tier == HapticTier.essential,
      HapticSetting.full => true,
    };
  }

  /// Offer [moment] (already resolved to [spec]) to the motor.
  void submit(
    HapticMoment moment,
    HapticSpec spec, {
    required HapticSetting setting,
    required bool focusRunning,
    bool constrained = false,
    bool landed = false,
    HapticSpec? faceDownAlt,
  }) {
    if (!admits(setting, moment.tier, constrained: constrained)) return;
    if (focusRunning && moment.ambient) return;

    var playSpec = spec;
    if (moment.stream) {
      final now = _clock();
      final lastSubmit = _lastStreamSubmit;
      _lastStreamSubmit = now;
      if (!landed) {
        final lastPlay = _lastStreamPlay;
        if (lastPlay != null && now.difference(lastPlay) < wheelGap) return;
        if (lastSubmit != null && now.difference(lastSubmit) < wheelGap) {
          playSpec = playSpec.scaled(0.5);
        }
      }
      _lastStreamPlay = now;
    }

    final rank = moment.tier == HapticTier.full ? 1 : 0;
    final pending = _pending;
    if (pending == null || rank <= pending.rank) {
      _pending = _Pending(moment, playSpec, rank, faceDownAlt);
    }
    if (!_flushScheduled) {
      _flushScheduled = true;
      _schedule(flush);
    }
  }

  /// Play whatever won this frame. Public because the tests drive it.
  void flush() {
    _flushScheduled = false;
    final pending = _pending;
    _pending = null;
    if (pending == null) return;
    final now = _clock();
    final id = _nextId++;

    if (pending.spec.signature) {
      final last = _lastSignatureAt;
      final lastId = _lastSignatureId;
      if (last != null && lastId != null && now.difference(last) < signatureGap) stop(lastId);
      _lastSignatureAt = now;
      _lastSignatureId = id;
    }

    var spec = pending.spec;
    var alt = pending.faceDownAlt;
    if (_repeatable(pending.moment, spec)) {
      final k = _repeatFactor(spec.name, now);
      spec = spec.scaled(k);
      alt = alt?.scaled(k);
    }
    play(AdmittedHaptic(id: id, spec: spec, faceDownAlt: alt));
  }

  /// A hold (the thaw breath, a ratchet): admitted now, outside the frame
  /// coalescing, and never softened by repetition — its strength is the
  /// spec's. Returns null when the setting or the session silences it.
  AdmittedHaptic? admitHold(
    HapticMoment moment,
    HapticSpec spec, {
    required HapticSetting setting,
    required bool focusRunning,
    bool constrained = false,
  }) {
    if (!admits(setting, moment.tier, constrained: constrained)) return null;
    if (focusRunning && moment.ambient) return null;
    return AdmittedHaptic(id: _nextId++, spec: spec);
  }

  bool _repeatable(HapticMoment moment, HapticSpec spec) =>
      !moment.stream && moment.tier != HapticTier.preview && spec.iosSystem == null;

  double _repeatFactor(String name, DateTime now) {
    final last = _repeats[name];
    final k = last == null || now.difference(last.$1) >= repetitionWindow
        ? 1.0
        : math.max(repetitionFloor, last.$2 * repetitionDecay);
    _repeats[name] = (now, k);
    return k;
  }
}

class _Pending {
  _Pending(this.moment, this.spec, this.rank, this.faceDownAlt);

  final HapticMoment moment;
  final HapticSpec spec;
  final int rank;
  final HapticSpec? faceDownAlt;
}
