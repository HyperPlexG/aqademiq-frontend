import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/primary_button.dart';
import 'widgets/onboarding_scaffold.dart';

/// `ob-age-gate`: the under-18 block. Reached from the age screen when the
/// entered age is below 18. There is no way forward — only "Go back" to the
/// age step (pops this route).
class ObBlockedScreen extends StatelessWidget {
  const ObBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OnboardingScaffold(
      activeStep: 0,
      body: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hourglass_empty_rounded,
                  size: 44, color: colors.accent),
            ),
            const SizedBox(height: 28),
            Text(
              "We're not ready\nfor you — yet",
              textAlign: TextAlign.center,
              style:
                  AppText.sans(size: 26, weight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 18),
            Text(
              'Aqademiq is currently only available to students aged 18 and '
              "over. For legal and safety reasons we can't set up an account "
              'for you just yet.',
              textAlign: TextAlign.center,
              style: AppText.sans(size: 13, height: 1.6, color: colors.textMed),
            ),
            const SizedBox(height: 16),
            Text(
              "We're actively working on a safe, age-appropriate experience "
              "for under-18s — hang tight, we'd love to have you soon.",
              textAlign: TextAlign.center,
              style: AppText.sans(size: 13, height: 1.6, color: colors.textMed),
            ),
          ],
        ),
      ),
      footer: PrimaryButton(
        label: 'Go back',
        icon: Icons.arrow_back,
        onPressed: () => context.pop(),
      ),
    );
  }
}
