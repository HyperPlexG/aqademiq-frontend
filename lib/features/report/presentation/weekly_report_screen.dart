import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/weekly_report.dart';
import '../../../data/repositories/weekly_report_repository.dart';
import '../../../shared/widgets/ic.dart';
import '../../freeze/domain/freeze_models.dart';
import '../../freeze/providers/freeze_controller.dart';
import '../report_copy.dart';
import '../report_screenshots.dart';
import '../report_thaws.dart';
import 'share_shape_sheet.dart';
import 'widgets/report_beats.dart';
import 'widgets/screenshot_banner.dart';

/// The weekly report — up to nine beats, story first and evidence second.
///
/// A pager rather than a scroll, and that is the design rather than a
/// preference. A dashboard puts everything on screen at once and asks the
/// reader to work out what it means; a sequence decides what they read first.
/// This one opens on one sentence about the *shape* of the week and shows a
/// single count only after it, which is the difference between a report that
/// describes a week and a report that grades one.
///
/// Everything after beat 3 is conditional: a beat with nothing true to say is
/// absent, and the page dots shrink with it. That includes "When you thawed",
/// the one beat drawn from the phone rather than the server: it is there only
/// when App freeze is set up and the week holds a thaw. Nothing is greyed
/// out and nothing renders as a zero, because a greyed card still tells you
/// that something was supposed to be there and you did not do it.
///
/// What deliberately does not exist here:
///
///  * No date picker and no back-browsing. Scrolling through past weeks is a
///    rumination affordance, and the provider has no way to name another week.
///  * No percentage, rate, change, or `x of y` anywhere. Every number on this
///    screen is a count of things that happened.
///  * No account prompt. A guest's week is a real week, and "sign up to see
///    your full week" monetises a student's curiosity about themselves.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  final _pager = PageController();
  int _page = 0;
  bool _supportDismissed = false;

  /// Dots while the week loads: the most beats a week can have.
  static const _maxBeats = 9;

  /// The drilling beat holds for at least this long even if the request comes
  /// back sooner, so the core is seen forming rather than flashing.
  static const _minDrill = Duration(milliseconds: 1450);

  /// Started with the screen, not with the data: a lazy field would only
  /// start counting when the week arrived, and hold a fast answer for the
  /// whole minimum on top of the wait.
  final Future<void> _drilled = Future<void>.delayed(_minDrill);

  /// A screenshot was just taken (`core-screenshot`): the banner is up.
  bool _shot = false;
  bool _tagCopied = false;
  Timer? _shotTimer;

  /// How long the banner stays before it eases away on its own.
  static const _shotHold = Duration(seconds: 6);

  /// A screenshot older than this when it reaches the screen was taken of
  /// something else (the share screen, pushed over the report).
  static const _shotFresh = Duration(seconds: 2);

  @override
  void dispose() {
    _shotTimer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  void _showShot() {
    _shotTimer?.cancel();
    _shotTimer = Timer(_shotHold, _hideShot);
    setState(() {
      _shot = true;
      _tagCopied = false;
    });
  }

  void _hideShot() {
    _shotTimer?.cancel();
    _shotTimer = null;
    if (mounted && _shot) setState(() => _shot = false);
  }

  Future<void> _copyTag() async {
    await Clipboard.setData(const ClipboardData(text: ReportCopy.storyHandle));
    if (!mounted) return;
    // Held a little longer, so the student sees it took.
    _shotTimer?.cancel();
    _shotTimer = Timer(_shotHold, _hideShot);
    setState(() => _tagCopied = true);
  }

  void _useCard(WeeklyReport report) {
    _hideShot();
    unawaited(showShareShapeSheet(context, report));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final async = ref.watch(weeklyReportProvider);
    // App freeze's thaws, read off the phone (the log is device-local and keeps
    // about 15 days, which always covers the week being read).
    final freeze = ref.watch(freezeControllerProvider);
    // Screenshots, heard only while this screen is mounted: the provider is
    // auto-disposed, and lets go of the channel when the report closes.
    ref.listen<AsyncValue<DateTime>>(reportScreenshotProvider, (_, next) {
      final heardAt = next.value;
      if (heardAt == null) return;
      // Only a screenshot of the report: fresh, and with the report the page
      // in front. A listener whose screen is covered can be paused (Riverpod
      // 3), and then a screenshot of the share screen is handed over late, on
      // the pop — with the report in front again, so only its age gives it
      // away.
      final fresh = DateTime.now().difference(heardAt) < _shotFresh;
      if (fresh && (ModalRoute.of(context)?.isCurrent ?? true)) _showShot();
    });
    final report = async.value;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _content(context, async, freeze)),
            // Non-blocking: under the status bar, over the story, never in
            // front of the ✕ for longer than it takes to read.
            Positioned(
              top: 4,
              left: 12,
              right: 12,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, -0.25), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: _shot && report != null
                    ? ScreenshotBanner(
                        key: const ValueKey('screenshot-banner'),
                        report: report,
                        tagCopied: _tagCopied,
                        onCopyTag: () => unawaited(_copyTag()),
                        onUseCard: () => _useCard(report),
                        onDismiss: _hideShot,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AsyncValue<WeeklyReport> week, FreezeData freeze) {
    return week.when(
      loading: () => _Shell(
        pageCount: _maxBeats,
        page: 0,
        onClose: () => _close(context),
        child: const BeatDrilling(),
      ),
      error: (_, _) => _Shell(
        pageCount: 1,
        page: 0,
        onClose: () => _close(context),
        child: _Failed(onRetry: () => ref.invalidate(weeklyReportProvider)),
      ),
      data: (report) => FutureBuilder<void>(
        future: _drilled,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _Shell(
              pageCount: _maxBeats,
              page: 0,
              onClose: () => _close(context),
              child: BeatDrilling(days: report.days),
            );
          }
          return _story(context, report, freeze);
        },
      ),
    );
  }

  Widget _story(BuildContext context, WeeklyReport report, FreezeData freeze) {
    final beats = _beatsFor(report, freeze);
    return _Shell(
      pageCount: beats.length,
      page: _page.clamp(0, beats.length - 1),
      onClose: () => _close(context),
      banner: _showSupport(report) && !_supportDismissed
          ? SupportBanner(
              onView: () => _close(context),
              onDismiss: () => setState(() => _supportDismissed = true),
            )
          : null,
      child: PageView(
        controller: _pager,
        onPageChanged: (i) => setState(() => _page = i),
        children: beats,
      ),
    );
  }

  /// Only the beats this week can honestly fill.
  List<Widget> _beatsFor(WeeklyReport r, FreezeData freeze) {
    final subjectsById = {for (final s in r.subjects) s.id: s};
    final momentSubject = r.moment?.subjectId == null ? null : subjectsById[r.moment!.subjectId];

    // Laid on the report's own days, so the beat reads the same week the
    // core does.
    final thaws = thawsByDay(r.days, freeze.thawLog);

    final texture = <(String, String)>[
      if (r.longestSession != null) (ReportCopy.longestTitle, ReportCopy.longest(r.longestSession!)),
      if (r.heldMinutes > 0) (ReportCopy.heldTitle, ReportCopy.held(r.heldMinutes)),
      if (r.rhythmWeekdays.isNotEmpty) (ReportCopy.rhythmTitle, ReportCopy.rhythm(r.rhythmWeekdays)),
      if (r.prismMix.isNotEmpty)
        (ReportCopy.prismTitle, r.prismMix.map((m) => m.name).join(' · ')),
    ];

    return [
      BeatShape(shape: r.shape),
      BeatCore(report: r),
      if (r.moment != null)
        BeatMoment(
          moment: r.moment!,
          subjectName: momentSubject?.name,
          subjectColor: momentSubject?.colorHex,
        ),
      // The week's own count, not the lifetime one. A weekly report headlining
      // a lifetime total is not a weekly report, and a number above 7 above a
      // seven-band core reads as a mistake.
      BeatNumeral(value: r.activeDays),
      if (r.subjects.isNotEmpty) BeatAttention(report: r),
      if (showThawedBeat(freezeSetUp: freeze.setUp, thaws: thaws)) BeatThawed(days: r.days, thaws: thaws),
      if (r.recovery != null) BeatRecovery(recovery: r.recovery!),
      if (texture.isNotEmpty) BeatTexture(rows: texture),
      BeatLanding(
        isEmptyWeek: r.isEmpty,
        onKeep: () => _close(context),
        onShare: () => unawaited(showShareShapeSheet(context, r)),
        onDismiss: () => _close(context),
      ),
    ];
  }

  /// A run of empty weeks is a bad season, not a bad week. The banner is the
  /// only response: no escalation, no advice, and Ada stays out of it.
  ///
  /// Approximated from the current week alone for now — a week with nothing at
  /// all and no lifetime history behind it. The real rule needs several
  /// consecutive weeks, which needs history the report deliberately does not
  /// fetch, so this errs towards showing it rarely rather than often.
  bool _showSupport(WeeklyReport r) => r.isEmpty && r.daysOnBoard > 0;

  void _close(BuildContext context) => Navigator.of(context).maybePop();
}

/// Chrome shared by every state: the close affordance and the page dots.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.child,
    required this.pageCount,
    required this.page,
    required this.onClose,
    this.banner,
  });

  final Widget child;
  final int pageCount;
  final int page;
  final VoidCallback onClose;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        // CoreTop: a way out, and where you are in the story.
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 22, 10),
          child: Row(
            children: [
              // Leaving is one tap and always in the same place. A story you
              // have to finish is a story that can corner someone. A bare 20
              // glyph on a 44 target, so leaving never out-shouts the story.
              IconButton(
                onPressed: onClose,
                icon: Ic('close', size: 20, color: colors.textMed),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              ),
              Expanded(child: _Dots(count: pageCount, active: page)),
              const SizedBox(width: 32),
            ],
          ),
        ),
        Expanded(child: child),
        ?banner,
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idle = dark ? colors.textDim.withValues(alpha: 0.4) : const Color(0xFFE0E0E0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 5),
            width: i == active ? 22 : 6,
            height: 4,
            decoration: BoxDecoration(
              color: i == active ? colors.accent : idle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ReportCopy.loadFailed,
              textAlign: TextAlign.center,
              style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.45, color: colors.text),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                ReportCopy.retry,
                style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
