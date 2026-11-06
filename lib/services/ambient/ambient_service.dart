import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/router/app_router.dart';
import '../../core/router/pending_launch_route.dart';
import '../../core/utils/date_format.dart';
import '../../data/models/enums.dart';
import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import '../../data/repositories/focus_repository.dart';
import '../../data/repositories/mood_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../features/focus/providers/linked_task_provider.dart';
import '../../features/focus/providers/prism_audio_provider.dart';
import '../../features/plan/providers/plan_providers.dart';
import '../local_notifications.dart';
import 'ambient_bridge.dart';
import 'ambient_glance.dart';
import 'ambient_state.dart';

/// Keeps the surfaces outside the app in step with the session inside it.
///
/// Watched at the app root so it runs whichever tab is on screen — a session
/// keeps going while the app is closed, which is the entire reason these
/// surfaces exist.
///
/// The push budget is enforced here rather than trusted to callers: the
/// controller emits a new session state every second (the in-app timer counts
/// up), and all but a handful of those are dropped. What survives is a melt
/// stage changing, a freeze, or a change in what is being worked on.
final ambientServiceProvider = Provider<void>((ref) {
  final service = AmbientService(ref);
  ref.onDispose(service.dispose);
  service.start();
});

class AmbientService {
  AmbientService(this._ref, {AmbientBridge? bridge})
      : _bridge = bridge ?? AmbientBridge.instance;

  final Ref _ref;
  final AmbientBridge _bridge;

  /// The last session state the surfaces were told about, so the next one can
  /// be compared against what is actually on screen rather than against the
  /// previous tick.
  AmbientSession? _published;
  ProviderSubscription<dynamic>? _sub;
  ProviderSubscription<dynamic>? _tasksSub;
  ProviderSubscription<dynamic>? _moodSub;
  bool _disposed = false;

  /// Live-session pushes so far (start, update, end), so a press can tell
  /// whether the session's own listener already told the surfaces.
  int _pushes = 0;

  /// The last glance actually published, encoded. Every publish reloads every
  /// widget timeline, so the same picture is never sent twice.
  String? _lastGlance;

  /// Today's tasks, as last seen while the Plan was showing today. The Plan's
  /// list follows whichever day the student is browsing; "Next" never does.
  List<Task>? _todayTasks;
  DateTime? _todayTasksOn;

  /// Seconds focused on this phone today, and the day they count
  /// (`yyyy-MM-dd`). Nothing else in the app keeps a today total, so the
  /// session's own ends are counted here and kept on disk, so the lock-screen
  /// ring survives a relaunch.
  String? _focusDay;
  int _focusSec = 0;
  SharedPreferences? _prefs;

  /// Until the stored total is read, a glance would publish a false 0m.
  bool _focusReady = false;

  static const _kFocusDay = 'ambient_focus_day';
  static const _kFocusSec = 'ambient_focus_sec';

  void start() {
    _bridge
      ..setActionHandler(_handleAction)
      ..setRouteHandler(_handleRoute)
      // Last, so a press parked before launch lands on a fully wired bridge.
      ..announceReady();
    unawaited(_loadFocusToday().then((_) => _publishGlance()));
    _sub = _ref.listen(
      focusControllerProvider,
      (_, _) => _sync(),
      fireImmediately: true,
    );
    // The glanceable half changes on a different clock from the session — a
    // task ticked off, a check-in logged — so it is watched separately rather
    // than recomputed on every session tick.
    _tasksSub = _ref.listen(
      dayTasksProvider,
      (_, _) => _publishGlance(),
      fireImmediately: true,
    );
    _moodSub = _ref.listen(
      moodWeekProvider,
      (_, _) => _publishGlance(),
    );
  }

  void dispose() {
    _disposed = true;
    _sub?.close();
    _tasksSub?.close();
    _moodSub?.close();
  }

