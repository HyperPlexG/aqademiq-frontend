// The report has to survive the weeks it was designed for.
//
// Almost every screen in the app renders a list of things a student made. This
// one renders a *judgement-shaped* summary of a week they lived, and the two
// weeks most likely to break it are the two least likely to be looked at during
// development: the week where nothing happened, and the week where everything
// did. So both are pumped here at a real phone size, and the assertion that
// matters most is the boring one — no overflow, no exception, on a 375pt
// viewport, because a RenderFlex error on this screen shows a depleted student
// a yellow-and-black hazard stripe where their week should be.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/weekly_report.dart';
import 'package:aqademiq/data/repositories/weekly_report_repository.dart';
import 'package:aqademiq/features/report/presentation/weekly_report_screen.dart';
import 'package:aqademiq/features/report/report_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _monday = DateTime(2026, 8, 31);

ReportDay _day(int i, {bool active = true, int? mood, int mins = 30}) => ReportDay(
      date: _monday.add(Duration(days: i)),
      weekday: i + 1,
      hasActivity: active,
      moodIndex: mood,
      tasksCompleted: active ? 2 : 0,
      focusMinutes: active ? mins : 0,
      focusSessions: active ? 1 : 0,
    );

WeeklyReport _full() => WeeklyReport(
      weekStart: _monday,
      weekEnd: _monday.add(const Duration(days: 6)),
      shape: WeekShape.clustered,
      activeDays: 5,
      daysOnBoard: 23,
      days: [
        _day(0, mood: 1),
        _day(1, mood: 3),
        _day(2), // happened, no check-in
        _day(3, active: false),
        _day(4, mood: 4, mins: 90),
        _day(5, mood: 2),
        _day(6, active: false),
      ],
      subjects: const [
        ReportSubject(id: 's1', name: 'Machine Learning', colorHex: '#6B5CF0', focusMinutes: 130, share: 0.5),
        // A long name, because subject names are user data and the row has a
        // number pinned to its right.
        ReportSubject(id: 's2', name: 'Introduction to Thermodynamics and Statistical Mechanics', focusMinutes: 65, share: 0.3),
      ],
      moment: ReportMoment(date: _monday.add(const Duration(days: 2)), title: 'Reading'),
      recovery: const ReportRecovery(sessions: 3, beforeAvg: 2, afterAvg: 3.4, lift: 1.4),
      longestSession: ReportLongest(minutes: 52, date: _monday.add(const Duration(days: 4)), taskTitle: 'Problem set'),
      heldMinutes: 18,
      prismMix: const [ReportPrismSlice(presetId: 'p1', name: 'Rain', sessions: 5, share: 0.62)],
      rhythmWeekdays: const [2, 3, 5],
      focusMinutes: 195,
      focusSessions: 7,
      tasksCompleted: 9,
    );

WeeklyReport _empty() => WeeklyReport(
      weekStart: _monday,
      weekEnd: _monday.add(const Duration(days: 6)),
      shape: WeekShape.empty,
      daysOnBoard: 4,
      days: [for (var i = 0; i < 7; i++) _day(i, active: false)],
    );

Future<void> _pump(WidgetTester tester, WeeklyReport report, {Size size = const Size(375, 812)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [weeklyReportProvider.overrideWith((ref) async => report)],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: const WeeklyReportScreen(),
      ),
    ),
  );
  // Explicit pumps rather than pumpAndSettle: the core's freeze-in is a 1.25s
  // controller, and pumpAndSettle would sit through it on every test.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1400));
}

void main() {
  testWidgets('a full week renders with no overflow on a phone', (tester) async {
    await _pump(tester, _full());
    expect(tester.takeException(), isNull);
    expect(find.text(ReportCopy.shape(WeekShape.clustered)), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(find.text(ReportCopy.heroLabel), findsOneWidget);
  });

  testWidgets('an empty week renders as a week, not as an error', (tester) async {
    // The most important case in the file. Nothing logged must still produce a
    // core, a sentence and the lifetime numeral — never a blank screen, never a
    // retry button, and never a prompt to do better next time.
    await _pump(tester, _empty());
    expect(tester.takeException(), isNull);
    expect(find.text(ReportCopy.shape(WeekShape.empty)), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text(ReportCopy.closingEmpty), findsOneWidget);
  });

  testWidgets('beats with nothing to say are absent, not greyed or zeroed', (tester) async {
    // A greyed card still tells the student something was supposed to be there.
    await _pump(tester, _empty());
    expect(find.text(ReportCopy.momentTitle), findsNothing);
    expect(find.text(ReportCopy.recoveryTitle), findsNothing);
    expect(find.text(ReportCopy.longestTitle), findsNothing);
    expect(find.text(ReportCopy.heldTitle), findsNothing);
    expect(find.text(ReportCopy.prismTitle), findsNothing);
    expect(find.text(ReportCopy.attentionTitle), findsNothing);
  });

  testWidgets('a week with a gap explains what an empty band is', (tester) async {
    await _pump(tester, _full());
    expect(find.textContaining(ReportCopy.gapCaption), findsOneWidget);
  });

  testWidgets('a full week is not handed an explanation it does not need', (tester) async {
    // Separate test rather than a second pump in the one above: re-pumping a
    // new ProviderScope leaves the previous AsyncValue in place long enough to
    // pass on stale text, so the assertion would hold whether or not the
    // condition worked.
    final noGaps = WeeklyReport(
      weekStart: _monday,
      weekEnd: _monday.add(const Duration(days: 6)),
      shape: WeekShape.steady,
      activeDays: 7,
      daysOnBoard: 30,
      days: [for (var i = 0; i < 7; i++) _day(i, mood: 3)],
    );
    await _pump(tester, noGaps);
    expect(find.textContaining(ReportCopy.gapCaption), findsNothing);
    expect(find.textContaining(ReportCopy.coreCaption), findsOneWidget);
  });

  testWidgets('nothing on screen renders an x-of-y denominator', (tester) async {
    // The screen-level version of the copy lint: whatever the widgets compose
    // at runtime, no rendered string may contain one.
    await _pump(tester, _full());
    final denominator = RegExp(r'\d\s*/\s*\d');
    final offenders = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where(denominator.hasMatch)
        .toList();
    expect(offenders, isEmpty, reason: 'rendered: $offenders');
  });

  testWidgets('a long subject name does not overflow its row', (tester) async {
    await _pump(tester, _full());
    expect(tester.takeException(), isNull);
  });

  testWidgets('it survives a small phone', (tester) async {
    // 320pt is the narrowest viewport the app still supports, and the core plus
    // its labels take a fixed ~104pt out of it before any text is laid out.
    await _pump(tester, _full(), size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('it renders in dark mode', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [weeklyReportProvider.overrideWith((ref) async => _full())],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark, accent: AppAccent.green),
          home: const WeeklyReportScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(tester.takeException(), isNull);
    expect(find.text(ReportCopy.heroLabel), findsOneWidget);
  });
}
