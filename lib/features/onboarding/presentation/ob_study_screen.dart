import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/subject.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../subjects/presentation/widgets/subject_form_sheet.dart';
import '../providers/onboarding_controller.dart';
import 'widgets/onboarding_scaffold.dart';

/// ob2 — Step 2: what the student studies (level + subjects).
///
/// Level is single-select (`setLevel`); subjects toggle in/out of the draft
/// (`toggleSubject`). The dashed "+ More" chip opens the shared subject form
/// sheet so a custom subject can be added before continuing to ob-mood.
class ObStudyScreen extends ConsumerWidget {
  const ObStudyScreen({super.key});

  static const _levels = ['Undergraduate', 'Postgraduate', 'School', 'Self-taught'];
  static const _subjects = ['Engineering', 'CS', 'Medicine', 'Business', 'Law'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final draft = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);

    return OnboardingScaffold(
      activeStep: 5,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you\nstudying?',
            style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            'Ada shapes your plan around your workload',
            style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textMed),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Level'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final level in _levels)
                _Chip(
                  label: level,
                  active: draft.level == level,
                  onTap: () => controller.setLevel(level),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const FieldLabel('Subjects'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Presets first, then any custom subject the user added via
              // "+ More". Without appending the customs, an added subject went
              // into the draft but had no chip, so it looked like nothing
              // happened.
              for (final subject in [
                ..._subjects,
                for (final s in draft.subjects)
                  if (!_subjects.contains(s)) s,
              ])
                _Chip(
                  label: subject,
                  active: draft.subjects.contains(subject),
                  onTap: () => controller.toggleSubject(subject),
                ),
              _MoreChip(onTap: () => _openAddSubject(context, controller)),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
      footer: PrimaryButton(
        label: 'Continue →',
        onPressed: () => unawaited(context.push(Routes.obMood)),
      ),
    );
  }

  Future<void> _openAddSubject(
    BuildContext context,
    OnboardingController controller,
  ) async {
    final subject = await showModalBottomSheet<Subject>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SubjectFormSheet(),
    );
    final name = subject?.name.trim();
    if (name != null && name.isNotEmpty) {
      controller.toggleSubject(name);
    }
  }
}

/// Onboarding pill chip (v11 `Chip`): 36 high, 15/600. Active = accent
/// border + accent-soft fill + accent text; inactive = hairline border +
/// surface + muted text.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? colors.accentSoft : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: active ? colors.accent : colors.border, width: 1.5),
          ),
          child: _ChipLabel(label: label, color: active ? colors.accent : colors.textMed, padding: 14),
        ),
      ),
    );
  }
}

/// The dashed, accent-tinted "+ More" chip (v11 ob2): 36 high, 15/600.
class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Add another subject',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: _DashedPillBorder(color: colors.accent.alpha8(0x88)),
          child: _ChipLabel(label: '+ More', color: colors.accent, padding: 12),
        ),
      ),
    );
  }
}

/// A chip's label, 36 high and only as wide as its text (a Wrap would let an
/// aligned Container stretch to the full row).
class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label, required this.color, required this.padding});

  final String label;
  final Color color;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Center(
          widthFactor: 1,
          child: Text(label, style: AppText.sans(size: 15, color: color)),
        ),
      ),
    );
  }
}

/// Paints a 1.5px dashed pill outline for the "+ More" chip.
class _DashedPillBorder extends CustomPainter {
  const _DashedPillBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.pill),
    );
    final path = Path()..addRRect(rrect);

    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillBorder oldDelegate) => oldDelegate.color != color;
}
