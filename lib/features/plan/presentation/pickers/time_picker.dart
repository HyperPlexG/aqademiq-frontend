import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../services/haptics/haptics_service.dart';
import '../widgets/plan_sheet.dart';

/// Presents the time-of-day picker (`plan-pick-time`) as the v11 floating
/// sheet.
///
/// Returns the chosen bucket label ("Anytime"/"Morning"/"Afternoon"/"Evening"),
/// or the formatted time ("2:30 PM") if the user sets a specific time via the
/// custom dialog. Returns `null` on dismiss.
Future<String?> showTimeOfDayPicker(BuildContext context, {String? current}) {
  return showPlanSheet<String>(
    context,
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
    final selected = current ?? 'Anytime';
    // A non-bucket value is a specific time, so highlight "Specific time".
    final isSpecific = !_buckets.contains(selected);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlanSheetTitle('Time of day', sub: 'When should this land in your day?'),
        PlanOptRow(
          icon: 'all_inclusive',
          label: 'Anytime',
          sub: 'Ada slots it into a free moment',
          active: selected == 'Anytime',
          onTap: () => Navigator.of(context).pop('Anytime'),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'wb_twilight',
          label: 'Morning',
          sub: 'Before 12 PM',
          active: selected == 'Morning',
          onTap: () => Navigator.of(context).pop('Morning'),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'light_mode',
          label: 'Afternoon',
          sub: '12 – 5 PM',
          active: selected == 'Afternoon',
          onTap: () => Navigator.of(context).pop('Afternoon'),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'nights_stay',
          label: 'Evening',
          sub: 'After 5 PM',
          active: selected == 'Evening',
          onTap: () => Navigator.of(context).pop('Evening'),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'schedule',
          label: 'Specific time',
          active: isSpecific,
          // When a specific time is already set, show it instead of "Set".
          trailing: isSpecific ? PlanSetPill(label: selected) : const PlanSetPill(),
          onTap: () async {
            final picked = await _showSpecificTimeDialog(context, current: isSpecific ? selected : null);
            if (picked != null && context.mounted) {
              Navigator.of(context).pop(picked);
            }
          },
        ),
      ],
    );
  }
}

/// Centered "Set time" dialog (`plan-pick-time-custom`). Returns the formatted
/// time on commit, or `null` on dismiss. Opens on [current] ("2:30 PM") when a
/// specific time is already set.
Future<String?> _showSpecificTimeDialog(BuildContext context, {String? current}) {
  return showPlanDialog<String>(context, child: _SpecificTimeDialog(current: current));
}

class _SpecificTimeDialog extends StatefulWidget {
  const _SpecificTimeDialog({this.current});

  final String? current;

  @override
  State<_SpecificTimeDialog> createState() => _SpecificTimeDialogState();
}

class _SpecificTimeDialogState extends State<_SpecificTimeDialog> {
  // Seeded to the previous mock default (2:30 PM) so nothing looks empty.
  int _hour = 2; // 1..12
  int _minute = 30; // 0..59
  bool _pm = true;

  @override
  void initState() {
    super.initState();
    // "2:30 PM" → 2, 30, PM. Anything that does not parse keeps the seed.
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(widget.current?.trim() ?? '');
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min = int.parse(m.group(2)!);
      if (h >= 1 && h <= 12 && min >= 0 && min <= 59) {
        _hour = h;
        _minute = min;
        _pm = m.group(3)!.toUpperCase() == 'PM';
      }
    }
  }

  String get _formatted => '$_hour:${_minute.toString().padLeft(2, '0')} ${_pm ? 'PM' : 'AM'}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PlanCenterDialog(
      title: 'Set time',
      sub: 'Pick the exact start time',
      ctaLabel: 'Set · $_formatted',
      onCta: () => Navigator.of(context).pop(_formatted),
      child: Row(
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        ':',
                        style: AppText.sans(size: 22, weight: FontWeight.w800, color: colors.text),
                      ),
                    ),
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
    );
  }
}

/// A scrollable wheel column (v11 `TimeWheelCol`): the centred value 28/800,
/// neighbours 17/600 and quiet. Reports the selected index as the wheel
/// settles.
///
/// Consumer-backed for the detent tick only. Spec Finding 03: this is a
/// `ListWheelScrollView`, not a `CupertinoPicker`, and only the latter
/// self-haptics — so the wheels have been silent exactly where iOS users hold
/// the strongest expectation.
class _TimeWheel extends ConsumerStatefulWidget {
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
  ConsumerState<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends ConsumerState<_TimeWheel> {
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
          // Uniform tick per item. A fast fling would rattle, so the governor
          // suppresses runs of rapid detents (§4.4) rather than this widget
          // trying to guess at scroll velocity.
          ref.read(hapticsProvider).wheelItem();
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
                  size: selected ? 28 : 17,
                  weight: selected ? FontWeight.w800 : FontWeight.w600,
                  height: 1,
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

/// AM/PM toggle — tap to switch. The active half is accent-filled, 17/800.
class _AmPmToggle extends StatelessWidget {
  const _AmPmToggle({required this.pm, required this.onChanged});

  final bool pm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget seg({required String label, required bool active, required VoidCallback onTap}) {
      return Semantics(
        button: true,
        selected: active,
        child: GestureDetector(
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
                size: 17,
                weight: active ? FontWeight.w800 : FontWeight.w700,
                color: active ? Colors.white : colors.textMed,
              ),
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
