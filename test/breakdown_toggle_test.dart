// The breakdown toggle in the task editor.
//
// Two rules, and both are about the toggle describing the task's real state
// rather than an intention:
//
//   1. It is OFF by default. Breaking a task down costs a model call and
//      rewrites the plan, so it is opt-in — not something that happens to every
//      task someone types.
//   2. Editing acts on the CHANGE, not on the flag. Turning it off deletes the
//      steps that exist; leaving it on does NOT re-run breakdown, because that
//      appends a second set on top of the first.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/data/repositories/tasks_repository.dart';
import 'package:aqademiq/data/sources/tasks_source.dart';
import 'package:aqademiq/features/plan/presentation/add_task_screen.dart';
import 'package:aqademiq/shared/widgets/app_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Records which side of the transition the editor took.
class _RecordingRepo extends TasksRepository {
  _RecordingRepo() : super(MockTasksSource());

  final breakdownCalls = <String>[];
  final clearCalls = <String>[];

  @override
  Future<Task> create(Task draft) async => draft.copyWith(id: 'new-task-1');

  @override
  Future<Task> update(Task task) async => task;

  @override
  Future<void> breakdown(String id, DateTime date, {bool refine = false}) async =>
      breakdownCalls.add(id);

  @override
  Future<void> clearSteps(String id) async => clearCalls.add(id);
}

Task _task({required List<Subtask> subtasks}) => Task(
      id: 'task-1',
      title: 'DSP lab report',
      tagId: '',
      date: DateTime(2026, 8, 14),
      subtasks: subtasks,
    );

Future<_RecordingRepo> _pump(WidgetTester tester, {Task? existing}) async {
  final repo = _RecordingRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [tasksRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: AddTaskScreen(existing: existing),
      ),
    ),
  );
  // Let the mock-latency timers behind tags/subjects settle.
  await tester.pump(const Duration(seconds: 1));
  return repo;
}

bool _toggleValue(WidgetTester tester) =>
    tester.widget<AppToggle>(find.byType(AppToggle)).value;

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a new task has breakdown off', (tester) async {
    await _pump(tester);
    expect(_toggleValue(tester), isFalse);
  });

  testWidgets('a new task saved untouched is not broken down', (tester) async {
    final repo = await _pump(tester);
    await _save(tester);
    expect(repo.breakdownCalls, isEmpty);
    expect(repo.clearCalls, isEmpty);
  });

  testWidgets('editing a task that has steps shows the toggle on', (tester) async {
    // The switch reports what the task actually is, not what someone might want.
    await _pump(
      tester,
      existing: _task(subtasks: const [Subtask(id: 's1', title: 'Plot the response')]),
    );
    expect(_toggleValue(tester), isTrue);
  });

  testWidgets('editing a task with no steps shows the toggle off', (tester) async {
    await _pump(tester, existing: _task(subtasks: const []));
    expect(_toggleValue(tester), isFalse);
  });

  testWidgets('turning the toggle off deletes the existing steps', (tester) async {
    final repo = await _pump(
      tester,
      existing: _task(subtasks: const [Subtask(id: 's1', title: 'Plot the response')]),
    );
    expect(_toggleValue(tester), isTrue);

    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    expect(_toggleValue(tester), isFalse);

    await _save(tester);
    expect(repo.clearCalls, ['task-1']);
    expect(repo.breakdownCalls, isEmpty);
  });

  testWidgets('leaving the toggle on does not add a second set of steps', (tester) async {
    // Re-running breakdown appends rather than replaces, so an unchanged edit
    // must do nothing at all.
    final repo = await _pump(
      tester,
      existing: _task(subtasks: const [Subtask(id: 's1', title: 'Plot the response')]),
    );
    await _save(tester);
    expect(repo.breakdownCalls, isEmpty);
    expect(repo.clearCalls, isEmpty);
  });

  testWidgets('turning the toggle on breaks the task down', (tester) async {
    final repo = await _pump(tester, existing: _task(subtasks: const []));
    await tester.tap(find.byType(AppToggle));
    await tester.pump();

    await _save(tester);
    expect(repo.breakdownCalls, ['task-1']);
    expect(repo.clearCalls, isEmpty);
  });
}
