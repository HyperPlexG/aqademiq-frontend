import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/presentation/widgets/otp_field.dart';
import '../providers/onboarding_controller.dart';
import 'widgets/onboarding_scaffold.dart';

/// Onboarding step 0 (prototype `ob-referral`): optional referral code entry.
/// The field starts empty; the CTA and the "I don't have one" link both advance
/// to the name step. Typed codes are captured into the onboarding draft so they
/// are submitted on completion.
class ObReferralScreen extends ConsumerWidget {
  const ObReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return OnboardingScaffold(
      activeStep: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Got a referral\ncode?',
            style: AppText.sans(size: 26, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Referral code'),
          OtpField(
            length: 5,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              const _UpperCaseTextFormatter(),
            ],
            onChanged: (v) =>
                ref.read(onboardingProvider.notifier).setReferral(v),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdaMascot(size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A friend invited you? Pop in their code and you both '
                    'earn Aqademiq Pro perks.',
                    style: AppText.sans(
                      size: 11,
                      height: 1.6,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: 'Continue →',
            onPressed: () => unawaited(context.push(Routes.obName)),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () {
                // No code: discard any partial entry so it isn't submitted.
                ref.read(onboardingProvider.notifier).setReferral('');
                unawaited(context.push(Routes.obName));
              },
              child: Text(
                "I don't have one",
                style: AppText.sans(
                  size: 11.5,
                  color: colors.textMed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercases referral input so the stored and displayed code matches the
/// canonical format (e.g. `ADA42`), regardless of the soft keyboard's shift
/// state.
class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
