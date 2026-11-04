import 'package:flutter/foundation.dart';

/// App freeze — the device-local model (v11 §04-A).
///
/// Nothing here leaves the phone. iOS hands us opaque tokens instead of app
/// names, and Android's package names stay on the device too: the design
/// promises "We never see your picks", so there is no source, no repository and
/// no DTO for any of this. It is persisted by `FreezeStore` and handed to the
/// native side as one policy object (`freeze_policy.dart`).
///
/// Plain classes with hand-written JSON, like the import models — no
/// build_runner step.

/// How a frost is triggered: by the clock, or by pressing start.
enum FrostKind { schedule, session }

/// "Freeze these" or "Keep only these" (fz-select / fz-select-keep). Keep only
/// freezes everything else, new apps too.
enum AppSetMode { freezeThese, keepOnly }

/// Thaw resistance (settings-thaw-resistance).
enum ThawResistance { standard, increasing }

/// A set of apps, in whichever form this platform gives us.
///
/// * Android: package names, readable on the device only.
/// * iOS: a `FamilyActivitySelection` that only the native side can read. We
///   keep its id (the key it is stored under in the App Group) and how many
///   things it holds, which is all iOS lets an app know.
@immutable
class AppSet {
  const AppSet({
    this.packages = const [],
    this.iosSelection,
    this.iosCount = 0,
    this.mode = AppSetMode.freezeThese,
  });

  final List<String> packages;
  final String? iosSelection;
  final int iosCount;
  final AppSetMode mode;

  static const empty = AppSet();

  bool get keepOnly => mode == AppSetMode.keepOnly;

  /// What the UI counts: "Freeze 6 apps", "4 apps".
  int get count => iosSelection != null ? iosCount : packages.length;

  bool get isEmpty => count == 0;

  bool contains(String app) => packages.contains(app);

  AppSet copyWith({
    List<String>? packages,
    String? iosSelection,
    int? iosCount,
    AppSetMode? mode,
  }) =>
      AppSet(
        packages: packages ?? this.packages,
        iosSelection: iosSelection ?? this.iosSelection,
        iosCount: iosCount ?? this.iosCount,
        mode: mode ?? this.mode,
      );

  Map<String, Object?> toJson() => {
        'packages': packages,
        if (iosSelection != null) 'ios_selection': iosSelection,
        'ios_count': iosCount,
        'mode': mode.name,
      };

