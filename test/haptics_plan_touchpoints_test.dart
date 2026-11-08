// Plan and Subjects touchpoints (haptic architecture §4, "02 · Plan, 03 ·
// Subjects, 09 · Swipe actions" plus the wheel pickers and chips there).

import 'dart:async';

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/plan/presentation/pickers/time_picker.dart';
import 'package:aqademiq/features/plan/presentation/widgets/swipe_haptics.dart';
import 'package:aqademiq/features/subjects/presentation/widgets/subject_form_sheet.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:aqademiq/shared/widgets/mood_blob.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

typedef _Played = ({HapticMoment moment, int step, bool landed});

class _RecordingHaptics extends NoopHapticsService {
  final played = <_Played>[];

  List<HapticMoment> get moments => [for (final p in played) p.moment];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      played.add((moment: moment, step: step, landed: landed));
}

Future<_RecordingHaptics> _pump(WidgetTester tester, Widget home) async {
  final haptics = _RecordingHaptics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hapticsProvider.overrideWithValue(haptics)],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: Scaffold(body: home),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return haptics;
}

const _extent = 0.34;

Widget _swipeRow() => Center(
      child: SizedBox(
        width: 400,
        height: 60,
        child: Slidable(
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: _extent,
            children: [
              SlidableAction(onPressed: (_) {}, label: 'Delete'),
            ],
          ),
          child: const SwipeHaptics(
            extentRatio: _extent,
            child: ColoredBox(color: Colors.white, child: SizedBox.expand(child: Text('row'))),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('swipe actions', () {
    testWidgets('tick past the reveal point, unlatch when pulled back', (tester) async {
      final haptics = await _pump(tester, _swipeRow());
      final gesture = await tester.startGesture(tester.getCenter(find.text('row')));

      // Under the reveal point (17% of 400 = 68 px): nothing yet.
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      expect(haptics.moments, isEmpty);

      // Past it: the action arms.
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(haptics.moments, [HapticMoment.swipeArm]);

      // Further out stays armed and silent.
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      expect(haptics.moments, [HapticMoment.swipeArm]);

      // Back under it: unlatch.
      await gesture.moveBy(const Offset(90, 0));
      await tester.pump();
      expect(haptics.moments, [HapticMoment.swipeArm, HapticMoment.swipeBack]);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(haptics.moments, [HapticMoment.swipeArm, HapticMoment.swipeBack]);
    });

    testWidgets('the pane snapping open or shut after release is silent', (tester) async {
      final haptics = await _pump(tester, _swipeRow());

      // Let go past the reveal point: the arm tick came with the finger, and
      // the pane finishing its open on its own adds nothing.
      final gesture = await tester.startGesture(tester.getCenter(find.text('row')));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(-25, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      final controller = Slidable.of(tester.element(find.text('row')))!;
      expect(controller.ratio.abs(), closeTo(_extent, 0.01));
      expect(haptics.moments, [HapticMoment.swipeArm]);

      // Closing it from code is not the finger either.
      unawaited(controller.close());
      await tester.pumpAndSettle();
      expect(haptics.moments, [HapticMoment.swipeArm]);
    });
  });

  group('wheel pickers', () {
    Future<_RecordingHaptics> openTimeDialog(WidgetTester tester) async {
      final haptics = await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showTimeOfDayPicker(context),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Specific time'));
      await tester.pumpAndSettle();
      return haptics;
    }

    testWidgets('one tick per item, then one landing tick at full strength', (tester) async {
      final haptics = await openTimeDialog(tester);
      haptics.played.clear();

      // The hour wheel opens on 2; drag it down two 40 px rows, slowly.
      final gesture = await tester.startGesture(tester.getCenter(find.text('2').first));
      for (var i = 0; i < 16; i++) {
        await gesture.moveBy(const Offset(0, -5));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final steps = haptics.played.where((p) => p.moment == HapticMoment.wheelStep).toList();
      expect(steps.where((p) => !p.landed), hasLength(2), reason: 'per item, not per pixel');
      expect(steps.where((p) => p.landed), hasLength(1));
      expect(steps.last.landed, isTrue, reason: 'the landing comes last');
    });

    testWidgets('AM / PM ticks on a change only', (tester) async {
      final haptics = await openTimeDialog(tester);
      haptics.played.clear();

      await tester.tap(find.text('PM')); // already PM
      await tester.pump();
      expect(haptics.moments, isEmpty);

      await tester.tap(find.text('AM'));
      await tester.pump();
      expect(haptics.moments, [HapticMoment.chipSelect]);
    });
  });

  group('subject form', () {
    testWidgets('segments and chips tick on a change; cubes play their texture', (tester) async {
      final haptics = await _pump(tester, const SingleChildScrollView(child: SubjectFormSheet()));
      haptics.played.clear();

      await tester.tap(find.text('Letter')); // already Letter
      await tester.pump();
      expect(haptics.moments, isEmpty);

      await tester.tap(find.text('GPA'));
      await tester.pump();
      expect(haptics.moments, [HapticMoment.chipSelect]);

      await tester.tap(find.text('%').first);
      await tester.pump();
      await tester.tap(find.text('%').first);
      await tester.pump();
      expect(haptics.moments, [HapticMoment.chipSelect, HapticMoment.chipSelect]);

      // Feelings per subject: a new cube plays its own texture step.
      await tester.tap(find.byType(MoodBlob).at(3));
      await tester.pump();
      expect(haptics.played.last, (moment: HapticMoment.feelingPick, step: 3, landed: false));
    });
  });
}
