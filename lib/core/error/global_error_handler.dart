import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Where an uncaught error goes. Swap in a crash reporter here when one is
/// added; the signature deliberately matches what Sentry and Crashlytics both
/// take, so wiring one up later is a one-line change at the call site rather
/// than a rewrite of every handler below.
typedef ErrorReporter = void Function(Object error, StackTrace? stack);

/// Default sink: the console. Honest about what it is — without a crash SDK
/// there is nowhere else for these to go, and a released build's errors are
/// only visible to someone attached to the device log.
void _debugPrintReporter(Object error, StackTrace? stack) {
  debugPrint('[uncaught] $error');
  if (stack != null) debugPrint(stack.toString());
}

/// The last error each handler saw. Test-only visibility — the handlers are
/// installed on global singletons, so this is the only way to assert that they
/// actually intercepted something rather than merely being assigned.
@visibleForTesting
Object? lastFlutterError;
@visibleForTesting
Object? lastPlatformError;

/// Install app-wide handlers for errors that no `try`/`catch` will ever see.
///
/// Flutter has two escape hatches that are unset by default, and each drops a
/// different class of failure on the floor:
///
///  * `FlutterError.onError` — anything thrown inside build, layout or paint.
///    Unhandled, release builds render a grey box where the widget should be and
///    carry on as if nothing happened.
///  * `PlatformDispatcher.instance.onError` — errors from async work with no
///    Dart caller left to catch them: a `Future` that rejects after its `await`
///    is gone, a stream with no `onError`, a platform channel reply. Unhandled,
///    these terminate the isolate — the app simply disappears, with no crash
///    dialog and nothing written down.
///
/// The second is what makes this worth having. An app that vanishes mid-session
/// is indistinguishable, to the person holding the phone, from the unresponsive
/// screen that got build 1.0(14) rejected — and just as invisible to us, because
/// nothing survives the process to tell us it happened.
///
/// Returning `true` from the platform handler claims the error as handled, which
/// keeps the isolate alive. That is the right trade for a study planner: a
/// failed background refresh should cost the refresh, not the session the user
/// was in the middle of.
void installGlobalErrorHandlers({ErrorReporter reporter = _debugPrintReporter}) {
  FlutterError.onError = (details) {
    lastFlutterError = details.exception;
    // Keep Flutter's own console formatting in debug — it is far more useful
    // than a bare toString, and it is what a developer expects to see.
    if (kDebugMode) FlutterError.presentError(details);
    reporter(details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    lastPlatformError = error;
    reporter(error, stack);
    return true; // handled — do not take the isolate down with it
  };

  // In release, a widget that throws should not leave a raw error box on screen.
  // Debug keeps the loud red box: hiding a build error from the person able to
  // fix it is how it ships.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const _QuietErrorPlaceholder();
  }
}

/// Occupies the failed widget's slot without alarming anyone.
///
/// Deliberately unstyled by the app theme: this renders precisely when
/// something in the tree is already broken, and reaching for `context.colors`
/// here risks throwing a second time inside the error path.
class _QuietErrorPlaceholder extends StatelessWidget {
  const _QuietErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Run [body] with both the global handlers and a guarded zone installed.
///
/// The zone catches the remaining case the two handlers above cannot: an error
/// thrown synchronously inside a callback that Flutter itself scheduled before
/// `runApp` finished wiring up.
Future<void> runGuardedApp(
  FutureOr<void> Function() body, {
  ErrorReporter reporter = _debugPrintReporter,
}) async {
  installGlobalErrorHandlers(reporter: reporter);
  await runZonedGuarded<Future<void>>(
    () async => body(),
    (error, stack) => reporter(error, stack),
  );
}
