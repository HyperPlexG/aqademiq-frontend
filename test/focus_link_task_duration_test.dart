import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/features/focus/presentation/timer_screen.dart';
import 'package:aqademiq/features/plan/providers/plan_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Serves a fixed day-task list so the Link-a-task sheet lists a known task.
class _FixedDayTasks extends DayTasksController {
  _FixedDayTasks(this._tasks);
  final List<Task> _tasks;

  @override
  Future<List<Task>> build() async => _tasks;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('linking a 5-minute task sets the timer to 5 minutes', (tester) async {
    final task = Task(
      id: 't1',
      title: 'Travis shot',
      tagId: 'tag',
      date: DateTime.now(),
      durationMin: 5,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayTasksProvider.overrideWith(() => _FixedDayTasks([task])),
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
          home: const Scaffold(body: TimerScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 950));

    // Starts at the default 25:00.
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('05:00'), findsNothing);

    // Open the Link-a-task sheet via the task chip.
    await tester.tap(find.text('Focus session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Link task'), findsOneWidget);

    // The first task is pre-selected; confirm the link.
    await tester.tap(find.text('Link task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The session adopts the task's 5-minute duration.
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('25:00'), findsNothing);
  });
}
