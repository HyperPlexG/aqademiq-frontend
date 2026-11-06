import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../data/app_freeze_channel.dart';
import '../presentation/thaw_screen.dart';
import 'freeze_controller.dart';

/// Carries the shield's "Thaw · 10s" into the app.
///
/// The shield is native — Android's `ShieldActivity`, iOS's ShieldAction
/// extension — and cannot run the breath itself, so it queues a
/// `thaw_request` and opens Aqademiq (Android directly; iOS by a "Tap to thaw"
/// notification, since an extension cannot open an app). This reads the
/// queue whenever the app comes to the front, or when the native side says it
/// has something waiting, and opens the breath for that app.
///
/// It also re-applies the policy on every resume: cheap, idempotent, and the
/// way a frost survives the native side having been killed in the meantime.
final freezeEventsProvider = Provider<FreezeEvents>((ref) {
  final events = FreezeEvents(ref);
  ref.onDispose(events.dispose);
  return events..start();
});

class FreezeEvents with WidgetsBindingObserver {
  FreezeEvents(this._ref);

  final Ref _ref;
  String? _lastTarget;
  DateTime? _lastAt;
  bool _draining = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _ref.read(appFreezeChannelProvider).onEventsWaiting(() => unawaited(_drain()));
    // Cold start from the shield: the event is already queued.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ref.read(freezeControllerProvider.notifier).reapply());
      unawaited(_drain());
    });
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_ref.read(freezeControllerProvider.notifier).reapply());
    unawaited(_drain());
  }

  /// Opens the breath — but not over the splash. On a cold start from the
  /// shield the splash routes 1.6 s in and its `go` would replace the whole
  /// stack, losing the press; so wait until it has, then push.
  void _open(ThawRequest request) {
    final router = _ref.read(routerProvider);
    final delegate = router.routerDelegate;
    bool onSplash() {
      final path = delegate.currentConfiguration.uri.path;
      return path.isEmpty || path == Routes.splash;
    }

    void push() => unawaited(router.push<Object?>(Routes.freezeThaw, extra: request));
    if (!onSplash()) return push();
    late final VoidCallback wait;
    wait = () {
      if (onSplash()) return;
      delegate.removeListener(wait);
      push();
    };
    delegate.addListener(wait);
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final events = await _ref.read(appFreezeChannelProvider).takeEvents();
      // Only the newest request matters: two presses of Thaw on two shields
      // are one decision to make now, not two breaths in a row.
      final request = events.where((e) => e.type == FreezeEvent.thawRequest).lastOrNull;
      if (request == null) return;
      final target = request.target ?? '*';
      // One press, one breath: the same queued event read twice (a resume
      // and an eventsWaiting racing) must not open it twice. A second press
      // has its own timestamp and opens it again.
      if (_lastTarget == target && _lastAt == request.at) return;
      _lastTarget = target;
      _lastAt = request.at;
      _open(ThawRequest(target: target, label: request.label));
    } finally {
      _draining = false;
    }
  }
}
