import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/primary_button.dart';
import 'widgets/onboarding_scaffold.dart';

/// `ob-age-gate`: the under-18 block. Reached from the age screen when the
/// entered age is below 18, or from the loading screen (via `go`, so there is
/// no stack) when the server refuses. There is no way forward — only "Go back"
/// to the age step (pops this route, or goes to the age step if there is
/// nothing to pop).
class ObBlockedScreen extends StatelessWidget {
  const ObBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OnboardingScaffold(
      activeStep: 0,
      centerBody: true,
      body: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Ic('duration', size: 38, color: colors.accent),
          ),
          const SizedBox(height: 20),
          Text(
            "We're not ready\nfor you just yet",
            textAlign: TextAlign.center,
            style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 10),
          Text(
            'Aqademiq is currently only available to students aged 18 and '
            "over. For legal and safety reasons we can't set up an account "
            'for you just yet.',
            textAlign: TextAlign.center,
            style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.65, color: colors.textMed),
          ),
          const SizedBox(height: 14),
          Text(
            "We're actively working on a safe, age-appropriate experience "
            "for under-18s. Hang tight, we'd love to have you soon. 💜",
            textAlign: TextAlign.center,
            style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.65, color: colors.textMed),
          ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PrimaryButton(
          label: 'Go back',
          icon: Icons.arrow_back,
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.obAge),
        ),
      ),
    );
  }
}
