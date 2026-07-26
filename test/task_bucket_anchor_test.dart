import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/data/sources/tasks_source.dart';
import 'package:aqademiq/features/plan/providers/plan_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reported bug: a task saved as "Afternoon" came back under Anytime,
/// because the backend only stores scheduled_at (no day-part) and a bucket sent
/// no time. bucketAnchor gives the bucket a representative time so it survives
/// the round trip; taskBucket must then re-derive the same bucket.
void main() {
  final date = DateTime(2026, 7, 26);

  Task taskAt(DateTime? start) =>
      Task(id: '1', title: 'x', tagId: 't', date: date, startTime: start);

  group('bucketAnchor round-trips through taskBucket', () {
    test('afternoon anchors into the afternoon bucket', () {
      final anchor = bucketAnchor('afternoon', date);
      expect(anchor, isNotNull);
      expect(taskBucket(taskAt(anchor)), DayPart.afternoon);
    });

    test('morning anchors into the morning bucket', () {
      expect(taskBucket(taskAt(bucketAnchor('morning', date))), DayPart.morning);
    });

    test('evening anchors into the evening bucket', () {
      expect(taskBucket(taskAt(bucketAnchor('evening', date))), DayPart.evening);
    });

    test('anytime and null produce no anchor (stay Anytime)', () {
      expect(bucketAnchor('anytime', date), isNull);
      expect(bucketAnchor(null, date), isNull);
    });

    test('the anchor lands on the task\'s own date', () {
      final anchor = bucketAnchor('afternoon', date)!;
      expect(anchor.year, date.year);
      expect(anchor.month, date.month);
      expect(anchor.day, date.day);
    });
  });
}