  static AppSet fromJson(Object? json) {
    if (json is! Map) return empty;
    return AppSet(
      packages: _strings(json['packages']),
      iosSelection: json['ios_selection'] is String ? json['ios_selection'] as String : null,
      iosCount: _int(json['ios_count']) ?? 0,
      mode: json['mode'] == AppSetMode.keepOnly.name ? AppSetMode.keepOnly : AppSetMode.freezeThese,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSet &&
      listEquals(other.packages, packages) &&
      other.iosSelection == iosSelection &&
      other.iosCount == iosCount &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(Object.hashAll(packages), iosSelection, iosCount, mode);
}

/// A frost: a rule that freezes a set of apps, by schedule or as a session.
@immutable
class Frost {
  const Frost({
    required this.id,
    required this.name,
    this.kind = FrostKind.schedule,
    this.days = const {1, 2, 3, 4, 5},
    this.startMinute = 9 * 60,
    this.endMinute = 13 * 60,
    this.fromDay,
    this.untilDay,
    this.sessionMinutes = 120,
    this.sessionStartedAt,
    this.deep = false,
    this.apps = AppSet.empty,
    this.enabled = true,
    this.skipUntil,
  });

  final String id;

  /// "Shown on the frozen screen." (fz-name)
  final String name;
  final FrostKind kind;

  /// `DateTime.weekday` numbers, 1 = Monday … 7 = Sunday.
  final Set<int> days;

  /// Minutes after local midnight. `endMinute <= startMinute` runs overnight
  /// (Wind down, 10 PM – 7 AM); 0 → 1440 is all day.
  final int startMinute;
  final int endMinute;

  /// Optional date range (Exam week, "Mon 12 – Sun 18"). Date only.
  final DateTime? fromDay;
  final DateTime? untilDay;

  /// Session frosts: how long one run lasts. Null runs until stopped.
  final int? sessionMinutes;

  /// Session frosts: when the current run started; null when not running.
  final DateTime? sessionStartedAt;

  /// Deep freeze: no thawing while it runs, and no editing it either.
  final bool deep;
  final AppSet apps;
  final bool enabled;

  /// "End early" → "End {name} for today?": off until this moment (the end
  /// of the window that was running).
  final DateTime? skipUntil;

  bool get allDay => startMinute == 0 && endMinute >= 1440;
  bool get overnight => !allDay && endMinute <= startMinute;

  Frost copyWith({
    String? name,
    FrostKind? kind,
    Set<int>? days,
    int? startMinute,
    int? endMinute,
    DateTime? fromDay,
    DateTime? untilDay,
    bool clearDates = false,
    int? sessionMinutes,
    bool clearSessionMinutes = false,
    DateTime? sessionStartedAt,
    bool clearSessionStartedAt = false,
    bool? deep,
    AppSet? apps,
    bool? enabled,
    DateTime? skipUntil,
    bool clearSkipUntil = false,
  }) =>
      Frost(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        days: days ?? this.days,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
        fromDay: clearDates ? null : (fromDay ?? this.fromDay),
        untilDay: clearDates ? null : (untilDay ?? this.untilDay),
        sessionMinutes: clearSessionMinutes ? null : (sessionMinutes ?? this.sessionMinutes),
        sessionStartedAt:
            clearSessionStartedAt ? null : (sessionStartedAt ?? this.sessionStartedAt),
        deep: deep ?? this.deep,
        apps: apps ?? this.apps,
        enabled: enabled ?? this.enabled,
        skipUntil: clearSkipUntil ? null : (skipUntil ?? this.skipUntil),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'days': (days.toList()..sort()),
        'start': startMinute,
        'end': endMinute,
        if (fromDay != null) 'from_day': _day(fromDay!),
        if (untilDay != null) 'until_day': _day(untilDay!),
        'session_minutes': sessionMinutes,
        if (sessionStartedAt != null) 'session_started_at': sessionStartedAt!.millisecondsSinceEpoch,
        'deep': deep,
        'apps': apps.toJson(),
        'enabled': enabled,
        if (skipUntil != null) 'skip_until': skipUntil!.millisecondsSinceEpoch,
      };

  static Frost? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    return Frost(
      id: id,
      name: name,
      kind: json['kind'] == FrostKind.session.name ? FrostKind.session : FrostKind.schedule,
      days: _ints(json['days']).where((d) => d >= 1 && d <= 7).toSet(),
      startMinute: (_int(json['start']) ?? 540).clamp(0, 1440),
      endMinute: (_int(json['end']) ?? 780).clamp(0, 1440),
      fromDay: _parseDay(json['from_day']),
      untilDay: _parseDay(json['until_day']),
      sessionMinutes: _int(json['session_minutes']),
      sessionStartedAt: _ms(json['session_started_at']),
      deep: json['deep'] == true,
      apps: AppSet.fromJson(json['apps']),
      enabled: json['enabled'] != false,
      skipUntil: _ms(json['skip_until']),
    );
  }
}

/// "Freeze now" (fz-session): an ad-hoc freeze that is not a frost.
@immutable
class FreezeNow {
  const FreezeNow({
    required this.startedAt,
    this.endsAt,
    this.deep = false,
    this.apps = AppSet.empty,
    this.withFocus = false,
  });

  final DateTime startedAt;

  /// Null = "Until I stop".
  final DateTime? endsAt;
  final bool deep;
  final AppSet apps;

  /// "This session · 25 min": thaws when the focus session ends, so ending the
  /// session early ends this too.
  final bool withFocus;

  Map<String, Object?> toJson() => {
        'started_at': startedAt.millisecondsSinceEpoch,
        if (endsAt != null) 'ends_at': endsAt!.millisecondsSinceEpoch,
        'deep': deep,
        'apps': apps.toJson(),
        'with_focus': withFocus,
      };

  static FreezeNow? fromJson(Object? json) {
    if (json is! Map) return null;
    final started = _ms(json['started_at']);
    if (started == null) return null;
    return FreezeNow(
      startedAt: started,
      endsAt: _ms(json['ends_at']),
      deep: json['deep'] == true,
      apps: AppSet.fromJson(json['apps']),
      withFocus: json['with_focus'] == true,
    );
  }
}

/// A thaw: [target] opens until [until], then refreezes by itself.
///
/// [target] is [allApps] (Thaw all / Thaw apps), an Android package name, or
/// on iOS the id the shield gave the native side for the app it covered.
@immutable
class ThawGrant {
  const ThawGrant({required this.target, required this.until, required this.startedAt, this.label});

