// "Break down more" has to go FINER, not sideways.
//
// The button previously did nothing visible: the plan screen guarded the whole
// call on `t.subtasks.isEmpty`, so with steps present it skipped the request and
// only toggled the card — you were shown the same three steps you already had.
//
// The fix has two halves and both are asserted here, because the second is easy
// to lose: refining must REPLACE the current steps with a finer set, and it must
// produce more of them than it was given. A "refinement" that returns the same
// count is a failed refinement, and the server rejects it rather than
// overwriting good steps with a reshuffle.
//
// Covered at the source seam because that is where mock and live must agree
// (README §7, seam 3) — a mock that no-ops on refine would hide the exact bug
// this parameter exists to fix.

import 'package:aqademiq/data/dtos/task_dto.dart';
import 'package:aqademiq/data/fixtures/fixtures.dart';
import 'package:aqademiq/data/sources/tasks_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockTasksSource source;
  late DateTime day;

  setUp(() {
    source = MockTasksSource();
    // The mock only seeds the fixture day; any other date is empty.
    day = Fixtures.today;
  });

  Future<TaskDto> firstTask() async => (await source.tasksForDay(day)).first;

  test('a first breakdown adds steps to a task that has none', () async {
    var task = await firstTask();
    // Start from a known-empty state so the assertion is about breakdown, not
    // about whatever the fixture happened to ship with.
    await source.clearSteps(task.id);
    task = (await source.tasksForDay(day)).firstWhere((t) => t.id == task.id);
    expect(task.subtasks, isEmpty);

    await source.breakdown(task.id, day);
    task = (await source.tasksForDay(day)).firstWhere((t) => t.id == task.id);
    expect(task.subtasks, isNotEmpty);
  });

  test('refining produces MORE steps than it was given', () async {
    var task = await firstTask();
    await source.clearSteps(task.id);
    await source.breakdown(task.id, day);
    task = (await source.tasksForDay(day)).firstWhere((t) => t.id == task.id);
    final before = task.subtasks.length;

    await source.breakdown(task.id, day, refine: true);
    task = (await source.tasksForDay(day)).firstWhere((t) => t.id == task.id);

    expect(
      task.subtasks.length,
      greaterThan(before),
      reason: '"Break down more" that returns the same count is doing nothing',
    );
  });

  test('refining replaces the old steps rather than appending', () async {
    // Appending is what stacked three breakdowns on one task in production.
    var task = await firstTask();
    await source.clearSteps(task.id);
    await source.breakdown(task.id, day);
    task = (await source.tasksForDay(day)).firstWhere((t) => t.id == task.id);
    final oldTitles = task.subtasks.map((s) => s.title).toSet();

    await source.breakdown(task.id, day, refine: true);
    task = (await source.tasksForDay(day)).firstWhere((t) => t.id == task.id);
    final newTitles = task.subtasks.map((s) => s.title).toSet();

    expect(
      newTitles.intersection(oldTitles),
      isEmpty,
      reason: 'the previous steps should be gone, not sitting above the new ones',
    );
  });

  test('breaking down twice without refine does not stack', () async {
    var task = await firstTask();
    await source.clearSteps(task.id);
    await source.breakdown(task.id, day);
    task = (await source.tasksForDay(day)).firstWhere((t) => t.id == task.id);
    final first = task.subtasks.length;

    await source.breakdown(task.id, day);
    task = (await source.tasksForDay(day)).firstWhere((t) => t.id == task.id);

    expect(task.subtasks, hasLength(first));
  });
}
