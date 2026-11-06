import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screenshots taken while the weekly report is on screen (v11
/// `core-screenshot`).
///
/// The phone says so on its own channel, `aqademiq/screenshot`: iOS forwards
/// `UIApplication.userDidTakeScreenshotNotification` (ScreenshotPlugin.swift),
/// Android 14+ an `Activity.ScreenCaptureCallback` (MainActivity.kt; older
/// Android has no such callback and simply never calls). Native sends
/// `screenshotTaken` with no arguments; nothing about the picture crosses.
///
/// Dart listens only while someone is watching [reportScreenshotProvider] —
/// the report screen, while it is mounted — and lets go of the channel the
/// moment they stop, so a screenshot anywhere else in the app is ignored.
abstract final class ReportScreenshots {
  static const MethodChannel _channel = MethodChannel('aqademiq/screenshot');

  /// One event per screenshot, numbered so two in a row are two events.
  static Stream<int> watch() {
    var n = 0;
    late final StreamController<int> controller;
    controller = StreamController<int>(
      onListen: () => _channel.setMethodCallHandler((call) async {
        if (call.method == 'screenshotTaken' && !controller.isClosed) controller.add(++n);
      }),
      onCancel: () {
        _channel.setMethodCallHandler(null);
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }
}

/// The screenshot count while the report is watching. Auto-disposed, so the
/// channel is held exactly as long as the screen is.
final reportScreenshotProvider = StreamProvider.autoDispose<int>((ref) => ReportScreenshots.watch());
