import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/onboarding_controller.dart';
import 'widgets/onboarding_scaffold.dart';

/// Onboarding step 0 (`ob-age`): the age gate. Aqademiq is 18+. Entering a
/// valid age enables Continue; under-18 routes to the block screen, 18+ to the
/// consent step. The age is persisted to the onboarding draft so it can be
/// submitted with `POST /onboarding/complete`
/// (`ONBOARDING_CONSENT_AGE_INTEGRATION.md`).
class ObAgeScreen extends ConsumerStatefulWidget {
  const ObAgeScreen({super.key});

  @override
  ConsumerState<ObAgeScreen> createState() => _ObAgeScreenState();
}

class _ObAgeScreenState extends ConsumerState<ObAgeScreen> {
  final _controller = TextEditingController();

  int? get _age => int.tryParse(_controller.text);
  bool get _valid => (_age ?? 0) > 0 && (_age ?? 0) <= 120;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final age = _age;
    if (age == null || !_valid) return;
    // Persist the collected age; the server re-checks the ≥18 rule on submit.
    ref.read(onboardingProvider.notifier).setAge(age);
    unawaited(
      context.push(age < 18 ? Routes.obBlocked : Routes.obConsent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OnboardingScaffold(
      activeStep: 0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How old\nare you?',
            style: AppText.sans(size: 26, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            'Ada tunes pacing and check-ins to your age',
            style: AppText.sans(size: 12, color: colors.textMed),
          ),
          const SizedBox(height: 40),
          // Large centered numeric field (prototype ob-age).
          Center(
            child: SizedBox(
              width: 150,
              child: TextField(
                controller: _controller,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                cursorColor: colors.accent,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _continue(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                style: AppText.sans(
                  size: 34,
                  weight: FontWeight.w800,
                  color: colors.text,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: colors.bg,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Only used to tailor your experience',
            textAlign: TextAlign.center,
            style: AppText.sans(size: 11, color: colors.textDim),
          ),
        ],
      ),
      footer: PrimaryButton(
        label: 'Continue →',
        enabled: _valid,
        onPressed: _continue,
      ),
    );
  }
}
