import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Presents the time-of-day picker (`plan-pick-time`) as a bottom sheet.
///
/// Returns the chosen bucket label ("Anytime"/"Morning"/"Afternoon"/"Evening"),
/// or the formatted time ("2:30 PM") if the user sets a specific time via the
/// custom dialog. Returns `null` on dismiss.
Future<String?> showTimeOfDayPicker(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x4C140F1C),
    builder: (_) => _TimeOfDaySheet(current: current),
  );
}

const _buckets = ['Anytime', 'Morning', 'Afternoon', 'Evening'];

class _TimeOfDaySheet extends StatelessWidget {
  const _TimeOfDaySheet({this.current});

  /// The currently-selected label ("Anytime"/"Morning"/…) or a specific-time
  /// string ("2:30 PM"). Null defaults to Anytime.
  final String? current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = current ?? 'Anytime';
    // A non-bucket value is a specific time, so highlight "Specific time".
    final isSpecific = !_buckets.contains(selected);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
        boxShadow: colors.sheetShadow,
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0DDD7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Time of day',
                      style: AppText.sans(
                        size: 20,
                        weight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                  ),
                  _CloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 12),
                child: Text(
                  'When should this land in your day?',
                  style: AppText.sans(size: 11.5, color: colors.textMed),
                ),
              ),
              _OptRow(
                icon: Icons.all_inclusive,
                label: 'Anytime',
                sub: 'Ada slots it into a free moment',
                active: selected == 'Anytime',
                onTap: () => Navigator.of(context).pop('Anytime'),
              ),
              const SizedBox(height: 1),
              _OptRow(
                icon: Icons.wb_twilight,
                label: 'Morning',
                sub: 'Before 12 PM',
                active: selected == 'Morning',
                onTap: () => Navigator.of(context).pop('Morning'),
              ),
              const SizedBox(height: 1),
              _OptRow(
                icon: Icons.light_mode,
                label: 'Afternoon',
                sub: '12 – 5 PM',
                active: selected == 'Afternoon',
                onTap: () => Navigator.of(context).pop('Afternoon'),
              ),
              const SizedBox(height: 1),
              _OptRow(
                icon: Icons.nights_stay,
                label: 'Evening',
                sub: 'After 5 PM',
                active: selected == 'Evening',
                onTap: () => Navigator.of(context).pop('Evening'),
              ),
              const SizedBox(height: 1),
              _OptRow(
                icon: Icons.schedule,
                label: 'Specific time',
                active: isSpecific,
                // When a specific time is already set, show it instead of "Set".
                trailing: isSpecific ? _SetPill(label: selected) : const _SetPill(),
                onTap: () async {
                  final picked = await _showSpecificTimeDialog(context);
                  if (picked != null && context.mounted) {
                    Navigator.of(context).pop(picked);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A picker list row (prototype `OptRow`).
class _OptRow extends StatelessWidget {
  const _OptRow({
    required this.icon,
    required this.label,
    this.sub,
    this.trailing,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final Widget? trailing;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: active ? colors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: active ? colors.accent : colors.textMed,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.sans(
                      size: 13.5,
                      weight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? colors.accent : colors.text,
                    ),
                  ),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        sub!,
                        style: AppText.sans(size: 10.5, color: colors.textDim),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (active)
              Icon(Icons.check, size: 14, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

/// Trailing "Set →" pill (prototype `SetPill`).
class _SetPill extends StatelessWidget {
  const _SetPill({this.label});

  /// Shown when a specific time is already chosen; otherwise the "Set →" prompt.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = label != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? colors.accentSoft : colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label ?? 'Set →',
        style: AppText.sans(
          size: 11,
          weight: FontWeight.w700,
          color: active ? colors.accent : colors.textMed,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.bg, shape: BoxShape.circle),
        child: Text(
          '✕',
          style: TextStyle(fontSize: 12, color: colors.textMed, height: 1),
        ),
      ),
    );
  }
}

/// Centered "Set time" dialog (`plan-pick-time-custom`). Returns the formatted
/// time on commit, or `null` on dismiss.
Future<String?> _showSpecificTimeDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: const Color(0x66140F1C),
    builder: (_) => const _SpecificTimeDialog(),
  );
}

class _SpecificTimeDialog extends StatefulWidget {
  const _SpecificTimeDialog();

  @override
  State<_SpecificTimeDialog> createState() => _SpecificTimeDialogState();
}

class _SpecificTimeDialogState extends State<_SpecificTimeDialog> {
  // Seeded to the previous mock default (2:30 PM) so nothing looks empty.
  int _hour = 2; // 1..12
  int _minute = 30; // 0..59
  bool _pm = true;

  String get _formatted =>
      '$_hour:${_minute.toString().padLeft(2, '0')} ${_pm ? 'PM' : 'AM'}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 226,
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sheetTop),
            boxShadow: const [
              BoxShadow(
                color: Color(0x57000000),
                blurRadius: 64,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Set time',
                      style: AppText.sans(
                        size: 19,
                        weight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                  ),
                  _CloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 14),
                child: Text(
                  'Pick the exact start time',
                  style: AppText.sans(size: 11, color: colors.textMed),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: -2,
                          right: -2,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.accentSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _TimeWheel(
                                count: 12,
                                initialIndex: _hour - 1,
                                label: (i) => '${i + 1}',
                                onChanged: (i) => setState(() => _hour = i + 1),
                              ),
                            ),
                            const _WheelColon(),
                            Expanded(
                              child: _TimeWheel(
                                count: 60,
                                initialIndex: _minute,
                                label: (i) => i.toString().padLeft(2, '0'),
                                onChanged: (i) => setState(() => _minute = i),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AmPmToggle(
                    pm: _pm,
                    onChanged: (v) => setState(() => _pm = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Set · $_formatted',
                onPressed: () => Navigator.of(context).pop(_formatted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrollable wheel column (prototype `TimeWheelCol`): the centered value is
/// large, neighbours dimmed. Reports the selected index as the wheel settles.
class _TimeWheel extends StatefulWidget {
  const _TimeWheel({
    required this.count,
    required this.initialIndex,
    required this.label,
    required this.onChanged,
  });

  final int count;
  final int initialIndex;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.initialIndex);
  late int _selected = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 120,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: 40,
        perspective: 0.004,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) {
          setState(() => _selected = i);
          widget.onChanged(i);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.count,
          builder: (context, i) {
            final selected = i == _selected;
            return Center(
              child: Text(
                widget.label(i),
                style: AppText.sans(
                  size: selected ? 22 : 15,
                  weight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? colors.text : const Color(0xFFC8C4BE),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WheelColon extends StatelessWidget {
  const _WheelColon();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      ':',
      style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.text),
    );
  }
}

/// AM/PM toggle — tap to switch. The active half is accent-filled.
class _AmPmToggle extends StatelessWidget {
  const _AmPmToggle({required this.pm, required this.onChanged});

  final bool pm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget seg({required String label, required bool active, required VoidCallback onTap}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: active ? colors.accent : colors.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppText.sans(
              size: 12,
              weight: active ? FontWeight.w800 : FontWeight.w700,
              color: active ? Colors.white : colors.textMed,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        seg(label: 'AM', active: !pm, onTap: () => onChanged(false)),
        const SizedBox(height: 6),
        seg(label: 'PM', active: pm, onTap: () => onChanged(true)),
      ],
    );
  }
}