  static const allApps = '*';

  final String target;
  final DateTime until;
  final DateTime startedAt;

  /// The app's name, for "Instagram thawed · refreezes 3:47". Null on iOS,
  /// which never tells us.
  final String? label;

  Map<String, Object?> toJson() => {
        'target': target,
        'until': until.millisecondsSinceEpoch,
        'started_at': startedAt.millisecondsSinceEpoch,
        if (label != null) 'label': label,
      };

  static ThawGrant? fromJson(Object? json) {
    if (json is! Map) return null;
    final target = json['target'];
    final until = _ms(json['until']);
    if (target is! String || until == null) return null;
    return ThawGrant(
      target: target,
      until: until,
      startedAt: _ms(json['started_at']) ?? until,
      label: json['label'] is String ? json['label'] as String : null,
    );
  }
}

/// "Thaw everything" (settings-thaw-all): every frost stands down until
/// [until] (null = until brought back). A Deep freeze that was running keeps
/// its deal — [holds] maps its id to the end of the window it was in.
@immutable
class Standdown {
  const Standdown({required this.since, this.until, this.holds = const {}});

  final DateTime since;
  final DateTime? until;
  final Map<String, DateTime> holds;

  Map<String, Object?> toJson() => {
        'since': since.millisecondsSinceEpoch,
        if (until != null) 'until': until!.millisecondsSinceEpoch,
        'holds': {for (final e in holds.entries) e.key: e.value.millisecondsSinceEpoch},
      };

  static Standdown? fromJson(Object? json) {
    if (json is! Map) return null;
    final since = _ms(json['since']);
    if (since == null) return null;
    final holds = <String, DateTime>{};
    final raw = json['holds'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final at = _ms(e.value);
        if (e.key is String && at != null) holds[e.key as String] = at;
      }
    }
    return Standdown(since: since, until: _ms(json['until']), holds: holds);
  }
}

/// One thaw, kept for "Each thaw today waits a little longer", the session-end
/// count and the weekly report's "When you thawed" beat. Device-local.
@immutable
class ThawRecord {
  const ThawRecord({required this.at, required this.minutes, this.target});

  final DateTime at;
  final int minutes;
  final String? target;

  Map<String, Object?> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'minutes': minutes,
        if (target != null) 'target': target,
      };

  static ThawRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = _ms(json['at']);
    if (at == null) return null;
    return ThawRecord(
      at: at,
      minutes: _int(json['minutes']) ?? 0,
      target: json['target'] is String ? json['target'] as String : null,
    );
  }
}

/// Always open (the floor, never frozen), Never open (frozen all the time,
/// thawing doesn't reach these) and Distracting (Ada checks in).
@immutable
class FreezeGroups {
  const FreezeGroups({
    this.alwaysOpen = AppSet.empty,
    this.neverOpen = AppSet.empty,
    this.distracting = AppSet.empty,
    this.adultSites = false,
  });

  final AppSet alwaysOpen;
  final AppSet neverOpen;
  final AppSet distracting;

  /// Never open → "Adult sites" (iOS web content filter).
  final bool adultSites;

  FreezeGroups copyWith({AppSet? alwaysOpen, AppSet? neverOpen, AppSet? distracting, bool? adultSites}) =>
      FreezeGroups(
        alwaysOpen: alwaysOpen ?? this.alwaysOpen,
        neverOpen: neverOpen ?? this.neverOpen,
        distracting: distracting ?? this.distracting,
        adultSites: adultSites ?? this.adultSites,
      );

  Map<String, Object?> toJson() => {
        'always_open': alwaysOpen.toJson(),
        'never_open': neverOpen.toJson(),
        'distracting': distracting.toJson(),
        'adult_sites': adultSites,
      };

  static FreezeGroups fromJson(Object? json) {
    if (json is! Map) return const FreezeGroups();
    return FreezeGroups(
      alwaysOpen: AppSet.fromJson(json['always_open']),
      neverOpen: AppSet.fromJson(json['never_open']),
      distracting: AppSet.fromJson(json['distracting']),
      adultSites: json['adult_sites'] == true,
    );
  }
}

@immutable
class ThawSettings {
  const ThawSettings({this.resistance = ThawResistance.standard, this.minutes = 2});

