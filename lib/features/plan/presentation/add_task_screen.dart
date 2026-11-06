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
import '../../../services/haptics/haptics_service.dart';
import '../../../services/reminder_scheduler.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_toggle.dart';
import '../../../shared/widgets/dismiss_keyboard.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../settings/presentation/sheets/add_tag_sheet.dart';
import '../plan_time.dart';
import '../providers/plan_providers.dart';
import '../providers/plan_ui_providers.dart';
import 'pickers/date_picker.dart';
import 'pickers/duration_picker.dart';
import 'pickers/repeat_picker.dart';
import 'pickers/time_picker.dart';

/// FRAMES `plan-addtask` (v11 `AddTaskBody`) — the full add-task form. Each
/// detail row opens the matching picker (time / date / duration / repeat) and
/// reflects the result.
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
  /// Off by default. Breaking a task down costs a model call and rewrites the
  /// user's plan, so it is opt-in rather than something that happens to every
  /// task someone types.
  ///
  /// When editing, it is initialised from whether the task already HAS steps,
  /// so the switch describes the task's real state instead of an intention.
  bool _adaBreakdown = false;

  /// What the toggle read when the screen opened. The save path compares
  /// against it so it can tell "leave it alone" from "the user just changed
  /// their mind", which is what decides between generating and deleting.
  bool _hadBreakdown = false;
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
      // Now that the picker actually persists, editing has to show the saved
      // subject — otherwise opening a task and saving it would silently clear
      // one, which is a worse bug than the picker doing nothing at all.
      _subject = existing.subjectId ?? '';
      _date = existing.date;
      _durationMin = existing.durationMin ?? 30;
      _repeat = existing.repeat;
      _adaBreakdown = existing.subtasks.isNotEmpty;
      _hadBreakdown = _adaBreakdown;
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
      // A tag picked in Quick-add carries over; none leaves the form's own
      // default (the first tag) in place.
      final tagId = draft.tagId;
      if (tagId != null && tagId.isNotEmpty) _tag = tagId;
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
    // `_subject` is empty for the picker's own "no subject" option, which is
    // now a real choice rather than a shrug the wire never heard about.
    final subjectId = _subject.isEmpty ? null : _subject;
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
          subjectId: subjectId,
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
          subjectId: subjectId,
          date: date,
          dayPart: dayPart,
          startTime: startTime,
          durationMin: _durationMin,
          repeat: repeat,
        ));
      }
      // Act on the CHANGE, not on the flag. Re-running breakdown on a task that
      // already has steps appends a second set, and re-deleting steps that were
      // never there is a wasted round trip.
      //
      // Both are best-effort: the task itself is already saved, and losing the
      // microsteps is not worth failing the save the user asked for.
      if (saved.id.isNotEmpty && _adaBreakdown != _hadBreakdown) {
        try {
          if (_adaBreakdown) {
            // The day the occurrence is on right now: a changed date is only
            // applied by the move below, after this.
            await repo.breakdown(saved.id, existing?.date ?? date);
          } else {
            await repo.clearSteps(saved.id);
          }
        } on Object {
          // Non-fatal.
        }
      }
      // TSK-3: PATCH /tasks has no date — the day is changed by its own
      // endpoint, the one Reschedule uses. Without this an edited date was
      // dropped while the save reported success. Last, so the update and any
      // steps act on the occurrence where it currently is.
      if (existing != null && saved.id.isNotEmpty && !_sameDay(existing.date, date)) {
        await repo.move(saved, date);
      }
      // Tier 2, and only for a creation. An edit is not a new task, and Plan's
      // budget of 4 (§7) has no room for "task edited" — nor should it.
      if (existing == null) ref.read(hapticsProvider).taskCreated();
      ref.invalidate(dayTasksProvider);
      // Arm the device's reminders for the task the user just saved, without
      // waiting for the next resume.
      unawaited(ref.read(reminderSchedulerProvider).reconcile(force: true));
      if (mounted) context.pop();
    } on Object {
      // Tier 4. The user explicitly submitted this and it did not land; the
      // snackbar is easy to miss and the form looks unchanged.
      ref.read(hapticsProvider).saveFailed();
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save task. Try again.")),
      );
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _addTag() async {
    final draft = await showAddTagSheet(context);
    if (draft == null || !mounted) return;
    await ref.read(tagsProvider.notifier).add(label: draft.label, colorHex: hexFromColor(draft.color));
    if (!mounted) return;
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
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final subjects = ref.watch(subjectsProvider).value ?? const [];
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
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _HeaderCard(
                        controller: _title,
                        editing: widget.existing != null,
                        saving: _saving,
                        onClose: _saving ? null : () => context.pop(),
                        onSave: _save,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Section(
                      label: "Tag · what's this for?",
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
                    _Section(
                      label: 'Subject · link it (optional)',
                      children: [
                        for (final s in subjects)
                          TagChip(
                            label: (s.code != null && s.code!.trim().isNotEmpty) ? s.code! : s.name,
                            color: hexColor(s.color),
                            active: _subject == s.id,
                            onTap: _saving ? null : () => setState(() => _subject = s.id),
                          ),
                        TagChip(
                          label: 'None',
                          active: _subject.isEmpty,
                          onTap: _saving ? null : () => setState(() => _subject = ''),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        child: Column(
                          children: [
                            _DetailRow(
                              icon: 'schedule',
                              label: 'Time of day',
                              value: _timeOfDay,
                              onTap: _saving ? null : _pickTime,
                            ),
                            _DetailRow(
                              icon: 'event',
                              label: 'Date',
                              value: taskDateLabel(_date),
                              onTap: _saving ? null : _pickDate,
                            ),
                            _DetailRow(
                              icon: 'hourglass_empty',
                              label: 'Duration',
                              value: '$_durationMin min',
                              onTap: _saving ? null : _pickDuration,
                            ),
                            _DetailRow(
                              icon: 'repeat',
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AppCard(
                        child: Row(
                          children: [
                            const AdaMascot(size: 28, expr: AdaExpr.focused),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Let Ada break this down',
                                style: AppText.sans(
                                  size: 17,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                padding: const EdgeInsets.only(top: 1),
                                child: Ic('note', size: 20, color: colors.textMed),
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
                                  style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    hintText: 'Add a note…',
                                    hintStyle: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textDim),
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
    if (v != null && mounted) setState(() => _timeOfDay = v);
  }

  Future<void> _pickDate() async {
    final v = await showTaskDatePicker(context, initial: _date);
    if (v != null && mounted) setState(() => _date = v);
  }

  Future<void> _pickDuration() async {
    final v = await showDurationPicker(context, current: _durationMin);
    if (v != null && mounted) setState(() => _durationMin = v);
  }

  Future<void> _pickRepeat() async {
    final v = await showRepeatPicker(context, current: _repeat, date: _date);
    if (v != null && mounted) setState(() => _repeat = v);
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.controller,
    required this.onSave,
    this.onClose,
    this.saving = false,
    this.editing = false,
  });
  final TextEditingController controller;

  /// Opened on an existing task, so the title says Edit rather than Add.
  final bool editing;
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
              // BarDismiss at the left edge: the bare ✕, its glyph on the
              // padding line, in a 32 × 44 target.
              Semantics(
                button: true,
                label: 'Close',
                excludeSemantics: true,
                onTap: onClose,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: SizedBox(
                    width: 32,
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Ic('close', size: 20, color: colors.textMed),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  editing ? 'Edit task' : 'Add task',
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
                ),
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
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: saving ? colors.hilite : colors.ink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.textDim,
                          ),
                        )
                      : Text(
                          'Save',
                          style: AppText.sans(
                            size: 17,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: TextField(
              controller: controller,
              enabled: !saving,
              style: AppText.sans(size: 17, color: colors.text),
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'What do you need to do?',
                hintStyle: AppText.sans(size: 17, color: colors.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section label (v11 `SLabel`, 12/800 tracked caps) over one row of chips
/// that scrolls sideways rather than wrapping.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
            child: Text(
              label.toUpperCase(),
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w800,
                letterSpacing: AppText.em(0.12, 12),
                color: colors.textDim,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A detail row (Time of day / Date / Duration / Repeat): icon 20, 17/600
/// label and the value in a 36 well pill; 52 min, separators inset to the label.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.last = false,
  });

  /// A design icon name (`schedule`).
  final String icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            Ic(icon, size: 20, color: colors.textMed),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: last ? null : Border(bottom: BorderSide(color: colors.border)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      Expanded(
                        child: Text(label, style: AppText.sans(size: 17, color: colors.text)),
                      ),
                      const SizedBox(width: 8),
                      // Its natural width, up to 60% of the row; past that the
                      // value ellipsizes. Unbounded, as an inflexible Row child
                      // is, the ellipsis never ran and a long value overflowed.
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                          // widthFactor 1: hug the value (a bounded Align
                          // would stretch the pill to the cap).
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sans(size: 15, color: colors.textMed),
                            ),
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
    );
  }
}
