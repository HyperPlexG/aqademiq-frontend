import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/focus_session.dart';
import '../../../data/repositories/focus_repository.dart';
import '../data/app_freeze_channel.dart';
import '../data/freeze_store.dart';
import '../domain/freeze_engine.dart';
import '../domain/freeze_models.dart';

final appFreezeChannelProvider = Provider<AppFreezeChannel>((ref) => AppFreezeChannel());

/// Which phone we are on, for the copy that differs (Screen Time vs two
/// grants). Overridable in tests.
final freezePlatformProvider = Provider<TargetPlatform>((ref) => defaultTargetPlatform);

/// A clock for the screens: "1h 40m left", a thaw ring running down. Ticks
/// every 15 s, which is finer than any label it drives.
final freezeClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(const Duration(seconds: 15), (_) => DateTime.now());
});

/// What the phone lets App freeze do, refreshed on demand (Check my setup,
/// returning from Settings).
final freezeAccessProvider = FutureProvider<FreezeAccess>((ref) => ref.watch(appFreezeChannelProvider).status());

/// Android: the installed apps, for Choose apps and Pick what freezes.
final installedAppsProvider =
    FutureProvider<List<DeviceApp>>((ref) => ref.watch(appFreezeChannelProvider).installedApps());

/// Android: the floor — the phone's own Phone, Messages, Maps and Wallet.
final floorAppsProvider = FutureProvider<Map<String, String>>((ref) => ref.watch(appFreezeChannelProvider).floorApps());

final freezeControllerProvider = NotifierProvider<FreezeController, FreezeData>(FreezeController.new);

/// The one place App freeze changes. Every mutation prunes what ran out,
/// saves, and hands the whole policy to the native side — which is what keeps
/// a frost running while Aqademiq is closed.
class FreezeController extends Notifier<FreezeData> {
  Timer? _refresh;
  int _ids = 0;

  /// For tests: the clock the controller reads.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  AppFreezeChannel get _channel => ref.read(appFreezeChannelProvider);

  @override
  FreezeData build() {
    ref.onDispose(() => _refresh?.cancel());
    // "This session · 25 min" follows the focus session: it moves when the
    // session is held, and thaws when it ends.
    ref.listen<FocusSession>(focusControllerProvider, (prev, next) => _followFocus(next));
    final data = FreezeEngine.prune(FreezeStore.instance.read(), clock());
    _schedule(data);
    return data;
  }

  // ---- plumbing ----------------------------------------------------------

  String _newId(String prefix) => '$prefix-${clock().microsecondsSinceEpoch.toRadixString(36)}-${_ids++}';

  /// A fresh iOS selection id, for a new frost's or group's app set.
  String newSelectionId(String owner) => _newId('sel-$owner');

  void _commit(FreezeData next) {
    final pruned = FreezeEngine.prune(next, clock());
    state = pruned;
    unawaited(FreezeStore.instance.write(pruned));
    unawaited(_channel.apply(pruned));
    _schedule(pruned);
  }

  /// Re-evaluate (and drop what ran out) at the next moment anything changes,
  /// so the hub's Frozen row empties when a thaw runs out rather than on the
  /// next tap.
  void _schedule(FreezeData data) {
    _refresh?.cancel();
    final now = clock();
    final next = FreezeEngine.nextChange(data, now);
    if (next == null) return;
    var wait = next.difference(now) + const Duration(seconds: 1);
    // Timers are not for days ahead; the clock provider and app resume cover
    // the long gaps.
    if (wait > const Duration(hours: 6)) wait = const Duration(hours: 6);
    _refresh = Timer(wait, () {
      final pruned = FreezeEngine.prune(state, clock());
      state = pruned;
      unawaited(FreezeStore.instance.write(pruned));
      _schedule(pruned);
    });
  }

  /// Re-reads the store and re-applies — app resume, Check my setup.
  Future<void> reapply() async {
    _commit(FreezeStore.instance.read());
    ref.invalidate(freezeAccessProvider);
  }

  void _followFocus(FocusSession focus) {
    final now = state.now;
    if (now == null || !now.withFocus) return;
    if (focus.status == FocusStatus.completed || focus.status == FocusStatus.idle) {
      _commit(state.copyWith(clearNow: true));
    } else if (focus.status == FocusStatus.paused && focus.frozenAt != null) {
      // A held session's end is stale until it resumes (resume pushes it out
      // by the hold). Hold the freeze open meanwhile, so a long pause cannot
      // let it run out and leave the rest of the session unfrozen; resume
      // re-anchors it to the session's new end in the branch below.
      final hold = focus.frozenAt!.add(const Duration(hours: 12));
      if (now.endsAt != hold) {
        _commit(state.copyWith(
          now: FreezeNow(startedAt: now.startedAt, endsAt: hold, deep: now.deep, apps: now.apps, withFocus: true),
        ));
      }
    } else if (focus.endsAt != null && focus.endsAt != now.endsAt && focus.status == FocusStatus.running) {
      _commit(state.copyWith(
        now: FreezeNow(
          startedAt: now.startedAt,
          endsAt: focus.endsAt,
          deep: now.deep,
          apps: now.apps,
          withFocus: true,
        ),
      ));
    }
  }

