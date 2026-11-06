import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/primary_button.dart';

/// FRAME `guest-save` — save-progress prompt shown after a guest completes a
/// real focus session. A faded session-complete backdrop behind a bottom sheet.
class GuestSavePrompt extends StatelessWidget {
  const GuestSavePrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: const Stack(
        children: [
          Positioned.fill(child: SafeArea(child: _SessionDoneBackdrop())),
          // The session screen it is raised over, dimmed (v11 scrim 0.22).
          Positioned.fill(child: ColoredBox(color: Color(0x38140F1C))),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(top: false, child: _SavePromptSheet()),
          ),
        ],
      ),
    );
  }
}

/// Layer A — faded session-complete backdrop (opacity 0.4, centered column).
class _SessionDoneBackdrop extends StatelessWidget {
  const _SessionDoneBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Opacity(
      opacity: 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const AdaMascot(size: 56),
            ),
            const SizedBox(height: 14),
            Text(
              'Session done',
              textAlign: TextAlign.center,
              style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2, color: colors.text),
            ),
            const SizedBox(height: 4),
            Text(
              'You focused for 25 minutes',
              textAlign: TextAlign.center,
              style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textMed),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layer B — white bottom sheet with the save-progress CTA.
class _SavePromptSheet extends StatelessWidget {
  const _SavePromptSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // v11: floats 8 clear of the sides and bottom, corners concentric with
    // the display (55 − 8 = 47).
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(47),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000), // 0 -8px 40px rgba(0,0,0,0.14)
              blurRadius: 40,
              offset: Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Don't lose this session",
              style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
            ),
            const SizedBox(height: 3),
            Text(
              "You're in guest mode, so this won't be saved. "
              'Create an account to keep your streak & history.',
              style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.55, color: colors.textMed),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Create account & save →',
              onPressed: () => context.go(Routes.signup),
            ),
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Not now',
                    style: AppText.sans(size: 15, color: colors.textMed),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
