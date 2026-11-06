import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/ic.dart';
import '../../../freeze/presentation/widgets/fz_widgets.dart';

/// The in-place task operations offered by the task-overflow action sheet
/// (section-09). Each action row pops one of these from the sheet.
enum TaskOverflowAction {
  markDone,
  edit,
  startSession,
  reschedule,
  breakDown,
  moveTomorrow,
  delete,
}

/// Presents the task-overflow action sheet (long-press on a Plan task), the
/// v11 floating panel.
///
/// Resolves to the [TaskOverflowAction] the user tapped, or `null` if dismissed
/// (tap scrim / grabber). The sheet shows a task header (subject dot + code,
/// title, subtitle) above the action rows. [done] words the first row as
/// "Mark as not done"; [hasSteps] words the breakdown row "Break down more"
/// rather than "Break down". An empty [subtitle] hides that line.
Future<TaskOverflowAction?> showTaskOverflowSheet(
  BuildContext context, {
  required String title,
  required String subjectCode,
  required Color subjectColor,
  String subtitle = '',
  bool done = false,
  bool hasSteps = false,
}) {
  return showModalBottomSheet<TaskOverflowAction>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x4C140F1C),
    builder: (_) => FzSheet(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 18),
      child: _TaskOverflowSheet(
        title: title,
        subjectCode: subjectCode,
        subjectColor: subjectColor,
        subtitle: subtitle,
        done: done,
        hasSteps: hasSteps,
      ),
    ),
  );
}

class _TaskOverflowSheet extends StatelessWidget {
  const _TaskOverflowSheet({
    required this.title,
    required this.subjectCode,
    required this.subjectColor,
    required this.subtitle,
    required this.done,
    required this.hasSteps,
  });

  final String title;
  final String subjectCode;
  final Color subjectColor;
  final String subtitle;
  final bool done;
  final bool hasSteps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TaskHeader(
          title: title,
          subjectCode: subjectCode,
          subjectColor: subjectColor,
          subtitle: subtitle,
        ),
        _ActionRow(
          icon: 'check_circle_outline',
          label: done ? 'Mark as not done' : 'Mark as done',
          action: TaskOverflowAction.markDone,
        ),
        const _ActionRow(
          icon: 'edit',
          label: 'Edit task',
          action: TaskOverflowAction.edit,
        ),
        _ActionRow(
          icon: 'timer',
          label: 'Start session',
          action: TaskOverflowAction.startSession,
          color: colors.accent,
        ),
        const _ActionRow(
          icon: 'carry_forward',
          label: 'Reschedule',
          action: TaskOverflowAction.reschedule,
        ),
        _ActionRow(
          icon: 'auto_awesome',
          label: hasSteps ? 'Break down more' : 'Break down',
          action: TaskOverflowAction.breakDown,
        ),
        const _ActionRow(
          icon: 'arrow_forward',
          label: 'Move to tomorrow',
          action: TaskOverflowAction.moveTomorrow,
        ),
        const _ActionRow(
          icon: 'delete_outline',
          label: 'Delete',
          action: TaskOverflowAction.delete,
          color: kFzDanger,
          last: true,
        ),
      ],
    );
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({
    required this.title,
    required this.subjectCode,
    required this.subjectColor,
    required this.subtitle,
  });

  final String title;
  final String subjectCode;
  final Color subjectColor;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: subjectColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    subjectCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 12, weight: FontWeight.w800, color: subjectColor),
                  ),
                ),
              ],
            ),
          ),
          Text(
            title,
            style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textDim),
            ),
        ],
      ),
    );
  }
}

/// An action: icon 18, 17/600 label, 52 min, the separator inset to the label.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.action,
    this.color,
    this.last = false,
  });

  final String icon;
  final String label;
  final TaskOverflowAction action;
  final Color? color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = color ?? colors.text;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(action),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                Ic(icon, size: 18, color: tint),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.only(right: 18),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      border: last ? null : Border(bottom: BorderSide(color: colors.border)),
                    ),
                    child: Text(
                      label,
                      style: AppText.sans(size: 17, color: tint),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
