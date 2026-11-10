import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/task.dart';
import '../../providers/plan_providers.dart';
import '../pickers/repeat_picker.dart';
import '../widgets/plan_sheet.dart';

/// What ticking a repeating task off means.
enum RepeatDoneChoice {
  /// This occurrence is done; the series carries on (it comes back next time).
  thisDay,

  /// This occurrence is done and the series ends on its day.
  forGood,
}

/// Whether ticking [task] off has to ask first: it repeats, and it is being
/// ticked (un-ticking never asks).
bool tickNeedsChoice(Task task) =>
    !task.done &&
    task.repeat != null &&
    task.repeat!.frequency != RepeatFrequency.none;

/// The one way the Plan ticks a task off or back on — the done circle in both
/// views and the overflow sheet's "Mark as done" all come through here.
///
/// A one-off, or an un-tick, goes straight to the controller as before. Ticking
/// a repeating task first asks whether it is done for this day or for good
/// (TestFlight: a tester ticked an "Every day" task once and expected it gone,
/// then found it back the next morning). Dismissing the sheet ticks nothing.
///
/// No feel here: the controller plays the tick (or the day's last tick) when
/// the circle fills, which is after the choice — one feel per tick.
Future<void> tickTask(BuildContext context, WidgetRef ref, Task task) async {
  final controller = ref.read(dayTasksProvider.notifier);
  if (!tickNeedsChoice(task)) {
    unawaited(controller.toggleDone(task));
    return;
  }
  final choice = await showRepeatDoneSheet(context, task: task);
  if (choice == null) return;
  unawaited(
    controller.toggleDone(task, endSeries: choice == RepeatDoneChoice.forGood),
  );
}

/// The small choice sheet (v11 floating picker: title with ✕, two option rows).
/// Resolves to the choice, or null when dismissed.
Future<RepeatDoneChoice?> showRepeatDoneSheet(
  BuildContext context, {
  required Task task,
}) {
  return showPlanSheet<RepeatDoneChoice>(
    context,
    builder: (_) => _RepeatDoneSheet(task: task),
  );
}

class _RepeatDoneSheet extends StatelessWidget {
  const _RepeatDoneSheet({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final title = task.title.trim().isEmpty ? 'This task' : task.title.trim();
    // A day other than today (the strip lets you tick any day) is worded as
    // that day: "for good" ends the series there, not today.
    final isToday = AppDate.sameDay(task.date, AppDate.today());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanSheetTitle(title, sub: 'Repeats · ${repeatRuleLabel(task.repeat)}'),
        PlanOptRow(
          icon: 'today',
          label: isToday ? 'Done for today' : 'Done for this day',
          sub: 'It keeps repeating',
          onTap: () => Navigator.of(context).pop(RepeatDoneChoice.thisDay),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'check_circle',
          label: 'Done for good',
          sub: isToday
              ? 'Stops repeating after today'
              : 'Stops repeating after this day',
          onTap: () => Navigator.of(context).pop(RepeatDoneChoice.forGood),
        ),
      ],
    );
  }
}
