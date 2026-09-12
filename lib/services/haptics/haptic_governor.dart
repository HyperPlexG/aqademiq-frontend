import 'dart:async';

import 'haptic_patterns.dart';

/// The user-facing setting — spec §6.5.
///
/// Sits **under** the OS accessibility setting and never overrides it; see
/// [HapticGovernor.admits] for how reduce-motion clamps it.
enum HapticSetting {
  /// Nothing fires, ever.
  off,

  /// Tiers 1 and 4 only — the earned moments and the warnings.
  essential,

  /// All four tiers.
  full;

  /// Stable key for SharedPreferences; a bare `name` would silently change
  /// meaning if a value were ever renamed.
  String get storageKey => switch (this) {
        HapticSetting.off => 'off',
        HapticSetting.essential => 'essential',
        HapticSetting.full => 'full',
      };

  static HapticSetting fromStorageKey(String? key) => switch (key) {
        'off' => HapticSetting.off,
        'essential' => HapticSetting.essential,
        _ => HapticSetting.full,
      };

  /// Row label in Settings → Prism.
  String get label => switch (this) {
        HapticSetting.off => 'Off',
        HapticSetting.essential => 'Essential',
        HapticSetting.full => 'Full',
      };

  String get description => switch (this) {
        HapticSetting.off => 'No haptics at all.',
        HapticSetting.essential =>
          'Only the moments you earned, and warnings.',
        HapticSetting.full => 'Confirmations and selection ticks too.',
      };
}

/// What actually reaches the motor — guide §1.3.
///
/// Everything routes through here. Without it haptics rots: every new feature
/// adds a buzz and nobody ever sees the aggregate.
///
/// Deliberately a plain class that takes the current focus status and setting as
/// **inputs** rather than reaching into providers itself, so the rules that fail
/// silently can be unit-tested with no widget tree and no platform channel
/// (`test/haptics_governor_test.dart`).
///
/// The rules, in the order the guide lists them:
///
///  1. the user setting — Off / Essential / Full, clamped by reduce-motion;
///  2. focus-session suppression — the strictest rule in the document;
///  3. a minimum interval floor between any two fires;
///  4. fling suppression, so a fast scroll does not rattle;
///  5. burst coalescing — one frame, one haptic, the highest tier.
class HapticGovernor {
  HapticGovernor({
    required this.play,
    DateTime Function()? clock,
    void Function(void Function() flush)? schedule,
  })  : _clock = clock ?? DateTime.now,
        _schedule = schedule ?? scheduleMicrotask;

  /// Hands an admitted event to the physical layer. Injected so tests can
  /// record instead of vibrate.
  final void Function(HapticEvent event, int? rampStep) play;

  final DateTime Function() _clock;

  /// Defers [flush] to the end of the current turn. Defaults to
  /// [scheduleMicrotask] rather than a post-frame callback so the governor
  /// stays free of Flutter bindings; tests pass a manual scheduler and drive
  /// [flush] themselves.
  final void Function(void Function() flush) _schedule;

  /// §4.4 — "a 40–60 ms floor between ticks". The midpoint.
  static const Duration minInterval = Duration(milliseconds: 50);

  /// Detents arriving closer together than this are a fling, not a selection.
  /// Deliberate wheel-turning lands well outside it.
  static const Duration flingGap = Duration(milliseconds: 80);

  /// How many rapid detents in a row before we call it a fling. Two fast ticks
  /// happen when someone flicks a wheel one stop; three is a scroll.
  static const int flingRun = 3;

  /// The only events allowed through while a session is running — spec §4.2:
  /// "Only user-triggered freeze, resume and end may fire."
  ///
  /// [HapticEvent.focusStarted] is **not** here on purpose. It is a session
  /// transition too, but by the time it fires the session has begun, and
  /// allow-listing it would widen the strictest rule in the document to cover
  /// the interior of a run. `FocusController.start` fires it in the window
  /// before the status flips to running instead; see the note there.
  static const Set<HapticEvent> sessionTransitions = {
    HapticEvent.sessionFrozen,
    HapticEvent.sessionResumed,
    HapticEvent.sessionEndedEarly,
    HapticEvent.focusCompleted,
  };

  DateTime? _lastPlayedAt;
  DateTime? _lastDetentAt;
  int _rapidDetents = 0;

  HapticEvent? _pending;
  int? _pendingRamp;
  bool _flushScheduled = false;

  /// Offer [event] to the motor. Silently drops it unless every rule passes.
  void submit(
    HapticEvent event, {
    required HapticSetting setting,
    required bool focusRunning,
    required bool reducedMotion,
    int? rampStep,
  }) {
    // 1 — the user setting (and the OS one above it).
    if (!admits(setting, event.tier, reducedMotion: reducedMotion)) return;

    // 2 — focus-session suppression. The entire promise of /focus is
    // undisturbed attention, and this is also how the haptic layer stays out of
    // Prism's way.
    if (focusRunning && !sessionTransitions.contains(event)) return;

    // 3 — fling suppression. During a fling the user is not reading positions,
    // so the ticks convey nothing and merely blur into a rattle.
    if (event.tier == HapticTier.detent && _consumeDetentAsFling()) return;

    // 4 — burst coalescing: remember only the highest tier offered this frame.
    final pending = _pending;
    if (pending == null || event.tier.index < pending.tier.index) {
      _pending = event;
      _pendingRamp = rampStep;
    }
    if (!_flushScheduled) {
      _flushScheduled = true;
      _schedule(flush);
    }
  }

  /// Play whatever won this frame, if the interval floor allows it.
  ///
  /// Public because the tests drive it directly; nothing in `lib/` calls it.
  void flush() {
    _flushScheduled = false;
    final event = _pending;
    if (event == null) return;
    final rampStep = _pendingRamp;
    _pending = null;
    _pendingRamp = null;

    // 5 — the minimum interval, measured against what actually fired rather
    // than what was offered, so a burst of dropped events cannot starve the
    // next real one.
    final now = _clock();
    final last = _lastPlayedAt;
    if (last != null && now.difference(last) < minInterval) return;

    _lastPlayedAt = now;
    play(event, rampStep);
  }

  /// Whether [tier] survives [setting] under the current OS accessibility
  /// state.
  ///
  /// Spec §6.5 asks the setting to "honour the same contract as
  /// prefers-reduced-motion". Reduce-motion is very often a statement about
  /// sensory load rather than battery life, so it clamps Full down to
  /// Essential: the earned moments and the warnings carry information and
  /// survive; the confirmations and detents are texture and do not. Off stays
  /// Off — the app setting may always be *stricter* than the OS, never looser.
  static bool admits(
    HapticSetting setting,
    HapticTier tier, {
    required bool reducedMotion,
  }) {
    final effective = reducedMotion && setting == HapticSetting.full
        ? HapticSetting.essential
        : setting;
    return switch (effective) {
      HapticSetting.off => false,
      HapticSetting.essential =>
        tier == HapticTier.earned || tier == HapticTier.warning,
      HapticSetting.full => true,
    };
  }

  /// Records this detent and reports whether we are mid-fling.
  ///
  /// Mutates on every detent, including suppressed ones, so the run keeps
  /// counting for as long as the wheel is spinning and resets the moment it
  /// slows below [flingGap].
  bool _consumeDetentAsFling() {
    final now = _clock();
    final last = _lastDetentAt;
    _lastDetentAt = now;
    if (last != null && now.difference(last) < flingGap) {
      _rapidDetents++;
    } else {
      _rapidDetents = 0;
    }
    return _rapidDetents >= flingRun;
  }
}
