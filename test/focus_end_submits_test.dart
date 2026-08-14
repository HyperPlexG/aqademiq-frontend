// The focus end screen has to SEND what it collects.
//
// It previously did not. The timer's End button calls complete() with no
// arguments, and this screen only ever called reset() — so the mood the user
// picked was rendered, selected, and thrown away. Nothing failed; the column
// was simply always empty, which is indistinguishable from "nobody answered".
//
// That is the whole class of bug this file guards: a control that looks like it
// records something and does not.

import 'package:aqademiq/core/router/app_router.dart';
import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/focus_session.dart';
import 'package:aqademiq/data/repositories/focus_repository.dart';
import 'package:aqademiq/data/sources/focus_source.dart';
import 'package:aqademiq/features/focus/presentation/focus_end_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _RecordingFocusRepo extends FocusRepository {
  _RecordingFocusRepo() : super(MockFocusSource());

  int? sentMood;
  int? sentRating;
  int completeCalls = 0;

  @override
  Future<FocusSession> start({
    required int durationMin,
    String? taskId,
    String? prismMode,
  }) async =>
      const FocusSession(id: 'fs-1', durationMin: 25);

  @override
  Future<FocusSession> checkpoint(
    String id, {
    required int elapsedSec,
    required bool paused,
  }) async =>
      const FocusSession(id: 'fs-1', durationMin: 25);

  @override
  Future<FocusSession> complete(
    String id, {
    int? mood,
    int? elapsedSec,
    int? rating,
  }) async {
    completeCalls++;
    sentMood = mood;
    sentRating = rating;
    return const FocusSession(id: 'fs-1', durationMin: 25);
  }
}

/// A live session, with the periodic timer stopped so nothing is pending at
/// teardown. `complete()` no-ops unless the session has an id.
Future<ProviderContainer> _liveSession(_RecordingFocusRepo repo) async {
  final container = ProviderContainer(
    overrides: [focusRepositoryProvider.overrideWithValue(repo)],
  );
  await container.read(focusControllerProvider.notifier).start();
  container.read(focusControllerProvider.notifier).pause();
  return container;
}

Future<void> _pumpEnd(WidgetTester tester, ProviderContainer container) async {
  // A real router, because leaving the screen navigates — and the submit runs
  // in the same callback, so a missing router would mask whether it happened.
  final router = GoRouter(
    initialLocation: '/end',
    routes: [
      GoRoute(path: '/end', builder: (_, _) => const FocusEndScreen()),
      GoRoute(path: Routes.plan, builder: (_, _) => const Scaffold(body: SizedBox.shrink())),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('leaving the screen submits the selected mood', (tester) async {
    final repo = _RecordingFocusRepo();
    final container = await _liveSession(repo);
    addTearDown(container.dispose);

    await _pumpEnd(tester, container);
    await tester.tap(find.text('Back to today →'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repo.completeCalls, 1);
    expect(repo.sentMood, isNotNull, reason: 'the mood picker must not be decorative');
  });

  testWidgets('a rating is sent when one is chosen', (tester) async {
    final repo = _RecordingFocusRepo();
    final container = await _liveSession(repo);
    addTearDown(container.dispose);

    await _pumpEnd(tester, container);
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('Back to today →'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repo.sentRating, 4);
  });

  testWidgets('no rating stays null rather than defaulting to a middle score', (tester) async {
    // The analytics read null as "not asked". Defaulting to 3 would invent a
    // neutral answer from every user who skipped the question.
    final repo = _RecordingFocusRepo();
    final container = await _liveSession(repo);
    addTearDown(container.dispose);

    await _pumpEnd(tester, container);
    await tester.tap(find.text('Back to today →'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repo.sentRating, isNull);
  });

  testWidgets('tapping the chosen rating again clears it', (tester) async {
    final repo = _RecordingFocusRepo();
    final container = await _liveSession(repo);
    addTearDown(container.dispose);

    await _pumpEnd(tester, container);
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('Back to today →'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repo.sentRating, isNull);
  });
}
