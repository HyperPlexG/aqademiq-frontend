import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../services/haptics/haptics_service.dart';

/// Press and hold to confirm — for the two actions the haptic architecture
/// gives the most friction: Thaw everything (1.2 s) and Delete account (2 s).
///
/// While the thumb is down, the pill fills from the left and the [holdMoment]
/// ratchet builds under it — pressure on ice until it gives. Reaching the end
/// plays [doneMoment] (a crack then a melt, or a knock) and calls
/// [onConfirmed]. Lifting early drains the fill and ends the ratchet with a
/// soft fall: nothing happened, and nothing is judged.
///
/// For a screen reader the pill is an ordinary button: the double-tap that
/// activates it is already a deliberate act, and a hold is hard to perform
/// through VoiceOver or Switch Control.
class HoldToConfirm extends ConsumerStatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.duration,
    required this.holdMoment,
    required this.doneMoment,
    required this.onConfirmed,
    this.background,
    this.fill,
    this.foreground,
    this.height = 50,
    this.radius = 100,
    this.enabled = true,
  });

  /// "Hold to thaw everything", "Hold to delete".
  final String label;
  final Duration duration;
  final HapticMoment holdMoment;
  final HapticMoment doneMoment;
  final VoidCallback onConfirmed;

  /// Defaults: an ink pill that fills with the danger colour.
  final Color? background;
  final Color? fill;
  final Color? foreground;
  final double height;
  final double radius;
  final bool enabled;

  @override
  ConsumerState<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends ConsumerState<HoldToConfirm> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener(_onStatus);
  HapticHold? _hold;
  bool _confirmed = false;

  @override
  void dispose() {
    _hold?.cancel();
    _progress.dispose();
    super.dispose();
  }

  void _down() {
    if (!widget.enabled || _confirmed) return;
    _hold?.cancel();
    _hold = ref.read(hapticsProvider).hold(widget.holdMoment);
    unawaited(_progress.forward());
  }

  void _up() {
    if (_confirmed || !_progress.isAnimating) return;
    _hold?.cancel();
    _hold = null;
    // Drains faster than it fills: letting go is never a second effort.
    unawaited(_progress.animateBack(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut));
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _confirmed) return;
    _confirm();
  }

  void _confirm() {
    _confirmed = true;
    _hold?.finish();
    _hold = null;
    ref.read(hapticsProvider).play(widget.doneMoment);
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = widget.enabled ? (widget.background ?? colors.ink) : colors.hilite;
    final fill = widget.fill ?? colors.danger;
    final fg = widget.enabled ? (widget.foreground ?? Colors.white) : colors.textDim;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      onTap: widget.enabled && !_confirmed ? _confirm : null,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: bg),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progress.value,
                    child: ColoredBox(color: fill),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(size: 15, weight: FontWeight.w800, letterSpacing: 0.15, color: fg),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
