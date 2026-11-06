import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/onboarding_dots.dart';

/// Shared onboarding step layout (v11 `Phone bg={WHITE}`, padding 4 22): white
/// page, step dots, a scrollable [body], and a pinned [footer] (the CTA + any
/// skip link).
///
/// [centerBody] centres a short body in the space above the footer — used by
/// the under-18 block screen — and still scrolls when it doesn't fit.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.activeStep,
    required this.body,
    required this.footer,
    this.centerBody = false,
  });

  final int activeStep;
  final Widget body;
  final Widget footer;
  final bool centerBody;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingDots(active: activeStep),
              Expanded(
                child: centerBody
                    ? LayoutBuilder(
                        builder: (context, box) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: box.maxHeight),
                            child: Center(child: body),
                          ),
                        ),
                      )
                    : SingleChildScrollView(child: body),
              ),
              const SizedBox(height: 12),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}
