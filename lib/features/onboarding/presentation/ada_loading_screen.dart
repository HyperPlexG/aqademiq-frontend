import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/onboarding_repository.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/onboarding_controller.dart';

/// Onboarding step 7 (prototype `adaload`): the automatic loading/transition
/// screen shown while Ada builds the first plan. It has no step Dots and no
/// CTA — after a short delay it finishes onboarding and enters the app.
///
/// If completion is rejected (age/consent 403, validation 400, auth 401 — see
/// `ONBOARDING_CONSENT_AGE_INTEGRATION.md` §4) it routes/keeps the user on the
/// right step instead of silently entering the app.
class AdaLoadingScreen extends ConsumerStatefulWidget {
  const AdaLoadingScreen({super.key});

  @override
  ConsumerState<AdaLoadingScreen> createState() => _AdaLoadingScreenState();
}

class _AdaLoadingScreenState extends ConsumerState<AdaLoadingScreen> {
  Timer? _timer;

  /// A non-null message switches this screen from the loading animation to a
  /// recoverable error state (validation / auth / network — the age & consent
  /// rejections navigate away instead).
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), _finish);
  }

  Future<void> _finish() async {
    try {
      await ref.read(onboardingProvider.notifier).finish();
      if (mounted) context.go(Routes.plan);
    } on AgeRestrictedException {
      // Under 18 — the server refused; send the user to the block screen.
      if (mounted) context.go(Routes.obBlocked);
    } on ConsentRequiredException {
      // Consent missing — back to the consent step to grant it.
      if (mounted) context.go(Routes.obConsent);
    } on OnboardingAuthException catch (e) {
      // Session died mid-onboarding — re-authenticate.
      if (mounted) {
        context.go(Routes.welcome);
        _snack(e.message);
      }
    } on OnboardingCompletionException catch (e) {
      // Validation (400) / network / unknown — recoverable in place.
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _retry() {
    setState(() => _error = null);
    unawaited(_finish());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _error == null
                ? const _Building()
                : _CompletionError(message: _error!, onRetry: _retry),
          ),
        ),
      ),
    );
  }
}

/// The default loading animation: Ada + the plan-building checklist.
class _Building extends StatelessWidget {
  const _Building();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    const checklist = <(bool, String)>[
      (true, 'Reading your materials'),
      (true, 'Mapping your deadlines'),
      (false, 'Building your week'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdaMascot(size: 76, expr: AdaExpr.focused),
        const SizedBox(height: 18),
        Text(
          "Ada's getting ready",
          textAlign: TextAlign.center,
          style: AppText.sans(size: 20, weight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Building your first plan...',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 12, color: colors.textMed),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (done, label) in checklist) ...[
                _ChecklistRow(done: done, label: label),
                if (label != checklist.last.$2) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Recoverable completion failure (validation / network): sad Ada, the server's
/// message, and a retry.
class _CompletionError extends StatelessWidget {
  const _CompletionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdaMascot(size: 76, expr: AdaExpr.sad),
        const SizedBox(height: 18),
        Text(
          "Ada couldn't finish setup",
          textAlign: TextAlign.center,
          style: AppText.sans(size: 20, weight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.sans(size: 13, height: 1.5, color: colors.textMed),
        ),
        const SizedBox(height: 26),
        PrimaryButton(label: 'Try again', onPressed: onRetry),
      ],
    );
  }
}

/// One checklist row: a 22px status circle (filled accent + white check when
/// done, else an outlined circle holding a tiny spinner) and its label.
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? colors.accent : Colors.transparent,
            border: done
                ? null
                : Border.all(color: colors.textDim, width: 1.5),
          ),
          child: done
              ? const Icon(Icons.check, size: 10, color: Colors.white)
              : SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppText.sans(
              size: 12,
              weight: done ? FontWeight.w400 : FontWeight.w700,
              color: done ? colors.textDim : colors.text,
            ).copyWith(
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}
