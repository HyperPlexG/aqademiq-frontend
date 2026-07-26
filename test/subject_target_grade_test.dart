import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/subject.dart';
import 'package:aqademiq/data/repositories/subjects_repository.dart';
import 'package:aqademiq/features/subjects/presentation/widgets/subject_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Captures the Subject passed to save() so the encoded target grade can be
/// asserted.
class _CapturingSubjects extends SubjectsController {
  Subject? saved;

  @override
  Future<List<Subject>> build() async => const [];

  @override
  Future<Subject> save(Subject subject) async {
    saved = subject;
    return subject;
  }
}

Finder get _nameField =>
    find.byWidgetPredicate((w) => w is TextField && w.autofocus);
Finder _fieldWithHint(String hint) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<_CapturingSubjects> pumpForm(WidgetTester tester) async {
    final subjects = _CapturingSubjects();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [subjectsProvider.overrideWith(() => subjects)],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
          home: Scaffold(
            body: Builder(
              // Push the sheet so save()'s Navigator.pop returns here instead of
              // popping the only route (which leaves the transition pending).
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: SubjectFormSheet()),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return subjects;
  }

  /// Tap Save and let the save + pop transition and the semesters mock-latency
  /// timer settle (a pump long enough that no Future.delayed stays pending).
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('Subject target grade — GPA / % are editable and saved', () {
    testWidgets('a GPA value can be typed and is saved', (tester) async {
      final subjects = await pumpForm(tester);

      await tester.enterText(_nameField, 'Physics');
      await tester.tap(find.text('GPA'));
      await tester.pump();

      // The GPA field is a real input (was hardcoded static text before).
      expect(_fieldWithHint('3.7'), findsOneWidget);
      await tester.enterText(_fieldWithHint('3.7'), '3.9');

      await save(tester);

      expect(subjects.saved?.targetGrade, '3.9');
    });

    testWidgets('a percentage value is saved with a % suffix', (tester) async {
      final subjects = await pumpForm(tester);

      await tester.enterText(_nameField, 'Chemistry');
      await tester.tap(find.text('%'));
      await tester.pump();

      await tester.enterText(_fieldWithHint('85'), '92');
      await save(tester);

      expect(subjects.saved?.targetGrade, '92%');
    });

    testWidgets('Letter mode still saves the picked grade', (tester) async {
      final subjects = await pumpForm(tester);

      await tester.enterText(_nameField, 'Maths');
      // Letter is the default tab; the default index is 'A'.
      await save(tester);

      expect(subjects.saved?.targetGrade, 'A');
    });
  });
}
