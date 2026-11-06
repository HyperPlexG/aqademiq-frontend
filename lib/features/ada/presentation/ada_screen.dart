import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/ada_action.dart';
import '../../../data/models/ada_message.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/ada_repository.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../services/reminder_scheduler.dart';
import '../../../services/voice_input_service.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/dismiss_keyboard.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/voice_feedback.dart';
import '../../../shared/widgets/voice_recording_bar.dart';
import '../../plan/providers/plan_providers.dart';
import 'widgets/ada_chrome.dart';
import 'widgets/ada_look.dart';
import 'widgets/ada_thread.dart';
import 'widgets/chat_history_sheet.dart';
import 'widgets/proposal_card.dart';

/// FRAMES `ada-empty` / `ada-chat` / `ada-thinking` / `ada-proposals` /
/// `ada-proposals-end` / `ada-applied` — the Ada tab: the intro when empty, the
/// thread once started. History opens as a slide-over (`ada-history`).
///
/// v11 lays it out like Gemini: a 72 header on the page colour, the thread
/// scrolling under an eased fade beneath it, and a floating glass text box
/// docked above the nav — with the proposal tray above that when two or more
/// of Ada's changes wait. The thread runs under all of it.
class AdaScreen extends ConsumerStatefulWidget {
  const AdaScreen({super.key});

  @override
  ConsumerState<AdaScreen> createState() => _AdaScreenState();
}

