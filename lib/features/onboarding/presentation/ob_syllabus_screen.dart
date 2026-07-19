import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/onboarding_controller.dart';
import 'widgets/onboarding_scaffold.dart';

/// FRAME `ob3` — Step 4 (activeStep 4): upload syllabus / notes / reading list.
/// A dashed dropzone picks files (remembered on the onboarding draft); they're
/// uploaded to the first subject once onboarding completes. Both the CTA and the
/// skip link advance to [Routes.obPeak].
class ObSyllabusScreen extends ConsumerWidget {
  const ObSyllabusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final materials = ref.watch(onboardingProvider).materials;
    final hasFiles = materials.isNotEmpty;

    Future<void> goNext() async {
      await context.push(Routes.obPeak);
    }

    Future<void> pickMaterials() async {
      const typeGroup = XTypeGroup(
        label: 'Documents',
        extensions: <String>['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'md'],
        mimeTypes: <String>['application/pdf', 'text/plain'],
      );
      final files = await openFiles(acceptedTypeGroups: const [typeGroup]);
      if (files.isNotEmpty) {
        ref.read(onboardingProvider.notifier).addMaterials(files);
      }
    }

    return OnboardingScaffold(
      activeStep: 6,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Let Ada plan\nyour week',
            style: AppText.sans(
              size: 26,
              weight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload your syllabus, notes, or reading list',
            style: AppText.sans(size: 12, color: colors.textMed),
          ),
          const SizedBox(height: 14),
          // Dropzone — tap to pick files.
          GestureDetector(
            onTap: () => unawaited(pickMaterials()),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.accent.alpha8(0x66),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                child: Column(
                  children: [
                    Icon(
                      hasFiles ? Icons.check_circle_outline : Icons.arrow_upward,
                      size: 26,
                      color: colors.accent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasFiles
                          ? '${materials.length} file${materials.length == 1 ? '' : 's'} added'
                          : 'Tap to upload',
                      style: AppText.sans(
                        size: 13,
                        weight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasFiles ? 'Tap to add more' : 'PDF or document',
                      style: AppText.sans(size: 11, color: colors.textMed),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasFiles) ...[
            const SizedBox(height: 10),
            for (final file in materials)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file_outlined,
                        size: 16, color: colors.textMed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(size: 12, color: colors.text),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(onboardingProvider.notifier).removeMaterial(file),
                      child: Icon(Icons.close, size: 16, color: colors.textMed),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          // "What Ada does with it" card (no shadow, bg = page bg).
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What Ada does with it',
                    style: AppText.sans(size: 11, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Reads your deadlines → breaks work into sessions → maps '
                    'them across your week. You just show up.',
                    style: AppText.sans(
                      size: 11,
                      color: colors.textMed,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: hasFiles ? 'Continue' : 'Upload materials',
            onPressed: () => unawaited(hasFiles ? goNext() : pickMaterials()),
          ),
          const SizedBox(height: 9),
          GestureDetector(
            onTap: () => unawaited(goNext()),
            child: Text(
              "Skip — I'll add tasks manually →",
              textAlign: TextAlign.center,
              style: AppText.sans(size: 11, color: colors.textMed),
            ),
          ),
        ],
      ),
    );
  }
}
