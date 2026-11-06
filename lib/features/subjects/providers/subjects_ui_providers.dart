import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/subject.dart';
import '../../../data/repositories/subjects_repository.dart';

/// Subjects list layout (prototype `subjectsLayout` tweak — List default, Grid
/// via the Appearance tweak in Settings).
enum SubjectsLayout { list, grid }

final subjectsLayoutProvider =
    NotifierProvider<SubjectsLayoutController, SubjectsLayout>(SubjectsLayoutController.new);

class SubjectsLayoutController extends Notifier<SubjectsLayout> {
  @override
  SubjectsLayout build() => SubjectsLayout.list;

  void set(SubjectsLayout layout) => state = layout;

  void toggle() => state = state == SubjectsLayout.list ? SubjectsLayout.grid : SubjectsLayout.list;
}

/// The orderings the "Sort subjects" sheet offers (v11 `subj-sort`), in the
/// sheet's order. [manual] is the order the subjects arrive in.
enum SubjectSortKey { manual, alphabetical, grade, credits, mood }

/// The chosen ordering plus the sheet's "Reverse order" toggle.
@immutable
class SubjectSort {
  const SubjectSort({this.key = SubjectSortKey.manual, this.reverse = false});

  final SubjectSortKey key;
  final bool reverse;

  SubjectSort copyWith({SubjectSortKey? key, bool? reverse}) =>
      SubjectSort(key: key ?? this.key, reverse: reverse ?? this.reverse);

  @override
  bool operator ==(Object other) =>
      other is SubjectSort && other.key == key && other.reverse == reverse;

  @override
  int get hashCode => Object.hash(key, reverse);
}

/// How the Subjects tab orders its list and grid. Device-local, like the
/// haptics level: kept in SharedPreferences, never sent to the backend.
final subjectSortProvider =
    NotifierProvider<SubjectSortController, SubjectSort>(SubjectSortController.new);

class SubjectSortController extends Notifier<SubjectSort> {
  static const _kKey = 'subjects_sort';
  static const _kReverse = 'subjects_sort_reverse';

  /// Set once the student picks something, so a late restore can't undo it.
  bool _chosen = false;

  /// Starts on the default and restores the saved choice straight after,
  /// rather than needing an `init()` in `main`. SharedPreferences is already
  /// warm by then (other settings load it before the first frame), so the
  /// restore lands a frame later at most.
  @override
  SubjectSort build() {
    unawaited(_restore());
    return const SubjectSort();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_chosen || !ref.mounted) return;
      final key = SubjectSortKey.values.asNameMap()[prefs.getString(_kKey)];
      state = SubjectSort(
        key: key ?? SubjectSortKey.manual,
        reverse: prefs.getBool(_kReverse) ?? false,
      );
    } on Object {
      // No store to read (a test without a mock one): stay on the default.
    }
  }

  void setKey(SubjectSortKey key) => _choose(state.copyWith(key: key));

  void setReverse({required bool reverse}) =>
      _choose(state.copyWith(reverse: reverse));

  void _choose(SubjectSort next) {
    _chosen = true;
    state = next;
    unawaited(_persist(next));
  }

  Future<void> _persist(SubjectSort sort) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, sort.key.name);
      await prefs.setBool(_kReverse, sort.reverse);
    } on Object {
      // Best-effort: the order still applies for the rest of this run.
    }
  }
}

/// The Subjects tab's subjects in the chosen order — what the list and the
/// grid both render. Loading and error pass through as they were.
final sortedSubjectsProvider = Provider<AsyncValue<List<Subject>>>((ref) {
  final sort = ref.watch(subjectSortProvider);
  return ref.watch(subjectsProvider).when<AsyncValue<List<Subject>>>(
        data: (subjects) => AsyncData(sortSubjects(subjects, sort)),
        loading: () => const AsyncLoading(),
        error: AsyncError<List<Subject>>.new,
      );
});

/// [subjects] in [sort] order. Grade, credits and mood put the highest first
/// (Reverse puts the lowest first); subjects without that value always go
/// last. Ties, and the alphabetical order itself, go by name (then id, so the
/// order never depends on how the list arrived).
List<Subject> sortSubjects(List<Subject> subjects, SubjectSort sort) {
  if (sort.key == SubjectSortKey.manual) {
    return sort.reverse ? subjects.reversed.toList() : List.of(subjects);
  }

  int byName(Subject a, Subject b) {
    final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  num? valueOf(Subject s) => switch (sort.key) {
        SubjectSortKey.grade => subjectTargetScore(s),
        SubjectSortKey.credits => s.credits,
        SubjectSortKey.mood => s.mood,
        SubjectSortKey.manual || SubjectSortKey.alphabetical => null,
      };

  final sorted = List.of(subjects);
  if (sort.key == SubjectSortKey.alphabetical) {
    return sorted..sort((a, b) => sort.reverse ? byName(b, a) : byName(a, b));
  }
  return sorted
    ..sort((a, b) {
      final va = valueOf(a);
      final vb = valueOf(b);
      if (va == null || vb == null) {
        if (va == null && vb == null) return byName(a, b);
        return va == null ? 1 : -1;
      }
      final c = sort.reverse ? va.compareTo(vb) : vb.compareTo(va);
      return c != 0 ? c : byName(a, b);
    });
}

/// A subject's target grade on one 0–100 scale, so letters, GPAs and
/// percentages sort together; null when it has none. `target_grade` is one
/// free-form string (a letter, a GPA or `n%`, as the subject form writes it);
/// a GPA is read on the 4.0 scale.
double? subjectTargetScore(Subject subject) {
  final raw = subject.targetGrade?.trim() ?? '';
  if (raw.isNotEmpty) {
    if (raw.endsWith('%')) {
      return double.tryParse(raw.substring(0, raw.length - 1).trim());
    }
    final letter = _letterScores[raw.replaceAll('−', '-').replaceAll('–', '-').toUpperCase()];
    if (letter != null) return letter;
    final gpa = double.tryParse(raw);
    if (gpa != null) return gpa / 4 * 100;
  }
  final target = subject.target;
  if (target == null) return null;
  return target.kind == SubjectTargetKind.percent ? target.value : target.value / 4 * 100;
}

const Map<String, double> _letterScores = {
  'A+': 97,
  'A': 93,
  'A-': 90,
  'B+': 87,
  'B': 83,
  'B-': 80,
  'C+': 77,
  'C': 73,
  'C-': 70,
  'D+': 67,
  'D': 63,
  'D-': 60,
  'E': 50,
  'F': 50,
};
