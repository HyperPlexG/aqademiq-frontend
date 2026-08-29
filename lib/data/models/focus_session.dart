import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'focus_session.freezed.dart';

/// How many discrete melt stages a session is drawn in, on every surface.
///
/// The ambient surfaces (Live Activity, Dynamic Island, widgets) cannot animate
/// a mascot continuously: the OS renders the countdown itself and we are only
/// allowed to push a handful of updates per session. Five stages — one of them
/// the start — is the whole animation budget, so a stage change is the only
/// moment Ada visibly moves out there.
const int kMeltStages = 5;

/// A focus session. Once wired (README §8) the elapsed time is server-
/// authoritative (Redis + Socket.IO ticks); locally we keep [elapsedSec] for
/// cold-start resume.
@freezed
abstract class FocusSession with _$FocusSession {
  const factory FocusSession({
    required String id,
    required int durationMin,
    String? taskId,
    String? prismMode,
    @Default(0) int elapsedSec,
    @Default(FocusStatus.idle) FocusStatus status,
    DateTime? startedAt,
    DateTime? completedAt,
    int? endMood,

    /// Server-assigned experiment arm. When true the soundscape stays silent
    /// for this session — the client is told, never asked (see §4.3 holdout).
    @Default(false) bool controlArm,

    /// The instant this session is due to finish.
    ///
    /// In-app the timer counts [elapsedSec] up, but every *ambient* surface
    /// counts down from an absolute instant that the OS renders for free — a
    /// Live Activity, a Dynamic Island, an Android chronometer. None of them can
    /// be driven by a per-second push, so they need the end, not the elapsed.
    ///
    /// Freezing pushes this forward by however long the session was held (see
    /// [frozenAt]), which is what keeps the two clocks agreeing after a resume.
    DateTime? endsAt,

    /// When the session was frozen, or null while it is running.
    ///
    /// Held time must not be spent time: on resume the gap since this instant is
    /// added to [endsAt]. It also marks the countdown as stale — a system-drawn
    /// timer cannot be paused, so a frozen surface shows [remaining] as static
    /// text instead of a live clock.
    DateTime? frozenAt,
  }) = _FocusSession;

  const FocusSession._();

  /// Progress 0..1 of elapsed against the planned duration.
  double get progress {
    final total = durationMin * 60;
    if (total <= 0) return 0;
    return (elapsedSec / total).clamp(0.0, 1.0);
  }

  /// Whether the session is held. Frost, not a pause glyph.
  bool get isFrozen => status == FocusStatus.paused;

  /// Ada's current melt stage, `0..kMeltStages - 1`.
  ///
  /// Derived rather than stored so the three renderers cannot disagree about
  /// which stage a given progress is.
  int get meltStage =>
      (progress * kMeltStages).floor().clamp(0, kMeltStages - 1);

  /// Time left before [endsAt], frozen-aware and never negative.
  ///
  /// While frozen the clock is measured from [frozenAt], so the remaining time
  /// stops falling for exactly as long as the session is held.
  Duration get remaining {
    final end = endsAt;
    if (end == null) {
      return Duration(
        seconds: (durationMin * 60 - elapsedSec).clamp(0, 1 << 31),
      );
    }
    final from = frozenAt ?? DateTime.now();
    final left = end.difference(from);
    return left.isNegative ? Duration.zero : left;
  }
}
