import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/models/focus_session.dart';
import 'package:aqademiq/services/ambient/ambient_state.dart';
import 'package:flutter_test/flutter_test.dart';

FocusSession _running({
  int durationMin = 25,
  int elapsedSec = 0,
  FocusStatus status = FocusStatus.running,
  DateTime? endsAt,
  DateTime? frozenAt,
}) =>
    FocusSession(
      id: 's',
      durationMin: durationMin,
      elapsedSec: elapsedSec,
      status: status,
      endsAt: endsAt ?? DateTime.now().add(Duration(minutes: durationMin)),
      frozenAt: frozenAt,
    );

void main() {
  group('AmbientSession.from', () {
    test('is absent unless a session is actually live', () {
      // The Island is taken for a running session and nothing else, so an idle
      // or finished session must produce nothing to draw.
      expect(
        AmbientSession.from(const FocusSession(id: '', durationMin: 25)),
        isNull,
      );
      expect(
        AmbientSession.from(_running(status: FocusStatus.completed)),
        isNull,
      );
      expect(AmbientSession.from(_running()), isNotNull);
    });

    test('a frozen session still shows — it is held, not over', () {
      final frozenAt = DateTime.now();
      final session = AmbientSession.from(
        _running(status: FocusStatus.paused, frozenAt: frozenAt),
      );

      expect(session, isNotNull);
      expect(session!.frozen, isTrue);
    });

    test('carries what the expanded Island is for', () {
      final session = AmbientSession.from(
        _running(),
        taskTitle: 'Ch. 4 problem set',
        subjectLabel: 'Linear Algebra',
        subjectTint: '#6b5cf0',
        prismMode: 'Deep Work',
      )!;

      expect(session.taskTitle, 'Ch. 4 problem set');
      expect(session.subjectLabel, 'Linear Algebra');
      expect(session.subjectTint, '#6b5cf0');
      expect(session.prismMode, 'Deep Work');
    });

    test('never reports a session with no end to count down to', () {
      // Without an end instant the OS has nothing to render, so drawing the
      // surface at all would be worse than staying away.
      const noEnd = FocusSession(
        id: 's',
        durationMin: 25,
        status: FocusStatus.running,
      );
      expect(AmbientSession.from(noEnd), isNull);
    });
  });

  group('the push budget', () {
    test('a ticking clock alone is never worth a push', () {
      // Same stage, same everything, one second later. Five pushes a session is
      // the whole budget; spending one on the clock the OS draws for free is
      // how that budget gets blown.
      final endsAt = DateTime.now().add(const Duration(minutes: 20));
      final first = AmbientSession.from(_running(endsAt: endsAt, elapsedSec: 10))!;
      final later = AmbientSession.from(_running(endsAt: endsAt, elapsedSec: 11))!;

      expect(later.meltStage, first.meltStage);
      expect(later.differsMateriallyFrom(first), isFalse);
    });

    test('a stage change is', () {
      final endsAt = DateTime.now().add(const Duration(minutes: 20));
      // 25 min = 1500s, so a stage is 300s.
      final stage0 = AmbientSession.from(_running(endsAt: endsAt, elapsedSec: 100))!;
      final stage1 = AmbientSession.from(_running(endsAt: endsAt, elapsedSec: 400))!;

      expect(stage0.meltStage, 0);
      expect(stage1.meltStage, 1);
      expect(stage1.differsMateriallyFrom(stage0), isTrue);
    });

    test('so is a freeze, and so is the end moving after one', () {
      final endsAt = DateTime.now().add(const Duration(minutes: 20));
      final running = AmbientSession.from(_running(endsAt: endsAt))!;
      final frozen = AmbientSession.from(
        _running(
          endsAt: endsAt,
          status: FocusStatus.paused,
          frozenAt: DateTime.now(),
        ),
      )!;
      expect(frozen.differsMateriallyFrom(running), isTrue);

      // Resuming pushes the end out; every surface must re-anchor its clock.
      final resumed = AmbientSession.from(
        _running(endsAt: endsAt.add(const Duration(minutes: 2))),
      )!;
      expect(resumed.differsMateriallyFrom(running), isTrue);
    });

    test('having nothing on screen yet always counts', () {
      expect(
        AmbientSession.from(_running())!.differsMateriallyFrom(null),
        isTrue,
      );
    });
  });

  group('crossing the boundary', () {
    test('a session survives the round trip', () {
      final original = AmbientSession.from(
        _running(elapsedSec: 400),
        taskTitle: 'Ch. 4 problem set',
        subjectLabel: 'Linear Algebra',
        subjectTint: '#6b5cf0',
        prismMode: 'Deep Work',
      )!;

      final revived = AmbientSession.fromMap(original.toMap())!;

      expect(revived.endsAt.millisecondsSinceEpoch,
          original.endsAt.millisecondsSinceEpoch);
      expect(revived.frozen, original.frozen);
      expect(revived.meltStage, original.meltStage);
      expect(revived.remainingSec, original.remainingSec);
      expect(revived.taskTitle, original.taskTitle);
      expect(revived.subjectLabel, original.subjectLabel);
      expect(revived.subjectTint, original.subjectTint);
      expect(revived.prismMode, original.prismMode);
    });

    test('the whole payload survives it too', () {
      final original = AmbientState(
        session: AmbientSession.from(_running()),
        nextTaskTitle: 'Ch. 4 problem set',
        nextTaskTime: '14:00',
        nextTaskSubject: 'Linear Algebra',
        nextTaskTint: '#6b5cf0',
        weekDays: const [true, true, false, true, true, false, false],
        todayFocusMin: 42,
      );

      final revived = AmbientState.fromMap(original.toMap());

      expect(revived.session, isNotNull);
      expect(revived.nextTaskTitle, 'Ch. 4 problem set');
      expect(revived.nextTaskTime, '14:00');
      expect(revived.weekDays, original.weekDays);
      expect(revived.todayFocusMin, 42);
    });

    test('an empty payload is readable, not a crash', () {
      // Nothing has ever been written yet — the widgets still have to draw.
      final empty = AmbientState.fromMap(const {});
      expect(empty.session, isNull);
      expect(empty.weekDays, isEmpty);
      expect(empty.todayFocusMin, 0);
    });

    test('a malformed session reads as no session', () {
      expect(AmbientSession.fromMap(const {'frozen': true}), isNull);
      expect(AmbientSession.fromMap(null), isNull);
    });
  });
}
