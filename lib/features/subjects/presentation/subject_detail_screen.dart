import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_mood.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/hex_color.dart';
import '../../../core/utils/launch_external.dart';
import '../../../data/models/subject.dart';
import '../../../data/repositories/subjects_repository.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/mood_blob.dart';
import 'sheets/add_file_sheet.dart';
import 'widgets/subject_bits.dart';
import 'widgets/subject_form_sheet.dart';

/// FRAMES `subj-detail` — subject hero + stats + materials.
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({super.key, required this.id});
  final String id;

  /// Icon (a design name) + accent for a material, chosen from its file
  /// extension.
  static (String, Color) _fileVisual(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return ('picture_as_pdf', const Color(0xFFE85476));
    if (n.endsWith('.ppt') || n.endsWith('.pptx')) {
      return ('slideshow', const Color(0xFFE8A430));
    }
    if (n.endsWith('.doc') || n.endsWith('.docx')) {
      return ('description', const Color(0xFF5C7CFF));
    }
    if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg')) {
      return ('file', const Color(0xFF2A9D6B));
    }
    if (n.endsWith('.md') || n.endsWith('.txt')) {
      return ('note', const Color(0xFF5CBBFF));
    }
    return ('file', const Color(0xFF7A8699));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final byId = ref.watch(subjectsByIdProvider).value ?? const <String, Subject>{};
    final subject = byId[id];
    if (subject == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: Center(child: Text('Subject not found', style: AppText.sans(size: 15, color: colors.textMed))),
      );
    }
    final color = hexColor(subject.color);
    final filesAsync = ref.watch(subjectFilesProvider(subject.id));
    final files = filesAsync.value;
    final mood = (subject.mood ?? 2).clamp(0, 4);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Hero(
          subject: subject,
          color: color,
          onBack: () => context.pop(),
          onEdit: () => unawaited(_editSubject(context, ref, subject)),
          onDelete: () => unawaited(_deleteSubject(context, ref, subject)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      child: Row(
                        children: [
                          MoodBlob(idx: subject.mood ?? 2, size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('You feel', style: AppText.sans(size: 12, weight: FontWeight.w700, color: colors.textDim)),
                                Text(
                                  MoodScale.labels[mood],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.sans(size: 15, weight: FontWeight.w800, color: AppMood.ramp[mood]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      child: Row(
                        children: [
                          Ic('focus', size: 20, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('This week', style: AppText.sans(size: 12, weight: FontWeight.w700, color: colors.textDim)),
                                Text(
                                  '${subject.focusHours ?? 0}h focus',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SubjLabel('Materials (${files?.length ?? subject.fileCount})', bottom: 0)),
                  GestureDetector(
                    onTap: () => unawaited(
                      showAddFileSheet(context, subjectId: subject.id, subjectName: subject.name, subjectColor: color),
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Ic('add', size: 16, color: colors.accent),
                          const SizedBox(width: 2),
                          Text('Add file', style: AppText.sans(size: 13, weight: FontWeight.w800, color: colors.accent)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              ...filesAsync.when(
                data: (list) => list.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No materials yet — add your syllabus or notes.',
                            style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                          ),
                        ),
                      ]
                    : [
                        for (final f in list) ...[
                          Builder(
                            builder: (_) {
                              final (icon, fileColor) = _fileVisual(f.name);
                              return _FileRow(
                                key: ValueKey(f.id),
                                icon: icon,
                                name: f.name,
                                size: f.sizeLabel,
                                color: fileColor,
                                onTap: () => unawaited(_openFile(context, ref, f.id)),
                                onDelete: () => unawaited(
                                  _deleteFile(context, ref, subject.id, f.id, f.name),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                loading: () => [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  ),
                ],
                error: (_, _) => [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Couldn't load materials.",
                      style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Opens the shared subject form pre-filled for editing. The controller
  /// refreshes the detail (via `subjectsByIdProvider`) on save.
  Future<void> _editSubject(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) async {
    await showModalBottomSheet<Subject>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x4C140F1C),
      builder: (_) => SubjectFormSheet(existing: subject),
    );
  }

  /// Fetch a short-lived signed URL for [fileId] and open it in the browser /
  /// the OS document viewer.
  Future<void> _openFile(BuildContext context, WidgetRef ref, String fileId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref.read(subjectsRepositoryProvider).fileDownloadUrl(fileId);
      if (url.isEmpty) throw Exception('empty url');
      if (!context.mounted) return;
      await openExternal(context, Uri.parse(url));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open this file.")),
      );
    }
  }

  static const _keepsHistory = 'Its tasks stay on your plan without a subject, '
      'and past focus sessions and Ada chats keep their history.';

  /// SUB-6: the API and `SubjectsController.remove` both existed; nothing on
  /// screen called them. Confirms first and says what really happens, because
  /// the two kinds of attached data part ways: files are deleted with the
  /// subject, tasks keep going without one.
  Future<void> _deleteSubject(BuildContext context, WidgetRef ref, Subject subject) async {
    // The list on this screen when it has loaded: the subject's own count can
    // lag behind it, and the warning has to name what will really go.
    final files = ref.read(subjectFilesProvider(subject.id)).value?.length ?? subject.fileCount;
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${subject.name}?',
      message: [
        if (files > 0)
          '${files == 1 ? 'Its file' : 'All $files of its files'} will be deleted for good.',
        _keepsHistory,
      ].join(' '),
      confirmLabel: 'Delete subject',
      cancelLabel: 'Keep it',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Leave first: once the list refreshes this screen has no subject to show,
    // and would flash "Subject not found" on its way out.
    context.pop();
    try {
      await ref.read(subjectsProvider.notifier).remove(subject.id);
      messenger.showSnackBar(SnackBar(content: Text('Deleted ${subject.name}.')));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete this subject. Try again.")),
      );
    }
  }

  /// Confirm, then delete the material and refresh the list + subject file count.
  Future<void> _deleteFile(
    BuildContext context,
    WidgetRef ref,
    String subjectId,
    String fileId,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // Taken before the first await: the screen can be left while the alert or
    // the delete is up, and `ref` is unusable once it has gone.
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete $name?',
      message: 'This file will be deleted for good.',
      confirmLabel: 'Delete file',
    );
    if (!confirmed) return;

    try {
      await container.read(subjectsRepositoryProvider).deleteFile(fileId);
      // Refresh the materials list and the subject's file-count badge.
      container
        ..invalidate(subjectFilesProvider(subjectId))
        ..invalidate(subjectsProvider);
      messenger.showSnackBar(SnackBar(content: Text('Deleted "$name".')));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete this file. Try again.")),
      );
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.subject,
    required this.color,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
  });
  final Subject subject;
  final Color color;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final eyebrow = [
      if (subject.code != null) subject.code,
      if (subject.credits != null) '${subject.credits} CREDITS',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.69), color.withValues(alpha: 0.33)],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SubjBarCircle(icon: 'arrow_back', fill: SubjFill.glass, onTap: onBack, semanticLabel: 'Back'),
              const Spacer(),
              SubjBarCircle(icon: 'delete', fill: SubjFill.glass, onTap: onDelete, semanticLabel: 'Delete subject'),
              const SizedBox(width: 8),
              SubjBarPill(icon: 'edit', label: 'Edit', fill: SubjFill.glass, onTap: onEdit),
            ],
          ),
          const SizedBox(height: 12),
          if (eyebrow.isNotEmpty) ...[
            Text(
              eyebrow.toUpperCase(),
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w800,
                letterSpacing: AppText.em(0.06, 12),
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(subject.name, style: AppText.sans(size: 28, weight: FontWeight.w800, height: 1.15, color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (subject.professor != null && subject.professor!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Ic('profile', size: 18, color: Colors.white.withValues(alpha: 0.92)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subject.professor!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(size: 15, color: Colors.white.withValues(alpha: 0.92)),
                      ),
                    ),
                  ],
                ),
              if (subject.targetGrade != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(7)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Ic('goal', size: 14, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('Target ${subject.targetGrade}', style: AppText.sans(size: 13, weight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AppRadius.rowInput), boxShadow: colors.cardShadow),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: child,
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.icon,
    required this.name,
    required this.size,
    required this.color,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  /// A design icon name.
  final String icon;
  final String name;
  final String size;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Swipe left to reveal Delete (matches the Plan task rows), with the ⋮ as a
    // tap-to-delete affordance for discoverability — there was no way to remove
    // a material before.
    return Slidable(
      key: ValueKey('file-$name'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFE85476),
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12), boxShadow: colors.cardShadow),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.alpha8(0x18), borderRadius: BorderRadius.circular(9)),
                child: Ic(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.text)),
                    Text(size, style: AppText.sans(size: 12, color: colors.textDim)),
                  ],
                ),
              ),
              // Explicit delete affordance next to swipe-to-delete, so the
              // action is discoverable without knowing to swipe.
              Semantics(
                button: true,
                label: 'Delete file',
                excludeSemantics: true,
                onTap: onDelete,
                child: GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Ic('delete', size: 18, color: colors.textDim),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
