import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// What an input bar turns into while the student is dictating.
///
/// Modelled on ChatGPT's: a dark pill with discard on the left, a live
/// waveform in the middle, and stop and send on the right. It changes nothing
/// about how dictation works — the words still go into the field underneath;
/// this is only how recording looks.
///
/// * **✕** throws away what was said and puts the field back as it was.
/// * **■** stops, leaving the words in the field to read and correct.
/// * **↑** stops and sends — the student's own tap, as the send button always
///   was, just without the extra step.
class VoiceRecordingBar extends StatelessWidget {
  const VoiceRecordingBar({
    required this.listening,
    required this.level,
    required this.onDiscard,
    required this.onStop,
    required this.onSend,
    super.key,
  });

  /// Capturing, as opposed to still starting up. While starting, nothing said
  /// is heard, so the waveform stays flat and dim rather than inviting speech.
  final bool listening;

  /// The microphone level, 0–1.
  final ValueListenable<double> level;

  final VoidCallback onDiscard;
  final VoidCallback onStop;
  final VoidCallback onSend;

  static const _ink = Color(0xFF1A1320);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          _RoundButton(
            key: const Key('voice-discard'),
            label: 'Discard recording',
            onTap: onDiscard,
            child: const Icon(Icons.close, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: listening ? 'Listening' : 'Starting microphone',
              child: SizedBox(
                height: 28,
                child: VoiceWaveform(level: level, active: listening),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundButton(
            key: const Key('voice-stop'),
            label: 'Stop recording',
            onTap: onStop,
            background: Colors.white.withValues(alpha: 0.12),
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _RoundButton(
            key: const Key('voice-send'),
            label: 'Send',
            onTap: onSend,
            background: colors.accent,
            child: const Icon(
              Icons.arrow_upward,
              size: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.onTap,
    required this.child,
    this.background,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bars that enter from the right at the height of the voice and drift left,
/// so the last few seconds of speaking stay visible.
///
/// Sampled on a fixed beat rather than on every level report: the recognizers
/// report at uneven rates (Android roughly every 50–100 ms, iOS per audio
/// buffer), and drawing one bar per report would make the scroll speed up and
/// stutter with them.
///
/// With reduced motion on, the bars do not travel; they all rise and fall
/// together, which still shows the mic is hearing something.
class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({
    required this.level,
    required this.active,
    super.key,
  });

  final ValueListenable<double> level;

  /// Capturing. When false the line lies flat and dim.
  final bool active;

  /// Time between bars.
  static const beat = Duration(milliseconds: 70);

  /// Enough bars to fill any phone's width; the painter shows the newest that
  /// fit.
  static const capacity = 160;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  // Growable on purpose: the scroll removes from the front and appends at the
  // back, which a fixed-length list refuses on the very first beat.
  final List<double> _bars = List<double>.filled(
    VoiceWaveform.capacity,
    0,
    growable: true,
  );
  Duration _lastBeat = Duration.zero;
  double _smoothed = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _ticker.isActive) {
      _ticker.stop();
    } else if (!reduceMotion && !_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastBeat < VoiceWaveform.beat) return;
    _lastBeat = elapsed;
    final target = widget.active ? widget.level.value : 0.0;
    // Quick to rise, slower to fall — a syllable should register at once, and
    // the gap between words should not collapse to nothing instantly.
    _smoothed = target > _smoothed ? target : _smoothed * 0.55 + target * 0.45;
    setState(() {
      _bars
        ..removeAt(0)
        ..add(_smoothed);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = Colors.white.withValues(alpha: widget.active ? 0.92 : 0.32);
    if (!reduceMotion) {
      return CustomPaint(
        painter: _WaveformPainter(bars: _bars, color: color),
        size: Size.infinite,
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: widget.level,
      builder: (_, value, _) => CustomPaint(
        painter: _WaveformPainter(
          bars: List<double>.filled(
            VoiceWaveform.capacity,
            widget.active ? value : 0,
          ),
          color: color,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.bars, required this.color})
    : _snapshot = List<double>.of(bars);

  final List<double> bars;
  final Color color;

  /// The painter repaints on every beat; comparing against a copy is what lets
  /// [shouldRepaint] see that the shared list moved.
  final List<double> _snapshot;

  static const _barWidth = 2.5;
  static const _gap = 2.5;
  static const _minHeight = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final count = math.min(
      _snapshot.length,
      ((size.width + _gap) / (_barWidth + _gap)).floor(),
    );
    if (count <= 0) return;
    final midY = size.height / 2;
    final maxHeight = size.height;
    // Newest bar at the right edge, older ones to its left.
    for (var i = 0; i < count; i++) {
      final value = _snapshot[_snapshot.length - count + i];
      final h = _minHeight + (maxHeight - _minHeight) * value.clamp(0.0, 1.0);
      final x = size.width - (count - i) * (_barWidth + _gap) + _gap;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, midY - h / 2, _barWidth, h),
          const Radius.circular(_barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.color != color || !listEquals(old._snapshot, _snapshot);
}
