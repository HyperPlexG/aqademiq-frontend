import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/hex_color.dart';
import '../../../core/utils/launch_external.dart';
import '../../../data/models/subject.dart';
import '../../../data/repositories/subjects_repository.dart';
import '../../../shared/widgets/mood_blob.dart';
import 'sheets/add_file_sheet.dart';
import 'widgets/subject_form_sheet.dart';

/// FRAMES `subj-detail` — subject hero + stats + materials.
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({super.key, required this.id});
  final String id;

  /// Icon + accent for a material, chosen from its file extension.
  static (IconData, Color) _fileVisual(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return (Icons.picture_as_pdf, const Color(0xFFE85476));
    if (n.endsWith('.ppt') || n.endsWith('.pptx')) {
      return (Icons.slideshow, const Color(0xFFE8A430));
    }
    if (n.endsWith('.doc') || n.endsWith('.docx')) {
      return (Icons.article, const Color(0xFF5C7CFF));
    }
    if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg')) {
      return (Icons.image, const Color(0xFF2A9D6B));
    }
    if (n.endsWith('.md') || n.endsWith('.txt')) {
      return (Icons.description, const Color(0xFF5CBBFF));
    }
    return (Icons.insert_drive_file, const Color(0xFF7A8699));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final byId = ref.watch(subjectsByIdProvider).value ?? const <String, Subject>{};
    final subject = byId[id];
    if (subject == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: Center(child: Text('Subject not found', style: AppText.sans(size: 13, color: colors.textMed))),
      );
    }
    final color = hexColor(subject.color);
    final filesAsync = ref.watch(subjectFilesProvider(subject.id));
    final files = filesAsync.value;

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Hero(
          subject: subject,
          color: color,
          onBack: () => context.pop(),
          onEdit: () => _editSubject(context, ref, subject),
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
                                Text('You feel', style: AppText.sans(size: 9, weight: FontWeight.w700, color: colors.textDim)),
                                Text(MoodScale.labels[(subject.mood ?? 2).clamp(0, 4)], style: AppText.sans(size: 11, weight: FontWeight.w800, color: colors.text)),
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
                          Icon(Icons.timer, size: 20, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('This week', style: AppText.sans(size: 9, weight: FontWeight.w700, color: colors.textDim)),
                                Text('${subject.focusHours ?? 0}h focus', style: AppText.sans(size: 11, weight: FontWeight.w800, color: colors.text)),
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
                  Text('MATERIALS (${files?.length ?? subject.fileCount})', style: AppText.sans(size: 9, weight: FontWeight.w800, letterSpacing: AppText.em(0.12, 9), color: colors.textDim)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => showAddFileSheet(context, subjectId: subject.id, subjectName: subject.name, subjectColor: color),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 13, color: colors.accent),
                        const SizedBox(width: 2),
                        Text('Add file', style: AppText.sans(size: 10.5, weight: FontWeight.w800, color: colors.accent)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ...filesAsync.when(
                data: (list) => list.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No materials yet — add your syllabus or notes.',
                            style: AppText.sans(size: 11.5, color: colors.textMed),
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
                                onTap: () => _openFile(context, ref, f.id),
                                onDelete: () =>
                                    _deleteFile(context, ref, subject.id, f.id, f.name),
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
                      style: AppText.sans(size: 11.5, color: colors.textMed),
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

  /// Confirm, then delete the material and refresh the list + subject file count.
  Future<void> _deleteFile(
    BuildContext context,
    WidgetRef ref,
    String subjectId,
    String fileId,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('"$name" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE85476)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(subjectsRepositoryProvider).deleteFile(fileId);
      // Refresh the materials list and the subject's file-count badge.
      ref
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
  });
  final Subject subject;
  final Color color;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final eyebrow = [
      if (subject.code != null) subject.code,
      if (subject.credits != null) '${subject.credits} CREDITS',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
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
              GestureDetector(onTap: onBack, child: const Icon(Icons.arrow_back, size: 20, color: Colors.white)),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 15, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Edit', style: AppText.sans(size: 12, weight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(eyebrow.toUpperCase(), style: AppText.sans(size: 10, weight: FontWeight.w800, letterSpacing: AppText.em(0.06, 10), color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 3),
          Text(subject.name, style: AppText.sans(size: 22, weight: FontWeight.w800, height: 1.15, color: Colors.white)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.white.withValues(alpha: 0.92)),
              const SizedBox(width: 4),
              Text(subject.professor ?? '', style: AppText.sans(size: 11, color: Colors.white.withValues(alpha: 0.92))),
              const SizedBox(width: 10),
              if (subject.targetGrade != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(7)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.track_changes, size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('Target ${subject.targetGrade}', style: AppText.sans(size: 10, weight: FontWeight.w800, color: Colors.white)),
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
  final IconData icon;
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
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: 11.5, weight: FontWeight.w700, color: colors.text)),
                  Text(size, style: AppText.sans(size: 9, color: colors.textDim)),
                ],
              ),
            ),
              // Explicit delete affordance next to swipe-to-delete, so the
              // action is discoverable without knowing to swipe.
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Icon(Icons.delete_outline, size: 18, color: colors.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
