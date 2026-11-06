import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../models/user_settings.dart';
import '../sources/settings_source.dart';

/// Notification + email preferences and app rating, behind the mock/api seam.
class SettingsRepository {
  SettingsRepository(this._source);

  final SettingsSource _source;

  Future<NotificationPrefs> getNotificationPrefs() =>
      _source.getNotificationPrefs();

  Future<void> patchNotificationPrefs({
    String? sound,
    String? morningTime,
    String? reviewTime,
  }) =>
      _source.patchNotificationPrefs(
        sound: sound,
        morningTime: morningTime,
        reviewTime: reviewTime,
      );

  Future<void> putChannels(
    NotificationChannels channels, {
    required String morningTime,
    required String reviewTime,
    required String weeklyReviewTime,
  }) =>
      _source.putChannels(
        channels,
        morningTime: morningTime,
        reviewTime: reviewTime,
        weeklyReviewTime: weeklyReviewTime,
      );

  Future<EmailPrefs> getEmailPrefs() => _source.getEmailPrefs();
  Future<void> patchEmailPrefs(EmailPrefs prefs) =>
      _source.patchEmailPrefs(prefs);

  Future<void> submitRating({required int rating, String? comment}) =>
      _source.submitRating(rating: rating, comment: comment);

  Future<({String status, String? error})> sendTestNotification() =>
      _source.sendTestNotification();
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final source = Env.useMocks
      ? MockSettingsSource()
      : ApiSettingsSource(ref.watch(dioProvider));
  return SettingsRepository(source);
});

/// The signed-in user's notification preferences (loaded once per screen open).
///
/// autoDispose on purpose: the screen seeds its editable copy from the
/// loading → data transition (`ref.listen`), which a cached value would never
/// produce on a second visit — and a cached value would also be stale, since
/// edits are written straight to the repository, not back into this provider.
final notificationPrefsProvider = FutureProvider.autoDispose<NotificationPrefs>(
  (ref) => ref.watch(settingsRepositoryProvider).getNotificationPrefs(),
);

/// The signed-in user's marketing-email preferences (loaded once per screen
/// open; autoDispose for the same reason as [notificationPrefsProvider]).
final emailPrefsProvider = FutureProvider.autoDispose<EmailPrefs>(
  (ref) => ref.watch(settingsRepositoryProvider).getEmailPrefs(),
);
