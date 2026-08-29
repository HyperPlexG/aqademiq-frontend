import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ambient_state.dart';

/// Actions a student can take from a surface outside the app.
///
/// Both are deliberately session controls and nothing else: the surfaces are
/// glanced at, not operated, and one press is the entire interaction budget.
enum AmbientAction {
  /// Hold the session without unlocking, without finding the app, without the
  /// session dying — the tutorial's "freeze, don't quit", one press from
  /// anywhere. This is the single most valuable thing on any of these surfaces.
  freeze,

  /// Let it go again.
  resume,

  /// Give up the session.
  end,

  /// Begin a five-minute session — five, not twenty-five, because the point is
  /// the lowest possible barrier between an idle thumb and a started session.
  startFive,
}

/// The one channel between the app and everything it draws outside itself.
///
/// Kept as a hand-written channel rather than a widget plugin because the
/// surfaces need native control the plugins do not offer: an Android
/// foreground-service notification whose chronometer the system ticks, and an
/// iOS Live Activity whose countdown is rendered from an end timestamp. Both
/// exist precisely so the app never has to push the clock.
///
/// Every method is best-effort. A phone with no Dynamic Island, an Android
/// version without live chips, a platform that has none of this — all of them
/// must degrade to silence rather than to an exception, because none of this is
/// load-bearing for the session itself.
class AmbientBridge {
  AmbientBridge._();

  static final AmbientBridge instance = AmbientBridge._();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel('aqademiq/ambient');

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void Function(AmbientAction action)? _onAction;

  /// Register the single handler for presses that happen out there.
  ///
  /// Taps arrive from a notification action, a Live Activity button or a
  /// widget, and all of them land here so the session has exactly one place
  /// that can change it.
  void setActionHandler(void Function(AmbientAction action) handler) {
    _onAction = handler;
    if (!_supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'action') return null;
      final name = call.arguments as String?;
      final action = switch (name) {
        'freeze' => AmbientAction.freeze,
        'resume' => AmbientAction.resume,
        'end' => AmbientAction.end,
        'startFive' => AmbientAction.startFive,
        _ => null,
      };
      if (action != null) _onAction?.call(action);
      return null;
    });
  }

  /// Publish the glanceable data the widgets read.
  ///
  /// Written to the shared container (App Group / shared prefs) and followed by
  /// a reload request, so widgets pick it up without the app being open.
  Future<void> publish(AmbientState state) =>
      _invoke('publish', state.toMap());

  /// A session has begun: raise the live surfaces.
  Future<void> startSession(AmbientSession session) =>
      _invoke('startSession', session.toMap());

  /// A session changed in a way worth redrawing for — a melt stage, a freeze,
  /// or a new end instant after one. Never called for the clock alone.
  Future<void> updateSession(AmbientSession session) =>
      _invoke('updateSession', session.toMap());

  /// No session is running: stand down everywhere.
  ///
  /// The Island is taken for a running session and nothing else, so this is not
  /// housekeeping — leaving it up would make Aqademiq a squatter.
  Future<void> endSession() => _invoke('endSession', null);

  Future<void> _invoke(String method, Object? arguments) async {
    if (!_supported) return;
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (e) {
      // A surface that cannot be drawn is not a session that has gone wrong.
      debugPrint('AmbientBridge.$method unavailable: ${e.message}');
    } on MissingPluginException {
      // Older build of the host app, or a platform with no native half yet.
    }
  }
}
