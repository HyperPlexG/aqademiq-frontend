import 'package:dio/dio.dart';

import '../dtos/task_dto.dart';
import '../fixtures/fixtures.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// Data source for tasks (raw DTOs). Repositories choose the impl via
/// `Env.useMocks`; widgets never see this layer.
abstract interface class TasksSource {
  Future<List<TaskDto>> tasksForDay(DateTime date);

  /// Occurrences from [from] to [to] inclusive (`GET /tasks?from=&to=`). Used
  /// by the local reminder scheduler, which needs a horizon rather than a day.
  Future<List<TaskDto>> tasksInRange(DateTime from, DateTime to);

  Future<TaskDto> create(TaskDto input);
  Future<TaskDto> update(TaskDto task);
  Future<TaskDto> move(String id, DateTime newDate);
  Future<void> delete(String id);

  /// `POST /tasks/{id}/breakdown` — generate micro-steps for the occurrence
  /// (Ada, or a server-side fallback). The steps are attached server-side and
  /// come back on the next `tasksForDay` as the task's subtasks.
  Future<void> breakdown(String id, DateTime date);

  /// `PATCH /tasks/{id}/steps/{stepId}` — tick a micro-step off, or un-tick it.
  ///
  /// `done` is explicit rather than a toggle so a retried request cannot flip
  /// the step back to where it started.
  Future<void> setStepDone(String id, String stepId, {required bool done});

  /// `DELETE /tasks/{id}/steps` — drop the occurrence's micro-steps.
  ///
  /// Backs turning the breakdown toggle off while editing: the switch has to
  /// actually remove the steps, or it reads "off" while the plan still shows
  /// microtasks and the next save appends a second set on top.
  Future<void> clearSteps(String id);

  /// Count of completed tasks in the Mon–Sun week containing [around].
  Future<int> completedThisWeek(DateTime around);
}

class MockTasksSource implements TasksSource {
  final Map<String, List<TaskDto>> _byDay = {
    _key(Fixtures.today): Fixtures.tasksForToday(),
  };

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Future<List<TaskDto>> tasksForDay(DateTime date) {
    final base = List<TaskDto>.from(_byDay[_key(date)] ?? const []);
    // Expand recurring tasks stored on other days that recur onto this date.
    final recurring = <TaskDto>[];
    for (final list in _byDay.values) {
      for (final t in list) {
        if (_occursOn(t, date)) {
          recurring.add(t.copyWith(id: '${t.id}@${_key(date)}', date: _dayOnly(date), done: false));
        }
      }
    }
    return mockDelay(List<TaskDto>.unmodifiable([...base, ...recurring]));
  }

