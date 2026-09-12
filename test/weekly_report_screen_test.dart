// The report has to survive the weeks it was designed for.
//
// Almost every screen in the app renders a list of things a student made. This
// one renders a *judgement-shaped* summary of a week they lived, and the two
// weeks most likely to break it are the two least likely to be looked at during
// development: the week where nothing happened, and the week where everything
// did.
//
// Because it is a pager, "does it render" has to mean *every page*, not the
// first one. So these tests walk all of them and assert the boring thing on
// each: no overflow, no exception, at 390pt and at 320pt. A RenderFlex error on
// this screen shows a depleted student a yellow-and-black hazard stripe where
// their week should be, and it would only ever show up on page five.

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

ReportDay _day(int i, {bool active = true, int? mood, int mins = 30, bool future = false}) => ReportDay(
      date: _monday.add(Duration(days: i)),
      weekday: i + 1,
      hasActivity: active,
      isFuture: future,
      moodIndex: mood,
      tasksCompleted: active ? 2 : 0,
      focusMinutes: active ? mins : 0,
      focusSessions: active ? 1 : 0,
    );

WeeklyReport _full() => WeeklyReport(
      weekStart: _monday,
      weekEnd: _monday.add(const Duration(days: 6)),
      shape: WeekShape.clustered,
      // Mid-week, which is the state the report is in five days out of seven.
      activeDays: 5,
      elapsedDays: 6,
      daysOnBoard: 23,
      days: [
        _day(0, mood: 1),
        _day(1, mood: 3),
        _day(2), // happened, no check-in
        _day(3, active: false), // happened, nothing on it: a real gap
        _day(4, mood: 4, mins: 90),
        _day(5, mood: 2),
        _day(6, active: false, future: true), // has not happened
      ],
      subjects: const [
        ReportSubject(id: 's1', name: 'Machine Learning', colorHex: '#6B5CF0', focusMinutes: 130, share: 0.5),
        // A long name, because subject names are user data and the cube label
        // under it is only 74pt wide.
        ReportSubject(id: 's2', name: 'Introduction to Thermodynamics and Statistical Mechanics', focusMinutes: 65, share: 0.3),
        ReportSubject(id: 's3', name: 'Linear Algebra', colorHex: '#2A9D6B', focusMinutes: 40, share: 0.2),
      ],
      moment: ReportMoment(date: _monday.add(const Duration(days: 2)), title: 'Reading', subjectId: 's1'),
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
      days: [for (var i = 0; i < 7; i++) _day(i, active: false)],
    );

/// Pumps the screen and gets past the drilling beat, which deliberately holds
/// for ~1.45s so the core is seen forming rather than flashing.
Future<void> _pump(
  WidgetTester tester,
  WeeklyReport report, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [weeklyReportProvider.overrideWith((ref) async => report)],
      child: MaterialApp(
        theme: buildAppTheme(brightness: brightness, accent: AppAccent.violet),
        home: const WeeklyReportScreen(),
      ),
    ),
  );
  await tester.pump();
  // Past the minimum drill, then past the core's own 1.25s freeze-in. Explicit
  // pumps rather than pumpAndSettle, which would sit through both every time.
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump(const Duration(milliseconds: 1400));
}

int _pageCount(WidgetTester tester) {
  final pv = tester.widget<PageView>(find.byType(PageView));
  return pv.childrenDelegate.estimatedChildCount ?? 0;
}

/// Walks every page, running [onPage] once each has settled.
Future<void> _walk(WidgetTester tester, Future<void> Function(int i) onPage) async {
  final pv = tester.widget<PageView>(find.byType(PageView));
  final controller = pv.controller;
  final n = pv.childrenDelegate.estimatedChildCount ?? 0;
  expect(n, greaterThan(0), reason: 'the story had no beats at all');
  expect(controller, isNotNull, reason: 'the pager lost its controller');
  for (var i = 0; i < n; i++) {
    controller!.jumpToPage(i);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    await onPage(i);
  }
}

