import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/referral_repository.dart';
import '../../../services/deep_link_service.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/presentation/widgets/otp_field.dart';
import '../providers/onboarding_controller.dart';
import 'ob_source_screen.dart' show ObLink;
import 'widgets/onboarding_scaffold.dart';

/// Onboarding step 0 (prototype `ob-referral`): optional referral code entry.
///
/// Continue with a non-empty code validates immediately via
/// `POST /referrals/validate`. Invalid codes stay on this screen with an inline
/// error — they must not reach final setup. Empty Continue / "I don't have one"
/// skips attribution and advances.
class ObReferralScreen extends ConsumerStatefulWidget {
  const ObReferralScreen({super.key});

  @override
  ConsumerState<ObReferralScreen> createState() => _ObReferralScreenState();
}

class _ObReferralScreenState extends ConsumerState<ObReferralScreen> {
  bool _validating = false;
  String? _error;

  /// Seeded from a referral deep link, when the app was opened by one.
  ///
  /// Prefill only — never auto-submitted. A link is attacker-controlled input,
  /// so the code has to be on screen where it can be read and cleared before
  /// it is used. Taken once, so clearing the field does not get undone by the
  /// next rebuild, and only when nothing has been typed yet.
  String _prefill = '';

  @override
  void initState() {
    super.initState();
    final typed = ref.read(onboardingProvider).referral;
    if (typed.isNotEmpty) {
      _prefill = typed;
      return;
    }
    final code = ref.read(deepLinkServiceProvider).takeReferralCode();
    if (code == null) return;
    _prefill = code;
    // Mirrored into the wizard's draft after the first frame. Writing to a
    // provider during initState or build is what Riverpod refuses, and the
    // field itself is seeded from `_prefill` rather than from the draft, so
    // nothing on screen is waiting for this.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(onboardingProvider.notifier).setReferral(code);
    });
  }

  Future<void> _continueWithCode() async {
    if (_validating) return;
    final code = ref.read(onboardingProvider).referral.trim();

    // No code typed → same as skip (attribution optional).
    if (code.isEmpty) {
      setState(() => _error = null);
      if (mounted) unawaited(context.push(Routes.obSource));
      return;
    }

    // All codes are exactly 8 chars; a partial entry can only be a typo, so
    // catch it here instead of a round-trip that returns "invalid".
    if (code.length < 8) {
      setState(() => _error = 'Enter the full referral code, or skip.');
      return;
    }

    setState(() {
      _validating = true;
      _error = null;
    });

    try {
      await ref.read(referralRepositoryProvider).validateCode(code);
      if (!mounted) return;
      unawaited(context.push(Routes.obSource));
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on Object {
      if (!mounted) return;
      setState(() => _error = "Couldn't check that code. Try again.");
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  void _skip() {
    // No code: discard any partial entry so it isn't submitted at finish.
    ref.read(onboardingProvider.notifier).setReferral('');
    setState(() => _error = null);
    unawaited(context.push(Routes.obSource));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OnboardingScaffold(
      activeStep: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Got a referral\ncode?',
            style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Referral code'),
          OtpField(
            initial: _prefill,
            // Codes are 8 chars — the backend generates them as
            // randomBytes(4).hex (see referrals.service.ts). The field was
            // capped at 5, so the full code could never be entered.
            length: 8,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            // v11 ob-referral: 4 + 4, tighter and smaller than the 6-digit code.
            gap: 5,
            groupAfter: 4,
            cellRadius: 11,
            fontSize: 20,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              const _UpperCaseTextFormatter(),
            ],
            onChanged: (v) {
              ref.read(onboardingProvider.notifier).setReferral(v);
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.danger),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      size: 15,
                      weight: FontWeight.w500,
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
            label: _validating ? 'Checking…' : 'Continue →',
            enabled: !_validating,
            onPressed: _validating ? null : () => unawaited(_continueWithCode()),
          ),
          ObLink(label: "I don't have one", onTap: _validating ? null : _skip),
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
