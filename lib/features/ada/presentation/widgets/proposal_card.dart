import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/hex_color.dart';
import '../../../../data/models/ada_action.dart';
import '../../../../data/models/tag_resolve.dart';
import '../../../../data/repositories/tags_repository.dart';
import '../../../../shared/widgets/ic.dart';
import 'ada_look.dart';

/// A change Ada wants to make, with the student's Approve / Decline gate
/// (v11 `ProposalCard`, frames `ada-proposals` and `ada-applied`).
///
/// Nothing behind this card has happened yet: the backend holds it as a
/// pending action and applies it only when Approve is tapped. Once decided the
/// card settles into a receipt — "Added to today", "Declined" — so the thread
/// stays readable on reload. An added one-off task offers Undo when the app
/// knows which task it was ([AdaAction.canUndo]); nothing else does.
class AdaProposalCard extends ConsumerWidget {
  const AdaProposalCard({
    super.key,
    required this.action,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
    required this.onUndo,
  });

  final AdaAction action;

  /// A decision (or an undo) for this card is in flight.
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final a = action;
    final pending = a.status.isPending;
    final delete = a.operation == AdaActionOperation.delete;
    final undoable = a.canUndo;
    final headline = proposalHeadline(a);

    // A new task's details read as chips (Today · 30 min · Gym); a change
    // reads as before → after rows.
    final chipped = a.operation == AdaActionOperation.create && a.resource == 'task';
    String? note;
    final chips = <Widget>[];
    final rows = <AdaActionField>[];
    for (final f in a.fields) {
      final to = f.to;
      if (to == null || to.trim().isEmpty) continue;
      if (!chipped || f.isChange) {
        // The delete card's own "Task: <title>" only repeats the headline.
        if (!f.isChange && to == headline) continue;
        rows.add(f);
        continue;
      }
      switch (f.label) {
        case 'Date':
          chips.add(_MetaChip(icon: 'date', label: _dayLabel(to)));
        case 'Time':
          chips.add(_MetaChip(icon: 'schedule', label: _timeLabel(to)));
        case 'Duration':
          chips.add(_MetaChip(icon: 'hourglass_empty', label: to));
        case 'Subject':
          chips.add(_MetaChip(icon: 'subjects', label: to));
        case 'Tag':
          final tags = ref.watch(tagsProvider).value ?? const [];
          final tag = resolveStudyTag(tags, to);
          chips.add(_MetaChip(dot: tag == null ? colors.textDim : hexColor(tag.color), label: tag?.label ?? to));
        case 'Repeats':
          chips.add(_MetaChip(icon: 'repeat', label: _capitalised(to)));
        case 'Note':
          note = to;
        default:
          chips.add(_MetaChip(label: '${f.label}: $to'));
      }
    }

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          width: 1.5,
          color: pending ? (delete ? colors.danger : colors.accent).alpha8(0x40) : colors.border,
        ),
        boxShadow: pending ? colors.cardShadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Row(
              children: [
                Flexible(child: pending ? _KindChip(action: a) : _Receipt(action: a)),
                // Room for Undo, which floats over this corner (below).
                if (undoable) const SizedBox(width: 52),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            headline,
            style: AppText.sans(
              size: 17,
              weight: FontWeight.w700,
              height: 1.35,
              color: a.undone || a.status.isDeclined ? colors.textMed : colors.text,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
          if (note != null) ...[
            const SizedBox(height: 9),
            Text(
              note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 15, weight: FontWeight.w400, height: 1.4, color: colors.textMed),
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 9),
            for (final f in rows) _FieldRow(field: f),
          ],
          if (a.warning != null) ...[
            const SizedBox(height: 9),
            Text(
              a.warning!,
              style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.4, color: colors.danger),
            ),
          ],
          if (a.status.isFailed && a.error != null) ...[
            const SizedBox(height: 9),
            Text(
              a.error!,
              style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.4, color: colors.danger),
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CardButton(label: 'Approve', ink: true, busy: busy, onTap: busy ? null : onApprove),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CardButton(label: 'Decline', ink: false, busy: false, onTap: busy ? null : onDecline),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!undoable) return card;
    // Undo's target is the full 44, centred on the receipt line, without
    // pushing the card taller than the design's 24 line.
    return Stack(
      children: [
        card,
        Positioned(
          top: 5,
          right: 10,
          child: _UndoButton(busy: busy, onTap: busy ? null : onUndo),
        ),
      ],
    );
  }
}

/// The card's subject without the verb its chip already says:
/// "Add task “Proper workout”" → "Proper workout". Anything else ("Move 3
/// tasks to Friday", "Mark “Essay” done") is shown as Ada wrote it.
String proposalHeadline(AdaAction a) {
  final m = _verbAndName.firstMatch(a.title.trim());
  return m?.group(1) ?? a.title;
}

final RegExp _verbAndName = RegExp(r'^(?:Add|Edit|Delete) (?:task|subject|semester|study tag) “(.+)”$');

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// `2026-11-04` → "Today", "Tomorrow" or "Thu 5 Nov".
String _dayLabel(String ymd) {
  final d = DateTime.tryParse(ymd);
  if (d == null) return ymd;
  final today = AppDate.today();
  if (AppDate.sameDay(d, today)) return 'Today';
  if (AppDate.sameDay(d, DateTime(today.year, today.month, today.day + 1))) return 'Tomorrow';
  return '${AppDate.weekdayFull(d).substring(0, 3)} ${d.day} ${_months[d.month - 1]}';
}