  // ---- setup ---------------------------------------------------------------

  void markSetUp() {
    if (state.setUp) return;
    _commit(state.copyWith(setUp: true));
  }

  /// The floor — Always open starts as the phone's own Phone, Messages, Maps
  /// and Wallet (Android). iOS has nothing to seed: Phone is never shieldable.
  void seedFloor(Map<String, String> floor) {
    if (!state.groups.alwaysOpen.isEmpty || floor.isEmpty) return;
    _commit(state.copyWith(
      groups: state.groups.copyWith(alwaysOpen: AppSet(packages: floor.values.toSet().toList())),
    ));
  }

  // ---- freeze now ----------------------------------------------------------

  /// fz-session. [length] null = Until I stop; [withFocus] = This session.
  void freezeNow({required AppSet apps, Duration? length, DateTime? endsAt, bool deep = false, bool withFocus = false}) {
    final now = clock();
    final end = endsAt ?? (length == null ? null : now.add(length));
    _commit(state.copyWith(
      now: FreezeNow(startedAt: now, endsAt: end, deep: deep && end != null, apps: apps, withFocus: withFocus),
      recentApps: apps,
    ));
  }

  void stopNow() => _commit(state.copyWith(clearNow: true));

  /// The Focus ice chip's set ("The usual · 9 on ice"): what freezes when a
  /// focus session starts. Empty turns the chip back to "Nothing on ice".
  void setRecentApps(AppSet apps) => _commit(state.copyWith(recentApps: apps));

  /// Start focus with the ice chip set: freeze it for exactly the session.
  void freezeForFocus(DateTime endsAt) {
    final apps = state.recentApps;
    if (!state.setUp || (apps.isEmpty && !apps.keepOnly)) return;
    freezeNow(apps: apps, endsAt: endsAt, withFocus: true);
  }

  /// "Save as a frost": the Freeze now choice becomes a session frost.
  Frost saveAsFrost({required String name, required AppSet apps, int? minutes, bool deep = false}) {
    final frost = Frost(
      id: _newId('f'),
      name: name,
      kind: FrostKind.session,
      sessionMinutes: minutes,
      deep: deep && minutes != null,
      apps: apps,
    );
    _commit(state.copyWith(frosts: [...state.frosts, frost]));
    return frost;
  }

  // ---- frosts --------------------------------------------------------------

  Frost newFrost({String name = 'New frost', FrostKind kind = FrostKind.schedule}) =>
      Frost(id: _newId('f'), name: name, kind: kind, sessionMinutes: kind == FrostKind.session ? 120 : null);

  void saveFrost(Frost frost) {
    final i = state.frosts.indexWhere((f) => f.id == frost.id);
    final list = [...state.frosts];
    if (i < 0) {
      list.add(frost);
    } else {
      list[i] = frost;
    }
    _commit(state.copyWith(frosts: list));
  }

  void deleteFrost(String id) {
    final frost = state.frosts.where((f) => f.id == id).firstOrNull;
    if (frost == null) return;
    final sel = frost.apps.iosSelection;
    // Onboarding's frosts and The usual share one Screen Time pick; only
    // forget it once nothing else uses it.
    bool used(String s) =>
        state.frosts.any((f) => f.id != id && f.apps.iosSelection == s) ||
        state.recentApps.iosSelection == s ||
        state.now?.apps.iosSelection == s ||
        state.groups.alwaysOpen.iosSelection == s ||
        state.groups.neverOpen.iosSelection == s ||
        state.groups.distracting.iosSelection == s;
    if (sel != null && !used(sel)) unawaited(_channel.deleteSelection(sel));
    _commit(state.copyWith(frosts: state.frosts.where((f) => f.id != id).toList()));
  }

  /// A Deep freeze in its window cannot be changed: "Changes to this frost
  /// unlock at 1:00 PM".
  DateTime? lockedUntil(Frost frost) {
    if (!frost.deep) return null;
    final a = FreezeEngine.active(state, clock()).where((a) => a.id == frost.id).firstOrNull;
    return a?.end;
  }

