import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Drops whatever text field has focus and puts the keyboard away.
///
/// Only a leaf (a field, a button) is unfocused — never a route's focus scope,
/// which would knock focus out of the route that is arriving. The keyboard is
/// then told to hide outright, so it cannot outlive its field across a page
/// change. A page that wants it straight back (an autofocused field, the OTP
/// code) asks for it again after it builds, which is after this has run.
void dismissKeyboard() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus != null && focus is! FocusScopeNode) focus.unfocus();
  unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
}

/// Puts the keyboard away whenever the page changes, so text typed on one
/// screen never leaves the keyboard up over the next (onboarding's name step
/// → the steps without a field; sign-in → Plan).
///
/// Register one per navigator: on the `GoRouter` and on each tab branch.
/// Only page routes count — a sheet or dialog opening over a field manages
/// focus itself, and may carry its own autofocused field.
///
/// The observer fires synchronously as the route changes, before the arriving
/// page has built, so a page that autofocuses (add task, the OTP screen, the
/// name step) still gets its keyboard: its request lands afterwards.
class DismissKeyboardObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _changed(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _changed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _changed(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _changed(newRoute ?? oldRoute);

  static void _changed(Route<dynamic>? route) {
    if (route is PageRoute) dismissKeyboard();
  }
}

/// Wraps a screen so a tap on empty space dismisses the keyboard.
///
/// Uses a [Listener] (not a competing [GestureDetector]) so descendant
/// [TextField]s always receive taps. Unfocus only runs when the pointer lands
/// outside the currently focused widget's bounds — never steals focus from an
/// editable that was just tapped.
///
/// Prefer this on full-screen forms; bottom sheets usually get dismiss-on-scrim
/// for free via the shared bottom-sheet helper.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _unfocusIfOutside,
      child: child,
    );
  }

  static void _unfocusIfOutside(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return;
    // Never tear down the enclosing scope — only leaf focus (e.g. a TextField).
    if (focus is FocusScopeNode) return;

    final ro = focus.context!.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;

    final local = ro.globalToLocal(event.position);
    if (!ro.size.contains(local)) {
      focus.unfocus();
    }
  }
}
