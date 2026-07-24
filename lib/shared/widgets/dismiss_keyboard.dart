import 'package:flutter/material.dart';

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