class _AdaScreenState extends ConsumerState<AdaScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  /// Lets the "N waiting" tray scroll the transcript to its cards.
  final _list = GlobalKey<_MessageListState>();
  late final _dictation = Dictation(_input);

  /// Held from [initState] so [dispose] can end a dictation without touching
  /// `ref` while the widget is being torn down.
  late final VoiceInputController _voice;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceInputProvider.notifier);
  }

  @override
  void dispose() {
    endDictationAfterTeardown(_voice, this);
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final chat = ref.read(adaChatProvider);
    // While a reply is on its way the arrow is Stop: one turn at a time.
    if (chat.awaitingReply) return;
    final value = (text ?? _input.text).trim();
    if (value.isEmpty && chat.pendingAttachments.isEmpty) return;
    // Sending ends any dictation, started or merely starting. Cancel rather
    // than stop: the field already
    // shows what was heard, and a final result arriving after the clear below
    // would otherwise write the words back into an empty box.
    unawaited(_voice.cancel(owner: this));
    _input.clear();
    unawaited(ref.read(adaChatProvider.notifier).send(value));
  }

  /// Send became Stop (`ada-thinking`): stop waiting for this reply. There is
  /// no server cancel; the controller just drops the answer when it lands.
  void _stop() => ref.read(adaChatProvider.notifier).stop();

  /// Opens the mic. While it is open the input bar becomes the recording pill,
  /// whose buttons are the three handlers below. The words still land in the
  /// input for the student to read and correct — nothing is sent until they
  /// tap send.
  Future<void> _startVoice() async {
    if (ref.read(voiceInputProvider).isActiveFor(this)) return;
    _dictation.begin();
    final problem = await _voice.start(
      owner: this,
      // The first tap may sit behind the OS permission prompt; a screen left in
      // the meantime must not have words written into its disposed field.
      onWords: (words) {
        if (mounted) _dictation.show(words);
      },
    );
    if (problem != null && mounted) showVoiceUnavailable(context, problem);
  }

  /// ✕ — throw away what was said. Cancelled first so no late word can land
  /// after the field is put back.
  void _discardVoice() {
    unawaited(_voice.cancel(owner: this));
    _dictation.restore();
  }

  /// ■ — stop, and leave the words in the box to review.
  void _stopVoice() => unawaited(_voice.stop(owner: this));

  /// ↑ — stop and send. Waits for the recognizer's last words so the message
  /// is what was actually said, not the partial result a moment before it.
  Future<void> _sendVoice() async {
    await _voice.stopAndSettle(owner: this);
    if (mounted) _send();
  }

  Future<void> _applyPlan(String messageId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adaChatProvider.notifier).applyPlan(messageId);
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't apply this plan.")),
      );
      return;
    }
    // Checked outside the try: `ref` after dispose throws, and inside it that
    // throw would land in the catch and report a plan that DID apply as failed.
    if (!mounted) return;
    // Ada's entire budget is 1 (§7): "'Plan my week' applied to the plan".
    // Message send, message arrival and streaming tokens are all zero — none
    // of them is a state change the user caused, and a chat that buzzes as it
    // types is the fastest way to lose the channel.
    //
    // Reuses `taskCreated` rather than minting a 23rd Tier 2 event: what just
    // happened is that tasks appeared on the plan, which is the same state
    // change the Plan screen confirms with the same light single. Spec §3
    // caps the vocabulary at the events it lists, and this needs no new one.
    ref.read(hapticsProvider).taskCreated();
    ref.invalidate(dayTasksProvider);
    messenger.showSnackBar(
      const SnackBar(content: Text('Added to your plan ✓')),
    );
  }

  /// Approve one of Ada's proposed changes. Nothing was written until now — the
  /// server executes it here, then lets the agent carry on from the result.
  Future<void> _approve(AdaAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    final applied = await ref.read(adaChatProvider.notifier).approveAction(action.id);
    if (!mounted) return;
    if (applied) {
      _refreshAffected(action.resource);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't apply “${proposalHeadline(action)}”.")),
      );
    }
  }

  Future<void> _reject(AdaAction action) =>
      ref.read(adaChatProvider.notifier).rejectAction(action.id);

  Future<void> _decideAll({required bool approve}) async {
    final messenger = ScaffoldMessenger.of(context);
    final applied = await ref.read(adaChatProvider.notifier).decideAll(approve: approve);
    if (!mounted) return;
    if (approve) {
      _refreshAffected('task');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            applied == 0
                ? "Couldn't apply those changes."
                : '$applied change${applied == 1 ? '' : 's'} applied ✓',
          ),
        ),
      );
    }
  }

  /// Undo on an added task (`ada-applied`). Deletes the task the approval
  /// created — only offered when the app knows exactly which one — then
  /// refreshes what the Plan's own Delete refreshes.
  Future<void> _undo(AdaAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    final undone = await ref.read(adaChatProvider.notifier).undoAction(action.id);
    if (!mounted) return;
    if (undone) {
      ref
        ..invalidate(dayTasksProvider)
        ..invalidate(weeklyCompletedProvider);
      unawaited(ref.read(reminderSchedulerProvider).reconcile(force: true));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't undo that. It's still on your plan.")),
      );
    }
  }

  /// Ada writes through the same services the rest of the app reads from, so an
  /// applied change has to invalidate those caches or the plan looks unchanged.
  void _refreshAffected(String resource) {
    if (resource == 'task' || resource == 'subject' || resource == 'semester') {
      ref.invalidate(dayTasksProvider);
    }
  }

  Future<void> _pickAndUpload() async {
    const typeGroup = XTypeGroup(
      label: 'Documents',
      // iOS filters by UTIs; without them the picker greys out every file.
      extensions: <String>['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'md'],
      mimeTypes: <String>['application/pdf', 'text/plain'],
      uniformTypeIdentifiers: <String>[
        'com.adobe.pdf',
        'public.plain-text',
        'public.text',
        'net.daringfireball.markdown',
        'com.microsoft.word.doc',
        'org.openxmlformats.wordprocessingml.document',
        'com.microsoft.powerpoint.ppt',
        'org.openxmlformats.presentationml.presentation',
        'public.image',
      ],
    );
    // Multi-select when the platform supports it; each file is staged only —
    // nothing is sent until the user taps Send.
    final messenger = ScaffoldMessenger.of(context);
    final files = await openFiles(acceptedTypeGroups: const [typeGroup]);
    if (files.isEmpty || !mounted) return;

    final notifier = ref.read(adaChatProvider.notifier);
    for (final file in files) {
      try {
        await notifier.stageAttachment(file);
      } on Object {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text("Couldn't upload ${file.name}. Try again.")),
        );
      }
    }
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(adaChatProvider);
    final voice = ref.watch(voiceInputProvider);
    final look = AdaLook.of(context);
    // Sit above the keyboard when typing, otherwise above the floating nav
    // (the design docks the box ~20 clear of the bar's top edge).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final inputBottom = keyboard > 0 ? keyboard + 8 : AppScaffold.navClearanceOf(context);

    final tray = chat.outstandingActions.length > 1;
    final staged = chat.uploading || chat.pendingAttachments.isNotEmpty;
    // Whatever floats on top of the text box, so content can clear it.
    final above = (tray ? kAdaTrayHeight + kAdaTrayGap : 0.0) +
        (staged ? AdaAttachmentRow.height + kAdaTrayGap : 0.0);
    final boxTop = inputBottom + kAdaInputHeight + above;

    return DismissKeyboard(
      child: Stack(
        children: [
          if (chat.isEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: AdaGlowPainter(core: look.glowCore, mid: look.glowMid),
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdaHeader(
                onHistory: () => unawaited(showChatHistory(context)),
                onUpload: chat.uploading ? null : () => unawaited(_pickAndUpload()),
                uploading: chat.uploading,
              ),
              Expanded(
                child: chat.isEmpty
                    ? _Intro(onSuggest: _send, bottomInset: boxTop + 22)
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: _MessageList(
                              key: _list,
                              // The last line rests 48 above the text box, or
                              // 40 above the tray when there is one.
                              bottomInset: boxTop + (tray ? 40 : 48),
                              messages: chat.messages,
                              typing: chat.typing,
                              stopped: chat.stoppedReplies,
                              error: chat.error,
                              onRetry: () => unawaited(
                                ref.read(adaChatProvider.notifier).retryLast(),
                              ),
                              onDismissError: ref.read(adaChatProvider.notifier).clearError,
                              onApplyPlan: (id) => unawaited(_applyPlan(id)),
                              actionsByMessage: chat.actionsByMessage,
                              decidingIds: chat.decidingActionIds,
                              onApprove: (a) => unawaited(_approve(a)),
                              onReject: (a) => unawaited(_reject(a)),
                              onUndo: (a) => unawaited(_undo(a)),
                            ),
                          ),
                          const Positioned(top: 0, left: 0, right: 0, child: AdaEdgeFade.top()),
                        ],
                      ),
              ),
            ],
          ),
          if (!chat.isEmpty)
            // Solid up to the nav's top edge, easing out by the text box's
            // midline — the thread dissolves before the glass and the bar.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AdaEdgeFade.bottom(
                height: inputBottom + kAdaInputHeight / 2,
                solid: math.max(0, inputBottom - AppScaffold.navBreathing),
              ),
            ),
          Positioned(
            left: kAdaGlassInset,
            right: kAdaGlassInset,
            bottom: inputBottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tray) ...[
                  AdaProposalTray(
                    count: chat.outstandingActions.length,
                    busy: chat.decidingActionIds.isNotEmpty,
                    onShow: () => _list.currentState?.scrollToFirstPending(),
                    onApproveAll: () => unawaited(_decideAll(approve: true)),
                    onDeclineAll: () => unawaited(_decideAll(approve: false)),
                  ),
                  const SizedBox(height: kAdaTrayGap),
                ],
                if (staged) ...[
                  AdaAttachmentRow(
                    uploading: chat.uploading,
                    attachments: chat.pendingAttachments,
                    onRemove: (key) =>
                        ref.read(adaChatProvider.notifier).removePendingAttachment(key),
                  ),
                  const SizedBox(height: kAdaTrayGap),
                ],
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                      child: child,
                    ),
                  ),
                  child: voice.isActiveFor(this)
                      ? SizedBox(
                          key: const ValueKey('recording'),
                          height: kAdaInputHeight,
                          child: Center(
                            child: VoiceRecordingBar(
                              listening: voice.isListeningFor(this),
                              level: _voice.level,
                              onDiscard: _discardVoice,
                              onStop: _stopVoice,
                              onSend: () => unawaited(_sendVoice()),
                            ),
                          ),
                        )
                      : AdaInputBar(
                          key: const ValueKey('typing'),
                          controller: _input,
                          focusNode: _focus,
                          thread: !chat.isEmpty,
                          busy: chat.awaitingReply,
                          // Only a phone with no recognizer at all loses the
                          // control; a refused permission keeps it, so the
                          // student can fix it.
                          voiceAvailable: voice.unavailable != VoiceUnavailable.unsupported,
                          onSend: _send,
                          onSpeak: () => unawaited(_startVoice()),
                          onStop: _stop,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `ada-empty`: Ada and her line centred in the space above four suggestions,
/// laid out as Gemini does — a line icon, the words beside it, 44 a row.
class _Intro extends StatelessWidget {
  const _Intro({required this.onSuggest, required this.bottomInset});

  final ValueChanged<String> onSuggest;

  /// From the bottom of the screen to where the suggestions must end.
  final double bottomInset;

  static const _suggestions = [
    ('planner', 'Plan my week'),
    ('self_improvement', "I'm overwhelmed"),
    ('account_tree', 'Break this down'),
    ('alarm', 'Deadline help'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final look = AdaLook.of(context);
    // Scrolls only when there is not room (a short phone with the keyboard
    // up); otherwise it fills the space and centres Ada in it.
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AdaMascot(size: 78),
                        const SizedBox(height: 15),
                        Text(
                          "Drop your thoughts.\nI'll turn them into a plan.",
                          textAlign: TextAlign.center,
                          style: AppText.sans(size: 20, weight: FontWeight.w700, height: 1.4, color: colors.text),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 6, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (icon, label) in _suggestions)
                        Semantics(
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSuggest(label),
                            child: SizedBox(
                              height: 44,
                              child: Row(
                                children: [
                                  Ic(icon, size: 22, color: look.reply),
                                  const SizedBox(width: 14),
                                  Flexible(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.sans(size: 17, weight: FontWeight.w500, color: look.reply),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    super.key,
    required this.bottomInset,
    required this.messages,
    required this.typing,
    required this.stopped,
    required this.error,
    required this.onRetry,
    required this.onDismissError,
    required this.onApplyPlan,
    required this.actionsByMessage,
    required this.decidingIds,
    required this.onApprove,
    required this.onReject,
    required this.onUndo,
  });

  /// From the bottom of the screen to where the last line may sit: clear of
  /// the glass (tray + text box) and the nav, which all float over the thread.
  final double bottomInset;
  final List<AdaMessage> messages;
  final bool typing;

  /// User messages whose reply was stopped.
  final Set<String> stopped;

  /// Why the last turn failed, or null. Rendered in the transcript rather than
  /// as a snackbar: a snackbar for a minute-long request is gone before the
  /// user looks back at the screen, and this is the answer to "what happened
  /// to my message".
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onDismissError;
  final ValueChanged<String> onApplyPlan;
  final Map<String, List<AdaAction>> actionsByMessage;
  final Set<String> decidingIds;
  final ValueChanged<AdaAction> onApprove;
  final ValueChanged<AdaAction> onReject;
  final ValueChanged<AdaAction> onUndo;

  @override
  State<_MessageList> createState() => _MessageListState();
}

/// The transcript, kept at the newest message.
///
/// It never scrolled by itself: a reply with five cards landed below the fold
/// — under the keyboard, behind the "N waiting" tray — and the user asked
/// "where is it?" while the cards sat just out of sight.
class _MessageListState extends State<_MessageList> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _toEnd(animate: false);
  }

  @override
  void didUpdateWidget(_MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length ||
        widget.typing != oldWidget.typing ||
        widget.error != oldWidget.error ||
        widget.bottomInset != oldWidget.bottomInset ||
        _cardCount(widget) != _cardCount(oldWidget)) {
      _toEnd(animate: true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static int _cardCount(_MessageList w) =>
      w.actionsByMessage.values.fold(0, (n, list) => n + list.length);

  void _toEnd({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        unawaited(_scroll.animateTo(end, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic));
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  /// Bring the oldest message with an undecided card into view.
  void scrollToFirstPending() {
    for (final m in widget.messages) {
      final cards = widget.actionsByMessage[m.id] ?? const <AdaAction>[];
      if (!cards.any((a) => a.status.isPending)) continue;
      final target = _keys[m.id]?.currentContext;
      if (target != null) {
        unawaited(Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), alignment: 0.1));
      } else {
        _toEnd(animate: true);
      }
      return;
    }
  }

  List<Widget> _items() {
    final w = widget;
    final items = <Widget>[];
    for (final m in w.messages) {
      final key = _keys.putIfAbsent(m.id, GlobalKey.new);
      if (m.role == AdaRole.user) {
        items.add(YouSay(key: key, text: m.text));
        if (w.stopped.contains(m.id)) items.add(const AdaStoppedNote());
        continue;
      }
      // A replaced card is history, not a choice: the newer one carries it.
      final cards = [
        for (final a in w.actionsByMessage[m.id] ?? const <AdaAction>[])
          if (a.status != AdaActionStatus.superseded) a,
      ];
      final below = <Widget>[];
      final firstGap = m.text.trim().isEmpty ? 0.0 : 10.0;
      if (m.hasPlan) {
        below.addAll([SizedBox(height: firstGap), AdaApplyPlanButton(onTap: () => w.onApplyPlan(m.id))]);
      }
      for (final a in cards) {
        below
          ..add(SizedBox(height: below.isEmpty ? firstGap : 8))
          ..add(
            AdaProposalCard(
              action: a,
              busy: w.decidingIds.contains(a.id),
              onApprove: () => w.onApprove(a),
              onDecline: () => w.onReject(a),
              onUndo: () => w.onUndo(a),
            ),
          );
      }
      items.add(AdaSay(key: key, text: m.text, below: below));
    }
    if (w.typing) items.add(const AdaThinking());
    if (w.error != null) {
      items.add(
        AdaErrorNote(
          message: w.error!,
          onRetry: w.onRetry,
          onDismiss: w.onDismissError,
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    return ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(16, kAdaEdgeFade + 2, 16, widget.bottomInset),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, i) => items[i],
    );
  }
}
