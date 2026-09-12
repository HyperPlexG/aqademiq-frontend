import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the weekly report is shown at all.
///
/// §6 of the design starts with a real off switch, and everything else in the
/// contract depends on it: a report you cannot decline is a report that can
/// hurt you every seven days forever. So this is one tap, honoured
/// immediately — no confirmation, no "are you sure you'll miss out", no
/// win-back screen, and no re-prompt in a later release. Turning it off
/// removes the entry point from the Stats tab; there is no other way in.
///
/// Stored locally rather than on the server, beside the haptics and Prism
/// settings. Two reasons: it takes effect on the device the student is holding
/// with no round trip, and it works identically in Guest Mode, where a
/// server-side preference would need an account — which would make declining
/// the report something you have to sign up to do.
class ReportSettingsService {
  ReportSettingsService._();

  static final ReportSettingsService instance = ReportSettingsService._();

  static const _kEnabled = 'weekly_report_enabled';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Defaults to on. An unset value is a student who has not been asked yet,
  /// and the report is a normal part of the product until they say otherwise.
  bool get enabled => _prefs?.getBool(_kEnabled) ?? true;

  Future<void> setEnabled({required bool value}) async =>
      _prefs?.setBool(_kEnabled, value);
}

class WeeklyReportEnabled extends Notifier<bool> {
  @override
  bool build() => ReportSettingsService.instance.enabled;

  /// Applied to state first, so the entry point disappears on the same frame
  /// as the tap rather than after a disk write.
  Future<void> set({required bool value}) async {
    state = value;
    await ReportSettingsService.instance.setEnabled(value: value);
  }
}

final weeklyReportEnabledProvider =
    NotifierProvider<WeeklyReportEnabled, bool>(WeeklyReportEnabled.new);
