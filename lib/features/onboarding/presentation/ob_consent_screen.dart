import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/launch_external.dart';
import '../../../shared/widgets/primary_button.dart';
import 'widgets/onboarding_scaffold.dart';

/// Onboarding step 1 (`ob-consent`): data-collection consent. "Yes" enables
/// Continue and surfaces the privacy/terms links; "No" disables Continue with a
/// warning. Proceeding (Yes only) advances to the referral step. Consent is a
/// local gate — it is not persisted (UI-only per this change).
class ObConsentScreen extends StatefulWidget {
  const ObConsentScreen({super.key});

  @override
  State<ObConsentScreen> createState() => _ObConsentScreenState();
}

class _ObConsentScreenState extends State<ObConsentScreen> {
  /// null = nothing chosen, true = consented, false = declined.
  bool? _consent;

  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _termsTap;

  @override
  void initState() {
    super.initState();
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => unawaited(
            openExternal(context, Uri.parse('https://aqademiq.com/privacy-policy')),
          );
    _termsTap = TapGestureRecognizer()
      ..onTap = () => unawaited(
            openExternal(context, Uri.parse('https://aqademiq.com/terms-of-use')),
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
            style: AppText.sans(size: 26, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            'To work at its best, Aqademiq collects the info you share — study '
            'details, mood check-ins and focus patterns.',
            style: AppText.sans(size: 12, height: 1.5, color: colors.textMed),
          ),
          const SizedBox(height: 26),
          _ConsentCard(
            title: 'Yes, I consent',
            subtitle: 'Aqademiq can collect and use my info',
            selected: _consent == true,
            onTap: () => setState(() => _consent = true),
          ),
          const SizedBox(height: 12),
          _ConsentCard(
            title: "No, I don't consent",
            subtitle: "You won't be able to use Aqademiq",
            selected: _consent == false,
            onTap: () => setState(() => _consent = false),
          ),
          const SizedBox(height: 20),
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
        onPressed: () => unawaited(context.push(Routes.obReferral)),
      ),
    );
  }
}

/// A single-select consent option (radio-style): purple border + soft fill +
/// filled check when selected; plain grey card + empty ring otherwise.
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : colors.hilite,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            width: 1.5,
            color: selected ? colors.accent : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            _RadioDot(selected: selected),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.sans(
                      size: 15,
                      weight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.sans(size: 12, color: colors.textMed),
                  ),
                ],
              ),
            ),
          ],
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
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: selected
            ? null
            : Border.all(color: colors.textDim, width: 1.6),
      ),
      child: selected
          ? const Icon(Icons.check, size: 15, color: Colors.white)
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
        Icon(Icons.info_outline, size: 17, color: colors.warn),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'We need your consent to continue setting up Aqademiq. You can '
            'change your mind anytime in Settings.',
            style: AppText.sans(size: 12, height: 1.5, color: colors.textMed),
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
    final base = AppText.sans(size: 12, height: 1.5, color: colors.textMed);
    final link = AppText.sans(
      size: 12,
      height: 1.5,
      weight: FontWeight.w700,
      color: colors.accent,
    );
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
