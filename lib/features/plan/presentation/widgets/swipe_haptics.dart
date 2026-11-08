import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../services/haptics/haptics_service.dart';

/// The swipe feel for a [Slidable] row (spec 09): a tick when the finger drags
/// the row past the reveal point, an unlatch if it pulls back under it.
///
/// Put it directly inside the [Slidable], around the row. Only the finger's
/// own drag plays: the pane snapping open or shut after release is silent.
class SwipeHaptics extends ConsumerStatefulWidget {
  const SwipeHaptics({super.key, required this.extentRatio, required this.child});

  /// The action pane's `extentRatio`. The reveal point is half of it, which
  /// is where flutter_slidable snaps the pane open on release.
  final double extentRatio;

  final Widget child;

  @override
  ConsumerState<SwipeHaptics> createState() => _SwipeHapticsState();
}

class _SwipeHapticsState extends ConsumerState<SwipeHaptics> {
  SlidableController? _controller;
  int? _pointer;
  double _travel = 0;
  bool _armed = false;

  double get _revealPoint => widget.extentRatio / 2;

  bool get _pastReveal => (_controller?.ratio.abs() ?? 0) >= _revealPoint;

  /// A finger is down on this row and has moved sideways past the slop.
  bool get _dragging => _pointer != null && _travel > kTouchSlop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = Slidable.of(context);
    if (controller == _controller) return;
    _controller?.animation.removeListener(_onMove);
    _controller = controller?..animation.addListener(_onMove);
    _armed = _pastReveal;
  }

  @override
  void dispose() {
    _controller?.animation.removeListener(_onMove);
    super.dispose();
  }

  void _onMove() {
    final past = _pastReveal;
    if (past == _armed) return;
    _armed = past;
    if (!_dragging) return;
    ref.read(hapticsProvider).play(past ? HapticMoment.swipeArm : HapticMoment.swipeBack);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _travel = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        _travel = 0;
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) _travel += e.delta.dx.abs();
      },
      onPointerUp: _up,
      onPointerCancel: _up,
      child: widget.child,
    );
  }
}
