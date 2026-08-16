import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/hex_color.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/tag.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/subjects_repository.dart';
import '../../../data/repositories/tags_repository.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_toggle.dart';
import '../../../shared/widgets/dismiss_keyboard.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../settings/presentation/sheets/add_tag_sheet.dart';
import '../plan_time.dart';
import '../providers/plan_providers.dart';
import '../providers/plan_ui_providers.dart';
import 'pickers/date_picker.dart';
import 'pickers/duration_picker.dart';
import 'pickers/repeat_picker.dart';
import 'pickers/time_picker.dart';

/// FRAMES `plan-addtask` — the full add-task form. Each detail row opens the
/// matching picker (time / date / duration / repeat) and reflects the result.
class AddTaskScreen extends ConsumerStatefulWidget {
  const AddTaskScreen({super.key, this.existing});

  /// When non-null, the screen edits this task (prefilled fields, saves via
  /// `update`) instead of creating a new one.
  final Task? existing;

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  String _tag = '';
  /// Empty = None. Populated from the user's real subjects, never demo codes.
  String _subject = '';
  String _timeOfDay = 'Anytime';
  late DateTime _date;
  int _durationMin = 30;
  RepeatRule? _repeat;
  bool _adaBreakdown = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Editing an existing task: prefill from it and ignore any Quick-add draft.
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _note.text = existing.note ?? '';
      // Legacy coerced wire values are not real study tags — leave unset so the
      // chip row / save path can pick a real tag instead of re-saving "other".
      final stored = existing.tagId.trim().toLowerCase();
      _tag = (stored == 'other' || stored == 'general') ? '' : existing.tagId;
      // Prefer a concrete clock label when startTime is set — never wipe a
      // planned time back to the coarse Anytime/Morning chip.
      _timeOfDay = existing.startTime != null
          ? AppDate.time12h(existing.startTime!)
          : PlanTime.dayPartLabel(existing.dayPart ?? DayPart.anytime);
      _date = existing.date;
      _durationMin = existing.durationMin ?? 30;
      _repeat = existing.repeat;
      return;
    }
    _date = ref.read(selectedDateProvider);
    // Consume a Quick-add draft so the typed title / time / repeat carry over.
    // Read the value here (no mutation), then clear the one-shot draft *after*
    // this build lifecycle — mutating a provider inside initState throws
    // Riverpod's "modify a provider while the widget tree was building" error
    // (which was crashing this screen when opened from Quick-add "More" or the
    // list-view group "+").
    final draft = ref.read(taskDraftProvider);
    if (draft != null) {
      _title.text = draft.title;
      if (draft.timeLabel != null && draft.timeLabel!.isNotEmpty) {
        _timeOfDay = draft.timeLabel!;
      } else if (draft.dayPart != null) {
        _timeOfDay = PlanTime.dayPartLabel(draft.dayPart!);
      }
      _repeat = draft.repeat;
    }
    unawaited(Future(() {
      if (mounted) ref.read(taskDraftProvider.notifier).take();
    }));
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Ignore repeat taps while create/update (+ optional Ada breakdown) is in flight.
    if (_saving) return;
    setState(() => _saving = true);

    final repeat =
        (_repeat != null && _repeat!.frequency != RepeatFrequency.none) ? _repeat : null;
    final title = _title.text.trim().isEmpty ? 'New task' : _title.text.trim();
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final existing = widget.existing;
    final date = _date;
    // Resolve the tag: fall back to the first available study tag so a task is
    // never saved with an empty/unknown tag (which would render as "Other").
    final tags = ref.read(tagsProvider).value ?? const <Tag>[];
    final tagId = _tag.isNotEmpty
        ? _tag
        : (tags.isNotEmpty ? tags.first.id : _tag);
    final resolved = PlanTime.resolve(_timeOfDay, date);
    final startTime = resolved.startTime;
    final dayPart = resolved.dayPart;

    try {
      final repo = ref.read(tasksRepositoryProvider);
      Task saved;
      if (existing != null) {
        // Edit: keep the task's own id, apply the edited fields.
        saved = await repo.update(existing.copyWith(
          title: title,
          note: note,
          tagId: tagId,
          date: date,
          dayPart: dayPart,
          startTime: startTime,
          durationMin: _durationMin,
          repeat: repeat,
        ));
      } else {
        saved = await repo.create(Task(
          id: '',
          title: title,
          note: note,
          tagId: tagId,
          date: date,
          dayPart: dayPart,
          startTime: startTime,
          durationMin: _durationMin,
          repeat: repeat,
        ));
      }
      // Let Ada break the task into microtasks (best-effort — never blocks save).
      if (_adaBreakdown && saved.id.isNotEmpty) {
        try {
          await repo.breakdown(saved.id, date);
        } on Object {
          // Non-fatal: the task is saved even if breakdown fails.
        }
      }
      ref.invalidate(dayTasksProvider);
      if (mounted) context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save task. Try again.")),
      );
    }
  }

  Future<void> _addTag() async {
    final draft = await showAddTagSheet(context);
    if (draft == null) return;
    await ref.read(tagsProvider.notifier).add(label: draft.label, colorHex: hexFromColor(draft.color));
    final tags = ref.read(tagsProvider).value ?? const <Tag>[];
    Tag? created;
    for (final t in tags) {
      if (t.label == draft.label) created = t;
    }
    if (created != null) setState(() => _tag = created!.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tagsAsync = ref.watch(tagsProvider);
    final tags = tagsAsync.value ?? const <Tag>[];
    final subjectsAsync = ref.watch(subjectsProvider);
    final subjects = subjectsAsync.value ?? const [];
    // Highlight the chosen tag; if none picked yet, pre-highlight the first so a
    // task is never saved untagged (which would show as "Other").
    final effectiveTag =
        _tag.isNotEmpty ? _tag : (tags.isNotEmpty ? tags.first.id : '');
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Stack(
          children: [
            DismissKeyboard(
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                  children: [
                    _HeaderCard(
                      controller: _title,
                      saving: _saving,
                      onClose: _saving ? null : () => context.pop(),
                      onSave: _save,
                    ),
                    const SizedBox(height: 6),
                    _Section(
                      label: "Tag · what's this for?",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fresh accounts land here tagless; say so instead of
                          // showing a lone dashed chip (skip while loading).
                          if (tagsAsync.hasValue && tags.isEmpty) ...[
                            Text(
                              'No tags yet — tap "+ New" to make your first one.',
                              style: AppText.sans(size: 11.5, color: colors.textDim),
                            ),
                            const SizedBox(height: 7),
                          ],
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final t in tags)
                                TagChip(
                                  label: t.label,
                                  color: hexColor(t.color),
                                  active: effectiveTag == t.id,
                                  onTap: _saving ? null : () => setState(() => _tag = t.id),
                                ),
                              TagChip(
                                label: '+ New',
                                color: colors.accent,
                                dashed: true,
                                onTap: _saving ? null : _addTag,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _Section(
                      label: 'Subject · link it (optional)',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subjectsAsync.hasValue && subjects.isEmpty) ...[
                            Text(
                              "No subjects yet — once you add them, they'll show up here.",
                              style: AppText.sans(size: 11.5, color: colors.textDim),
                            ),
                            const SizedBox(height: 7),
                          ],
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final s in subjects)
                                TagChip(
                                  label: (s.code != null && s.code!.trim().isNotEmpty)
                                      ? s.code!
                                      : s.name,
                                  color: hexColor(s.color),
                                  active: _subject == s.id,
                                  onTap: _saving
                                      ? null
                                      : () => setState(() => _subject = s.id),
                                ),
                              TagChip(
                                label: 'None',
                                active: _subject.isEmpty,
                                onTap: _saving ? null : () => setState(() => _subject = ''),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        child: Column(
                          children: [
                            _DetailRow(
                              icon: Icons.schedule,
                              label: 'Time of day',
                              value: _timeOfDay,
                              onTap: _saving ? null : _pickTime,
                            ),
                            _DetailRow(
                              icon: Icons.event,
                              label: 'Date',
                              value: taskDateLabel(_date),
                              onTap: _saving ? null : _pickDate,
                            ),
                            _DetailRow(
                              icon: Icons.hourglass_empty,
                              label: 'Duration',
                              value: '$_durationMin min',
                              onTap: _saving ? null : _pickDuration,
                            ),
                            _DetailRow(
                              icon: Icons.repeat,
                              label: 'Repeat',
                              value: repeatRuleLabel(_repeat),
                              onTap: _saving ? null : _pickRepeat,
                              last: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AppCard(
                        child: Row(
                          children: [
                            const AdaMascot(size: 28, expr: AdaExpr.focused),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Let Ada break this down',
                                style: AppText.sans(
                                  size: 12.5,
                                  weight: FontWeight.w700,
                                  color: colors.text,
                                ),
                              ),
                            ),
                            AppToggle(
                              value: _adaBreakdown,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _adaBreakdown = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      // The whole note card is the tap target. The TextField's
                      // intrinsic height is only one dense line; without this,
                      // taps on card padding / the icon were swallowed by
                      // DismissKeyboard and never focused the field.
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _saving ? null : _noteFocus.requestFocus,
                        child: AppCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(Icons.notes, size: 16, color: colors.textMed),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _note,
                                  focusNode: _noteFocus,
                                  enabled: !_saving,
                                  minLines: 1,
                                  maxLines: 6,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  style: AppText.sans(size: 12.5, color: colors.text),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: 'Add a note…',
                                    hintStyle: AppText.sans(size: 12.5, color: colors.textDim),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_saving)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: colors.bg.withValues(alpha: 0.55),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colors.accent,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    // Pass the current selection so reopening the sheet highlights it (it used
    // to always show "Anytime").
    final v = await showTimeOfDayPicker(context, current: _timeOfDay);
    if (v != null) setState(() => _timeOfDay = v);
  }

  Future<void> _pickDate() async {
    final v = await showTaskDatePicker(context, initial: _date);
    if (v != null) setState(() => _date = v);
  }

  Future<void> _pickDuration() async {
    final v = await showDurationPicker(context, current: _durationMin);
    if (v != null) setState(() => _durationMin = v);
  }

  Future<void> _pickRepeat() async {
    final v = await showRepeatPicker(context);
    if (v != null) setState(() => _repeat = v);
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.controller,
    required this.onSave,
    this.onClose,
    this.saving = false,
  });
  final TextEditingController controller;
  final VoidCallback? onClose;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.bg, shape: BoxShape.circle),
                  child: Text('✕', style: TextStyle(fontSize: 13, color: colors.textMed, height: 1)),
                ),
              ),
              Expanded(
                child: Text('Add task', textAlign: TextAlign.center, style: AppText.sans(size: 16, weight: FontWeight.w800, color: colors.text)),
              ),
              GestureDetector(
                // Disabled while a save is in flight — the parent's `_saving`
                // guard already blocks re-entry, but nulling onTap + the inline
                // spinner make it obvious the tap registered, so the user isn't
                // tempted to keep tapping (which previously created one task per
                // tap on builds without the guard).
                onTap: saving ? null : onSave,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: saving ? colors.hilite : colors.ink,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: saving
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.textDim,
                          ),
                        )
                      : Text(
                          'Save',
                          style: AppText.sans(
                            size: 12,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: controller,
              enabled: !saving,
              style: AppText.sans(size: 14, color: colors.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'What do you need to do?',
                hintStyle: AppText.sans(size: 14, color: colors.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              label.toUpperCase(),
              style: AppText.sans(size: 9, weight: FontWeight.w800, letterSpacing: AppText.em(0.12, 9), color: colors.textDim),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: colors.border)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colors.textMed),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppText.sans(size: 12.5, color: colors.text))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text(value, style: AppText.sans(size: 11, color: colors.textMed)),
            ),
          ],
        ),
      ),
    );
  }
}
