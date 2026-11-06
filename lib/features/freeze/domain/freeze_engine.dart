import 'freeze_models.dart';

/// The App freeze rules, as pure functions of the data and a moment.
///
/// This file is the specification the native sides follow: `FreezeRules.kt`
/// (Android) and `FreezeRules.swift` (iOS) evaluate the same policy with the
/// same rules, because a frost has to keep running while Aqademiq is closed.
/// Change a rule here and change it in both, and in `test/freeze_engine_test`.
///
/// The rule for one app at one moment:
///
/// 1. Never open freezes it, always. Thawing doesn't reach these.
/// 2. Always open never freezes it, by any frost.
/// 3. Otherwise it is frozen if a running freeze covers it — a frost in its
///    window, or Freeze now. "Keep only these" covers every app it does not
///    list.
/// 4. A thaw opens it again until the thaw runs out — unless a Deep freeze is
///    one of the things covering it. Deep freeze means no thawing.
/// 5. Thaw everything stands every frost down, except a Deep freeze that was
///    already running, which holds until its window ends.

/// A freeze that is running now: a frost in its window, or Freeze now.
class ActiveFreeze {
  const ActiveFreeze({
    required this.id,
    required this.name,
    required this.apps,
    required this.deep,
    required this.start,
    this.end,
    this.frost,
  });

  /// The frost's id, or [nowId] for Freeze now.
  final String id;
  final String name;
  final AppSet apps;
  final bool deep;
  final DateTime start;

  /// Null runs until stopped.
  final DateTime? end;
  final Frost? frost;

  static const nowId = 'now';

  bool covers(String app) => apps.keepOnly ? !apps.contains(app) : apps.contains(app);
}

/// One window of a frost: when it starts, and when it ends (null = until
/// stopped).
class FrostWindow {
  const FrostWindow(this.start, this.end);

  final DateTime start;
  final DateTime? end;
}

abstract final class FreezeEngine {
  /// Thaws count per day, and a day starts at 4 AM — "Resets each morning",
  /// not at midnight, so a thaw at 1 AM still counts against last night.
  static const dayStartHour = 4;

  /// Standard resistance, and the first thaw of the day on Increasing.
  static const breathSeconds = 10;

  /// Increasing adds this per thaw already taken today, up to [maxBreath].
  static const breathStep = 10;
  static const maxBreath = 60;

  static DateTime _at(DateTime day, int minute) => DateTime(day.year, day.month, day.day, 0, minute);

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  static bool _inDates(Frost f, DateTime day) {
    final d = _dayOf(day);
    if (f.fromDay != null && d.isBefore(_dayOf(f.fromDay!))) return false;
    if (f.untilDay != null && d.isAfter(_dayOf(f.untilDay!))) return false;
    return true;
  }

  /// The window of [f] that contains [t], ignoring whether the frost is on,
  /// skipped or standing down.
  static FrostWindow? windowAt(Frost f, DateTime t) {
    if (f.kind == FrostKind.session) {
      final started = f.sessionStartedAt;
      if (started == null || t.isBefore(started)) return null;
      final end = f.sessionMinutes == null ? null : started.add(Duration(minutes: f.sessionMinutes!));
      if (end != null && !t.isBefore(end)) return null;
      return FrostWindow(started, end);
    }
    final today = _dayOf(t);
    final minute = t.hour * 60 + t.minute;
    if (!f.overnight) {
      final end = f.allDay ? 1440 : f.endMinute;
      if (f.days.contains(t.weekday) && _inDates(f, today) && minute >= f.startMinute && minute < end) {
        return FrostWindow(_at(today, f.startMinute), _at(today, end));
      }
      return null;
    }
    // Overnight: tonight's window, or the tail of last night's.
    if (f.days.contains(t.weekday) && _inDates(f, today) && minute >= f.startMinute) {
      return FrostWindow(_at(today, f.startMinute), _at(today, 1440 + f.endMinute));
    }
    final yesterday = DateTime(t.year, t.month, t.day - 1);
    if (f.days.contains(yesterday.weekday) && _inDates(f, yesterday) && minute < f.endMinute) {
      return FrostWindow(_at(yesterday, f.startMinute), _at(today, f.endMinute));
    }
    return null;
  }