  @override
  Future<List<TaskDto>> tasksInRange(DateTime from, DateTime to) async {
    final out = <TaskDto>[];
    var day = _dayOnly(from);
    final last = _dayOnly(to);
    while (!day.isAfter(last)) {
      out.addAll(await tasksForDay(day));
      // Re-normalise each step: adding 24h across a DST boundary lands at
      // 01:00, and `_key` would then bucket the wrong day.
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return List<TaskDto>.unmodifiable(out);
  }

  /// Whether a recurring [base] task lands on [day] (excluding its own start
  /// day, which is already returned directly). Forward-only from the start.
  static bool _occursOn(TaskDto base, DateTime day) {
    final r = base.repeat;
    if (r == null || r.frequency == 'none') return false;
    final start = _dayOnly(base.date);
    final d = _dayOnly(day);
    if (!d.isAfter(start)) return false;
    final interval = r.interval <= 0 ? 1 : r.interval;
    switch (r.frequency) {
      case 'daily':
        return d.difference(start).inDays % interval == 0;
      case 'weekly':
        final days = r.weekdays.isEmpty ? [start.weekday] : r.weekdays;
        if (!days.contains(d.weekday)) return false;
        final weeks = d.difference(start).inDays ~/ 7;
        return weeks % interval == 0;
      case 'monthly':
        if (d.day != start.day) return false;
        final months = (d.year - start.year) * 12 + (d.month - start.month);
        return months % interval == 0;
      default:
        return false;
    }
  }

  @override
  Future<TaskDto> create(TaskDto input) async {
    final created = input.id.isEmpty
        ? input.copyWith(id: 'task-${DateTime.now().microsecondsSinceEpoch}')
        : input;
    final key = _key(created.date);
    _byDay.update(
      key,
      (list) => [...list, created],
      ifAbsent: () => [created],
    );
    return mockDelay(created);
  }

  @override
  Future<TaskDto> update(TaskDto task) async {
    final key = _key(task.date);
    final list = _byDay[key];
    if (list != null) {
      final i = list.indexWhere((t) => t.id == task.id);
      if (i >= 0) list[i] = task;
    }
    return mockDelay(task);
  }

  @override
  Future<TaskDto> move(String id, DateTime newDate) async {
    TaskDto? found;
    for (final entry in _byDay.entries) {
      final i = entry.value.indexWhere((t) => t.id == id);
      if (i >= 0) {
        found = entry.value.removeAt(i);
        break;
      }
    }
    final moved = (found ?? TaskDto(id: id, title: '', tagId: '', date: newDate))
        .copyWith(date: _dayOnly(newDate));
    _byDay.update(_key(newDate), (list) => [...list, moved], ifAbsent: () => [moved]);
    return mockDelay(moved);
  }

  @override
  Future<void> delete(String id) async {
    for (final entry in _byDay.entries) {
      entry.value.removeWhere((t) => t.id == id);
    }
    return mockDelayVoid();
  }

  @override
  Future<void> setStepDone(String id, String stepId, {required bool done}) {
    for (final entry in _byDay.entries) {
      final i = entry.value.indexWhere((t) => t.id == id);
      if (i >= 0) {
        final t = entry.value[i];
        entry.value[i] = t.copyWith(
          subtasks: [
            for (final s in t.subtasks)
              if (s.id == stepId) s.copyWith(done: done) else s,
          ],
        );
        break;
      }
    }
    return mockDelayVoid();
  }

  @override
  Future<void> clearSteps(String id) {
    for (final entry in _byDay.entries) {
      final i = entry.value.indexWhere((t) => t.id == id);
      if (i >= 0) {
        entry.value[i] = entry.value[i].copyWith(subtasks: const []);
        break;
      }
    }
    return mockDelayVoid();
  }

  @override
  Future<void> breakdown(String id, DateTime date) async {
    for (final list in _byDay.values) {
      final i = list.indexWhere((t) => t.id == id);
      if (i >= 0) {
        final t = list[i];
        if (t.subtasks.isEmpty) {
          list[i] = t.copyWith(subtasks: [
            SubtaskDto(id: '$id-s1', title: 'List what the brief actually asks for'),
            SubtaskDto(id: '$id-s2', title: 'Draft the part you understand best'),
            SubtaskDto(id: '$id-s3', title: 'Fill the gaps and check it against the brief'),
          ]);
        }
        break;
      }
    }
    return mockDelayVoid();
  }

  @override
  Future<int> completedThisWeek(DateTime around) async {
    final monday = _dayOnly(around).subtract(Duration(days: _dayOnly(around).weekday - 1));
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final list = _byDay[_key(monday.add(Duration(days: i)))];
      if (list != null) count += list.where((t) => t.done).length;
    }
    return mockDelay(count);
  }
}

/// Live impl — NestJS `/v1/tasks` occurrence model (contract §12.C).
///
/// The backend has no day-part enum and stores time in `scheduled_at`; a task's
/// study tag rides in the free-form `category` field (so tag coloring
/// round-trips). Occurrence ids are `"{series}@{yyyy-MM-dd}"`.
class ApiTasksSource implements TasksSource {
  ApiTasksSource(this._dio);
  final Dio _dio;

  @override
  Future<List<TaskDto>> tasksForDay(DateTime date) async {
    final body = await _dio.getMap('/tasks', query: {'date': ymd(date)});
    return listOf(body, 'tasks')
        .map((j) => _occToDto(j, fallbackDate: date))
        .toList(growable: false);
  }

  @override
  Future<List<TaskDto>> tasksInRange(DateTime from, DateTime to) async {
    final body = await _dio.getMap(
      '/tasks',
      query: {'from': ymd(from), 'to': ymd(to)},
    );
    // Every occurrence in a range response carries its own date in the id, so
    // the fallback is only a guard against a malformed row.
    return listOf(body, 'tasks')
        .map((j) => _occToDto(j, fallbackDate: from))
        .toList(growable: false);
  }

  @override
  Future<TaskDto> create(TaskDto input) async {
    final body = <String, dynamic>{
      'title': input.title,
      'date': ymd(input.date),
      if (input.tagId.isNotEmpty) 'category': input.tagId,
      if (input.note != null) 'note': input.note,
      if (input.durationMin != null) 'duration_seconds': input.durationMin! * 60,
      if (input.startTime != null) 'scheduled_at': naiveIso(input.startTime!),
      // The bucket persists on its own column now, so Morning/Afternoon/Evening
      // survive without a specific time (no more Anytime fallback).
      'part_of_day': input.timeOfDay ?? 'anytime',
      if (input.repeat != null)
        'repeat': _repeatToWire(input.repeat!)
      else
        'repeat': {'kind': 'none'},
    };
    return _occToDto(await _dio.postMap('/tasks', body), fallbackDate: input.date);
  }