  void startSession(String frostId) {
    final f = state.frosts.where((f) => f.id == frostId).firstOrNull;
    if (f == null || f.kind != FrostKind.session) return;
    saveFrost(f.copyWith(sessionStartedAt: clock(), enabled: true));
  }

  /// "End early" → "End for today". A session frost simply stops; a schedule
  /// frost is off until its current window would have ended.
  void endEarly(String frostId) {
    final f = state.frosts.where((f) => f.id == frostId).firstOrNull;
    if (f == null || lockedUntil(f) != null) return;
    if (f.kind == FrostKind.session) {
      saveFrost(f.copyWith(clearSessionStartedAt: true));
      return;
    }
    final w = FreezeEngine.windowAt(f, clock());
    if (w?.end == null) return;
    saveFrost(f.copyWith(skipUntil: w!.end));
  }

  // ---- thawing -------------------------------------------------------------

  /// Whether a thaw is allowed at all right now (fz-deep holds otherwise).
  ActiveFreeze? get deepHold => FreezeEngine.deepRunning(state, clock());

  int get breathSeconds => FreezeEngine.breathFor(state, clock());

  /// After the breath: [target] opens for [minutes], then refreezes by itself.
  ThawGrant thaw({required String target, required int minutes, String? label}) {
    final now = clock();
    final grant = ThawGrant(target: target, until: now.add(Duration(minutes: minutes)), startedAt: now, label: label);
    _commit(state.copyWith(
      grants: [...state.grants.where((g) => g.target != target), grant],
      thawLog: [...state.thawLog, ThawRecord(at: now, minutes: minutes, target: target)],
    ));
    return grant;
  }

  /// The toast's Refreeze: the thaw ends now.
  void refreeze(String target) => _commit(state.copyWith(grants: state.grants.where((g) => g.target != target).toList()));

  void setThawSettings(ThawSettings settings) => _commit(state.copyWith(thaw: settings));

  // ---- thaw everything -----------------------------------------------------

  /// settings-thaw-all. [until] null = Until I bring it back. A Deep freeze
  /// that is running keeps its deal.
  void standDown(DateTime? until) {
    final now = clock();
    final holds = FreezeEngine.holdsFor(state, now);
    final keepNow = state.now != null && holds.containsKey(ActiveFreeze.nowId);
    _commit(state.copyWith(
      standdown: Standdown(since: now, until: until, holds: holds),
      clearNow: !keepNow,
      thawLog: [...state.thawLog, ThawRecord(at: now, minutes: 0, target: ThawGrant.allApps)],
    ));
  }

  void bringBack() => _commit(state.copyWith(clearStanddown: true));

  /// 7:00 AM tomorrow — "Just today" means back tomorrow morning.
  DateTime tomorrowMorning() {
    final n = clock();
    return DateTime(n.year, n.month, n.day + 1, 7);
  }

  // ---- groups --------------------------------------------------------------

  void setGroups(FreezeGroups groups) => _commit(state.copyWith(groups: groups));

  // ---- onboarding ----------------------------------------------------------

  /// Onboarding's Study hours step hands over its days and hours; App freeze
  /// turns them into the frosts ob-freeze shows (`onboardingFrosts`).
  /// "I don't have set hours" after all: drop the frosts onboarding made.
  void dropOnboardingFrosts() {
    if (!state.frosts.any((f) => f.id.startsWith('ob-'))) return;
    _commit(state.copyWith(frosts: state.frosts.where((f) => !f.id.startsWith('ob-')).toList()));
  }

  void adoptOnboardingFrosts(List<Frost> frosts, {required AppSet apps}) {
    final kept = state.frosts.where((f) => !f.id.startsWith('ob-')).toList();
    _commit(state.copyWith(
      setUp: true,
      frosts: [for (final f in frosts) f.copyWith(apps: apps), ...kept],
      recentApps: apps,
    ));
  }
}

/// The frosts onboarding proposes from the student's study hours (ob-freeze):
/// Study hours on the study days, and Wellness time — 9 AM to noon — on the
/// days left over. All seven days studied → no Wellness time.
List<Frost> onboardingFrosts({required Set<int> studyDays, required int fromMinute, required int untilMinute}) {
  final rest = {1, 2, 3, 4, 5, 6, 7}.difference(studyDays);
  return [
    if (rest.isNotEmpty)
      Frost(id: 'ob-wellness', name: 'Wellness time', days: rest, endMinute: 12 * 60),
    if (studyDays.isNotEmpty)
      Frost(id: 'ob-study', name: 'Study hours', days: studyDays, startMinute: fromMinute, endMinute: untilMinute),
  ];
}
