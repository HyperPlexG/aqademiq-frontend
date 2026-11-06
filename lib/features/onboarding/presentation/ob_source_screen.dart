import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/onboarding_repository.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/onboarding_controller.dart';
import 'widgets/onboarding_scaffold.dart';

/// ob-source / ob-source-other — "How did you hear about us?" One pick, or
/// Skip. Other opens an optional "A word or two is plenty." field.
class ObSourceScreen extends ConsumerStatefulWidget {
  const ObSourceScreen({super.key});

  @override
  ConsumerState<ObSourceScreen> createState() => _ObSourceScreenState();
}

class _ObSourceScreenState extends ConsumerState<ObSourceScreen> {
  String? _pick;
  late final TextEditingController _other;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProvider);
    _pick = draft.heardFrom;
    _other = TextEditingController(text: draft.heardFromOther);
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _next({required bool skip}) {
    ref.read(onboardingProvider.notifier).setHeardFrom(skip ? null : _pick, other: _other.text);
    unawaited(context.push(Routes.obName));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OnboardingScaffold(
      activeStep: 3,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How did you hear\nabout us?', style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 4),
          Text(
            'Pick the main one. It helps us reach more students like you.',
            style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.6, color: colors.textMed),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final label in heardFromSlugs.keys)
                ObChip(label: label, active: label == _pick, onTap: () => setState(() => _pick = label)),
            ],
          ),
          if (_pick == 'Other') ...[
            const SizedBox(height: 14),
            TextField(
              controller: _other,
              autofocus: true,
              maxLength: 60,
              cursorColor: colors.accent,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.sans(size: 17, color: colors.text),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: colors.bg,
                counterText: '',
                hintText: 'A podcast',
                hintStyle: AppText.sans(size: 17, color: colors.textDim),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.accent, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Optional. A word or two is plenty.', style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textDim)),
          ],
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(label: 'Continue →', enabled: _pick != null, onPressed: () => _next(skip: false)),
          ObLink(label: 'Skip', onTap: () => _next(skip: true)),
        ],
      ),
    );
  }
}

/// The v11 chip (`Chip`): 36 high, a hairline border, accent-soft when picked.
class ObChip extends StatelessWidget {
  const ObChip({super.key, required this.label, required this.active, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? colors.accentSoft : colors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: active ? colors.accent : colors.border, width: 1.5),
          ),
          // Sized to the label: an aligned Container would take a whole Wrap line.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppText.sans(size: 15, color: active ? colors.accent : colors.textMed),
            ),
          ),
        ),
      ),
    );
  }
}

/// The quiet centred link under an onboarding button (`ObLink`).
class ObLink extends StatelessWidget {
  const ObLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppText.sans(size: 15, color: context.colors.textMed),
        ),
      ),
    );
  }
}
