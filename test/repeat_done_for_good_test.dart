// "Ask on tick" for repeating tasks (TestFlight: a tester ticked an "Every day"
// task once, expected it gone, and found it back unticked the next morning).
//
// Ticking a repeating task off asks: done for today (the series carries on) or
// done for good (today is completed and the series ends today). A one-off, or
// an un-tick, asks nothing. Every Plan tick goes through `tickTask`, so these
// drive it directly over the mock source — which has to behave like the
// server: per-day completions, and nothing after a series' until date.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/core/utils/date_format.dart';
import 'package:aqademiq/data/dtos/task_dto.dart';
import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/data/repositories/tasks_repository.dart';
import 'package:aqademiq/data/sources/tasks_source.dart';
import 'package:aqademiq/features/plan/presentation/sheets/repeat_done_sheet.dart';
import 'package:aqademiq/features/plan/presentation/widgets/plan_sheet.dart';
import 'package:aqademiq/features/plan/providers/plan_providers.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:aqademiq/services/reminder_scheduler.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _RecordingHaptics extends NoopHapticsService {
  final moments = <HapticMoment>[];

  @override
  void play(
    HapticMoment moment, {
    int step = 0,
    int count = 1,
    String? mode,
    bool landed = false,
  }) => moments.add(moment);
}

class _QuietScheduler extends ReminderScheduler {
  // The parent names its field `_ref`, which a super parameter cannot match.
  // ignore: matching_super_parameters
  _QuietScheduler(super.ref);

  @override
  Future<void> reconcile({bool force = false}) async {}
}

DateTime _day(DateTime d, [int plus = 0]) =>
    DateTime(d.year, d.month, d.day + plus);

/// The planner's day list with one tap target per task, wired to [tickTask]
/// exactly as the Plan's done circle and overflow "Mark as done" are.
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(dayTasksProvider).value ?? const <Task>[];
    return ListView(
      children: [
        for (final t in tasks)
          TextButton(
            key: ValueKey('tick-${t.id}'),
            onPressed: () => tickTask(context, ref, t),
            child: Text('${t.title} ${t.done ? 'done' : 'open'}'),
          ),
      ],
    );
  }
}

class _World {
  _World(this.repo, this.haptics, this.seriesId);
  final TasksRepository repo;
  final _RecordingHaptics haptics;
  final String seriesId;
}

/// A daily task that started yesterday, so today is one of its later
/// occurrences (`<id>@<today>`) — the shape every repeating task has after day
/// one, and the shape the tester hit.
Future<_World> _pump(WidgetTester tester) async {
  final source = MockTasksSource();
  final today = AppDate.today();
  final created = await tester.runAsync(
    () => source.create(
      TaskDto(
        id: 'series-1',
        title: 'Read 10 pages',
        tagId: '',
        date: _day(today, -1),
        repeat: const RepeatRuleDto(frequency: 'daily'),
      ),
    ),
  );
  final repo = TasksRepository(source);
  final haptics = _RecordingHaptics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tasksRepositoryProvider.overrideWithValue(repo),
        hapticsProvider.overrideWithValue(haptics),
        reminderSchedulerProvider.overrideWith(_QuietScheduler.new),
      ],
      child: MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.light,
          accent: AppAccent.violet,
        ),
        home: const Scaffold(body: _Harness()),
      ),
    ),
  );
  await _settle(tester);
  return _World(repo, haptics, created!.id);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Reads a day straight from the repository (past the mock latency).
Future<List<Task>> _dayOf(
  WidgetTester tester,
  TasksRepository repo,
  DateTime day,
) async => (await tester.runAsync(() => repo.tasksForDay(day)))!;