  final ThawResistance resistance;

  /// "Picked for you each time you thaw. You can still change it." 2/5/10/15.
  final int minutes;

  static const lengths = [2, 5, 10, 15];

  ThawSettings copyWith({ThawResistance? resistance, int? minutes}) =>
      ThawSettings(resistance: resistance ?? this.resistance, minutes: minutes ?? this.minutes);

  Map<String, Object?> toJson() => {'resistance': resistance.name, 'minutes': minutes};

  static ThawSettings fromJson(Object? json) {
    if (json is! Map) return const ThawSettings();
    final minutes = _int(json['minutes']) ?? 2;
    return ThawSettings(
      resistance:
          json['resistance'] == ThawResistance.increasing.name ? ThawResistance.increasing : ThawResistance.standard,
      minutes: lengths.contains(minutes) ? minutes : 2,
    );
  }
}

/// Everything App freeze keeps, in one object.
@immutable
class FreezeData {
  const FreezeData({
    this.setUp = false,
    this.frosts = const [],
    this.groups = const FreezeGroups(),
    this.thaw = const ThawSettings(),
    this.now,
    this.grants = const [],
    this.standdown,
    this.thawLog = const [],
    this.recentApps = AppSet.empty,
  });

  /// The intro and the permission step have been through once (fz-intro).
  final bool setUp;
  final List<Frost> frosts;
  final FreezeGroups groups;
  final ThawSettings thaw;
  final FreezeNow? now;
  final List<ThawGrant> grants;
  final Standdown? standdown;
  final List<ThawRecord> thawLog;

  /// The last set chosen in Freeze now, offered again next time ("The usual").
  final AppSet recentApps;

  FreezeData copyWith({
    bool? setUp,
    List<Frost>? frosts,
    FreezeGroups? groups,
    ThawSettings? thaw,
    FreezeNow? now,
    bool clearNow = false,
    List<ThawGrant>? grants,
    Standdown? standdown,
    bool clearStanddown = false,
    List<ThawRecord>? thawLog,
    AppSet? recentApps,
  }) =>
      FreezeData(
        setUp: setUp ?? this.setUp,
        frosts: frosts ?? this.frosts,
        groups: groups ?? this.groups,
        thaw: thaw ?? this.thaw,
        now: clearNow ? null : (now ?? this.now),
        grants: grants ?? this.grants,
        standdown: clearStanddown ? null : (standdown ?? this.standdown),
        thawLog: thawLog ?? this.thawLog,
        recentApps: recentApps ?? this.recentApps,
      );

  Map<String, Object?> toJson() => {
        'v': 1,
        'set_up': setUp,
        'frosts': [for (final f in frosts) f.toJson()],
        'groups': groups.toJson(),
        'thaw': thaw.toJson(),
        if (now != null) 'now': now!.toJson(),
        'grants': [for (final g in grants) g.toJson()],
        if (standdown != null) 'standdown': standdown!.toJson(),
        'thaw_log': [for (final r in thawLog) r.toJson()],
        'recent_apps': recentApps.toJson(),
      };

  static FreezeData fromJson(Object? json) {
    if (json is! Map) return const FreezeData();
    List<T> list<T>(Object? raw, T? Function(Object?) parse) => [
          if (raw is List)
            for (final item in raw)
              if (parse(item) case final T value) value,
        ];
    return FreezeData(
      setUp: json['set_up'] == true,
      frosts: list(json['frosts'], Frost.fromJson),
      groups: FreezeGroups.fromJson(json['groups']),
      thaw: ThawSettings.fromJson(json['thaw']),
      now: FreezeNow.fromJson(json['now']),
      grants: list(json['grants'], ThawGrant.fromJson),
      standdown: Standdown.fromJson(json['standdown']),
      thawLog: list(json['thaw_log'], ThawRecord.fromJson),
      recentApps: AppSet.fromJson(json['recent_apps']),
    );
  }
}

// ---- JSON helpers ---------------------------------------------------------

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

DateTime? _ms(Object? v) {
  final ms = _int(v);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

List<String> _strings(Object? v) => [
      if (v is List)
        for (final s in v)
          if (s is String) s,
    ];

List<int> _ints(Object? v) => [
      if (v is List)
        for (final n in v)
          if (_int(n) case final int i) i,
    ];

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _parseDay(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}
