import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import '../../data/repositories/focus_repository.dart';
import '../../data/repositories/mood_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../features/focus/providers/linked_task_provider.dart';
import '../../features/focus/providers/prism_audio_provider.dart';
import '../../features/plan/providers/plan_providers.dart';
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

  void start() {
    _bridge
      ..setActionHandler(_handleAction)
      ..setRouteHandler(_handleRoute);
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
    _sub?.close();
    _tasksSub?.close();
    _moodSub?.close();
  }

  /// Write what the widgets show when nothing is running.
  void _publishGlance() {
    final tasks = _ref.read(dayTasksProvider).value;
    final logs = _ref.read(moodWeekProvider).value;
    // Nothing loaded yet: publishing an empty payload would blank a widget
    // that is currently showing something perfectly good.
    if (tasks == null && logs == null) return;

    unawaited(
      _bridge.publish(
        glanceState(
          tasks: tasks ?? const [],
          weekLogs: logs ?? const [],
          tagsById: _ref.read(tagsByIdProvider),
          session: _published,
        ),
      ),
    );
  }

  /// Push the session to the live surfaces, but only when it earns it.
  void _sync() {
    final next = _describeSession();

    if (next == null) {
      // Nothing is running. Stand down — the Island is not ours to hold.
      if (_published != null) {
        _published = null;
        unawaited(_bridge.endSession());
      }
      return;
    }

    if (_published == null) {
      _published = next;
      unawaited(_bridge.startSession(next));
      return;
    }

    if (next.differsMateriallyFrom(_published)) {
      _published = next;
      unawaited(_bridge.updateSession(next));
    }
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
      _ => null,
    };
    if (destination == null) return;
    // A widget that starts five minutes both starts the session and shows it.
    if (route == 'focus/start5') _handleAction(AmbientAction.startFive);
    _ref.read(routerProvider).go(destination);
  }

  /// A press on a surface out there, routed to the one controller that owns
  /// the session. Everything here is idempotent on purpose: a notification
  /// button can be pressed twice before the redraw lands.
  void _handleAction(AmbientAction action) {
    final controller = _ref.read(focusControllerProvider.notifier);
    final session = _ref.read(focusControllerProvider);

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
        }
    }
    // The action changed the session; tell the surfaces immediately rather
    // than waiting for the next tick, so the press feels like it landed.
    _sync();
  }
}

/// Debug helper: what the surfaces would currently be told.
@visibleForTesting
AmbientSession? describeAmbientSession(AmbientService service) =>
    service._describeSession();