void main() {
  testWidgets('the drilling beat comes first, and it is the core forming', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [weeklyReportProvider.overrideWith((ref) async => _full())],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
          home: const WeeklyReportScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(ReportCopy.drilling), findsOneWidget);
    // Not a spinner. A spinner here would make the wait read as a failure
    // rather than as the thing being drilled.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text(ReportCopy.drilling), findsNothing);
  });

  testWidgets('a full week opens on the shape, before any number', (tester) async {
    await _pump(tester, _full());
    expect(tester.takeException(), isNull);
    expect(find.text('“${ReportCopy.shape(WeekShape.clustered)}”'), findsOneWidget);
    // The numeral is a later beat. Story first, evidence second.
    expect(find.text('5'), findsNothing);
  });

  testWidgets('every page of a full week renders without overflowing', (tester) async {
    await _pump(tester, _full());
    await _walk(tester, (i) async {
      expect(tester.takeException(), isNull, reason: 'page $i overflowed');
    });
  });

  testWidgets('every page survives a small phone', (tester) async {
    // 320pt is the narrowest viewport the app still supports, and the core plus
    // its day labels take a fixed ~140pt out of it before any text is laid out.
    await _pump(tester, _full(), size: const Size(320, 640));
    await _walk(tester, (i) async {
      expect(tester.takeException(), isNull, reason: 'page $i overflowed at 320pt');
    });
  });

  testWidgets('every page renders in dark mode', (tester) async {
    await _pump(tester, _full(), brightness: Brightness.dark);
    await _walk(tester, (i) async {
      expect(tester.takeException(), isNull, reason: 'page $i broke in dark mode');
    });
  });

  testWidgets('the numeral and its label are reachable', (tester) async {
    await _pump(tester, _full());
    var found = false;
    await _walk(tester, (i) async {
      if (find.text('5').evaluate().isNotEmpty) {
        found = true;
        expect(find.text(ReportCopy.heroLabel), findsOneWidget);
      }
    });
    expect(found, isTrue, reason: 'the hero numeral never appeared');
  });

  testWidgets('an empty week renders as a week, not as an error', (tester) async {
    // The most important case in the file. Nothing logged must still produce a
    // core, a sentence and the lifetime numeral — never a blank screen, never a
    // retry button, and never a prompt to do better next time.
    await _pump(tester, _empty());
    expect(tester.takeException(), isNull);
    expect(find.text('“${ReportCopy.shape(WeekShape.empty)}”'), findsOneWidget);
    expect(find.text(ReportCopy.retry), findsNothing);
  });

  testWidgets('beats with nothing to say are absent, not greyed or zeroed', (tester) async {
    // A greyed card still tells the student something was supposed to be there.
    // Checked across every page, because absence is the assertion.
    await _pump(tester, _empty());
    await _walk(tester, (i) async {
      expect(find.text(ReportCopy.momentTitle), findsNothing);
      expect(find.text(ReportCopy.recoveryTitle), findsNothing);
      expect(find.text(ReportCopy.attentionTitle), findsNothing);
      expect(find.text(ReportCopy.longestTitle), findsNothing);
      expect(find.text(ReportCopy.heldTitle), findsNothing);
    });
  });

  testWidgets('an empty week still gets a shape, a core, the numeral and a landing', (tester) async {
    // A week is never narrated as nothing at all. Four beats is the floor: the
    // shape, the core, the lifetime numeral — which is a count that cannot go
    // down, so it is safe on the worst week — and the landing.
    await _pump(tester, _empty());
    expect(_pageCount(tester), 4);
  });

  testWidgets('a full week gets every beat it can fill', (tester) async {
    // Separate test rather than a second pump above: re-pumping a new
    // ProviderScope leaves the previous AsyncValue in place long enough to
    // measure the wrong week, which made the comparison pass on stale data.
    await _pump(tester, _full());
    // shape, core, moment, numeral, attention, recovery, texture, landing.
    expect(_pageCount(tester), 8);
  });

  testWidgets('the empty week lands on its own closing, and asks for nothing', (tester) async {
    await _pump(tester, _empty());
    var sawEmptyClosing = false;
    await _walk(tester, (i) async {
      if (find.text(ReportCopy.closingEmpty).evaluate().isNotEmpty) sawEmptyClosing = true;
      expect(find.text(ReportCopy.closing), findsNothing);
    });
    expect(sawEmptyClosing, isTrue);
  });

  testWidgets('nothing on any page renders an x-of-y denominator', (tester) async {
    // The runtime version of the copy lint: whatever the widgets compose, no
    // rendered string may contain one.
    await _pump(tester, _full());
    final denominator = RegExp(r'\d\s*/\s*\d');
    await _walk(tester, (i) async {
      final offenders = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where(denominator.hasMatch)
          .toList();
      expect(offenders, isEmpty, reason: 'page $i rendered: $offenders');
    });
  });

  testWidgets('a week with a gap names the open day', (tester) async {
    await _pump(tester, _full());
    // Thursday is the first open band in the fixture, and the caption names it
    // rather than explaining gaps in the abstract.
    var sawGapCaption = false;
    await _walk(tester, (i) async {
      if (find.textContaining(ReportCopy.gapCaption('Thursday')).evaluate().isNotEmpty) {
        sawGapCaption = true;
      }
    });
    expect(sawGapCaption, isTrue, reason: 'the open band was never explained');
  });

  testWidgets('a week with no gaps is not handed an explanation it does not need', (tester) async {
    final noGaps = WeeklyReport(
      weekStart: _monday,
      weekEnd: _monday.add(const Duration(days: 6)),
      shape: WeekShape.steady,
      activeDays: 7,
      daysOnBoard: 30,
      days: [for (var i = 0; i < 7; i++) _day(i, mood: 3)],
    );
    await _pump(tester, noGaps);
    var sawCoreCaption = false;
    await _walk(tester, (i) async {
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final s = t.data ?? '';
        if (s.contains(ReportCopy.coreCaption)) sawCoreCaption = true;
        expect(s.contains('nothing logged'), isFalse,
            reason: 'page $i explained a gap that does not exist');
      }
    });
    expect(sawCoreCaption, isTrue);
  });

  testWidgets('leaving is one tap, on every page', (tester) async {
    await _pump(tester, _full());
    await _walk(tester, (i) async {
      expect(find.byIcon(Icons.close), findsOneWidget, reason: 'page $i had no way out');
    });
  });

  testWidgets('the hero numeral is the week, never a lifetime total', (tester) async {
    // The bug this replaced put 16 — a lifetime count — above a seven-band core.
    await _pump(tester, _full());
    var sawNumeral = false;
    await _walk(tester, (i) async {
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        if (t.data == '5' && find.text(ReportCopy.heroLabel).evaluate().isNotEmpty) sawNumeral = true;
        // 23 is the lifetime figure in the fixture. It must appear nowhere.
        expect(t.data, isNot('23'), reason: 'page $i showed the lifetime total');
      }
    });
    expect(sawNumeral, isTrue, reason: 'the weekly count never appeared');
  });

  testWidgets('a day that has not happened is never named as a gap', (tester) async {
    // Sunday is the future day in the fixture; Thursday is the real gap. Only
    // Thursday may be explained, or the report tells someone on Saturday that
    // they have already missed Sunday.
    await _pump(tester, _full());
    await _walk(tester, (i) async {
      expect(
        find.textContaining(ReportCopy.gapCaption('Sunday')),
        findsNothing,
        reason: 'page $i called a future day a gap',
      );
    });
  });
}
