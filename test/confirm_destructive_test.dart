// TSK-5 and the semester delete (16 Oct 2026 test report) removed things the
// instant Delete was tapped. Both now go through confirmDestructive, which must
// answer yes only to an explicit confirm.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/shared/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool?> run(WidgetTester tester, Future<void> Function() act) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                answer = await confirmDestructive(
                  context,
                  title: 'Delete task?',
                  message: '"Read chapter 4" will be removed from your plan.',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Keep it',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('"Read chapter 4" will be removed from your plan.'), findsOneWidget);
    await act();
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('confirming answers yes', (tester) async {
    expect(await run(tester, () => tester.tap(find.text('Delete'))), isTrue);
  });

  testWidgets('cancelling answers no', (tester) async {
    expect(await run(tester, () => tester.tap(find.text('Keep it'))), isFalse);
  });

  testWidgets('closing the dialog answers no', (tester) async {
    expect(await run(tester, () => tester.tap(find.text('✕'))), isFalse);
  });
}
