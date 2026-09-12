// The weekly report's vocabulary rule, enforced rather than documented.
//
// The design's §5 is a list of metrics and words that must never render, and
// the reason it is a *list* and not a review checklist is that copy review
// happens once and code changes forever. This file is the enforcement: it walks
// every sentence `ReportCopy` can produce, and then walks the feature's source
// looking for the two shapes that let a target back in.
//
// A target is the thing the whole design exists to avoid. A student who reads
// "5/7 days" has been handed a number they fell short of, by an app they opened
// to find out how their week went. Denominators are how targets get in, so the
// denominator check scans source text rather than only the assembled strings —
// a `'$x/$y'` written at a call site would never appear in `ReportCopy` at all.

import 'dart:io';

import 'package:aqademiq/data/models/weekly_report.dart';
import 'package:aqademiq/features/report/report_copy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every sentence the report can say, with clean stand-ins for the parts that
/// come from the student's own data.
List<String> _allCopy() => [
      // Every shape sentence, and every static label the story can render.
      for (final s in WeekShape.values) ReportCopy.shape(s),
      ReportCopy.entryEyebrow,
      ReportCopy.coreName,
      ReportCopy.entryTagline,
      ReportCopy.drilling,
      ReportCopy.shapeLabel,
      ReportCopy.coreCaption,
      ReportCopy.gapCaptionPlain,
      ReportCopy.momentTitle,
      ReportCopy.heroLabel,
      ReportCopy.attentionTitle,
      ReportCopy.recoveryTitle,
      ReportCopy.goingIn,
      ReportCopy.comingOut,
      ReportCopy.longestTitle,
      ReportCopy.heldTitle,
      ReportCopy.rhythmTitle,
      ReportCopy.prismTitle,
      ReportCopy.closing,
      ReportCopy.closingEmpty,
      ReportCopy.suggestionTitle,
      ReportCopy.suggestionSub,
      ReportCopy.keepIt,
      ReportCopy.notThisTime,
      ReportCopy.shareLabel,
      ReportCopy.sharePrivacy,
      ReportCopy.shareAction,
      ReportCopy.shareBrand,
      ReportCopy.settingsTitle,
      ReportCopy.settingsToggle,
      ReportCopy.settingsToggleNote,
      ReportCopy.neverDoesTitle,
      ReportCopy.neverNotify,
      ReportCopy.neverNotifySub,
      ReportCopy.neverBackBrowse,
      ReportCopy.neverBackBrowseSub,
      ReportCopy.neverShowWriting,
      ReportCopy.neverShowWritingSub,
      ReportCopy.supportBanner,
      ReportCopy.supportAction,
      ReportCopy.loadFailed,
      ReportCopy.retry,
      // The templated ones, with clean stand-ins for the parts that come from
      // the student's own data.
      for (var d = 1; d <= 7; d++) ReportCopy.gapCaption(weekdayName(d)),
      ReportCopy.moment(ReportMoment(date: DateTime(2026, 9, 2), title: 'Reading')),
      ReportCopy.momentWhere(ReportMoment(date: DateTime(2026, 9, 2), title: 'Reading'), 'Linear Algebra'),
      ReportCopy.momentWhere(ReportMoment(date: DateTime(2026, 9, 2), title: 'Reading'), null),
      ReportCopy.smallestTrueThing(ReportDay(date: DateTime(2026, 9, 2), weekday: 3, hasActivity: true)),
      ReportCopy.attentionCaption(null),
      ReportCopy.attentionCaption('Compilers'),
      ReportCopy.recovery(const ReportRecovery(sessions: 1, beforeAvg: 2, afterAvg: 3, lift: 1)),
      ReportCopy.recovery(const ReportRecovery(sessions: 4, beforeAvg: 2, afterAvg: 3, lift: 1)),
      ReportCopy.longest(ReportLongest(minutes: 52, date: DateTime(2026, 9, 4), taskTitle: 'Problem set')),
      ReportCopy.longest(ReportLongest(minutes: 52, date: DateTime(2026, 9, 4))),
      ReportCopy.held(18),
      ReportCopy.rhythm(const [2]),
      ReportCopy.rhythm(const [2, 3, 5]),
      for (var m = 0; m < 200; m++) ReportCopy.minutes(m),
    ];

