// The weekly report's feel (haptics §4, "08 · The Core"): the core drills in
// once as the report opens, a page turn ticks, the hero beat is still, the
// numeral lands with a thud, each thaw cracks once, and accepting the one
// small thing latches. A thin week gets exactly the same patterns.

import 'dart:async';

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/weekly_report.dart';
import 'package:aqademiq/data/repositories/weekly_report_repository.dart';
import 'package:aqademiq/features/freeze/domain/freeze_models.dart';
import 'package:aqademiq/features/freeze/providers/freeze_controller.dart';
import 'package:aqademiq/features/report/presentation/weekly_report_screen.dart';
import 'package:aqademiq/features/report/report_copy.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _monday = DateTime(2026, 8, 31);

class _RecordingHaptics extends NoopHapticsService {
  final events = <(HapticMoment, int)>[];

  List<HapticMoment> get moments => [for (final (m, _) in events) m];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      events.add((moment, count));
}

class _FixedFreeze extends FreezeController {
  _FixedFreeze(this._data);
  final FreezeData _data;

  @override
  FreezeData build() => _data;
}

/// Three thaws this week: two on Tuesday, one on Thursday.
FreezeData _thawedWeek() => FreezeData(
      setUp: true,
      thawLog: [
        ThawRecord(at: _monday.add(const Duration(days: 1, hours: 10)), minutes: 5),
        ThawRecord(at: _monday.add(const Duration(days: 1, hours: 21)), minutes: 2),
        ThawRecord(at: _monday.add(const Duration(days: 3, hours: 15)), minutes: 15),
      ],
    );

ReportDay _day(int i, {bool active = true}) => ReportDay(
      date: _monday.add(Duration(days: i)),
      weekday: i + 1,
      hasActivity: active,
      tasksCompleted: active ? 2 : 0,
      focusMinutes: active ? 30 : 0,
      focusSessions: active ? 1 : 0,
    );

WeeklyReport _full() => WeeklyReport(
      weekStart: _monday,
      weekEnd: _monday.add(const Duration(days: 6)),
      shape: WeekShape.clustered,
      activeDays: 5,
      daysOnBoard: 23,
      days: [for (var i = 0; i < 7; i++) _day(i, active: i != 3)],
      subjects: const [
        ReportSubject(id: 's1', name: 'Machine Learning', colorHex: '#6B5CF0', focusMinutes: 130, share: 0.6),
        ReportSubject(id: 's2', name: 'Linear Algebra', colorHex: '#2A9D6B', focusMinutes: 40, share: 0.4),
      ],
      moment: ReportMoment(date: _monday.add(const Duration(days: 2)), title: 'Reading', subjectId: 's1'),
      recovery: const ReportRecovery(sessions: 3, beforeAvg: 2, afterAvg: 3.4, lift: 1.4),
      heldMinutes: 18,
      focusMinutes: 170,
      focusSessions: 6,
      tasksCompleted: 9,
    );

/// A week with nothing in it, after weeks on board: the support line shows.
WeeklyReport _empty() => WeeklyReport(
      weekStart: _monday,
      weekEnd: _monday.add(const Duration(days: 6)),
      shape: WeekShape.empty,
      daysOnBoard: 30,
      days: [for (var i = 0; i < 7; i++) _day(i, active: false)],
    );

Future<_RecordingHaptics> _pump(
  WidgetTester tester,
  Future<WeeklyReport> Function() load, {
  FreezeData freeze = const FreezeData(),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final haptics = _RecordingHaptics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsProvider.overrideWithValue(haptics),
        weeklyReportProvider.overrideWith((ref) => load()),
        freezeControllerProvider.overrideWith(() => _FixedFreeze(freeze)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: const WeeklyReportScreen(),
      ),
    ),
  );
  await tester.pump();
  return haptics;
}

/// Past the minimum drill and the core's freeze-in.
Future<void> _pastDrill(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump(const Duration(milliseconds: 1400));
}

Future<void> _turnTo(WidgetTester tester, int page) async {
  tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(page);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('the core drills in once, even when the week arrives mid-drill', (tester) async {
    final week = Completer<WeeklyReport>();
    final haptics = await _pump(tester, () => week.future);
    expect(haptics.moments, [HapticMoment.coreFreezesIn]);

    await tester.pump(const Duration(milliseconds: 600));
    week.complete(_full());
    await tester.pump();
    await _pastDrill(tester);
    expect(find.text(ReportCopy.drilling), findsNothing);
    expect(haptics.moments, [HapticMoment.coreFreezesIn], reason: 'the data landing does not restart the drill');
  });

  testWidgets('page turns tick; the hero is still, the numeral thuds, each thaw cracks', (tester) async {
    final haptics = await _pump(tester, () async => _full(), freeze: _thawedWeek());
    await _pastDrill(tester);
    haptics.events.clear();

    // shape 0, core 1, moment 2, numeral 3, attention 4, thawed 5,
    // recovery 6, texture 7, landing 8.
    await _turnTo(tester, 1);
    expect(haptics.events, isEmpty, reason: 'beat 3, the hero: nothing');

    await _turnTo(tester, 2);
    expect(haptics.events.last, (HapticMoment.coreAdvance, 1));

    await _turnTo(tester, 3);
    expect(haptics.events.last, (HapticMoment.coreNumeral, 1));

    await _turnTo(tester, 4);
    expect(haptics.events.last, (HapticMoment.coreAdvance, 1));

    await _turnTo(tester, 5);
    expect(find.text(ReportCopy.thawedTitle), findsOneWidget);
    expect(haptics.events.last, (HapticMoment.coreThawedCubes, 3), reason: 'one crack per cube shown');

    await _turnTo(tester, 8);
    expect(haptics.events.last, (HapticMoment.coreAdvance, 1));
    expect(haptics.events, hasLength(5));

    await tester.tap(find.text(ReportCopy.keepIt));
    await tester.pump();
    expect(haptics.events.last, (HapticMoment.coreAccept, 1));
  });

  testWidgets('a thin week feels the same, and the support line is silent', (tester) async {
    final haptics = await _pump(tester, () async => _empty());
    await _pastDrill(tester);
    expect(haptics.moments, [HapticMoment.coreFreezesIn]);
    expect(find.textContaining(ReportCopy.supportAction, findRichText: true), findsOneWidget);

    // shape 0, core 1, numeral 2, landing 3.
    await _turnTo(tester, 1);
    await _turnTo(tester, 2);
    await _turnTo(tester, 3);
    expect(haptics.moments, [
      HapticMoment.coreFreezesIn,
      HapticMoment.coreNumeral,
      HapticMoment.coreAdvance,
    ]);
  });
}
