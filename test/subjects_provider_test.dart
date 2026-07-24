import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:aqademiq/data/models/subject.dart';
import 'package:aqademiq/data/repositories/subjects_repository.dart';
import 'package:aqademiq/data/sources/subjects_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository whose `all()` returns a fixed list, so the test controls exactly
/// what the backend would hand back.
class _FakeSubjectsRepo extends SubjectsRepository {
  _FakeSubjectsRepo(this._result) : super(MockSubjectsSource());
  final List<Subject> _result;
  int allCalls = 0;

  @override
  Future<List<Subject>> all() async {
    allCalls++;
    return _result;
  }
}

const _subject = Subject(
  id: 'c1',
  name: 'Engineering',
  color: '#6b5cf0',
  semesterId: 's1',
);

ProviderContainer _container(_FakeSubjectsRepo repo, {required bool guest}) {
  return ProviderContainer(
    overrides: [
      isGuestProvider.overrideWithValue(guest),
      subjectsRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  group('subjectsProvider', () {
    // The reported bug: a guest completes onboarding, the backend creates their
    // subjects, but the list showed nothing. The provider must fetch for a
    // non-guest (a real account, and — in live builds — an onboarded guest).
    test('a non-guest fetches subjects from the repository', () async {
      final repo = _FakeSubjectsRepo([_subject]);
      final container = _container(repo, guest: false);
      addTearDown(container.dispose);

      final subjects = await container.read(subjectsProvider.future);

      expect(subjects.map((s) => s.name), ['Engineering']);
      expect(repo.allCalls, 1, reason: 'the backend list must be fetched');
    });

    // Env.useMocks is a compile-time constant and is true under `flutter test`,
    // so this asserts the preserved mock-demo behaviour: a fresh demo guest
    // shows nothing until onboarding links them to an account. (The live-guest
    // branch — always fetch — cannot be exercised here because the const can't
    // be flipped at runtime; it is covered by device testing.)
    test('a mock-mode guest short-circuits to an empty list', () async {
      final repo = _FakeSubjectsRepo([_subject]);
      final container = _container(repo, guest: true);
      addTearDown(container.dispose);

      final subjects = await container.read(subjectsProvider.future);

      expect(subjects, isEmpty);
      expect(repo.allCalls, 0, reason: 'the demo guest must not hit the backend');
    });
  });
}