void main() {
  test('no sentence contains a banned word', () {
    // Whole words, so "below" and "follow" are not caught by "low" — the rule
    // is about vocabulary, and a substring match would force the copy into
    // contortions that read worse than the words it was avoiding.
    final offences = <String>[];
    for (final line in _allCopy()) {
      for (final word in kReportBannedWords) {
        if (RegExp('\\b$word\\b', caseSensitive: false).hasMatch(line)) {
          offences.add('"$line" contains "$word"');
        }
      }
    }
    expect(offences, isEmpty, reason: offences.join('\n'));
  });

  test('no sentence contains a denominator', () {
    // "5/7", "3 / 12". The single most dangerous shape in the whole feature.
    for (final line in _allCopy()) {
      expect(
        RegExp(r'\d\s*/\s*\d').hasMatch(line),
        isFalse,
        reason: '"$line" contains an x-of-y denominator',
      );
    }
  });

  test('no source file in the report feature writes a denominator', () {
    // Belt and braces: a denominator assembled at a call site — `'$done/$goal'`
    // — never passes through ReportCopy, so the string-level check above would
    // not see it. This catches the next person as well as this one.
    final dir = Directory('lib/features/report');
    expect(dir.existsSync(), isTrue, reason: 'report feature moved; update this test');

    final offences = <String>[];
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Comments explain the rule and are allowed to quote it.
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) continue;
        if (RegExp(r"'[^']*\d\s*/\s*\d[^']*'").hasMatch(line) ||
            RegExp(r"'[^']*\$\w+\s*/\s*\$").hasMatch(line)) {
          offences.add('${f.path}:${i + 1}: $line');
        }
      }
    }
    expect(offences, isEmpty, reason: offences.join('\n'));
  });

  test('every week shape has its own sentence', () {
    // Two shapes collapsing onto one string means a week is being described as
    // something it was not — the failure is silent and the sentence still reads
    // fine, which is exactly why it needs a test.
    final seen = WeekShape.values.map(ReportCopy.shape).toSet();
    expect(seen.length, WeekShape.values.length);
    expect(seen.every((s) => s.trim().isNotEmpty), isTrue);
  });

  test('an empty week gets a real sentence, not an error state', () {
    // The most important single line in the feature. A student who logged
    // nothing has to be met with a description, not a blank screen and not a
    // prompt to do better.
    final line = ReportCopy.shape(WeekShape.empty);
    expect(line.trim(), isNotEmpty);
    expect(line.toLowerCase(), isNot(contains('no ')));
  });

  test('minutes never render as a decimal', () {
    for (var m = 0; m < 500; m++) {
      expect(ReportCopy.minutes(m), isNot(contains('.')), reason: 'at $m minutes');
    }
    expect(ReportCopy.minutes(45), '45m');
    expect(ReportCopy.minutes(60), '1h');
    expect(ReportCopy.minutes(72), '1h 12m');
  });

  test('rhythm names weekdays and never counts weeks', () {
    expect(ReportCopy.rhythm(const []), '');
    expect(ReportCopy.rhythm(const [2]), 'Tuesdays carry your work.');
    expect(ReportCopy.rhythm(const [2, 3, 5]), 'Tuesdays, Wednesdays and Fridays carry your work.');
    // No digits at all — a count of weeks observed is a sample size the student
    // would read as a score.
    expect(RegExp(r'\d').hasMatch(ReportCopy.rhythm(const [1, 2, 3])), isFalse);
  });

  test('an out-of-range weekday does not throw inside a live screen', () {
    expect(weekdayName(0), '');
    expect(weekdayName(8), '');
    expect(weekdayName(1), 'Monday');
    expect(weekdayName(7), 'Sunday');
  });
}
