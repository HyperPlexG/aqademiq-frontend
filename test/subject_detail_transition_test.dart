// Opening a subject flashed the subject list through the detail page: the
// detail was a bare ListView pushed above the list in the Subjects tab's
// navigator, so for the whole slide (iOS) or zoom (Android) the rows showed
// through the hero's fading gradient and the cards. The page now paints its
// own opaque background, covering the list from the first frame of the push.

import 'dart:async';

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/subject.dart';
import 'package:aqademiq/data/repositories/subjects_repository.dart';
import 'package:aqademiq/data/sources/subjects_source.dart';
import 'package:aqademiq/features/subjects/presentation/subject_detail_screen.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _subject = Subject(id: 's1', name: 'Compilers', color: '#6b5cf0', semesterId: 'sem');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name}: the detail covers the list while it opens',
      variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}),
      (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final theme = buildAppTheme(brightness: brightness, accent: AppAccent.violet);
        final nav = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hapticsProvider.overrideWithValue(const NoopHapticsService()),
              subjectsByIdProvider.overrideWith((ref) async => {_subject.id: _subject}),
              subjectFilesProvider.overrideWith((ref, id) async => const <SubjectFileRef>[]),
            ],
            child: MaterialApp(
              theme: theme,
              // The shell's Scaffold paints the tab background; the tab's own
              // navigator (where the detail is pushed) paints nothing.
              home: Scaffold(
                body: Navigator(
                  key: nav,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => ListView(
                      children: [for (var i = 0; i < 12; i++) ListTile(title: Text('Subject row $i'))],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        unawaited(
          nav.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => const SubjectDetailScreen(id: 's1')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1)); // the subject resolves
        await tester.pump(const Duration(milliseconds: 120)); // mid-transition

        expect(tester.takeException(), isNull);
        expect(find.text('Compilers'), findsWidgets);

        // The detail's root paints an opaque box of the page colour, the full
        // size of the page.
        final detail = find.byType(SubjectDetailScreen);
        final box = find.descendant(of: detail, matching: find.byType(ColoredBox)).first;
        final colored = tester.widget<ColoredBox>(box);
        expect(colored.color.a, 1.0);
        expect(colored.color, theme.extension<AppColors>()!.bg);
        expect(tester.getSize(box), tester.getSize(detail));
        expect(
          find.descendant(of: box, matching: find.byType(ListView)),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
      },
    );
  }
}
