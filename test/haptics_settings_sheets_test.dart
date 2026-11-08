// Settings (haptics §4, "13 · Settings"): Rate Aqademiq ticks per star and
// latches on submit; Delete account takes a 2-second hold (a ratchet, then a
// knock) instead of a confirm button, and a screen reader can still confirm.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/settings/presentation/sheets/delete_account_dialog.dart';
import 'package:aqademiq/features/settings/presentation/sheets/rate_sheet.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:aqademiq/shared/icons/app_icon.dart';
import 'package:aqademiq/shared/widgets/hold_to_confirm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _RecordingHaptics extends NoopHapticsService {
  final events = <HapticMoment>[];
  final holds = <HapticMoment>[];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      events.add(moment);

  @override
  HapticHold hold(HapticMoment moment) {
    holds.add(moment);
    return super.hold(moment);
  }
}

/// A button that opens [open] and keeps what it returned.
Future<_RecordingHaptics> _pumpOpener(
  WidgetTester tester,
  Future<Object?> Function(BuildContext) open, {
  void Function(Object?)? onResult,
}) async {
  final haptics = _RecordingHaptics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hapticsProvider.overrideWithValue(haptics)],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  final result = await open(context);
                  onResult?.call(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return haptics;
}

/// The [n]th star (1-based) of the rating row.
Finder _star(int n) => find
    .byWidgetPredicate((w) => w is AppIcon && (w.icon == Icons.star || w.icon == Icons.star_outline))
    .at(n - 1);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a star ticks when the rating changes, and submit latches', (tester) async {
    final haptics = await _pumpOpener(tester, showRateSheet);
    expect(find.text('Rate Aqademiq'), findsOneWidget);

    await tester.tap(_star(3));
    await tester.pump();
    expect(haptics.events, [HapticMoment.rateStar]);

    await tester.tap(_star(3));
    await tester.pump();
    expect(haptics.events, [HapticMoment.rateStar], reason: 'the same star again is not a change');

    await tester.tap(_star(5));
    await tester.pump();
    expect(haptics.events, [HapticMoment.rateStar, HapticMoment.rateStar]);

    await tester.tap(find.text('Submit rating'));
    await tester.pump();
    expect(haptics.events.last, HapticMoment.rateSubmit);
    await tester.pumpAndSettle();
  });

  testWidgets('delete account: holding for 2 s ratchets, knocks and confirms', (tester) async {
    Object? result = 'unset';
    final haptics = await _pumpOpener(tester, showDeleteAccountDialog, onResult: (r) => result = r);

    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.text('Delete'), findsNothing, reason: 'the confirm button is gone');
    expect(find.text('Cancel'), findsOneWidget);

    // Let go early: nothing happens.
    final early = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirm)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await early.up();
    await tester.pumpAndSettle();
    expect(haptics.holds, [HapticMoment.deleteAccountHold]);
    expect(haptics.events, isEmpty);
    expect(find.text('Delete account?'), findsOneWidget);

    final hold = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirm)));
    await tester.pump();
    await tester.pump(deleteAccountHoldTime);
    await tester.pump(const Duration(milliseconds: 50));
    await hold.up();
    await tester.pumpAndSettle();
    expect(haptics.holds, [HapticMoment.deleteAccountHold, HapticMoment.deleteAccountHold]);
    expect(haptics.events, [HapticMoment.deleteAccountDone]);
    expect(result, isTrue);
    expect(find.text('Delete account?'), findsNothing);
  });

  testWidgets('delete account: cancel says no, silently', (tester) async {
    Object? result = 'unset';
    final haptics = await _pumpOpener(tester, showDeleteAccountDialog, onResult: (r) => result = r);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(haptics.events, isEmpty);
  });

  testWidgets('delete account: a screen reader activates the hold as a button', (tester) async {
    final semantics = tester.ensureSemantics();
    Object? result = 'unset';
    final haptics = await _pumpOpener(tester, showDeleteAccountDialog, onResult: (r) => result = r);

    tester.semantics.tap(find.semantics.byLabel('Hold to delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(haptics.events, [HapticMoment.deleteAccountDone]);
    semantics.dispose();
  });
}
