import 'package:dio/dio.dart';

import '../dtos/subject_dto.dart';
import '../fixtures/fixtures.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

abstract interface class SubjectsSource {
  Future<List<SubjectDto>> all();
  Future<List<SemesterDto>> semesters();
  Future<SubjectDto> upsert(SubjectDto subject);
  Future<void> delete(String id);
  Future<SemesterDto> upsertSemester(SemesterDto semester);
  Future<void> deleteSemester(String id);
}

class MockSubjectsSource implements SubjectsSource {
  final List<SubjectDto> _subjects = [...Fixtures.subjects];
  final List<SemesterDto> _semesters = [...Fixtures.semesters];

  @override
  Future<List<SubjectDto>> all() =>
      mockDelay(List<SubjectDto>.unmodifiable(_subjects));

  @override
  Future<List<SemesterDto>> semesters() =>
      mockDelay(List<SemesterDto>.unmodifiable(_semesters));

  @override
  Future<SubjectDto> upsert(SubjectDto subject) async {
    final created = subject.id.isEmpty
        ? subject.copyWith(id: 'subj-${DateTime.now().microsecondsSinceEpoch}')
        : subject;
    final i = _subjects.indexWhere((s) => s.id == created.id);
    if (i >= 0) {
      _subjects[i] = created;
    } else {
      _subjects.add(created);
    }
    return mockDelay(created);
  }

  @override
  Future<void> delete(String id) async {
    _subjects.removeWhere((s) => s.id == id);
    return mockDelayVoid();
  }

  @override
  Future<SemesterDto> upsertSemester(SemesterDto semester) async {
    final created = semester.id.isEmpty
        ? semester.copyWith(id: 'sem-${DateTime.now().microsecondsSinceEpoch}')
        : semester;
    final i = _semesters.indexWhere((s) => s.id == created.id);
    if (i >= 0) {
      _semesters[i] = created;
    } else {
      _semesters.add(created);
    }
    return mockDelay(created);
  }

  @override
  Future<void> deleteSemester(String id) async {
    _semesters.removeWhere((s) => s.id == id);
    return mockDelayVoid();
  }
}

/// Live impl — `/v1/subjects` + `/v1/semesters` (contract §12.D, §12.E).
class ApiSubjectsSource implements SubjectsSource {
  ApiSubjectsSource(this._dio);
  final Dio _dio;

  @override
  Future<List<SubjectDto>> all() async {
    final body = await _dio.getMap('/subjects');
    return listOf(body, 'subjects').map(_subjToDto).toList(growable: false);
  }

  @override
  Future<List<SemesterDto>> semesters() async {
    final body = await _dio.getMap('/semesters');
    return listOf(body, 'semesters').map(_semToDto).toList(growable: false);
  }

  @override
  Future<SubjectDto> upsert(SubjectDto subject) async {
    final body = <String, dynamic>{
      'name': subject.name,
      'color_hex': subject.color,
      if (subject.semesterId.isNotEmpty) 'semester_id': subject.semesterId,
      if (subject.code != null) 'code': subject.code,
      if (subject.credits != null) 'credits': subject.credits,
      if (subject.professor != null) 'prof': subject.professor,
      if (subject.targetGrade != null) 'target_grade': subject.targetGrade,
      if (subject.mood != null) 'mood': subject.mood,
    };
    final json = subject.id.isEmpty
        ? await _dio.postMap('/subjects', body)
        : await _dio.patchMap('/subjects/${subject.id}', body);
    return _subjToDto(json);
  }

  @override
  Future<void> delete(String id) => _dio.deleteMap('/subjects/$id');

  @override
  Future<SemesterDto> upsertSemester(SemesterDto semester) async {
    if (semester.id.isEmpty) {
      final now = DateTime.now();
      final json = await _dio.postMap('/semesters', {
        'name': semester.name,
        'start': ymd(now),
        'end': ymd(now.add(const Duration(days: 180))),
      });
      return _semToDto(json);
    }
    return _semToDto(
      await _dio.patchMap('/semesters/${semester.id}', {'name': semester.name}),
    );
  }

  @override
  Future<void> deleteSemester(String id) => _dio.deleteMap('/semesters/$id');

  SubjectDto _subjToDto(Map<String, dynamic> j) => SubjectDto(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        color: j['color_hex'] as String? ?? '#6b5cf0',
        semesterId: j['semester_id'] as String? ?? '',
        code: j['code'] as String?,
        targetGrade: j['target_grade'] as String?,
        professor: j['prof'] as String?,
        credits: (j['credits'] as num?)?.toInt(),
        mood: (j['mood'] as num?)?.toInt(),
        nextLabel: j['next_label'] as String?,
        fileCount: (j['files_count'] as num?)?.toInt() ?? 0,
      );

  SemesterDto _semToDto(Map<String, dynamic> j) => SemesterDto(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
      );
}
