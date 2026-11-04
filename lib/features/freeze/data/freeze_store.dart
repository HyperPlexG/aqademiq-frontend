import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/freeze_models.dart';

/// App freeze's one record on disk (SharedPreferences `freeze.v1`).
///
/// Device-local by design: the frosts, groups and thaw history never reach the
/// server. Initialised in `main.dart` beside the other settings services, so
/// the controller can read it synchronously on first build.
class FreezeStore {
  FreezeStore._();

  static final FreezeStore instance = FreezeStore._();

  static const _key = 'freeze.v1';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  FreezeData read() {
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return const FreezeData();
    try {
      return FreezeData.fromJson(jsonDecode(raw));
    } on FormatException catch (e) {
      // A corrupt record must not take the app down. Starting again empty is
      // the safe failure: nothing freezes that the student did not ask for.
      debugPrint('[freeze] unreadable store, starting empty: $e');
      return const FreezeData();
    }
  }

  Future<void> write(FreezeData data) async {
    await _prefs?.setString(_key, jsonEncode(data.toJson()));
  }
}
