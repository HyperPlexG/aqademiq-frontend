import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../services/haptics/haptics_service.dart';
import '../../../../shared/icons/app_icon.dart';
import '../../../../shared/widgets/app_toggle.dart';
import '../../../../shared/widgets/ic.dart';
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

/// A selectable Prism mode: its name, its glyph and its colour.
///
/// v11 `PRISM_MARK` / `PrismGlyph`: each mode is drawn by the icon pack's
/// Tier 3 state mark in the mode colour (Review borrows Creative, the
/// design's own "loosest fit"), and No sound is the pack's `mute`. The same
/// marks and colours as onboarding's Meet Prism cards.
class _PrismMode {
  const _PrismMode({required this.label, required this.glyph, required this.color});

  final String label;
  final String glyph;
  final Color Function(AppColors c) color;
}

final List<_PrismMode> _modes = [
  _PrismMode(label: 'Deep Work', glyph: 'state_deep_focus', color: (c) => c.accent),
  _PrismMode(label: 'Flow', glyph: 'state_focus', color: (c) => c.success),
  _PrismMode(label: 'Review', glyph: 'state_creative', color: (c) => c.warn),
  _PrismMode(label: 'Wind-down', glyph: 'state_relax', color: (c) => c.textMed),
  _PrismMode(label: 'No sound', glyph: 'mute', color: (c) => c.textDim),
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
class _ModeRow extends ConsumerWidget {
  const _ModeRow({required this.mode, required this.active, required this.last});

  final _PrismMode mode;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Choosing a mode is choosing a feel. The active one changes nothing.
        if (!active) ref.read(hapticsProvider).play(HapticMoment.prismPicked, mode: mode.label);
        Navigator.of(context).pop(mode.label);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: active ? colors.accentSoft : null,
          border: last
              ? null
              : Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Ic(mode.glyph, size: 22, color: mode.color(colors)),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                mode.label,
                style: AppText.sans(
                  size: 17,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? colors.accent : colors.text,
                ),
              ),
            ),
            if (active)
              AppIcon(Icons.check, size: 20, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

/// Footer row with the "Autoplay" toggle (top border). Persisted via
/// [prismAutoplayProvider] and shared with Settings → Prism ("Play Prism in
/// Focus" there, where the row has no Prism menu around it to say whose
/// autoplay it is). Here the menu does, so the word alone is enough.
class _AutoplayFooter extends ConsumerWidget {
  const _AutoplayFooter({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoplay = ref.watch(prismAutoplayProvider);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Ic('prism', size: 19, color: colors.textMed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Autoplay',
              style: AppText.sans(size: 17, color: colors.text),
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
