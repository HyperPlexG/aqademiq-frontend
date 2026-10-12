/// Everything the surfaces outside the app are allowed to know.
///
/// The lock screen, the Dynamic Island, the home-screen widgets and the Android
/// notification all render from this one flat object, handed across a shared
/// container (App Group on iOS, shared prefs on Android). Deliberately flat and
/// tiny: an extension gets a memory budget measured in megabytes and must never
/// be asked to think — no models, no network, no images cross this boundary.
///
/// Keeping it in one place is also what stops the three renderers disagreeing.
/// Anything a surface needs is added here and derived once, rather than each
/// platform recomputing it from raw session fields and drifting.
library;

import '../../data/models/enums.dart';
import '../../data/models/focus_session.dart';

/// The live-session half of the ambient state.
///
/// Absent (`null` on [AmbientState.session]) means no session is running, which
/// is the signal for every surface to stand down — on iOS that means ending the
/// Live Activity outright, because the Island is taken for a running session
/// and nothing else.
class AmbientSession {
  const AmbientSession({
    required this.endsAt,
    required this.frozen,
    required this.meltStage,
    required this.remainingSec,
    required this.durationSec,
    this.taskTitle,
    this.subjectLabel,
    this.subjectTint,
    this.prismMode,
  });

  /// When the session is due to finish. The OS counts down to this on its own.
  final DateTime endsAt;

  /// Whether the session is held. Frost, not a pause glyph.
  ///
  /// A system-rendered countdown cannot be paused, so a frozen surface shows
  /// [remainingSec] as static text instead of a live clock.
  final bool frozen;

  /// Ada's stage, `0..kMeltStages - 1`. The only thing we ever push.
  final int meltStage;

  /// Seconds left, for the frozen case where the live clock must be replaced.
  final int remainingSec;

  /// The whole planned length, so a surface can draw how much is spent without
  /// doing arithmetic the app has already done.
  final int durationSec;

  /// What the student sat down to do — the whole point of the expanded Island.
  final String? taskTitle;

  /// The subject the task belongs to, e.g. `Linear Algebra`.
  final String? subjectLabel;

  /// Subject colour as `#RRGGBB`, already resolved from the tag.
  final String? subjectTint;

  /// Which soundscape is running, e.g. `Deep Work`. Shown, never offered —
  /// the modes cross-fade over five adaptive seconds and cannot be switched
  /// from a lock-screen tap without sounding broken.
  final String? prismMode;

  Map<String, Object?> toMap() => {
        'endsAt': endsAt.toUtc().toIso8601String(),
        'frozen': frozen,
        'meltStage': meltStage,
        'remainingSec': remainingSec,
        'durationSec': durationSec,
        if (taskTitle != null) 'taskTitle': taskTitle,
        if (subjectLabel != null) 'subjectLabel': subjectLabel,
        if (subjectTint != null) 'subjectTint': subjectTint,
        if (prismMode != null) 'prismMode': prismMode,
      };

  static AmbientSession? fromMap(Map<String, Object?>? map) {
    if (map == null) return null;
    final endsAt = DateTime.tryParse(map['endsAt'] as String? ?? '');
    if (endsAt == null) return null;
    return AmbientSession(
      endsAt: endsAt.toLocal(),
      frozen: map['frozen'] as bool? ?? false,
      meltStage: map['meltStage'] as int? ?? 0,
      remainingSec: map['remainingSec'] as int? ?? 0,
      durationSec: map['durationSec'] as int? ?? 0,
      taskTitle: map['taskTitle'] as String?,
      subjectLabel: map['subjectLabel'] as String?,
      subjectTint: map['subjectTint'] as String?,
      prismMode: map['prismMode'] as String?,
    );
  }

  /// Derive the ambient view of a session. Returns null when nothing should be
  /// shown out there — an idle or finished session is not an ambient one.
  static AmbientSession? from(
    FocusSession session, {
    String? taskTitle,
    String? subjectLabel,
    String? subjectTint,
    String? prismMode,
  }) {
    final endsAt = session.endsAt;
    final live = session.status == FocusStatus.running ||
        session.status == FocusStatus.paused;
    if (!live || endsAt == null) return null;
    return AmbientSession(
      endsAt: endsAt,
      frozen: session.isFrozen,
      meltStage: session.meltStage,
      remainingSec: session.remaining.inSeconds,
      durationSec: session.durationMin * 60,
      taskTitle: taskTitle,
      subjectLabel: subjectLabel,
      subjectTint: subjectTint,
      prismMode: prismMode,
    );
  }

  /// Whether a change is worth waking a surface for.
  ///
  /// The budget is five pushes a session, so the clock alone must never spend
  /// one: [remainingSec] falls every second and is deliberately not compared.
  /// Only a stage change, a freeze, or a change in what is being worked on is
  /// a reason to redraw.
  bool differsMateriallyFrom(AmbientSession? other) =>
      other == null ||
      other.meltStage != meltStage ||
      other.frozen != frozen ||
      other.taskTitle != taskTitle ||
      other.subjectLabel != subjectLabel ||
      other.subjectTint != subjectTint ||
      other.prismMode != prismMode ||
      // A freeze moves the end, so the surfaces must re-anchor their countdown.
      other.endsAt != endsAt;
}

/// The whole shared payload: the session, plus the glanceable data the widgets
/// show when nothing is running.
class AmbientState {
  const AmbientState({
    this.session,
    this.nextTaskTitle,
    this.nextTaskTime,
    this.nextTaskSubject,
    this.nextTaskTint,
    this.weekDays = const [],
    this.todayFocusMin = 0,
  });

  factory AmbientState.fromMap(Map<String, Object?> map) => AmbientState(
        session: AmbientSession.fromMap(
          (map['session'] as Map?)?.cast<String, Object?>(),
        ),
        nextTaskTitle: map['nextTaskTitle'] as String?,
        nextTaskTime: map['nextTaskTime'] as String?,
        nextTaskSubject: map['nextTaskSubject'] as String?,
        nextTaskTint: map['nextTaskTint'] as String?,
        weekDays:
            (map['weekDays'] as List?)?.map((e) => e == true).toList() ?? const [],
        todayFocusMin: map['todayFocusMin'] as int? ?? 0,
      );

  /// The running session, or null when there is none.
  final AmbientSession? session;

  /// The single next task — one, never a list. A list makes a student choose
  /// again, and choosing again is the thing that stalls them.
  final String? nextTaskTitle;

  /// Its start time as already-formatted text, e.g. `14:00`.
  final String? nextTaskTime;
  final String? nextTaskSubject;
  final String? nextTaskTint;

  /// Seven flags, Monday first: did the student show up that day.
  ///
  /// A day they did wears Ada's face; a day they did not is an empty outline —
  /// never a puddle, because absence is not depletion.
  final List<bool> weekDays;

  /// Minutes focused today, for the lock-screen ring.
  final int todayFocusMin;

  Map<String, Object?> toMap() => {
        if (session != null) 'session': session!.toMap(),
        if (nextTaskTitle != null) 'nextTaskTitle': nextTaskTitle,
        if (nextTaskTime != null) 'nextTaskTime': nextTaskTime,
        if (nextTaskSubject != null) 'nextTaskSubject': nextTaskSubject,
        if (nextTaskTint != null) 'nextTaskTint': nextTaskTint,
        'weekDays': weekDays,
        'todayFocusMin': todayFocusMin,
      };
}
