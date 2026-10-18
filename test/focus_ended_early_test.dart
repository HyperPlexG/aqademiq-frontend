// FOC-4 (16 Oct 2026 test report): two minutes of a five-minute linked
// session, press End, and the task was ticked off as if finished. Only a
// session that runs to its end may complete its task; one ended early asks.
// `endedEarly` is what the timer screen and the end screen both decide on.

import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/models/focus_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planned = FocusSession(id: 's', durationMin: 5);

  test('ending two minutes into five is ending early', () {
    final s = planned.copyWith(status: FocusStatus.completed, elapsedSec: 120);
    expect(s.endedEarly, isTrue);
  });

  test('running to the end is not', () {
    final s = planned.copyWith(status: FocusStatus.completed, elapsedSec: 300);
    expect(s.endedEarly, isFalse);
  });

  test('one second short still counts as early', () {
    final s = planned.copyWith(status: FocusStatus.completed, elapsedSec: 299);
    expect(s.endedEarly, isTrue);
  });

  test('a session still running has not ended at all', () {
    final s = planned.copyWith(status: FocusStatus.running, elapsedSec: 120);
    expect(s.endedEarly, isFalse);
  });
}