String _occ(String series, DateTime day) => '$series@${_ymd(day)}';
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Finder _tick(String id) => find.byKey(ValueKey('tick-$id'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final today = AppDate.today();
  final tomorrow = _day(today, 1);

  testWidgets(
    'ticking a repeating task asks first, and plays nothing until the choice',
    (tester) async {
      final w = await _pump(tester);
      await tester.tap(_tick(_occ(w.seriesId, today)));
      await tester.pumpAndSettle();

      expect(find.text('Done for today'), findsOneWidget);
      expect(find.text('Done for good'), findsOneWidget);
      expect(find.text('Repeats · Every day'), findsOneWidget);
      expect(w.haptics.moments, isEmpty);
    },
  );

  testWidgets(
    '"Done for today" completes only today: tomorrow comes back fresh',
    (tester) async {
      final w = await _pump(tester);
      await tester.tap(_tick(_occ(w.seriesId, today)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done for today'));
      await _settle(tester);

      expect(find.text('Done for today'), findsNothing);
      expect(find.text('Read 10 pages done'), findsOneWidget);
      // Exactly one feel for the one tick.
      expect(w.haptics.moments, [HapticMoment.taskChecked]);

      final todayRow = (await _dayOf(
        tester,
        w.repo,
        today,
      )).singleWhere((t) => t.id == _occ(w.seriesId, today));
      expect(todayRow.done, isTrue);
      expect(todayRow.repeat?.untilDate, isNull);

      final next = (await _dayOf(
        tester,
        w.repo,
        tomorrow,
      )).where((t) => t.id == _occ(w.seriesId, tomorrow));
      expect(next, hasLength(1));
      expect(next.single.done, isFalse);
    },
  );

  testWidgets(
    '"Done for good" completes today and sets until = today: nothing tomorrow',
    (tester) async {
      final w = await _pump(tester);
      await tester.tap(_tick(_occ(w.seriesId, today)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done for good'));
      await _settle(tester);

      expect(find.text('Read 10 pages done'), findsOneWidget);
      expect(w.haptics.moments, [HapticMoment.taskChecked]);

      final todayRow = (await _dayOf(
        tester,
        w.repo,
        today,
      )).singleWhere((t) => t.id == _occ(w.seriesId, today));
      expect(todayRow.done, isTrue);
      expect(todayRow.repeat?.untilDate, today);

      for (final later in [tomorrow, _day(today, 2), _day(today, 30)]) {
        final rows = await _dayOf(tester, w.repo, later);
        expect(
          rows.where((t) => t.id.startsWith('${w.seriesId}@')),
          isEmpty,
          reason: 'nothing on $later',
        );
      }
      // History stays: the first day is still there.
      expect(
        (await _dayOf(
          tester,
          w.repo,
          _day(today, -1),
        )).where((t) => t.id == w.seriesId),
        hasLength(1),
      );
    },
  );

  testWidgets('a one-off task ticks straight away, with no question', (
    tester,
  ) async {
    final w = await _pump(tester);
    final oneOff = (await _dayOf(
      tester,
      w.repo,
      today,
    )).firstWhere((t) => t.repeat == null && !t.done);
    await tester.tap(_tick(oneOff.id));
    await _settle(tester);

    expect(find.text('Done for good'), findsNothing);
    expect(w.haptics.moments, hasLength(1));
    expect(
      (await _dayOf(
        tester,
        w.repo,
        today,
      )).singleWhere((t) => t.id == oneOff.id).done,
      isTrue,
    );
  });

  testWidgets('un-ticking a repeating task asks nothing', (tester) async {
    final w = await _pump(tester);
    final id = _occ(w.seriesId, today);
    await tester.tap(_tick(id));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done for today'));
    await _settle(tester);
    w.haptics.moments.clear();

    await tester.tap(_tick(id));
    await _settle(tester);

    expect(find.text('Done for good'), findsNothing);
    expect(find.text('Read 10 pages open'), findsOneWidget);
    expect(w.haptics.moments, [HapticMoment.taskUnchecked]);
  });

  testWidgets('dismissing the question ticks nothing', (tester) async {
    final w = await _pump(tester);
    await tester.tap(_tick(_occ(w.seriesId, today)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PlanDismiss));
    await _settle(tester);

    expect(find.text('Read 10 pages open'), findsOneWidget);
    expect(w.haptics.moments, isEmpty);
  });

  group('mock source (mock == real)', () {
    final anchor = DateTime(2026, 11, 2);

    Future<MockTasksSource> daily() async {
      final s = MockTasksSource();
      await s.create(
        TaskDto(
          id: 's',
          title: 'Habit',
          tagId: '',
          date: anchor,
          repeat: const RepeatRuleDto(frequency: 'daily'),
        ),
      );
      return s;
    }

    TaskDto occ(List<TaskDto> day) =>
        day.singleWhere((t) => t.id.startsWith('s@'));

    test('a ticked day stays ticked, and the next day is fresh', () async {
      final s = await daily();
      final d5 = occ(await s.tasksForDay(DateTime(2026, 11, 5)));
      await s.update(d5.copyWith(done: true));
      expect(occ(await s.tasksForDay(DateTime(2026, 11, 5))).done, isTrue);
      expect(occ(await s.tasksForDay(DateTime(2026, 11, 6))).done, isFalse);
      expect(await s.completedThisWeek(DateTime(2026, 11, 5)), 1);
    });

    test(
      '"for good" from a past day ends the series there but keeps a later ticked day',
      () async {
        final s = await daily();
        final d8 = occ(await s.tasksForDay(DateTime(2026, 11, 8)));
        await s.update(d8.copyWith(done: true));
        final d5 = occ(await s.tasksForDay(DateTime(2026, 11, 5)));
        await s.update(d5.copyWith(done: true), endSeriesOn: d5.date);

        expect(occ(await s.tasksForDay(DateTime(2026, 11, 5))).done, isTrue);
        expect(
          (await s.tasksForDay(
            DateTime(2026, 11, 6),
          )).where((t) => t.id.startsWith('s@')),
          isEmpty,
        );
        // Already ticked before the series was ended: history, so it stays.
        expect(occ(await s.tasksForDay(DateTime(2026, 11, 8))).done, isTrue);
        expect(
          (await s.tasksForDay(
            DateTime(2026, 11, 9),
          )).where((t) => t.id.startsWith('s@')),
          isEmpty,
        );
      },
    );

    test('"for good" on the first day itself ends the series there', () async {
      final s = await daily();
      final first = (await s.tasksForDay(
        anchor,
      )).singleWhere((t) => t.id == 's');
      await s.update(first.copyWith(done: true), endSeriesOn: anchor);
      expect(
        (await s.tasksForDay(anchor)).singleWhere((t) => t.id == 's').done,
        isTrue,
      );
      expect(
        (await s.tasksForDay(
          DateTime(2026, 11, 3),
        )).where((t) => t.id.startsWith('s@')),
        isEmpty,
      );
    });
  });

  group('live source', () {
    late List<RequestOptions> sent;

    ApiTasksSource api(Map<String, dynamic> reply) {
      sent = [];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              sent.add(o);
              h.resolve(
                Response(requestOptions: o, data: reply, statusCode: 200),
              );
            },
          ),
        );
      return ApiTasksSource(dio);
    }

    final task = TaskDto(
      id: 'abc@2026-11-10',
      title: 'Habit',
      tagId: '',
      date: DateTime(2026, 11, 10),
      done: true,
      repeat: const RepeatRuleDto(frequency: 'daily'),
    );

    test('"for good" is one PATCH: completed plus until_date', () async {
      final s = api({
        'id': 'row-1',
        'title': 'Habit',
        'status': 'COMPLETE',
        'repeat': {'kind': 'daily', 'interval': 1, 'until_date': '2026-11-10'},
      });
      final out = await s.update(task, endSeriesOn: DateTime(2026, 11, 10));
      expect(sent.single.method, 'PATCH');
      final body = sent.single.data as Map<String, dynamic>;
      expect(body['status'], 'COMPLETE');
      expect(body['until_date'], '2026-11-10');
      expect(out.repeat?.untilDate, DateTime(2026, 11, 10));
    });

    test('an ordinary save never sends until_date', () async {
      final s = api({
        'id': 'abc@2026-11-10',
        'title': 'Habit',
        'status': 'COMPLETE',
      });
      await s.update(task);
      expect(
        (sent.single.data as Map<String, dynamic>).containsKey('until_date'),
        isFalse,
      );
    });

    test(
      'an older server that sends no until_date (or repeat none) does not break anything',
      () async {
        final s = api({
          'id': 'row-1',
          'title': 'Habit',
          'status': 'COMPLETE',
          'repeat': {'kind': 'daily', 'interval': 1},
        });
        final out = await s.update(task, endSeriesOn: DateTime(2026, 11, 10));
        expect(out.done, isTrue);
        expect(out.repeat?.frequency, 'daily');
        expect(out.repeat?.untilDate, isNull);

        final none = api({
          'id': 'row-1',
          'title': 'Habit',
          'status': 'COMPLETE',
          'repeat': {'kind': 'none'},
        });
        expect(
          (await none.update(task, endSeriesOn: DateTime(2026, 11, 10))).repeat,
          isNull,
        );
      },
    );
  });

  test('only ticking a repeating task needs the question', () {
    final base = Task(
      id: 't',
      title: 'x',
      tagId: '',
      date: DateTime(2026, 11, 10),
    );
    const daily = RepeatRule(frequency: RepeatFrequency.daily);
    expect(tickNeedsChoice(base), isFalse);
    expect(tickNeedsChoice(base.copyWith(repeat: daily)), isTrue);
    expect(tickNeedsChoice(base.copyWith(repeat: daily, done: true)), isFalse);
    expect(
      tickNeedsChoice(
        base.copyWith(
          repeat: const RepeatRule(frequency: RepeatFrequency.none),
        ),
      ),
      isFalse,
    );
  });
}