/// `14:30` → "2:30 PM"; a part of the day ("morning") → "Morning".
String _timeLabel(String value) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (m == null) return _capitalised(value);
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return value;
  return AppDate.time12h(DateTime(2000, 1, 1, h, min));
}

String _capitalised(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// The "NEW TASK" capsule a waiting card leads with.
class _KindChip extends StatelessWidget {
  const _KindChip({required this.action});

  final AdaAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final noun = switch (action.resource) {
      'task' => 'task',
      'subject' => 'subject',
      'semester' => 'semester',
      'study_tag' => 'tag',
      'profile' => 'profile',
      'settings' => 'settings',
      _ => '',
    };
    final delete = action.operation == AdaActionOperation.delete;
    final (icon, label) = action.resource == 'mood'
        ? ('add', 'Log mood')
        : switch (action.operation) {
            AdaActionOperation.create => ('add', 'New $noun'),
            AdaActionOperation.update => ('edit', 'Edit $noun'),
            AdaActionOperation.delete => ('delete', 'Delete $noun'),
          };
    return Container(
      height: 24,
      padding: const EdgeInsets.fromLTRB(6, 0, 9, 0),
      decoration: BoxDecoration(
        color: delete ? colors.danger.alpha8(0x1F) : colors.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ic(icon, size: 14, color: delete ? colors.danger : colors.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label.trim().toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w800,
                letterSpacing: AppText.em(0.06, 12),
                color: colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What became of a decided card, in its own words.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.action});

  final AdaAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final look = AdaLook.of(context);
    final a = action;
    final (icon, label, color) = a.undone
        // The task is gone; the approval on the server is not. Say the part
        // that is true for the student's plan, nothing more.
        ? ('undo', 'Removed from your plan', colors.textMed)
        : switch (a.status) {
            AdaActionStatus.executed => ('check_circle', _appliedLabel(a), look.added),
            AdaActionStatus.rejected => ('close', 'Declined', colors.textMed),
            AdaActionStatus.failed => ('error_outline', "Couldn't apply", colors.danger),
            AdaActionStatus.approved => ('schedule', 'Applying…', colors.textMed),
            AdaActionStatus.pending || AdaActionStatus.superseded => ('check', 'Done', colors.textMed),
          };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ic(icon, size: 18, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.sans(size: 15, weight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }

  /// "Added to today" only when the task really is on today.
  static String _appliedLabel(AdaAction a) {
    if (a.resource == 'mood') return 'Logged';
    if (a.operation == AdaActionOperation.update) return 'Updated';
    if (a.operation == AdaActionOperation.delete) return 'Deleted';
    if (a.resource != 'task') return 'Added';
    String? date;
    for (final f in a.fields) {
      if (f.label == 'Date') date = f.to;
    }
    final day = date == null ? null : DateTime.tryParse(date);
    if (day == null) return 'Added to your plan';
    final today = AppDate.today();
    if (AppDate.sameDay(day, today)) return 'Added to today';
    if (AppDate.sameDay(day, DateTime(today.year, today.month, today.day + 1))) {
      return 'Added to tomorrow';
    }
    return 'Added to your plan';
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Undo, remove this task from your plan',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.textMed),
                )
              : Text('Undo', style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.textMed)),
        ),
      ),
    );
  }
}

/// A detail of a new task (`MetaChip`): a line icon or a coloured dot.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon, this.dot});

  final String label;
  final String? icon;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glyph = icon;
    final tint = dot;
    return Container(
      height: 30,
      padding: EdgeInsets.fromLTRB(glyph == null && tint == null ? 11 : 9, 0, 11, 0),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Ic(glyph, size: 16, color: colors.textMed),
            const SizedBox(width: 6),
          ] else if (tint != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 15, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// A change, before → after, or a value being set.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.field});

  final AdaActionField field;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = AppText.sans(size: 15, height: 1.4, color: colors.text);
    final quiet = AppText.sans(size: 15, weight: FontWeight.w400, height: 1.4, color: colors.textMed);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(field.label, style: quiet)),
          Expanded(
            child: field.isChange
                // The old value struck through, so a change reads as a change
                // rather than a fresh value the student has to reason about.
                ? Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: field.from,
                          style: quiet.copyWith(decoration: TextDecoration.lineThrough),
                        ),
                        TextSpan(text: '  →  ', style: quiet),
                        TextSpan(text: field.to ?? '—', style: value),
                      ],
                    ),
                  )
                : Text(field.to ?? '—', style: value),
          ),
        ],
      ),
    );
  }
}

/// Approve (ink) and Decline (well), 44 tall.
class _CardButton extends StatelessWidget {
  const _CardButton({required this.label, required this.ink, required this.busy, required this.onTap});

  final String label;
  final bool ink;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ink ? colors.ink : colors.bg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ink ? Colors.white : colors.textMed),
                )
              : Text(
                  label,
                  style: AppText.sans(
                    size: 17,
                    weight: ink ? FontWeight.w800 : FontWeight.w700,
                    color: ink ? Colors.white : colors.text,
                  ),
                ),
        ),
      ),
    );
  }
}
