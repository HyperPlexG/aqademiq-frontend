// Plain immutable models for the Settings sub-screens (notification + email
// preferences). Kept hand-written (not freezed) — they're small and only ever
// mapped in SettingsSource, so the codegen overhead isn't worth it.

/// The per-event notification channel toggles (backend `channel_key`s).
class NotificationChannels {
  const NotificationChannels({
    this.beforeTask = true, // task_due
    this.taskStart = true, // task_start
    this.taskHalf = false, // task_half
    this.taskEnd = false, // task_end
    this.morning = true, // morning
    this.review = true, // review
    this.weeklyReview = true, // weekly_review
  });

  final bool beforeTask;
  final bool taskStart;
  final bool taskHalf;
  final bool taskEnd;
  final bool morning;
  final bool review;
  final bool weeklyReview;

  NotificationChannels copyWith({
    bool? beforeTask,
    bool? taskStart,
    bool? taskHalf,
    bool? taskEnd,
    bool? morning,
    bool? review,
    bool? weeklyReview,
  }) =>
      NotificationChannels(
        beforeTask: beforeTask ?? this.beforeTask,
        taskStart: taskStart ?? this.taskStart,
        taskHalf: taskHalf ?? this.taskHalf,
        taskEnd: taskEnd ?? this.taskEnd,
        morning: morning ?? this.morning,
        review: review ?? this.review,
        weeklyReview: weeklyReview ?? this.weeklyReview,
      );
}

/// Notification preferences: the sound, the three reminder times (`HH:MM`), and
/// the per-event channel toggles.
class NotificationPrefs {
  const NotificationPrefs({
    this.sound = 'Chime',
    this.morningTime = '08:00',
    this.reviewTime = '20:00',
    this.weeklyReviewTime = '15:00',
    this.channels = const NotificationChannels(),
  });

  final String sound;
  final String morningTime;
  final String reviewTime;
  final String weeklyReviewTime;
  final NotificationChannels channels;

  NotificationPrefs copyWith({
    String? sound,
    String? morningTime,
    String? reviewTime,
    String? weeklyReviewTime,
    NotificationChannels? channels,
  }) =>
      NotificationPrefs(
        sound: sound ?? this.sound,
        morningTime: morningTime ?? this.morningTime,
        reviewTime: reviewTime ?? this.reviewTime,
        weeklyReviewTime: weeklyReviewTime ?? this.weeklyReviewTime,
        channels: channels ?? this.channels,
      );
}

/// Marketing-email opt-ins.
class EmailPrefs {
  const EmailPrefs({
    this.productUpdates = true,
    this.studyTips = true,
    this.offers = false,
    this.surveys = false,
  });

  final bool productUpdates;
  final bool studyTips;
  final bool offers;
  final bool surveys;

  EmailPrefs copyWith({
    bool? productUpdates,
    bool? studyTips,
    bool? offers,
    bool? surveys,
  }) =>
      EmailPrefs(
        productUpdates: productUpdates ?? this.productUpdates,
        studyTips: studyTips ?? this.studyTips,
        offers: offers ?? this.offers,
        surveys: surveys ?? this.surveys,
      );
}
