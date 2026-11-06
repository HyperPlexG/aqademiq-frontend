import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/launch_external.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/onboarding_controller.dart';
import 'widgets/onboarding_scaffold.dart';

/// The privacy-policy / terms version this consent screen renders. Sent as
/// `consent_version` for the PDPL audit trail
/// (`ONBOARDING_CONSENT_AGE_INTEGRATION.md` §2). Bump this whenever the policy
/// copy or the linked documents change.
const String consentPolicyVersion = '2026-07-01';

/// Onboarding step 1 (`ob-consent`): data-collection consent. "Yes" enables
/// Continue and surfaces the privacy/terms links; "No" disables Continue with a
/// warning. Proceeding (Yes only) persists consent + [consentPolicyVersion] to
/// the onboarding draft (submitted on completion) and advances to the referral
/// step.
class ObConsentScreen extends ConsumerStatefulWidget {
  const ObConsentScreen({super.key});

  @override
  ConsumerState<ObConsentScreen> createState() => _ObConsentScreenState();
}

class _ObConsentScreenState extends ConsumerState<ObConsentScreen> {
  /// null = nothing chosen, true = consented, false = declined.
  bool? _consent;

  void _continue() {
    if (_consent != true) return;
    ref.read(onboardingProvider.notifier).setConsent(
          given: true,
          version: consentPolicyVersion,
        );
    unawaited(context.push(Routes.obReferral));
  }

  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _termsTap;

  @override
  void initState() {
    super.initState();
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => unawaited(
            openExternal(context, Uri.parse('https://www.aqademiq.com/privacy-policy')),
          );
    _termsTap = TapGestureRecognizer()
      ..onTap = () => unawaited(
            openExternal(context, Uri.parse('https://www.aqademiq.com/terms-of-use')),
          );
  }

  @override
  void dispose() {
    _privacyTap.dispose();
    _termsTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OnboardingScaffold(
      activeStep: 1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Do we have\nyour consent?',
            style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            'To work at its best, Aqademiq collects the info you share: study '
            'details, mood check-ins and focus patterns.',
            style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.6, color: colors.textMed),
          ),
          const SizedBox(height: 16),
          _ConsentCard(
            title: 'Yes, I consent',
            subtitle: 'Aqademiq can collect and use my info',
            selected: _consent == true,
            onTap: () => setState(() => _consent = true),
          ),
          const SizedBox(height: 8),
          _ConsentCard(
            title: "No, I don't consent",
            subtitle: "You won't be able to use Aqademiq",
            selected: _consent == false,
            onTap: () => setState(() => _consent = false),
          ),
          const SizedBox(height: 16),
          if (_consent == false) _DeclinedWarning(colors: colors),
          if (_consent == true) _TermsLine(
            colors: colors,
            privacyTap: _privacyTap,
            termsTap: _termsTap,
          ),
        ],
      ),
      footer: PrimaryButton(
        label: 'Continue →',
        enabled: _consent == true,
        onPressed: _continue,
      ),
    );
  }
}

/// A single-select consent option (radio-style): a 2px accent border + soft
/// fill + filled check when selected; a plain well + empty ring otherwise.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : colors.bg,
            borderRadius: BorderRadius.circular(AppRadius.rowInput),
            border: Border.all(
              width: 2,
              color: selected ? colors.accent : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              _RadioDot(selected: selected),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.sans(
                        size: 17,
                        weight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textMed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: selected
            ? null
            : Border.all(color: colors.textDim, width: 2),
      ),
      child: selected
          ? const Ic('check', size: 15, color: Colors.white)
          : null,
    );
  }
}

/// Amber warning shown when consent is declined.
class _DeclinedWarning extends StatelessWidget {
  const _DeclinedWarning({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Ic('info', size: 19, color: colors.warn),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'We need your consent to continue setting up Aqademiq. You can '
            'change your mind anytime in Settings.',
            style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.6, color: colors.textMed),
          ),
        ),
      ],
    );
  }
}

/// Terms + privacy line with tappable links, shown when consent is given.
class _TermsLine extends StatelessWidget {
  const _TermsLine({
    required this.colors,
    required this.privacyTap,
    required this.termsTap,
  });

  final AppColors colors;
  final TapGestureRecognizer privacyTap;
  final TapGestureRecognizer termsTap;

  @override
  Widget build(BuildContext context) {
    final base = AppText.sans(size: 15, weight: FontWeight.w500, height: 1.7, color: colors.textMed);
    final link = AppText.sans(
      size: 15,
      height: 1.7,
      weight: FontWeight.w700,
      color: colors.accent,
    ).copyWith(decoration: TextDecoration.underline, decorationColor: colors.accent);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'aqademiq.com/privacy-policy',
            style: link,
            recognizer: privacyTap,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'aqademiq.com/terms-of-use',
            style: link,
            recognizer: termsTap,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
