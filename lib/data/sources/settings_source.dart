import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../models/user_settings.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// Source for the Settings sub-screens: notification + email preferences and
/// the app rating. Mirrors `/v1/me/*` (settings.service) and `POST /v1/ratings`.
abstract interface class SettingsSource {
  Future<NotificationPrefs> getNotificationPrefs();

  /// Persist the sound + morning/review times (`HH:MM`). Only non-null fields
  /// are sent.
  Future<void> patchNotificationPrefs({
    String? sound,
    String? morningTime,
    String? reviewTime,
  });

  /// Replace the per-event channel toggles (and the weekly-review time).
  Future<void> putChannels(
    NotificationChannels channels, {
    required String morningTime,
    required String reviewTime,
    required String weeklyReviewTime,
  });

  Future<EmailPrefs> getEmailPrefs();
  Future<void> patchEmailPrefs(EmailPrefs prefs);

  Future<void> submitRating({required int rating, String? comment});

  /// Ask the backend to push a test notification to this device. Returns the
  /// delivery outcome so the UI can distinguish "sent" from a server-side
  /// misconfiguration (`skipped_no_provider`) or an APNs/FCM `failed`.
  Future<({String status, String? error})> sendTestNotification();
}

class MockSettingsSource implements SettingsSource {
  NotificationPrefs _notif = const NotificationPrefs();
  EmailPrefs _email = const EmailPrefs();

  @override
  Future<NotificationPrefs> getNotificationPrefs() => mockDelay(_notif);

  @override
  Future<void> patchNotificationPrefs({
    String? sound,
    String? morningTime,
    String? reviewTime,
  }) {
    _notif = _notif.copyWith(
      sound: sound,
      morningTime: morningTime,
      reviewTime: reviewTime,
    );
    return mockDelay(null);
  }

  @override
  Future<void> putChannels(
    NotificationChannels channels, {
    required String morningTime,
    required String reviewTime,
    required String weeklyReviewTime,
  }) {
    _notif = _notif.copyWith(channels: channels, weeklyReviewTime: weeklyReviewTime);
    return mockDelay(null);
  }

  @override
  Future<EmailPrefs> getEmailPrefs() => mockDelay(_email);

  @override
  Future<void> patchEmailPrefs(EmailPrefs prefs) {
    _email = prefs;
    return mockDelay(null);
  }

  @override
  Future<void> submitRating({required int rating, String? comment}) =>
      mockDelay(null);

  @override
  Future<({String status, String? error})> sendTestNotification() =>
      mockDelay((status: 'sent', error: null));
}

class ApiSettingsSource implements SettingsSource {
  ApiSettingsSource(this._dio);
  final Dio _dio;

  @override
  Future<NotificationPrefs> getNotificationPrefs() async {
    final body = await _dio.getMap('/me/notification-preferences');
    return _notifFrom(body);
  }

  @override
  Future<void> patchNotificationPrefs({
    String? sound,
    String? morningTime,
    String? reviewTime,
  }) async {
    await _dio.patchMap('/me/notification-preferences', <String, dynamic>{
      'notification_sound': ?sound,
      'notification_time_morning': ?morningTime,
      'notification_time_review': ?reviewTime,
    });
  }

  @override
  Future<void> putChannels(
    NotificationChannels c, {
    required String morningTime,
    required String reviewTime,
    required String weeklyReviewTime,
  }) async {
    await _dio.putMap('/me/notification-channels', <String, dynamic>{
      'channels': <Map<String, dynamic>>[
        {'channel_key': 'task_due', 'enabled': c.beforeTask},
        {'channel_key': 'task_start', 'enabled': c.taskStart},
        {'channel_key': 'task_half', 'enabled': c.taskHalf},
        {'channel_key': 'task_end', 'enabled': c.taskEnd},
        {'channel_key': 'morning', 'enabled': c.morning, 'send_time': morningTime},
        {'channel_key': 'review', 'enabled': c.review, 'send_time': reviewTime},
        {
          'channel_key': 'weekly_review',
          'enabled': c.weeklyReview,
          'send_time': weeklyReviewTime,
        },
      ],
    });
  }

  @override
  Future<EmailPrefs> getEmailPrefs() async {
    final body = await _dio.getMap('/me/email-preferences');
    return EmailPrefs(
      productUpdates: body['product_updates'] as bool? ?? true,
      studyTips: body['study_tips'] as bool? ?? true,
      offers: body['offers'] as bool? ?? false,
      surveys: body['surveys'] as bool? ?? false,
    );
  }

  @override
  Future<void> patchEmailPrefs(EmailPrefs p) async {
    await _dio.patchMap('/me/email-preferences', <String, dynamic>{
      'product_updates': p.productUpdates,
      'study_tips': p.studyTips,
      'offers': p.offers,
      'surveys': p.surveys,
    });
  }

  @override
  Future<void> submitRating({required int rating, String? comment}) async {
    await _dio.postMap('/ratings', <String, dynamic>{
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  @override
  Future<({String status, String? error})> sendTestNotification() async {
    try {
      final body = await _dio.postMap('/me/notifications/test');
      return (
        status: body['status'] as String? ?? 'unknown',
        error: body['error'] as String?,
      );
    } on Failure catch (f) {
      // postMap maps every HTTP error to a typed Failure, so THIS is what a
      // non-2xx (e.g. 400 "No registered device to send a test push to")
      // surfaces as — not a DioException. Show its message verbatim.
      return (status: 'failed', error: f.message);
    } on Object catch (e) {
      return (status: 'failed', error: e.toString());
    }
  }

  NotificationPrefs _notifFrom(Map<String, dynamic> body) {
    final channels = <String, Map<String, dynamic>>{};
    for (final ch in listOf(body, 'channels')) {
      final key = ch['channel_key'] as String?;
      if (key != null) channels[key] = ch;
    }
    bool on(String key, {required bool orElse}) =>
        channels[key]?['enabled'] as bool? ?? orElse;
    String? timeOf(String key) => channels[key]?['send_time'] as String?;

    return NotificationPrefs(
      sound: body['notification_sound'] as String? ?? 'Chime',
      morningTime: body['notification_time_morning'] as String? ?? '08:00',
      reviewTime: body['notification_time_review'] as String? ?? '20:00',
      weeklyReviewTime: timeOf('weekly_review') ?? '15:00',
      channels: NotificationChannels(
        beforeTask: on('task_due', orElse: true),
        taskStart: on('task_start', orElse: true),
        taskHalf: on('task_half', orElse: false),
        taskEnd: on('task_end', orElse: false),
        morning: on('morning', orElse: true),
        review: on('review', orElse: true),
        weeklyReview: on('weekly_review', orElse: true),
      ),
    );
  }
}
