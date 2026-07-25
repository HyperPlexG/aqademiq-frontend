import 'package:aqademiq/data/repositories/subjects_repository.dart';
import 'package:aqademiq/data/sources/subjects_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the file id passed to deleteFile so the delegation can be asserted.
class _RecordingSource extends MockSubjectsSource {
  String? deletedId;

  @override
  Future<void> deleteFile(String fileId) async {
    deletedId = fileId;
  }
}

void main() {
  group('SubjectsRepository.deleteFile', () {
    // Materials had no delete path before; this guards the plumbing that a
    // swipe / delete button now relies on.
    test('delegates the file id to the source', () async {
      final source = _RecordingSource();
      final repo = SubjectsRepository(source);

      await repo.deleteFile('file-123');

      expect(source.deletedId, 'file-123');
    });
  });
}
