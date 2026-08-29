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
///
/// These five MUST stay identical to the `key` column of `feedback_statuses`
/// in the backend. They drifted once — this enum still carried an older
/// vocabulary (open / completed / acknowledged / exists_already) long after the
/// board shipped with under_review / planned / in_progress / shipped / declined
/// — and because [FeedbackStatusX.fromWire] silently falls back, three live
/// statuses collapsed into one value. The filter then queried a key the server
/// has never heard of, so a board with five shipped posts reported none.
enum FeedbackStatus {
  underReview,
  planned,
  inProgress,
  shipped,
  declined,
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
  /// Wire/string form used by the API and fixtures — the `feedback_statuses.key`
  /// the server filters on, so a wrong value here silently returns nothing.
  String get wire => switch (this) {
        FeedbackStatus.underReview => 'under_review',
        FeedbackStatus.inProgress => 'in_progress',
        _ => name,
      };

  /// Every key the backend defines is mapped explicitly.
  ///
  /// The fallback is the dangerous part and is deliberately the same value the
  /// database defaults to. It exists so an unrecognised key still renders, but
  /// it is also how this broke before: several real statuses landed on one enum
  /// value, which made the filter pills compare equal to each other and light up
  /// together. If the backend gains a status, add it here — a new key silently
  /// folding into `underReview` will look exactly like that bug again.
  static FeedbackStatus fromWire(String? value) => switch (value) {
        'under_review' => FeedbackStatus.underReview,
        'planned' => FeedbackStatus.planned,
        'in_progress' => FeedbackStatus.inProgress,
        'shipped' => FeedbackStatus.shipped,
        'declined' => FeedbackStatus.declined,
        _ => FeedbackStatus.underReview,
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
