import 'package:dio/dio.dart';

import '../dtos/subject_dto.dart';
import '../fixtures/fixtures.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// A stored material for a subject, for the detail screen's Materials list.
typedef SubjectFileRef = ({String id, String name, String sizeLabel, String kind});

abstract interface class SubjectsSource {
  Future<List<SubjectDto>> all();
  Future<List<SemesterDto>> semesters();
  Future<SubjectDto> upsert(SubjectDto subject);
  Future<void> delete(String id);
  Future<SemesterDto> upsertSemester(
    SemesterDto semester, {
    DateTime? start,
    DateTime? end,
  });
  Future<void> deleteSemester(String id);

  /// Uploads a material for [subjectId] and returns the created file id. The
  /// live impl runs the presign → PUT → commit handshake; the mock impl fakes
  /// it locally (bumping the subject's file count).
  Future<String> uploadFile({
    required String subjectId,
    required String name,
    required String kind,
    String? mimeType,
    required List<int> bytes,
  });

  /// The stored materials for [subjectId] (from `GET /subjects/{id}`).
  Future<List<SubjectFileRef>> files(String subjectId);

  /// A short-lived signed URL to open/download the material [fileId].
  Future<String> fileDownloadUrl(String fileId);
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
  Future<SemesterDto> upsertSemester(
    SemesterDto semester, {
    DateTime? start,
    DateTime? end,
  }) async {
    // The Semester model only carries id + name, so start/end aren't stored in
    // mock mode — they exist to drive the live API's date range.
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

  @override
  Future<String> uploadFile({
    required String subjectId,
    required String name,
    required String kind,
    String? mimeType,
    required List<int> bytes,
  }) async {
    // No real storage in mock mode: bump the subject's file count so the
    // materials header updates end-to-end.
    final i = _subjects.indexWhere((s) => s.id == subjectId);
    if (i >= 0) {
      _subjects[i] = _subjects[i].copyWith(
        fileCount: _subjects[i].fileCount + 1,
      );
    }
    return mockDelay('file-${DateTime.now().microsecondsSinceEpoch}');
  }

  @override
  Future<List<SubjectFileRef>> files(String subjectId) => mockDelay(const [
        (id: 'f1', name: 'Syllabus.pdf', sizeLabel: '2.4 MB', kind: 'syllabus'),
        (id: 'f2', name: 'Lecture 1.pdf', sizeLabel: '1.1 MB', kind: 'slides'),
      ]);

  @override
  Future<String> fileDownloadUrl(String fileId) =>
      mockDelay('https://example.com/$fileId.pdf');
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
  Future<SemesterDto> upsertSemester(
    SemesterDto semester, {
    DateTime? start,
    DateTime? end,
  }) async {
    if (semester.id.isEmpty) {
      final now = DateTime.now();
      final startDate = start ?? DateTime(now.year, now.month, now.day);
      final endDate =
          end ?? DateTime(now.year, now.month + 6, now.day);
      final json = await _dio.postMap('/semesters', {
        'name': semester.name,
        'start': ymd(startDate),
        'end': ymd(endDate),
      });
      return _semToDto(json);
    }
    return _semToDto(
      await _dio.patchMap('/semesters/${semester.id}', {'name': semester.name}),
    );
  }

  @override
  Future<void> deleteSemester(String id) => _dio.deleteMap('/semesters/$id');

  @override
  Future<String> uploadFile({
    required String subjectId,
    required String name,
    required String kind,
    String? mimeType,
    required List<int> bytes,
  }) async {
    final contentType = mimeType ?? 'application/octet-stream';

    // Presign → PUT bytes → commit. NOTE: this Dio's baseUrl already carries the
    // `/v1` prefix, so these are relative resource paths ('/uploads/...'), not
    // '/v1/uploads/...'.
    final init = await _dio.postMap('/uploads/init', {
      'subject_id': subjectId,
      'name': name,
      'kind': kind,
      'mime_type': contentType,
      'size_bytes': bytes.length,
    });
    final fileId = init['file_id'] as String;
    final uploadUrl = init['upload_url'] as String;

    // PUT straight to storage with a bare Dio so the signed URL isn't sent the
    // API client's base URL or Authorization header.
    await Dio().put<void>(
      uploadUrl,
      data: Stream<List<int>>.fromIterable([bytes]),
      options: Options(
        headers: <String, dynamic>{
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );

    final commit = await _dio.postMap('/uploads/$fileId/commit');
    return (commit['file_id'] as String?) ?? fileId;
  }

  @override
  Future<List<SubjectFileRef>> files(String subjectId) async {
    final body = await _dio.getMap('/subjects/$subjectId');
    return listOf(body, 'files')
        .map((j) => (
              id: j['id'] as String? ?? '',
              name: j['name'] as String? ?? 'File',
              sizeLabel: j['size_label'] as String? ?? '',
              kind: j['kind'] as String? ?? '',
            ))
        .toList(growable: false);
  }

  @override
  Future<String> fileDownloadUrl(String fileId) async {
    final body = await _dio.getMap('/files/$fileId/download');
    return body['url'] as String? ?? '';
  }

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
