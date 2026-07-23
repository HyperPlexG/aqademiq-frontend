import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/user_settings.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/widgets/settings_row.dart';
import 'sheets/notif_sound_sheet.dart';
import 'widgets/settings_scaffold.dart';

/// FRAMES `settings-notif` — the Notifications route. Loads the user's real
/// notification preferences (`/me/notification-preferences`) and persists every
/// change (sound + times via PATCH, per-event toggles via PUT channels).
///
/// Only the events the backend actually schedules are shown — the earlier
/// mock-only rows (all-day, state-of-mind, motivational) were dropped because
/// they had no channel behind them.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationPrefs? _prefs;

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parse(String s) {
    final parts = s.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  void _setPrefs(NotificationPrefs next) => setState(() => _prefs = next);

  Future<void> _setSound(String sound) async {
    _setPrefs(_prefs!.copyWith(sound: sound));
    await _repo.patchNotificationPrefs(sound: sound).catchError((_) {});
  }

  Future<void> _saveChannels(NotificationChannels channels) async {
    final p = _prefs!.copyWith(channels: channels);
    _setPrefs(p);
    await _repo
        .putChannels(
          channels,
          morningTime: p.morningTime,
          reviewTime: p.reviewTime,
          weeklyReviewTime: p.weeklyReviewTime,
        )
        .catchError((_) {});
  }

  Future<void> _sendTest() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.sendTestNotification();
      messenger.showSnackBar(
        const SnackBar(content: Text('Test notification sent — check your device.')),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't send a test notification.")),
      );
    }
  }

  Future<void> _pickTime(String current, ValueChanged<String> apply) async {
    final picked =
        await showTimePicker(context: context, initialTime: _parse(current));
    if (picked != null) apply(_hhmm(picked));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Seed local editable state once the preferences load.
    ref.listen(notificationPrefsProvider, (_, next) {
      final v = next.value;
      if (v != null && _prefs == null) setState(() => _prefs = v);
    });
    final async = ref.watch(notificationPrefsProvider);
    final prefs = _prefs;

    if (prefs == null) {
      return SettingsScaffold(
        title: 'Notifications',
        children: [
          const SizedBox(height: 40),
          Center(
            child: async.hasError
                ? Text(
                    "Couldn't load your notification settings",
                    style: AppText.sans(size: 13, color: colors.textMed),
                  )
                : CircularProgressIndicator(color: colors.accent, strokeWidth: 2.5),
          ),
        ],
      );
    }

    final c = prefs.channels;
    return SettingsScaffold(
      title: 'Notifications',
      children: [
        SetGroup(
          children: [
            SettingsRow(
              label: 'Notification sound',
              value: prefs.sound,
              showChevron: true,
              onTap: () async {
                final picked = await showNotifSoundSheet(context, current: prefs.sound);
                if (picked != null) await _setSound(picked);
              },
            ),
            SettingsRow(
              label: 'Send a test notification',
              icon: Icons.notifications_active_outlined,
              showChevron: true,
              last: true,
              onTap: _sendTest,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const GroupLabel('Tasks'),
        SetGroup(
          children: [
            SettingsRow(
              label: 'Before task',
              toggle: c.beforeTask,
              onToggle: (v) => unawaited(_saveChannels(c.copyWith(beforeTask: v))),
            ),
            SettingsRow(
              label: 'When a task starts',
              toggle: c.taskStart,
              onToggle: (v) => unawaited(_saveChannels(c.copyWith(taskStart: v))),
            ),
            SettingsRow(
              label: 'Halfway through task',
              toggle: c.taskHalf,
              onToggle: (v) => unawaited(_saveChannels(c.copyWith(taskHalf: v))),
            ),
            SettingsRow(
              label: 'When a task is finished',
              toggle: c.taskEnd,
              onToggle: (v) => unawaited(_saveChannels(c.copyWith(taskEnd: v))),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const GroupLabel('Daily reminders'),
        SetGroup(
          children: [
            SettingsRow(
              label: 'Morning check-in',
              toggle: c.morning,
              onToggle: (v) => unawaited(_saveChannels(c.copyWith(morning: v))),
            ),
            SettingsRow(
              label: 'At time',
              pill: _parse(prefs.morningTime).format(context),
              onTap: () => unawaited(_pickTime(prefs.morningTime, (t) async {
                _setPrefs(_prefs!.copyWith(morningTime: t));
                await _repo.patchNotificationPrefs(morningTime: t).catchError((_) {});
              })),
            ),
            SettingsRow(
              label: 'Evening review',
              toggle: c.review,
              onToggle: (v) => unawaited(_saveChannels(c.copyWith(review: v))),
            ),
            SettingsRow(
              label: 'At time',
              pill: _parse(prefs.reviewTime).format(context),
              onTap: () => unawaited(_pickTime(prefs.reviewTime, (t) async {
                _setPrefs(_prefs!.copyWith(reviewTime: t));
                await _repo.patchNotificationPrefs(reviewTime: t).catchError((_) {});
              })),
            ),
            SettingsRow(
              label: 'Weekly review',
              toggle: c.weeklyReview,
              onToggle: (v) => unawaited(_saveChannels(c.copyWith(weeklyReview: v))),
            ),
            SettingsRow(
              label: 'At time',
              pill: _parse(prefs.weeklyReviewTime).format(context),
              last: true,
              onTap: () => unawaited(_pickTime(prefs.weeklyReviewTime, (t) async {
                _setPrefs(_prefs!.copyWith(weeklyReviewTime: t));
                await _saveChannels(_prefs!.channels);
              })),
            ),
          ],
        ),
      ],
    );
  }
}
