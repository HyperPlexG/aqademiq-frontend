import 'dart:async';

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/data/repositories/tasks_repository.dart';
import 'package:aqademiq/data/sources/tasks_source.dart';
import 'package:aqademiq/features/plan/presentation/add_task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Counts create() calls and blocks each one on a gate that never opens, so the
/// first save stays "in flight" for the whole test — exactly the window in which
/// a second tap must be ignored.
class _CountingTasksRepo extends TasksRepository {
  _CountingTasksRepo() : super(MockTasksSource());
  int createCalls = 0;
  final _gate = Completer<Task>();

  @override
  Future<Task> create(Task draft) {
    createCalls++;
    return _gate.future; // never completes → save is held in flight
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('tapping Save twice creates the task only once', (tester) async {
    final repo = _CountingTasksRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tasksRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
          home: const AddTaskScreen(),
        ),
      ),
    );
    // Flush the mock-latency timers behind tags/subjects so nothing is left
    // pending at teardown.
    await tester.pump(const Duration(seconds: 1));

    final save = find.text('Save');
    expect(save, findsOneWidget);

    // Two taps with no pump in between: both reach the handler before the widget
    // can rebuild into its disabled/spinner state. The in-flight guard is the
    // only thing standing between the user and a duplicate task.
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();

    expect(
      repo.createCalls,
      1,
      reason: 'the second tap must be ignored while the first save is in flight',
    );

    // After the first save starts, the button swaps to a spinner and the overlay
    // absorbs pointers — so "Save" is gone and further taps cannot land.
    expect(find.text('Save'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Dispose the tree so the spinner's ticker stops; the held create Future is
    // a harmless never-resolving Future (not a timer).
    await tester.pumpWidget(const SizedBox());
  });
}