  @override
  Future<TaskDto> update(TaskDto task) async {
    final body = <String, dynamic>{
      'title': task.title,
      'status': task.done ? 'COMPLETE' : 'PENDING',
      if (task.tagId.isNotEmpty) 'category': task.tagId,
      'note': task.note ?? '',
      if (task.durationMin != null) 'duration_seconds': task.durationMin! * 60,
      if (task.startTime != null) 'scheduled_at': naiveIso(task.startTime!),
      'part_of_day': task.timeOfDay ?? 'anytime',
    };
    return _occToDto(await _dio.patchMap('/tasks/${task.id}', body), fallbackDate: task.date);
  }

  @override
  Future<TaskDto> move(String id, DateTime newDate) async {
    final from = dateFromOccurrenceId(id) ?? DateTime.now();
    await _dio.postMap('/tasks/move', {
      'from': ymd(from),
      'to': ymd(newDate),
      'ids': [id],
    });
    // The move endpoint returns a count; the caller ignores the model.
    return TaskDto(
      id: '${seriesIdOf(id)}@${ymd(newDate)}',
      title: '',
      tagId: '',
      date: DateTime(newDate.year, newDate.month, newDate.day),
    );
  }

  @override
  Future<void> delete(String id) => _dio.deleteMap('/tasks/$id');

  @override
  Future<void> breakdown(String id, DateTime date) async {
    await _dio.postMap('/tasks/$id/breakdown', {'date': ymd(date)});
  }

  @override
  Future<void> setStepDone(String id, String stepId, {required bool done}) async {
    await _dio.patchMap('/tasks/$id/steps/$stepId', {'done': done});
  }

  @override
  Future<void> clearSteps(String id) async {
    // The occurrence id already carries the date for a repeating task
    // ("<id>@<yyyy-MM-dd>"), so only that day's steps are removed.
    await _dio.deleteMap('/tasks/$id/steps');
  }

  @override
  Future<int> completedThisWeek(DateTime around) async {
    final body = await _dio.getMap('/tasks/history/completions');
    final monday = mondayOf(around);
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final key = ymd(monday.add(Duration(days: i)));
      final v = body[key];
      if (v is num) count += v.toInt();
    }
    return count;
  }

  // --- wire mapping ---------------------------------------------------------

  TaskDto _occToDto(Map<String, dynamic> j, {DateTime? fallbackDate}) {
    final id = j['id'] as String? ?? '';
    // Prefer the occurrence-id date, then the caller's day (list/create), so
    // API `scheduled_at: "HH:mm"` can be anchored to a real calendar day.
    final rawDate = dateFromOccurrenceId(id) ?? fallbackDate ?? DateTime.now();
    final date = DateTime(rawDate.year, rawDate.month, rawDate.day);
    final scheduledAt = parseDateTime(j['scheduled_at'], onDate: date);
    final durSec = (j['duration_seconds'] as num?)?.toInt();
    final steps = (j['steps'] as List?) ?? const [];
    final repeat = _repeatFromWire(j['repeat']);
    return TaskDto(
      id: id,
      title: j['title'] as String? ?? '',
      tagId: j['category'] as String? ?? '',
      date: date,
      note: (j['note'] as String?)?.isNotEmpty ?? false ? j['note'] as String : null,
      // Time-of-day bucket now round-trips via its own field, so a bucket task
      // (no scheduled_at) still regroups correctly instead of falling to Anytime.
      timeOfDay: j['part_of_day'] as String?,
      startTime: scheduledAt,
      durationMin: durSec == null ? null : (durSec / 60).round(),
      repeat: repeat,
      subtasks: steps.whereType<Map<String, dynamic>>().map((m) {
        return SubtaskDto(
          id: m['id'] as String? ?? '',
          title: m['title'] as String? ?? '',
          done: (m['status'] as String?) == 'COMPLETE',
        );
      }).toList(),
      done: (j['status'] as String?) == 'COMPLETE',
    );
  }

  RepeatRuleDto? _repeatFromWire(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'] as String? ?? 'none';
    if (kind == 'none') return null;
    final interval = (raw['interval'] as num?)?.toInt() ?? 1;
    return RepeatRuleDto(frequency: _kindToFrequency(kind), interval: interval);
  }

  Map<String, dynamic> _repeatToWire(RepeatRuleDto r) => {
        'kind': _frequencyToKind(r.frequency),
        'interval': r.interval,
      };

  // Backend kinds → the client's RepeatFrequency vocabulary.
  String _kindToFrequency(String kind) => switch (kind) {
        'daily' => 'daily',
        'weekly' => 'weekly',
        'monthly' => 'monthly',
        'none' => 'none',
        _ => 'custom', // weekdays / everyNDays / everyNWeeks / everyNMonths
      };

  String _frequencyToKind(String frequency) => switch (frequency) {
        'daily' => 'daily',
        'weekly' => 'weekly',
        'monthly' => 'monthly',
        'custom' => 'everyNDays',
        _ => 'none',
      };
}