  /// Write what the widgets show when nothing is running.
  void _publishGlance() {
    if (_disposed || !_focusReady) return;

    // "Next" is today's, whatever day the Plan is browsing. Its list is taken
    // only while it shows today and has settled — mid-reload it still holds
    // the day it is leaving — and otherwise today's last list stands in.
    final today = AppDate.today();
    final day = _ref.read(dayTasksProvider);
    if (AppDate.sameDay(_ref.read(selectedDateProvider), today) &&
        !day.isLoading &&
        !day.hasError &&
        day.hasValue) {
      _todayTasks = day.value;
      _todayTasksOn = today;
    }
    final seenOn = _todayTasksOn;
    final tasks =
        seenOn != null && AppDate.sameDay(seenOn, today) ? _todayTasks : null;
    final logs = _ref.read(moodWeekProvider).value;
    // Nothing loaded yet: publishing an empty payload would blank a widget
    // that is currently showing something perfectly good.
    if (tasks == null && logs == null) return;

    final now = DateTime.now();
    final state = glanceState(
      tasks: tasks ?? const [],
      weekLogs: logs ?? const [],
      tagsById: _ref.read(tagsByIdProvider),
      todayFocusMin: _focusDay == ambientDay(now) ? _focusSec ~/ 60 : 0,
      session: _published,
      now: now,
    );
    // The same picture again is not worth a reload of every widget.
    final encoded = jsonEncode(state.toMap());
    if (encoded == _lastGlance) return;
    _lastGlance = encoded;
    unawaited(_bridge.publish(state));
  }

