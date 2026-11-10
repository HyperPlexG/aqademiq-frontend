import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/onboarding_dots.dart';
import '../../providers/onboarding_steps.dart';

/// Shared onboarding step layout (v11 `Phone bg={WHITE}`, padding 4 22): white
/// page, step dots, a scrollable [body], and a pinned [footer] (the CTA + any
/// skip link).
///
/// The dots are drawn from [onboardingStepsProvider], so they count only the
/// steps this student will see: a skipped step (no subjects → no feelings
/// step) leaves no gap.
///
/// [centerBody] centres a short body in the space above the footer — used by
/// the under-18 block screen — and still scrolls when it doesn't fit.
class OnboardingScaffold extends ConsumerWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.body,
    required this.footer,
    this.centerBody = false,
  });

  /// Which step this screen is, for the progress dots.
  final ObStep step;
  final Widget body;
  final Widget footer;
  final bool centerBody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref.watch(onboardingStepsProvider);
    // A screen reached off the expected path (a skipped step opened anyway)
    // still draws its dots: it slots in at its place in the full order.
    final index = steps.indexOf(step);
    final active = index >= 0 ? index : steps.where((s) => s.index < step.index).length;
    final total = index >= 0 ? steps.length : steps.length + 1;
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingDots(active: active, total: total),
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
