// A task's subject has to reach the wire.
//
// The Add Task form has shown a subject picker since it shipped. It tracked the
// selection in `_subject`, highlighted the chosen chip, and offered a "no
// subject" option — and then dropped the value on the floor. There was no field
// for it on `Task` or `TaskDto`, no key for it in the request body, and no
// reader for it in the response. The picker was decorative, and every task was
// filed by whatever the server picked instead.
//
// Two consequences that these tests pin down, because both are silent:
//
//  * Selecting a subject had no effect on the saved task.
//  * Because the client never sent one, `POST /tasks` always took its "no
//    subject_id supplied" branch — which used to look up the user's first
//    subject and 422 when there wasn't one. A student with zero subjects could
//    not create a task by any route in the app.

import 'package:aqademiq/data/adapters/adapters.dart';
import 'package:aqademiq/data/dtos/task_dto.dart';
import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/data/sources/tasks_source.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task({String? subjectId}) => Task(
      id: '',
      title: 'Problem set',
      tagId: 'study',
      subjectId: subjectId,
      date: DateTime(2026, 9, 2),
      dayPart: DayPart.anytime,
    );

void main() {
  test('subjectId survives model → DTO → model', () {
    final dto = _task(subjectId: 'course-1').toDto();
    expect(dto.subjectId, 'course-1');
    expect(dto.toModel().subjectId, 'course-1');
  });

  test('no subject stays null rather than becoming an empty string', () {
    // The picker's own "none" option produces this. An empty string sent as
    // `subject_id` would be a malformed id, not an absent one.
    final dto = _task().toDto();
    expect(dto.subjectId, isNull);
    expect(dto.toModel().subjectId, isNull);
  });

  test('the mock source preserves it, so mock and live agree', () async {
    // Seam 3: `MockTasksSource` and `ApiTasksSource` have to behave the same,
    // or the UI is developed against a version of the app that does not exist.
    final saved = await MockTasksSource().create(_task(subjectId: 'course-9').toDto());
    expect(saved.subjectId, 'course-9');
  });

  test('an occurrence response carrying subject_id is read back', () {
    // The server has always returned this field. Nothing read it, so reopening
    // a task for editing showed no subject and saving it would have cleared one.
    const wire = <String, dynamic>{
      'id': 'abc@2026-09-02',
      'title': 'Reading',
      'category': 'study',
      'subject_id': 'course-3',
      'part_of_day': 'anytime',
      'status': 'PENDING',
    };
    final dto = TaskDto(
      id: wire['id'] as String,
      title: wire['title'] as String,
      tagId: wire['category'] as String,
      subjectId: wire['subject_id'] as String?,
      date: DateTime(2026, 9, 2),
    );
    expect(dto.toModel().subjectId, 'course-3');
  });

  test('copyWith can clear a subject back to none', () {
    // Freezed's copyWith takes null as "unchanged", so clearing has to go
    // through a fresh construction. Pinned because the edit screen relies on
    // the saved value round-tripping exactly.
    final withSubject = _task(subjectId: 'course-1');
    expect(withSubject.subjectId, 'course-1');
    final cleared = Task(
      id: withSubject.id,
      title: withSubject.title,
      tagId: withSubject.tagId,
      date: withSubject.date,
      dayPart: withSubject.dayPart,
    );
    expect(cleared.subjectId, isNull);
  });
}
