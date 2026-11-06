import 'dart:async';
import 'dart:ui' as ui;

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

  /// One event per screenshot: the moment it was heard, stamped as the
  /// handler runs, so an event that arrives late can be told from a fresh one.
  static Stream<DateTime> watch() {
    late final StreamController<DateTime> controller;
    controller = StreamController<DateTime>(
      onListen: () {
        // With no handler set, Flutter keeps the last message sent on a
        // channel and replays it to the next handler — so a screenshot taken
        // anywhere in the app, any time before, raised the banner the moment
        // the report opened. No buffer: a screenshot nobody is listening for
        // is simply gone (and quietly, without the overflow warning).
        ui.channelBuffers
          ..resize(_channel.name, 0)
          ..allowOverflow(_channel.name, true);
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'screenshotTaken' && !controller.isClosed) {
            controller.add(DateTime.now());
          }
        });
      },
      onCancel: () {
        _channel.setMethodCallHandler(null);
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }
}

/// When the last screenshot was heard while the report is watching.
/// Auto-disposed, so the channel is held exactly as long as the screen is.
final reportScreenshotProvider = StreamProvider.autoDispose<DateTime>((ref) => ReportScreenshots.watch());