  /// Read today's stored focus total. Never throws: with no store (a test, a
  /// platform failure) the count simply starts from this run.
  Future<void> _loadFocusToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      // Only if nothing has been counted yet this run, which is all but
      // certain: a session cannot end in the moment this read takes.
      if (_focusDay == null) {
        _focusDay = prefs.getString(_kFocusDay);
        _focusSec = prefs.getInt(_kFocusSec) ?? 0;
      }
    } on Object catch (e) {
      debugPrint('AmbientService: no stored focus total — $e');
    }
    _focusReady = true;
  }

  /// A session stopped: add what it spent to today's total, and say so.
  ///
  /// A session that crosses midnight counts for the day it ended on.
  void _countFocus(int seconds) {
    if (seconds <= 0) return;
    final today = ambientDay(DateTime.now());
    if (_focusDay != today) {
      _focusDay = today;
      _focusSec = 0;
    }
    _focusSec += seconds;
    final prefs = _prefs;
    if (prefs != null) {
      unawaited(prefs.setString(_kFocusDay, today));
      unawaited(prefs.setInt(_kFocusSec, _focusSec));
    }
    _publishGlance();
  }

  /// Push the session to the live surfaces, but only when it earns it.
  ///
  /// [force] skips the materiality check. Used after a press from outside the
  /// app, because the native side has already redrawn the Live Activity on its
  /// own to make the press feel instant — so the surface may now disagree with
  /// this session even though, from here, nothing material changed. Pushing
  /// the session's own state puts the two clocks back on one source of truth.
  void _sync({bool force = false}) {
    final next = _describeSession();

    if (next == null) {
      // Nothing is running. Stand down — the Island is not ours to hold.
      final last = _published;
      if (last != null) {
        _published = null;
        final focusedSec = _ranToItsEnd();
        _pushes++;
        unawaited(_bridge.endSession(focusedSec: focusedSec));
        if (focusedSec != null) _tellSessionDone(focusedSec, last.taskTitle);
        // Today's total moves only when a session stops, so this is the one
        // moment the lock-screen ring has anything new to say.
        _countFocus(_ref.read(focusControllerProvider).elapsedSec);
      }
      return;
    }

    if (_published == null) {
      _published = next;
      _pushes++;
      unawaited(_bridge.startSession(next));
      return;
    }

    if (force || next.differsMateriallyFrom(_published)) {
      _published = next;
      _pushes++;
      unawaited(_bridge.updateSession(next));
    }
  }

  /// The seconds spent, if the session that just stopped ran to its end.
  ///
  /// Only then does the lock screen keep a "Session done" card (la-lock-done):
  /// a session ended early was ended on purpose, usually from the app or the
  /// lock screen itself, and simply goes. One call either way — the done card
  /// is the final content of the activity, not another push.
  int? _ranToItsEnd() {
    final session = _ref.read(focusControllerProvider);
    if (session.status != FocusStatus.completed || session.endedEarly) {
      return null;
    }
    return session.elapsedSec;
  }

  /// "Session done" in the notification list (notif-ios), when the session ran
  /// to its end with the app off screen. On screen, the end screen says it;
  /// on Android, the card standing down says it. Passive, never an alert.
  void _tellSessionDone(int focusedSec, String? taskTitle) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    unawaited(
      LocalNotifications.instance.showSessionDone(
        focused: Duration(seconds: focusedSec),
        taskTitle: taskTitle,
      ),
    );
  }

  /// The ambient view of the running session, or null when there is none.
  AmbientSession? _describeSession() {
    final session = _ref.read(focusControllerProvider);
    final task = _ref.read(linkedTaskProvider);
    final prism = _ref.read(prismAudioControllerProvider);

    return AmbientSession.from(
      session,
      taskTitle: task?.title,
      subjectLabel: _subjectLabelFor(task),
      subjectTint: _subjectTintFor(task),
      // What is *sounding*, not what was configured: a session whose audio is
      // off should not claim a mode on the lock screen.
      prismMode: prism.activeMode,
    );
  }

  Tag? _tagFor(Task? task) {
    final tagId = task?.tagId;
    if (tagId == null) return null;
    // The tags are already loaded for the Plan screen; a widget must never
    // trigger a fetch, so an unresolved tag simply means no subject shown.
    return _ref.read(tagsByIdProvider)[tagId];
  }

  String? _subjectLabelFor(Task? task) => _tagFor(task)?.label;

  String? _subjectTintFor(Task? task) => _tagFor(task)?.color;

  /// A tapped widget, landed somewhere useful.
  ///
  /// The surfaces speak in intent (`focus`, `plan`, `stats`) rather than in the
  /// app's route strings, so a route rename cannot silently break a widget that
  /// is already installed on someone's home screen.
  void _handleRoute(String route) {
    final destination = switch (route) {
      'focus' || 'focus/start5' => Routes.timer,
      'plan' => Routes.plan,
      'stats' => Routes.stats,
      'subjects' => Routes.subjects,
      'ada' => Routes.ada,
      // App freeze's ongoing notification and Ada's check-in.
      'freeze' => Routes.freeze,
      // The shield's Thaw. Deliberately nowhere: the same press queued a
      // thaw_request, and FreezeEvents opens the breath from that — a `go`
      // here would race it and could replace the breath with the hub.
      'freeze/thaw' => null,
      _ => null,
    };
    if (destination == null) return;
    // A widget that starts five minutes both starts the session and shows it.
    if (route == 'focus/start5') _handleAction(AmbientAction.startFive);
    _go(destination);
  }

  /// Go somewhere — unless the splash still owns the screen.
  ///
  /// On a cold launch this runs before the splash has routed, and the splash's
  /// own `go` would land on top of it 1.6s later. Parked instead, the splash
  /// honours it (see `pendingLaunchRouteProvider`).
  void _go(String destination) {
    final router = _ref.read(routerProvider);
    final here = router.routerDelegate.currentConfiguration.uri.path;
    if (here.isEmpty || here == Routes.splash) {
      _ref.read(pendingLaunchRouteProvider.notifier).set(destination);
    } else {
      router.go(destination);
    }
  }

  /// A press on a surface out there, routed to the one controller that owns
  /// the session. Everything here is idempotent on purpose: a notification
  /// button can be pressed twice before the redraw lands.
  void _handleAction(AmbientAction action) {
    final controller = _ref.read(focusControllerProvider.notifier);
    final session = _ref.read(focusControllerProvider);
    final pushesBefore = _pushes;

    switch (action) {
      case AmbientAction.freeze:
        if (!session.isFrozen) controller.pause();
      case AmbientAction.resume:
        if (session.isFrozen) controller.resume();
      case AmbientAction.end:
        unawaited(controller.complete());
      case AmbientAction.startFive:
        // Five, not twenty-five. Only from a standing start — a press that
        // arrives mid-session must never restart the one already running.
        if (_published == null) {
          controller.configure(durationMin: 5);
          unawaited(controller.start());
          // And show it. The button opens the app, and a session running on a
          // screen the student is not looking at is indistinguishable from one
          // that did not start.
          _go(Routes.timer);
        }
    }
    // The action changed the session; tell the surfaces immediately rather
    // than waiting for the next tick, so the press feels like it landed — and
    // forced, because the surface may already have redrawn itself
    // optimistically and must be brought back to what the session says.
    //
    // Only if the session's own listener has not just done exactly that: a
    // Freeze flips `frozen`, which is already a material push, and a second
    // copy of it would be a wasted redraw. A press that changed nothing (a
    // second Freeze on a held session) still gets its forced push.
    if (_pushes == pushesBefore) _sync(force: true);
  }
}

/// Debug helper: what the surfaces would currently be told.
@visibleForTesting
AmbientSession? describeAmbientSession(AmbientService service) =>
    service._describeSession();
