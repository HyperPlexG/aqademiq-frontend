import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/models/subject.dart';
import '../../../data/repositories/subjects_repository.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/guest_badge.dart';
import '../../../shared/widgets/guest_nudge_card.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/share_sheet.dart';
import '../providers/subjects_ui_providers.dart';
import 'sheets/add_semester_sheet.dart';
import 'sheets/edit_semesters_sheet.dart';
import 'sheets/sort_subjects_sheet.dart';
import 'sheets/subject_menu.dart';
import 'widgets/subject_bits.dart';
import 'widgets/subject_form_sheet.dart';
import 'widgets/subject_tiles.dart';

/// FRAMES `subj-list` / `guest-subjects` — the Subjects tab.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final guest = ref.watch(isGuestProvider);
    // In the order picked on the Sort sheet — the list and the grid both
    // render from this.
    final subjectsAsync = ref.watch(sortedSubjectsProvider);
    final layout = ref.watch(subjectsLayoutProvider);
    final semesters = ref.watch(semestersProvider).value ?? const <Semester>[];
    final selectedId = ref.watch(selectedSemesterProvider);
    final selectedName = _selectedSemesterName(semesters, selectedId);

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SubjHeader(
            guest: guest,
            onShare: () => unawaited(showShareSheet(context)),
            onMenu: () => unawaited(_menu(context, ref)),
            onAdd: () => unawaited(_addSubject(context)),
          ),
          const SizedBox(height: 10),
          subjectsAsync.when(
            loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
            error: (_, _) => Expanded(child: Center(child: Text('Could not load subjects', style: AppText.sans(size: 15, color: colors.textMed)))),
            data: (subjects) => Expanded(
              child: subjects.isEmpty
                  ? _Empty(guest: guest, onAdd: () => unawaited(_addSubject(context)))
                  : _SubjectCollection(
                      subjects: subjects,
                      layout: layout,
                      semesterName: selectedName,
                      onAddMissingFile: () => _openMissingFile(context, subjects),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// The name of the currently selected semester, falling back to the first.
  String? _selectedSemesterName(List<Semester> semesters, String? selectedId) {
    if (semesters.isEmpty) return null;
    if (selectedId != null) {
      for (final s in semesters) {
        if (s.id == selectedId) return s.name;
      }
    }
    return semesters.first.name;
  }

  /// SUBJ-6: jump to the first subject missing a file so its working "Add file"
  /// affordance is reachable.
  void _openMissingFile(BuildContext context, List<Subject> subjects) {
    final target = subjects.firstWhere(
      (s) => s.fileCount == 0,
      orElse: () => subjects.first,
    );
    unawaited(context.push(Routes.subjectDetail(target.id)));
  }

  Future<void> _addSubject(BuildContext context) async {
    // The controller refreshes the list on save, so we only need to await it.
    await showModalBottomSheet<Subject>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x4C140F1C),
      builder: (_) => const SubjectFormSheet(),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final result = await showSubjectMenu(context);
    if (!context.mounted || result == null) return;
    switch (result) {
      case SubjectMenuResult.addSemester:
        await showAddSemesterSheet(context);
      case SubjectMenuResult.editSemesters:
        await showEditSemestersSheet(context);
      case SubjectMenuResult.sort:
        await showSortSubjectsSheet(context);
    }
  }
}

/// SubjHeader: the Share pill on the left (the logo and Guest badge for a
/// guest), and one white pill holding ··· and + on the right.
class _SubjHeader extends StatelessWidget {
  const _SubjHeader({required this.guest, required this.onShare, required this.onMenu, required this.onAdd});
  final bool guest;
  final VoidCallback onShare;
  final VoidCallback onMenu;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: kSubjHeadButton,
      child: Row(
        children: [
          if (guest) ...[
            Image.asset('assets/images/logo.png', width: 26, height: 26, fit: BoxFit.contain),
            const SizedBox(width: 8),
            const GuestBadge(),
          ] else
            SubjBarPill(icon: 'ios_share', label: 'Share', onTap: onShare),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AppRadius.pill), boxShadow: colors.cardShadow),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeadIcon(icon: 'more', label: 'Semester menu', onTap: onMenu),
                const SizedBox(width: 2),
                _HeadIcon(icon: 'add', label: 'Add subject', onTap: onAdd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One 36 circle inside the header's white pill, with a 24 glyph.
class _HeadIcon extends StatelessWidget {
  const _HeadIcon({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 36,
          child: Center(child: Ic(icon, color: context.colors.text)),
        ),
      ),
    );
  }
}

/// "Subjects" at 34, the count beside it, and the semester on the right — all
/// on one baseline.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.count, this.semesterName});
  final int count;
  final String? semesterName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('Subjects', style: AppText.sans(size: 34, weight: FontWeight.w800, letterSpacing: -0.5, color: colors.text)),
        const SizedBox(width: 7),
        Text('$count', style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.textDim)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            semesterName ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.textMed),
          ),
        ),
      ],
    );
  }
}

class _SubjectCollection extends StatelessWidget {
  const _SubjectCollection({
    required this.subjects,
    required this.layout,
    required this.semesterName,
    required this.onAddMissingFile,
  });
  final List<Subject> subjects;
  final SubjectsLayout layout;
  final String? semesterName;
  final VoidCallback onAddMissingFile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    void open(Subject s) => unawaited(context.push(Routes.subjectDetail(s.id)));
    final missingCount = subjects.where((s) => s.fileCount == 0).length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _TitleRow(count: subjects.length, semesterName: semesterName),
        const SizedBox(height: 12),
        if (missingCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.rowInput)),
            child: Row(
              children: [
                const AdaMascot(size: 24, expr: AdaExpr.focused),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '$missingCount ${missingCount == 1 ? 'subject is' : 'subjects are'} missing a syllabus. Add files so I can plan better.',
                    style: AppText.sans(size: 13, height: 1.4, color: colors.text),
                  ),
                ),
                const SizedBox(width: 9),
                GestureDetector(
                  onTap: onAddMissingFile,
                  behavior: HitTestBehavior.opaque,
                  child: Text('Add →', style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.accent)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (layout == SubjectsLayout.grid)
          SubjectGrid(subjects: subjects, onOpen: open)
        else
          for (final s in subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SubjectRow(subject: s, onTap: () => open(s)),
            ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.guest, required this.onAdd});
  final bool guest;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TitleRow(count: 0),
        const SizedBox(height: 14),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: colors.accentSoft, shape: BoxShape.circle),
                    child: const AdaMascot(size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text('No subjects yet', style: AppText.sans(size: 22, weight: FontWeight.w700, color: colors.text)),
                  const SizedBox(height: 6),
                  Text(
                    "Add the classes you're taking and I'll keep your materials, deadlines and grades in one place.",
                    textAlign: TextAlign.center,
                    style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.55, color: colors.textMed),
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        decoration: BoxDecoration(color: colors.ink, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Ic('add', size: 21, color: Colors.white),
                            const SizedBox(width: 7),
                            Text('Add your first subject', style: AppText.sans(size: 17, weight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (guest) ...[
          const GuestNudgeCard(
            body: 'Set up so I can plan your week & track grades.',
            mascotExpr: AdaExpr.focused,
            mascotSize: 28,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
