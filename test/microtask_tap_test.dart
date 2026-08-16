// Micro-steps have to be tickable.
//
// They were not. The expanded card wrapped its ENTIRE body in a
// GestureDetector(onTap: onCollapse), and the step rows carried no handler at
// all — so every tap aimed at a step bubbled up to the card and closed it. From
// the outside that read as "the breakdown closes when I try to use it", which is
// exactly how it was reported.
//
// Both halves are asserted here, because fixing only one still leaves the
// feature broken: a step that toggles but also collapses the card is no better.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/features/plan/presentation/widgets/plan_task_expanded_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _task = Task(
  id: 'task-1',
  title: 'getting LoIs signed',
  tagId: '',
  date: DateTime(2026, 8, 16),
  subtasks: const [
    Subtask(id: 's1', title: 'Review and finalize LoI details'),
    Subtask(id: 's2', title: 'Send LoIs to owners', done: true),
    Subtask(id: 's3', title: 'Verify executed signatures'),
  ],
);

Future<({List<String> toggled, List<String> collapses})> _pump(WidgetTester tester) async {
  final toggled = <String>[];
  final collapses = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PlanTaskExpandedCard(
            task: _task,
            onCollapse: () => collapses.add('x'),
            onToggleStep: (s) => toggled.add(s.id),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (toggled: toggled, collapses: collapses);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('every step is rendered', (tester) async {
    await _pump(tester);
    expect(find.text('Review and finalize LoI details'), findsOneWidget);
    expect(find.text('Send LoIs to owners'), findsOneWidget);
    expect(find.text('Verify executed signatures'), findsOneWidget);
  });

  testWidgets('tapping a step toggles it and does NOT collapse the card', (tester) async {
    final r = await _pump(tester);

    await tester.tap(find.text('Review and finalize LoI details'));
    await tester.pump();

    expect(r.toggled, ['s1']);
    expect(
      r.collapses,
      isEmpty,
      reason: 'the card-wide collapse gesture must not swallow step taps',
    );
  });

  testWidgets('an already-done step can be un-ticked', (tester) async {
    final r = await _pump(tester);
    await tester.tap(find.text('Send LoIs to owners'));
    await tester.pump();
    expect(r.toggled, ['s2']);
    expect(r.collapses, isEmpty);
  });

  testWidgets('the header still collapses', (tester) async {
    // The other half of the fix: moving the gesture off the body must not take
    // the only way to close the card with it.
    final r = await _pump(tester);
    await tester.tap(find.text('getting LoIs signed'));
    await tester.pump();
    expect(r.collapses, hasLength(1));
    expect(r.toggled, isEmpty);
  });

  testWidgets('progress counts the done steps', (tester) async {
    await _pump(tester);
    expect(find.text('1/3'), findsOneWidget);
  });
}
