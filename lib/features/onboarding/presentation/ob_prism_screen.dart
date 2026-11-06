import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../focus/providers/prism_audio_provider.dart';
import '../../settings/providers/prism_settings_provider.dart';
import '../providers/onboarding_controller.dart';
import 'widgets/onboarding_scaffold.dart';

/// Onboarding step 6 (prototype `ob5`): introduces Prism focus audio and lets
/// the user pick a default mode. Tapping a mode previews its soundscape live;
/// leaving the screen (CTA or system back) stops the preview.
class ObPrismScreen extends ConsumerStatefulWidget {
  const ObPrismScreen({super.key});

  @override
  ConsumerState<ObPrismScreen> createState() => _ObPrismScreenState();
}

class _ObPrismScreenState extends ConsumerState<ObPrismScreen> {
  @override
  void initState() {
    super.initState();
    // Default selection is already "Deep Work" in the draft, but preview only
    // started on tap — kick it off as soon as this step is on screen so the
    // mode is audible without an extra press.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mode = ref.read(onboardingProvider).prismMode;
      ref.read(prismDefaultModeProvider.notifier).set(mode);
      unawaited(
        ref.read(prismAudioControllerProvider.notifier).previewMode(mode),
      );
    });
  }

  @override
  void deactivate() {
    // Fires on back-pop and stack replacement; the forward push to obLoading
    // keeps this state alive, so that path is covered by the CTA below.
    // Here rather than in dispose(): Riverpod 3 refuses `ref` once the widget
    // is being disposed.
    unawaited(
      ref.read(prismAudioControllerProvider.notifier).stopPreview(),
    );
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = ref.watch(onboardingProvider).prismMode;

    final modes = <_PrismMode>[
      _PrismMode(
        color: colors.accent,
        name: 'Deep Work',
        glyph: 'state_deep_focus',
        desc: 'Low-freq focus carrier. Hard cognitive tasks.',
      ),
      _PrismMode(
        color: colors.success,
        name: 'Flow',
        glyph: 'state_focus',
        desc: 'Smooth ambient. Sustained concentration.',
      ),
      _PrismMode(
        color: colors.warn,
        name: 'Review',
        glyph: 'state_creative',
        desc: 'Steady midtempo. Reading, flashcards, revision.',
      ),
      _PrismMode(
        color: colors.textMed,
        name: 'Wind-down',
        glyph: 'state_relax',
        desc: 'Slow, calming. End-of-session decompression.',
      ),
    ];

    return OnboardingScaffold(
      activeStep: 10,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Meet Prism',
            style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            'Psychoacoustic audio that deepens focus. '
            'Auto-plays in sessions.',
            style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.4, color: colors.textMed),
          ),
          const SizedBox(height: 22),
          const FieldLabel('Prism modes'),
          for (final mode in modes) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              onTap: () {
                ref.read(onboardingProvider.notifier).setPrismMode(mode.name);
                // This pick doubles as the persisted default mode, and the
                // soundscape previews live so the choice is audible.
                ref.read(prismDefaultModeProvider.notifier).set(mode.name);
                unawaited(
                  ref
                      .read(prismAudioControllerProvider.notifier)
                      .previewMode(mode.name),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: mode.color.alpha8(0x18),
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      border: Border.all(
                        color:
                            mode.color.alpha8(selected == mode.name ? 0xFF : 0x44),
                        width: 1.5,
                      ),
                    ),
                    // v11 PrismGlyph: the mode's Tier 3 state mark.
                    child: Ic(mode.glyph, size: 22, color: mode.color),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode.name,
                          style: AppText.sans(size: 17, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          mode.desc,
                          style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.35, color: colors.textMed),
                        ),
                      ],
                    ),
                  ),
                  if (selected == mode.name) ...[
                    const SizedBox(width: 8),
                    Ic('check_circle:fill', size: 21, color: mode.color),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
        ],
      ),
      footer: PrimaryButton(
        label: "Let's go →",
        onPressed: () {
          unawaited(
            ref.read(prismAudioControllerProvider.notifier).stopPreview(),
          );
          unawaited(context.push(Routes.obLoading));
        },
      ),
    );
  }
}

/// One Prism audio mode row (icon color, its state mark + copy).
class _PrismMode {
  const _PrismMode({
    required this.color,
    required this.name,
    required this.glyph,
    required this.desc,
  });

  final Color color;
  final String name;
  final String glyph;
  final String desc;
}
