import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/freeze_engine.dart';
import '../domain/freeze_models.dart';

/// What the phone lets App freeze do right now.
@immutable
class FreezeAccess {
  const FreezeAccess({
    this.supported = false,
    this.authorized = false,
    this.usageAccess = false,
    this.overlay = false,
    this.batteryRestricted = false,
    this.notifications = true,
  });

  /// False on a platform with no native side (tests, desktop) or an iOS too
  /// old for Screen Time (below 16).
  final bool supported;

  /// iOS: Screen Time (FamilyControls) approved. Android: both grants.
  final bool authorized;

  /// Android: Usage access — "Shows which app is open."
  final bool usageAccess;

  /// Android: Display over other apps — "Puts the frozen screen on top."
  final bool overlay;

  /// Android: the phone's battery manager may close Aqademiq (fz-perm-battery).
  final bool batteryRestricted;

  /// Notifications allowed — the shield's "Thaw" on iOS and Ada's check-ins
  /// arrive as one.
  final bool notifications;

  static const unsupported = FreezeAccess();

  static FreezeAccess fromMap(Object? raw) {
    if (raw is! Map) return unsupported;
    bool b(String k) => raw[k] == true;
    return FreezeAccess(
      supported: b('supported'),
      authorized: b('authorized'),
      usageAccess: b('usage_access'),
      overlay: b('overlay'),
      batteryRestricted: b('battery_restricted'),
      notifications: raw['notifications'] != false,
    );
  }
}

/// An app installed on an Android phone (Choose apps, Pick what freezes).
@immutable
class DeviceApp {
  const DeviceApp({required this.package, required this.label});

  final String package;
  final String label;
}

/// Something the native side noticed while Aqademiq was not looking.
@immutable
class FreezeEvent {
  const FreezeEvent({required this.type, required this.at, this.target, this.label});

  /// The shield's "Thaw · 10s" was pressed: open the breath for [target].
  static const thawRequest = 'thaw_request';

  final String type;
  final DateTime at;

  /// Android: the package. iOS: the id the native side keeps for the app's
  /// token, opaque to Dart.
  final String? target;

  /// Android only — iOS never tells us the name.
  final String? label;

  static FreezeEvent? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final type = raw['type'];
    if (type is! String) return null;
    final at = raw['at'];
    return FreezeEvent(
      type: type,
      at: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : DateTime.now(),
      target: raw['target'] is String ? raw['target'] as String : null,
      label: raw['label'] is String ? raw['label'] as String : null,
    );
  }
}

/// The result of Apple's picker: the selection now saved under [selectionId]
/// in the App Group, and how many things it holds.
@immutable
class PickResult {
  const PickResult({required this.selectionId, required this.count});

  final String selectionId;
  final int count;
}

/// Dart's half of `aqademiq/app_freeze` — the contract is in APP_FREEZE.md.
///
/// Every call is best-effort: a phone without the native side (a test, an old
/// OS) answers as if App freeze is unavailable rather than throwing, so the
/// screens can say so instead of crashing.
class AppFreezeChannel {
  AppFreezeChannel({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(name);

  static const name = 'aqademiq/app_freeze';

  final MethodChannel _channel;

  /// Called by the native side when it has events waiting (the shield's Thaw
  /// was pressed while the app was running).
  void onEventsWaiting(VoidCallback callback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'eventsWaiting') callback();
      return null;
    });
  }

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('[freeze] $method failed: ${e.code} ${e.message}');
      return null;
    }
  }

  Future<FreezeAccess> status() async => FreezeAccess.fromMap(await _call<Object?>('status'));

  /// iOS: the one Screen Time ask. Android has no prompt — it answers with the
  /// current state; use [openSettings].
  Future<bool> requestAuthorization() async => await _call<bool>('requestAuthorization') ?? false;

  /// Android: `usage`, `overlay`, `battery` or `app`. iOS: `app` only.
  Future<void> openSettings(String target) => _call<void>('openSettings', {'target': target});

  /// iOS: presents Apple's FamilyActivityPicker over the app and saves the
  /// selection under [selectionId]. Null when cancelled.
  Future<PickResult?> pickApps({required String selectionId, String? title}) async {
    final raw = await _call<Object?>('pickApps', {'selection_id': selectionId, 'title': title});
    if (raw is! Map) return null;
    final count = raw['count'];
    return PickResult(selectionId: selectionId, count: count is int ? count : 0);
  }

  /// iOS: forget a saved selection (a deleted frost).
  Future<void> deleteSelection(String selectionId) =>
      _call<void>('deleteSelection', {'selection_id': selectionId});

  /// Android: launchable apps, without Aqademiq itself.
  Future<List<DeviceApp>> installedApps() async {
    final raw = await _call<List<Object?>>('installedApps');
    return [
      for (final a in raw ?? const <Object?>[])
        if (a is Map && a['package'] is String)
          DeviceApp(package: a['package'] as String, label: a['label'] is String ? a['label'] as String : ''),
    ];
  }

  /// Android: an app's icon as PNG bytes, [size] px square.
  Future<Uint8List?> appIcon(String package, {int size = 96}) =>
      _call<Uint8List>('appIcon', {'package': package, 'size': size});

  /// Android: the phone's own Phone, Messages, Maps and Wallet apps — the
  /// floor that is never frozen. Keys `phone`, `messages`, `maps`, `wallet`.
  Future<Map<String, String>> floorApps() async {
    final raw = await _call<Map<Object?, Object?>>('floorApps');
    return {
      for (final e in (raw ?? const {}).entries)
        if (e.key is String && e.value is String) e.key as String: e.value as String,
    };
  }

  /// Hands the native side the whole policy. It stores it and re-applies:
  /// shields now, and the schedule that keeps frosts running while Aqademiq is
  /// closed.
  Future<void> apply(FreezeData data, {String? focusLabel}) =>
      _call<void>('applyPolicy', {'policy': jsonEncode(policyOf(data, DateTime.now(), focusLabel: focusLabel))});

  /// Events the native side kept since the last call, oldest first. Reading
  /// them clears them.
  Future<List<FreezeEvent>> takeEvents() async {
    final raw = await _call<List<Object?>>('takeEvents');
    return [
      for (final e in raw ?? const <Object?>[])
        if (FreezeEvent.fromMap(e) case final FreezeEvent event) event,
    ];
  }

  /// The policy object (APP_FREEZE.md §3): the data minus the thaw history,
  /// which the native side has no use for.
  static Map<String, Object?> policyOf(FreezeData data, DateTime at, {String? focusLabel}) {
    final json = data.toJson()..remove('thaw_log');
    return {
      ...json,
      'generated_at': at.millisecondsSinceEpoch,
      'thaws_today': FreezeEngine.thawsToday(data, at),
      'thaws_counted_at': at.millisecondsSinceEpoch,
      if (focusLabel != null) 'focus_label': focusLabel,
    };
  }
}
