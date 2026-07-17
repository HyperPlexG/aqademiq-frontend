import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/app_toggle.dart';
import '../../../settings/providers/prism_settings_provider.dart';

/// fc-prism — anchored Prism mode picker dropdown.
///
/// Opened by tapping the "Prism" pill on fc-set / fc-running. Renders as an
/// anchored dropdown (top-left, offset 30/10) over the dimmed live screen.
/// Selecting a mode pops the mode's name; tapping outside / back returns
/// `null`. [current] highlights the session's active mode.
Future<String?> showPrismPicker(BuildContext context, {String? current}) {
  return showDialog<String>(
    context: context,
    barrierColor: const Color(0x59000000),
    builder: (_) => _PrismPickerOverlay(current: current),
  );
}

/// A selectable Prism mode descriptor.
class _PrismMode {
  const _PrismMode({
    required this.label,
    required this.color,
    this.mute = false,
  });

  final String label;
  final Color color;
  final bool mute;
}

const List<_PrismMode> _modes = [
  _PrismMode(label: 'Deep Work', color: Color(0xFF6B5CF0)),
  _PrismMode(label: 'Flow', color: Color(0xFF2A9D6B)),
  _PrismMode(label: 'Review', color: Color(0xFFE8A430)),
  _PrismMode(label: 'Wind-down', color: Color(0xFF777777)),
  _PrismMode(label: 'No sound', color: Color(0xFFC0C0C0), mute: true),
];

class _PrismPickerOverlay extends StatelessWidget {
  const _PrismPickerOverlay({this.current});

  final String? current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 30, left: 10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 184),
                child: IntrinsicWidth(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 36,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _modes.length; i++)
                            _ModeRow(
                              mode: _modes[i],
                              active: _modes[i].label == current,
                              last: i == _modes.length - 1,
                            ),
                          _AutoplayFooter(colors: colors),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single selectable mode row inside the dropdown.
class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.mode, required this.active, required this.last});

  final _PrismMode mode;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(mode.label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: active ? colors.accentSoft : null,
          border: last
              ? null
              : Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            CustomPaint(
              size: const Size.square(22),
              painter: _PrismGlyphPainter(color: mode.color, mute: mode.mute),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                mode.label,
                style: AppText.sans(
                  size: 14,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? colors.accent : colors.text,
                ),
              ),
            ),
            if (active)
              Icon(Icons.check, size: 12, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

/// 22×22 Prism glyph: r9 outer circle (stroke 1.6) + either 5 soundwave bars
/// `[4,7,10,7,4]` or a diagonal mute slash.
class _PrismGlyphPainter extends CustomPainter {
  const _PrismGlyphPainter({required this.color, required this.mute});

  final Color color;
  final bool mute;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, 9, stroke);

    if (mute) {
      const d = 9 / math.sqrt2;
      canvas.drawLine(
        Offset(center.dx - d, center.dy - d),
        Offset(center.dx + d, center.dy + d),
        stroke,
      );
      return;
    }

    const heights = [4.0, 7.0, 10.0, 7.0, 4.0];
    const gap = 2.6;
    final totalWidth = (heights.length - 1) * gap;
    var x = center.dx - totalWidth / 2;
    for (final h in heights) {
      canvas.drawLine(
        Offset(x, center.dy - h / 2),
        Offset(x, center.dy + h / 2),
        stroke,
      );
      x += gap;
    }
  }

  @override
  bool shouldRepaint(_PrismGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.mute != mute;
}

/// Footer row with the "Autoplay Prism" toggle (top border). Persisted via
/// [prismAutoplayProvider] and shared with Settings → Prism.
class _AutoplayFooter extends ConsumerWidget {
  const _AutoplayFooter({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoplay = ref.watch(prismAutoplayProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.music_note, size: 15, color: colors.textMed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Autoplay Prism',
              style: AppText.sans(size: 12.5, color: colors.text),
            ),
          ),
          AppToggle(
            value: autoplay,
            onChanged: (value) =>
                ref.read(prismAutoplayProvider.notifier).set(value),
          ),
        ],
      ),
    );
  }
}