  /// When [f] next starts after [t], for "Starts 10 PM" / "Starts in 4d".
  /// Null for a session frost, a frost with no days, or one whose dates have
  /// passed.
  static DateTime? nextStart(Frost f, DateTime t) {
    if (f.kind == FrostKind.session || f.days.isEmpty) return null;
    final today = _dayOf(t);
    for (var i = 0; i <= 400; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      if (f.untilDay != null && day.isAfter(_dayOf(f.untilDay!))) return null;
      if (!f.days.contains(day.weekday) || !_inDates(f, day)) continue;
      final start = _at(day, f.startMinute);
      if (start.isAfter(t)) return start;
    }
    return null;
  }

  static bool standingDown(FreezeData d, DateTime t) {
    final s = d.standdown;
    return s != null && !t.isBefore(s.since) && (s.until == null || t.isBefore(s.until!));
  }

  /// Everything running at [t]. A frost that is off, skipped for today, or
  /// standing down is not running.
  static List<ActiveFreeze> active(FreezeData d, DateTime t) {
    final out = <ActiveFreeze>[];
    final down = standingDown(d, t);
    for (final f in d.frosts) {
      if (!f.enabled) continue;
      if (f.skipUntil != null && t.isBefore(f.skipUntil!)) continue;
      final w = windowAt(f, t);
      if (w == null) continue;
      if (down) {
        final hold = d.standdown!.holds[f.id];
        if (hold == null || !t.isBefore(hold)) continue;
      }
      out.add(ActiveFreeze(id: f.id, name: f.name, apps: f.apps, deep: f.deep, start: w.start, end: w.end, frost: f));
    }
    final now = d.now;
    if (now != null && !t.isBefore(now.startedAt) && (now.endsAt == null || t.isBefore(now.endsAt!))) {
      var held = !down;
      if (down) {
        final hold = d.standdown!.holds[ActiveFreeze.nowId];
        held = hold != null && t.isBefore(hold);
      }
      if (held) {
        out.add(ActiveFreeze(
          id: ActiveFreeze.nowId,
          name: 'Freeze now',
          apps: now.apps,
          deep: now.deep,
          start: now.startedAt,
          end: now.endsAt,
        ));
      }
    }
    return out;
  }

  /// A thaw that covers [app] at [t].
  static ThawGrant? grantFor(FreezeData d, String app, DateTime t) {
    for (final g in d.grants) {
      if (!t.isBefore(g.until)) continue;
      if (g.target == ThawGrant.allApps || g.target == app) return g;
    }
    return null;
  }

  /// The rule above, for one app. [app] is a package name on Android.
  static bool isFrozen(FreezeData d, String app, DateTime t) {
    if (d.groups.neverOpen.contains(app)) return true;
    if (d.groups.alwaysOpen.contains(app)) return false;
    final covering = active(d, t).where((a) => a.covers(app)).toList();
    if (covering.isEmpty) return false;
    if (covering.any((a) => a.deep)) return true;
    return grantFor(d, app, t) == null;
  }

  /// A Deep freeze is running: thawing is closed until [deepUntil].
  static ActiveFreeze? deepRunning(FreezeData d, DateTime t) {
    ActiveFreeze? longest;
    for (final a in active(d, t)) {
      if (!a.deep) continue;
      if (longest == null || (a.end != null && longest.end != null && a.end!.isAfter(longest.end!))) {
        longest = a;
      }
    }
    return longest;
  }

  /// The start of the thaw day containing [t] (4 AM).
  static DateTime thawDayStart(DateTime t) {
    final fourToday = DateTime(t.year, t.month, t.day, dayStartHour);
    return t.isBefore(fourToday) ? DateTime(t.year, t.month, t.day - 1, dayStartHour) : fourToday;
  }

  static int thawsToday(FreezeData d, DateTime t) {
    final start = thawDayStart(t);
    return d.thawLog.where((r) => !r.at.isBefore(start) && !r.at.isAfter(t)).length;
  }

