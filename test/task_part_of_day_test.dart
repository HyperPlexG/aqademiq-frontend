import 'package:aqademiq/data/adapters/adapters.dart';
import 'package:aqademiq/data/dtos/task_dto.dart';
import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/features/plan/providers/plan_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reported bug: a task saved as "Afternoon" came back under Anytime. The
/// proper fix persists the bucket on its own field (tasks.planner_section),
/// carried as the wire `part_of_day` → TaskDto.timeOfDay → Task.dayPart. With no
/// specific time, taskBucket falls back to dayPart, so the bucket survives.
void main() {
  final date = DateTime(2026, 7, 26);

  TaskDto dtoWith({String? timeOfDay, DateTime? startTime}) => TaskDto(
        id: '1',
        title: 'x',
        tagId: 't',
        date: date,
        timeOfDay: timeOfDay,
        startTime: startTime,
      );

  group('part_of_day round-trips into the right bucket', () {
    test('a bucket with no specific time keeps its bucket', () {
      final task = dtoWith(timeOfDay: 'afternoon').toModel();
      expect(task.dayPart, DayPart.afternoon);
      expect(task.startTime, isNull);
      expect(taskBucket(task), DayPart.afternoon);
    });

    test('morning and evening buckets round-trip too', () {
      expect(taskBucket(dtoWith(timeOfDay: 'morning').toModel()), DayPart.morning);
      expect(taskBucket(dtoWith(timeOfDay: 'evening').toModel()), DayPart.evening);
    });

    test('anytime stays anytime', () {
      expect(taskBucket(dtoWith(timeOfDay: 'anytime').toModel()), DayPart.anytime);
      expect(taskBucket(dtoWith().toModel()), DayPart.anytime); // null bucket
    });

    test('a specific time still wins over the bucket for grouping', () {
      // 2 PM → afternoon by the hour, regardless of the stored bucket.
      final task = dtoWith(
        timeOfDay: 'anytime',
        startTime: DateTime(2026, 7, 26, 14),
      ).toModel();
      expect(taskBucket(task), DayPart.afternoon);
    });
  });
}
