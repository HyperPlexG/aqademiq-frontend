// Shared enums used across UI models. Kept free of freezed/codegen so they can
// be imported anywhere (models, adapters, widgets) without a part file.

/// Coarse time-of-day bucket for a task (the prototype's "Anytime / Morning /
/// Afternoon / Evening" grouping).
enum DayPart { morning, afternoon, evening, anytime }

/// How a task repeats. [none] means a one-off task.
enum RepeatFrequency { none, daily, weekly, monthly, custom }

/// Whether a subject's grade target is expressed as a GPA or a percentage.
enum SubjectTargetKind { gpa, percent }

/// Lifecycle of a focus session (server-authoritative once wired to Redis).
enum FocusStatus { idle, running, paused, completed }

/// When a mood was logged.
enum MoodPhase { morning, evening, adhoc }

/// Author of an Ada chat message.
enum AdaRole { user, ada }

/// Lifecycle of a feedback-board suggestion (the board's columns).
enum FeedbackStatus {
  open,
  planned,
  inProgress,
  completed,
  acknowledged,
  existsAlready,
}

/// What kind of feedback a board post is.
enum FeedbackCategory { feature, improvement, bug }

extension DayPartX on DayPart {
  /// Wire/string form used by the API and fixtures.
  String get wire => name;

  static DayPart fromWire(String? value) => switch (value) {
        'morning' => DayPart.morning,
        'afternoon' => DayPart.afternoon,
        'evening' => DayPart.evening,
        _ => DayPart.anytime,
      };
}

extension FeedbackStatusX on FeedbackStatus {
  /// Wire/string form used by the API and fixtures.
  String get wire => switch (this) {
        FeedbackStatus.inProgress => 'in_progress',
        FeedbackStatus.existsAlready => 'exists_already',
        _ => name,
      };

  static FeedbackStatus fromWire(String? value) => switch (value) {
        'planned' => FeedbackStatus.planned,
        'in_progress' => FeedbackStatus.inProgress,
        'completed' => FeedbackStatus.completed,
        'acknowledged' => FeedbackStatus.acknowledged,
        'exists_already' => FeedbackStatus.existsAlready,
        _ => FeedbackStatus.open,
      };
}

extension FeedbackCategoryX on FeedbackCategory {
  /// Wire/string form used by the API and fixtures.
  String get wire => name;

  static FeedbackCategory fromWire(String? value) => switch (value) {
        'improvement' => FeedbackCategory.improvement,
        'bug' => FeedbackCategory.bug,
        _ => FeedbackCategory.feature,
      };
}
