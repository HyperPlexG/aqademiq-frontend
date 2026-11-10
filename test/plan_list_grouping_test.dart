// Plan "···" → Grouping options → List used to blank the planner. Every
// grouping must draw, with tasks and without, in light and in dark.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/core/utils/date_format.dart';
import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/models/tag.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/data/repositories/tags_repository.dart';
import 'package:aqademiq/features/plan/presentation/plan_screen.dart';
import 'package:aqademiq/features/plan/providers/plan_providers.dart';
import 'package:aqademiq/features/plan/providers/plan_ui_providers.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FixedTasks extends DayTasksController {
  _FixedTasks(this.tasks);
  final List<Task> tasks;

  @override
  Future<List<Task>> build() async => tasks;
}

List<Task> _someTasks() {
  final today = AppDate.today();
  return [
    Task(id: 'a', title: 'Read chapter 4', tagId: '', date: today, dayPart: DayPart.anytime),
    Task(id: 'm', title: 'Morning flashcards', tagId: '', date: today, dayPart: DayPart.morning),
    Task(
      id: 'p',
      title: 'Lab report',
      tagId: '',
      date: today,
      startTime: DateTime(today.year, today.month, today.day, 14),
      durationMin: 60,
    ),
  ];
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<Task> tasks,
  required Brightness brightness,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsProvider.overrideWithValue(const NoopHapticsService()),
        dayTasksProvider.overrideWith(() => _FixedTasks(tasks)),
        tagsByIdProvider.overrideWithValue(const <String, Tag>{}),
        isGuestProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        theme: buildAppTheme(brightness: brightness, accent: AppAccent.violet),
        home: const Scaffold(body: PlanScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PlanScreen)));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final brightness in Brightness.values) {
    group('${brightness.name} mode', () {
      for (final mode in PlanViewMode.values) {
        testWidgets('${mode.name} grouping draws a day with tasks', (tester) async {
          final container = await _pump(tester, tasks: _someTasks(), brightness: brightness);
          container.read(planViewModeProvider.notifier).set(mode);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Read chapter 4'), findsOneWidget);
          expect(find.text('Morning flashcards'), findsOneWidget);
          expect(find.text('Lab report'), findsOneWidget);
        });

        testWidgets('${mode.name} grouping draws an empty day', (tester) async {
          final container = await _pump(tester, tasks: const [], brightness: brightness);
          container.read(planViewModeProvider.notifier).set(mode);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // Never a blank planner: there is always a way to add a task.
          expect(find.textContaining('Add a'), findsWidgets);
          if (mode == PlanViewMode.list) {
            for (final head in ['ANYTIME (0)', 'MORNING (0)', 'AFTERNOON (0)', 'EVENING (0)']) {
              expect(find.text(head), findsOneWidget);
            }
            expect(find.text('Add a task for the evening'), findsOneWidget);
          }
        });
      }
    });
  }

  for (final withTasks in [true, false]) {
    testWidgets('choosing List from the ··· menu draws the list (${withTasks ? 'tasks' : 'empty day'})',
        (tester) async {
      final container = await _pump(
        tester,
        tasks: withTasks ? _someTasks() : const [],
        brightness: Brightness.light,
      );
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grouping options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(planViewModeProvider), PlanViewMode.list);
      expect(find.textContaining('ANYTIME ('), findsOneWidget);
      if (withTasks) expect(find.text('Lab report'), findsOneWidget);
    });
  }
}
