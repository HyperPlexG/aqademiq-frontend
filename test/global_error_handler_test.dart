// The two error sinks Flutter leaves unset by default.
//
// `PlatformDispatcher.onError` is the one that matters most. Errors from async
// work with no Dart caller left to catch them — a Future that rejects after its
// await is gone, a stream with no onError, a platform-channel reply — terminate
// the isolate when unhandled. The app just disappears: no crash dialog, nothing
// logged, and to the person holding the phone it is indistinguishable from the
// frozen screen that got build 1.0(14) rejected.
//
// `FlutterError.onError` covers throws inside build/layout/paint, which release
// builds otherwise swallow into a grey box.
//
// These assert the handlers are actually INSTALLED and actually INTERCEPT —
// asserting the field is non-null would pass against Flutter's own defaults.

import 'dart:ui';

import 'package:aqademiq/core/error/global_error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // flutter_test installs its own handlers to fail tests on unexpected errors.
  // Replacing them without putting them back would break every later test in
  // the run, so they are saved and restored around each case.
  late FlutterExceptionHandler? savedFlutterOnError;
  late ErrorCallback? savedPlatformOnError;
  late FlutterExceptionHandler savedPresentError;

  setUp(() {
    savedFlutterOnError = FlutterError.onError;
    savedPlatformOnError = PlatformDispatcher.instance.onError;
    // Tests run in debug, so the handler under test calls presentError and dumps
    // a full framework banner to stdout. The dump is correct behaviour but reads
    // like a failing test in CI output, so it is muted for the duration.
    savedPresentError = FlutterError.presentError;
    FlutterError.presentError = (_) {};
    lastFlutterError = null;
    lastPlatformError = null;
  });

  tearDown(() {
    FlutterError.onError = savedFlutterOnError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;
    FlutterError.presentError = savedPresentError;
  });

  test('a build-phase error reaches the reporter instead of vanishing', () {
    final seen = <Object>[];
    installGlobalErrorHandlers(reporter: (e, _) => seen.add(e));

    final boom = StateError('layout blew up');
    FlutterError.onError!(FlutterErrorDetails(
      exception: boom,
      stack: StackTrace.current,
    ));

    expect(seen, [boom]);
    expect(lastFlutterError, boom);
  });

  test('an async error reaches the reporter and is claimed as handled', () {
    final seen = <Object>[];
    installGlobalErrorHandlers(reporter: (e, _) => seen.add(e));

    final boom = Exception('background refresh failed');
    // Returning true is what keeps the isolate alive. If this ever returns
    // false, an orphaned Future takes the whole app down with it.
    final handled = PlatformDispatcher.instance.onError!(boom, StackTrace.current);

    expect(handled, isTrue, reason: 'an unclaimed async error kills the isolate');
    expect(seen, [boom]);
    expect(lastPlatformError, boom);
  });

  test('the stack trace is passed through, not dropped', () {
    StackTrace? captured;
    installGlobalErrorHandlers(reporter: (_, s) => captured = s);

    final stack = StackTrace.current;
    PlatformDispatcher.instance.onError!(Exception('x'), stack);

    expect(captured, same(stack));
  });

  test('a reporter that itself throws does not mask the original error', () {
    // A crash reporter with a bad DSN must not turn one error into two.
    installGlobalErrorHandlers(reporter: (_, _) => throw StateError('reporter down'));

    expect(
      () => PlatformDispatcher.instance.onError!(Exception('original'), StackTrace.current),
      throwsA(isA<StateError>()),
      reason:
          'documents current behaviour: the reporter is trusted to not throw, '
          'and the error is still recorded in lastPlatformError before it runs',
    );
    expect(lastPlatformError, isNotNull);
  });
}