  /// How long the breath lasts before this thaw (fz-thaw-pause): 10 seconds,
  /// or on Increasing 10 more for each thaw already taken today, up to a
  /// minute.
  static int breathFor(FreezeData d, DateTime t) {
    if (d.thaw.resistance == ThawResistance.standard) return breathSeconds;
    final n = thawsToday(d, t);
    final s = breathSeconds + breathStep * n;
    return s > maxBreath ? maxBreath : s;
  }

  /// When the next thing changes — a window opens or closes, a thaw runs out,
  /// Freeze now ends, a stand-down lifts. The native side schedules its own
  /// wake-ups from the same data; this is what the app uses to refresh.
  static DateTime? nextChange(FreezeData d, DateTime t) {
    DateTime? best;
    void consider(DateTime? at) {
      if (at == null || !at.isAfter(t)) return;
      if (best == null || at.isBefore(best!)) best = at;
    }

    for (final f in d.frosts) {
      if (!f.enabled) continue;
      final w = windowAt(f, t);
      consider(w?.end);
      consider(nextStart(f, t));
      consider(f.skipUntil);
    }
    consider(d.now?.endsAt);
    for (final g in d.grants) {
      consider(g.until);
    }
    consider(d.standdown?.until);
    d.standdown?.holds.values.forEach(consider);
    return best;
  }

  /// Drops what has run out: thaws past their end, a finished Freeze now, a
  /// stand-down that lifted, a skip that passed, a session frost whose run
  /// ended, and thaw records older than two weeks (the report needs one).
  static FreezeData prune(FreezeData d, DateTime t) {
    final grants = d.grants.where((g) => t.isBefore(g.until)).toList();
    final now = d.now;
    final nowDone = now != null && now.endsAt != null && !t.isBefore(now.endsAt!);
    final s = d.standdown;
    final downDone = s != null && s.until != null && !t.isBefore(s.until!);
    final frosts = [
      for (final f in d.frosts)
        if (f.kind == FrostKind.session &&
            f.sessionStartedAt != null &&
            f.sessionMinutes != null &&
            !t.isBefore(f.sessionStartedAt!.add(Duration(minutes: f.sessionMinutes!))))
          f.copyWith(clearSessionStartedAt: true)
        else if (f.skipUntil != null && !t.isBefore(f.skipUntil!))
          f.copyWith(clearSkipUntil: true)
        else
          f,
    ];
    final keepFrom = t.subtract(const Duration(days: 15));
    final log = d.thawLog.where((r) => r.at.isAfter(keepFrom)).toList();
    return d.copyWith(
      grants: grants,
      clearNow: nowDone,
      clearStanddown: downDone,
      frosts: frosts,
      thawLog: log,
    );
  }

  /// The holds a stand-down starting at [t] keeps: every Deep freeze running
  /// now, until the end of its window.
  static Map<String, DateTime> holdsFor(FreezeData d, DateTime t) => {
        for (final a in active(d, t))
          if (a.deep && a.end != null) a.id: a.end!,
      };
}

/// The words the screens use for times, days and statuses.
abstract final class FreezeText {
  static const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const day3 = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "9:00 AM". [minute] may be 1440 (midnight at the end of the day).
  static String time(int minute, {bool short = false}) {
    final m = minute % 1440;
    final h24 = m ~/ 60;
    final mm = m % 60;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final ap = h24 < 12 ? 'AM' : 'PM';
    if (short && mm == 0) return '$h12 $ap';
    return '$h12:${mm.toString().padLeft(2, '0')} $ap';
  }

  static String clock(DateTime t, {bool short = false}) => time(t.hour * 60 + t.minute, short: short);

  /// "3:47" — the refreeze time in a toast, no AM/PM (fz-thawed).
  static String bareClock(DateTime t) {
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h12:${t.minute.toString().padLeft(2, '0')}';
  }

  /// "9 AM – 1 PM", "All day", "10 PM – 7 AM".
  static String span(Frost f, {bool short = true}) {
    if (f.allDay) return 'All day';
    return '${time(f.startMinute, short: short)} – ${time(f.endMinute, short: short)}';
  }

