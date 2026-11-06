import 'dart:convert';

import 'package:aqademiq/features/freeze/data/app_freeze_channel.dart';
import 'package:aqademiq/features/freeze/domain/freeze_engine.dart';
import 'package:aqademiq/features/freeze/domain/freeze_models.dart';
import 'package:aqademiq/features/freeze/providers/freeze_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// App freeze's rules (APP_FREEZE.md §2). The native sides — FreezeRules.kt
/// and FreezeRules.swift — port these functions; a change here is a change
/// there. The same cases also run under Node against a line-by-line port, in
/// five time zones including two with a DST change in the window.
void main() {
  const ig = 'com.instagram.android';
  const tt = 'com.zhiliaoapp.musically';
  const phone = 'com.android.dialer';
  const wa = 'com.whatsapp';
  // 2026-11-09 is a Monday.
  DateTime at(int m, int d, [int h = 0, int min = 0]) => DateTime(2026, m, d, h, min);

  const lecture = Frost(id: 'lec', name: 'Lecture hours', apps: AppSet(packages: [ig, tt]));
  const wind = Frost(id: 'wind', name: 'Wind down', days: {1, 2, 3, 4, 5, 6, 7}, startMinute: 22 * 60, endMinute: 7 * 60, apps: AppSet(packages: [ig]));

  test('the week starts on Monday the 9th', () => expect(at(11, 9).weekday, DateTime.monday));

  group('schedule windows', () {
    const d = FreezeData(frosts: [lecture]);
    test('inside, at the start, and the end is exclusive', () {
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 10)), isTrue);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 9)), isTrue);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 8, 59)), isFalse);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 13)), isFalse);
    });
    test('not on a weekend, not for another app, not when off', () {
      expect(FreezeEngine.isFrozen(d, ig, at(11, 14, 10)), isFalse);
      expect(FreezeEngine.isFrozen(d, wa, at(11, 9, 10)), isFalse);
      expect(FreezeEngine.isFrozen(FreezeData(frosts: [lecture.copyWith(enabled: false)]), ig, at(11, 9, 10)), isFalse);
    });
    test('statuses', () {
      expect(FreezeText.status(d, lecture, at(11, 9, 11, 20)), '1h 40m left');
      expect(FreezeText.status(d, lecture, at(11, 9, 7)), 'Starts 9 AM');
      expect(FreezeText.status(d, lecture, at(11, 13, 14)), 'Starts in 3d');
    });
  });

  group('overnight', () {
    test('tonight and the tail of last night', () {
      const d = FreezeData(frosts: [wind]);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 10, 23)), isTrue);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 11, 6, 59)), isTrue);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 11, 7)), isFalse);
      expect(FreezeEngine.windowAt(wind, at(11, 10, 23))!.end, at(11, 11, 7));
    });
    test("Saturday morning's tail belongs to Friday night", () {
      final d = FreezeData(frosts: [wind.copyWith(days: {5})]);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 14, 2)), isTrue);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 13, 2)), isFalse);
    });
  });

  test('a date range (Exam week) holds only inside its dates', () {
    final exam = Frost(
      id: 'exam',
      name: 'Exam week',
      days: const {1, 2, 3, 4, 5, 6, 7},
      startMinute: 0,
      endMinute: 1440,
      fromDay: DateTime(2026, 11, 16),
      untilDay: DateTime(2026, 11, 22),
      deep: true,
      apps: const AppSet(packages: [ig]),
    );
    final d = FreezeData(frosts: [exam]);
    expect(FreezeEngine.isFrozen(d, ig, at(11, 15, 23, 59)), isFalse);
    expect(FreezeEngine.isFrozen(d, ig, at(11, 16)), isTrue);
    expect(FreezeEngine.isFrozen(d, ig, at(11, 22, 23, 59)), isTrue);
    expect(FreezeEngine.isFrozen(d, ig, at(11, 23, 0, 1)), isFalse);
    expect(FreezeText.status(d, exam, at(11, 12, 12)), 'Starts in 4d');
    expect(FreezeText.status(d, exam, at(11, 23, 1)), 'Done');
  });

  group('groups', () {
    const keep = Frost(id: 'keep', name: 'Keep', apps: AppSet(packages: [wa], mode: AppSetMode.keepOnly));
    const groups = FreezeGroups(
      alwaysOpen: AppSet(packages: [phone]),
      neverOpen: AppSet(packages: [tt]),
      distracting: AppSet(packages: [ig]),
    );
    test('Keep only freezes everything it does not list', () {
      const d = FreezeData(frosts: [keep]);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 10)), isTrue);
      expect(FreezeEngine.isFrozen(d, wa, at(11, 9, 10)), isFalse);
    });
    test('Always open beats any frost; Never open needs none', () {
      const d = FreezeData(frosts: [keep], groups: groups);
      expect(FreezeEngine.isFrozen(d, phone, at(11, 9, 10)), isFalse);
      expect(FreezeEngine.isFrozen(d, tt, at(11, 9, 20)), isTrue);
    });
    test('Distracting is never frozen by the group itself', () {
      expect(FreezeEngine.isFrozen(const FreezeData(groups: groups), ig, at(11, 9, 20)), isFalse);
    });
    test("Thaw all doesn't reach Never open", () {
      final d = FreezeData(
        frosts: const [keep],
        groups: groups,
        grants: [ThawGrant(target: ThawGrant.allApps, until: at(11, 9, 10, 5), startedAt: at(11, 9, 10))],
      );
      expect(FreezeEngine.isFrozen(d, tt, at(11, 9, 10, 1)), isTrue);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 10, 1)), isFalse);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 10, 5)), isTrue);
    });
  });

  group('thaws', () {
    final grant = ThawGrant(target: ig, until: at(11, 9, 10, 5), startedAt: at(11, 9, 10));
    test('one app opens, then refreezes by itself', () {
      final d = FreezeData(frosts: const [lecture], grants: [grant]);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 10, 2)), isFalse);
      expect(FreezeEngine.isFrozen(d, tt, at(11, 9, 10, 2)), isTrue);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 10, 5)), isTrue);
    });
    test('Deep freeze ignores thaws', () {
      final d = FreezeData(frosts: [lecture.copyWith(deep: true)], grants: [grant]);
      expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 10, 2)), isTrue);
      expect(FreezeEngine.deepRunning(d, at(11, 9, 10))!.end, at(11, 9, 13));
    });
  });

  test('Thaw everything: a running Deep freeze keeps its deal', () {
    final deep = lecture.copyWith(deep: true);
    final night = wind.copyWith(apps: const AppSet(packages: [tt]));
    var d = FreezeData(frosts: [deep, Frost(id: 'w2', name: 'w2', days: night.days, startMinute: night.startMinute, endMinute: night.endMinute, apps: night.apps)]);
    final t0 = at(11, 9, 11);
    final holds = FreezeEngine.holdsFor(d, t0);
    expect(holds.keys, ['lec']);
    d = d.copyWith(standdown: Standdown(since: t0, until: at(11, 10, 7), holds: holds));
    expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 12)), isTrue);
    expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 13, 30)), isFalse);
    expect(FreezeEngine.isFrozen(d, tt, at(11, 9, 23)), isFalse);
    expect(FreezeEngine.isFrozen(d, tt, at(11, 10, 22, 30)), isTrue);
  });

  test('Freeze now ends on time; Until I stop does not', () {
    final d = FreezeData(now: FreezeNow(startedAt: at(11, 9, 15), endsAt: at(11, 9, 15, 25), apps: const AppSet(packages: [ig])));
    expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 15, 24)), isTrue);
    expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 15, 25)), isFalse);
    final forever = FreezeData(now: FreezeNow(startedAt: at(11, 9, 15), apps: const AppSet(packages: [ig])));
    expect(FreezeEngine.isFrozen(forever, ig, DateTime(2027, 6)), isTrue);
  });

  test('End early skips to the end of the window', () {
    final d = FreezeData(frosts: [lecture.copyWith(skipUntil: at(11, 9, 13))]);
    expect(FreezeEngine.isFrozen(d, ig, at(11, 9, 11)), isFalse);
    expect(FreezeEngine.isFrozen(d, ig, at(11, 10, 10)), isTrue);
  });

  group('the breath', () {
    List<ThawRecord> log(List<DateTime> ats) => [for (final a in ats) ThawRecord(at: a, minutes: 2)];
    const inc = ThawSettings(resistance: ThawResistance.increasing);
    test('10 s, then 10 more per thaw today, capped at a minute', () {
      expect(FreezeEngine.breathFor(const FreezeData(thaw: inc), at(11, 9, 10)), 10);
      expect(FreezeEngine.breathFor(FreezeData(thaw: inc, thawLog: log([at(11, 9, 9), at(11, 9, 9, 30)])), at(11, 9, 10)), 30);
      expect(FreezeEngine.breathFor(FreezeData(thaw: inc, thawLog: log([for (var i = 0; i < 7; i++) at(11, 9, 5, i)])), at(11, 9, 10)), 60);
    });
    test('the day turns at 4 AM', () {
      final d = FreezeData(thaw: inc, thawLog: log([at(11, 9, 2)]));
      expect(FreezeEngine.breathFor(d, at(11, 9, 3)), 20);
      expect(FreezeEngine.breathFor(d, at(11, 9, 4)), 10);
    });
  });

  test('onboarding frosts: Wellness time takes the days left over', () {
    String show(Set<int> days) => onboardingFrosts(studyDays: days, fromMinute: 540, untilMinute: 780)
        .map((f) => '${f.name}:${FreezeText.days(f.days)}:${FreezeText.span(f)}')
        .join(' | ');
    expect(show({1, 2, 3, 4, 5}), 'Wellness time:Weekends:9 AM – 12 PM | Study hours:Weekdays:9 AM – 1 PM');
    expect(show({1, 2, 4, 5}), 'Wellness time:Wed, Sat, Sun:9 AM – 12 PM | Study hours:Mon, Tue, Thu, Fri:9 AM – 1 PM');
    expect(show({1, 2, 3, 4, 5, 6, 7}), 'Study hours:Daily:9 AM – 1 PM');
    expect(FreezeText.daysProse({3, 6, 7}), 'Wed, Sat and Sun');
  });

  test('the store round-trips everything, and the policy drops the thaw log', () {
    final d = FreezeData(
      setUp: true,
      frosts: [lecture.copyWith(deep: true, skipUntil: at(11, 9, 13)), wind],
      groups: const FreezeGroups(alwaysOpen: AppSet(packages: [phone]), adultSites: true),
      thaw: const ThawSettings(resistance: ThawResistance.increasing, minutes: 5),
      now: FreezeNow(startedAt: at(11, 9, 15), endsAt: at(11, 9, 16), deep: true, apps: const AppSet(iosSelection: 'sel-now', iosCount: 6)),
      grants: [ThawGrant(target: ig, until: at(11, 9, 10, 5), startedAt: at(11, 9, 10), label: 'Instagram')],
      standdown: Standdown(since: at(11, 9), holds: {'lec': at(11, 9, 13)}),
      thawLog: [ThawRecord(at: at(11, 9, 10), minutes: 5, target: ig)],
    );
    final back = FreezeData.fromJson(jsonDecode(jsonEncode(d.toJson())));
    expect(jsonEncode(back.toJson()), jsonEncode(d.toJson()));
    final policy = AppFreezeChannel.policyOf(d, at(11, 9, 11));
    expect(policy.containsKey('thaw_log'), isFalse);
    expect(policy['thaws_today'], 1);
    expect((policy['frosts']! as List).length, 2);
  });

  test('a corrupt record reads as empty, never as a crash', () {
    expect(FreezeData.fromJson('nonsense').frosts, isEmpty);
    expect(FreezeData.fromJson({'frosts': [42, {'id': 1}]}).frosts, isEmpty);
  });
}
