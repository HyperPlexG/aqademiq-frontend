// The Focus tab: tapping 25:00 is a tap as the picker opens, and the face-down
// watch runs while the screen holds a session (so the completion bloom can go
// desk-safe), not for as long as the tab lives.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/models/focus_session.dart';
import 'package:aqademiq/data/repositories/focus_repository.dart';
import 'package:aqademiq/data/sources/focus_source.dart';
import 'package:aqademiq/features/focus/presentation/timer_screen.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _RecordingHaptics extends NoopHapticsService {
  final events = <HapticMoment>[];
  final faceDown = <bool>[];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      events.add(moment);

  @override
  void watchFaceDown({required bool on}) => faceDown.add(on);
}

class _StubFocusRepo extends FocusRepository {
  _StubFocusRepo() : super(MockFocusSource());

  @override
  Future<FocusSession> start({required int durationMin, String? taskId, String? prismMode}) async =>
      FocusSession(id: '', durationMin: durationMin);
}

Future<(_RecordingHaptics, ProviderContainer)> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final haptics = _RecordingHaptics();
  final container = ProviderContainer(
    overrides: [
      hapticsProvider.overrideWithValue(haptics),
      focusRepositoryProvider.overrideWithValue(_StubFocusRepo()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: const Scaffold(body: TimerScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 950));
  return (haptics, container);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('tapping the time opens the picker with a tap', (tester) async {
    final (haptics, _) = await _pump(tester);
    expect(haptics.events, isEmpty);

    await tester.tap(find.text('25:00'));
    expect(haptics.events, [HapticMoment.setTimeOpen]);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('face down is watched while a session is held, and stops after', (tester) async {
    final (haptics, container) = await _pump(tester);
    expect(haptics.faceDown, isEmpty, reason: 'idle: no sensor');

    final focus = container.read(focusControllerProvider.notifier);
    await focus.start();
    await tester.pump();
    expect(haptics.faceDown, [true]);

    focus.pause();
    await tester.pump();
    expect(haptics.faceDown, [true], reason: 'still a session');

    focus.reset();
    await tester.pump();
    expect(haptics.faceDown, [true, false]);

    await focus.start();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(haptics.faceDown, [true, false, true, false], reason: 'off when the screen goes');
    focus.reset();
  });
}