  static bool _run(List<int> sorted) => sorted.length > 1 && sorted.last - sorted.first == sorted.length - 1;

  /// "Weekdays", "Daily", "Weekends", "Mon–Thu", "Mon, Tue, Thu".
  static String days(Set<int> days) {
    final s = days.toList()..sort();
    if (s.isEmpty) return 'No days';
    if (s.length == 7) return 'Daily';
    if (s.length == 5 && s.first == 1 && s.last == 5) return 'Weekdays';
    if (s.length == 2 && s.first == 6 && s.last == 7) return 'Weekends';
    if (_run(s) && s.length > 2) return '${day3[s.first - 1]}–${day3[s.last - 1]}';
    return s.map((d) => day3[d - 1]).join(', ');
  }

  /// "Mon to Fri", "Sat and Sun" — the onboarding sentence (obDaysProse).
  static String daysProse(Set<int> days) {
    final s = days.toList()..sort();
    final n = s.map((d) => day3[d - 1]).toList();
    if (n.isEmpty) return '';
    if (n.length == 1) return n.first;
    if (_run(s) && n.length > 2) return '${n.first} to ${n.last}';
    return '${n.sublist(0, n.length - 1).join(', ')} and ${n.last}';
  }

  /// The frost's one-line summary: "9 AM – 1 PM · Mon–Fri", "2 hr session".
  static String summary(Frost f) {
    if (f.kind == FrostKind.session) return sessionLength(f.sessionMinutes);
    final d = f.days.length == 7 ? (f.allDay ? '7 days' : 'Daily') : days(f.days);
    return '${span(f)} · ${d == 'Weekdays' ? 'Mon–Fri' : d}';
  }

  static String sessionLength(int? minutes) {
    if (minutes == null) return 'Until you stop';
    if (minutes % 60 == 0) return '${minutes ~/ 60} hr session';
    return '$minutes min session';
  }

  /// "1h 40m", "25m", "3d".
  static String left(Duration d) {
    final mins = (d.inSeconds / 60).ceil();
    if (mins >= 48 * 60) return '${(mins / 1440).floor()}d';
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${mins < 1 ? 1 : mins}m';
  }

  /// A frost card's status pill (fz-hub): "1h 40m left", "Starts 10 PM",
  /// "Starts in 4d", "Paused", "Off".
  static String status(FreezeData d, Frost f, DateTime t) {
    if (!f.enabled) return 'Off';
    if (FreezeEngine.standingDown(d, t) && !d.standdown!.holds.containsKey(f.id)) return 'Paused';
    final running = FreezeEngine.active(d, t).any((a) => a.id == f.id);
    if (running) {
      final w = FreezeEngine.windowAt(f, t);
      return w?.end == null ? 'Running' : '${left(w!.end!.difference(t))} left';
    }
    if (f.kind == FrostKind.session) return sessionLength(f.sessionMinutes);
    if (f.skipUntil != null && t.isBefore(f.skipUntil!)) {
      final next = FreezeEngine.nextStart(f, f.skipUntil!);
      return next == null ? 'Off today' : 'Back ${clock(next, short: true)}';
    }
    final next = FreezeEngine.nextStart(f, t);
    if (next == null) return 'Done';
    final ahead = next.difference(t);
    if (ahead < const Duration(hours: 24)) return 'Starts ${clock(next, short: true)}';
    return 'Starts in ${(ahead.inHours / 24).ceil()}d';
  }

  /// "Back tomorrow at 7:00 AM." / "Back at 7:00 AM." / "Back on Mon at 9:00 AM."
  static String backAt(DateTime at, DateTime t) {
    // Calendar days between, counted in UTC so a DST change (a 23-hour day)
    // cannot turn "tomorrow" into "today".
    final diff = DateTime.utc(at.year, at.month, at.day).difference(DateTime.utc(t.year, t.month, t.day)).inDays;
    final when = clock(at);
    if (diff == 0) return 'Back at $when.';
    if (diff == 1) return 'Back tomorrow at $when.';
    if (diff < 7) return 'Back on ${day3[at.weekday - 1]} at $when.';
    return 'Back in $diff days.';
  }
}
