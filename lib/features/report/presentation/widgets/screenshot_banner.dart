import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/models/weekly_report.dart';
import '../../../../shared/widgets/ic.dart';
import '../../report_copy.dart';
import '../share_shape_sheet.dart';

/// v11 `core-screenshot`: the student took a screenshot of their week.
///
/// Non-blocking — it drops in under the status bar, leaves the system's own
/// thumbnail alone, and the screen eases it away after a few seconds. It offers
/// the tag, and the clean story card instead of the screenshot: a screenshot of
/// the core carries its mood tint, and the card is built without one.
class ScreenshotBanner extends StatelessWidget {
  const ScreenshotBanner({
    super.key,
    required this.report,
    required this.tagCopied,
    required this.onCopyTag,
    required this.onUseCard,
    required this.onDismiss,
  });

  final WeeklyReport report;

  /// The tag has just been copied: the pill says so.
  final bool tagCopied;
  final VoidCallback onCopyTag;
  final VoidCallback onUseCard;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = AppText.sans(size: 15, weight: FontWeight.w500, height: 1.45, color: colors.textMed);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: const [BoxShadow(color: Color(0x33140F28), blurRadius: 44, offset: Offset(0, 14))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The card itself, small: what "Use story card" will send.
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: StoryCard.width * 0.125,
                  height: StoryCard.height * 0.125,
                  child: FittedBox(child: StoryCard(report: shapeOnly(report))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ReportCopy.screenshotTitle,
                        style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          text: ReportCopy.screenshotLead,
                          style: body,
                          children: [
                            TextSpan(
                              text: ReportCopy.storyHandle,
                              style: AppText.sans(size: 15, weight: FontWeight.w800, height: 1.45, color: colors.accent),
                            ),
                            const TextSpan(text: ReportCopy.screenshotTail),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // A 44 target that overhangs the corner, so the ✕ sits on the
              // card's padding line without making the row taller.
              Transform.translate(
                offset: const Offset(6, -6),
                child: Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).closeButtonTooltip,
                  excludeSemantics: true,
                  // excludeSemantics drops the child's tap, so give it here too.
                  onTap: onDismiss,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(child: Ic('close', size: 20, color: colors.textMed)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: _BannerPill(
                  icon: tagCopied ? 'check' : 'duplicate',
                  label: tagCopied ? ReportCopy.tagCopied : ReportCopy.copyTag,
                  onTap: onCopyTag,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 13,
                child: _BannerPill(icon: 'share', label: ReportCopy.useStoryCard, ink: true, onTap: onUseCard),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// BarPill at 15: `fill="well"` or `fill="ink"`, 44 high.
class _BannerPill extends StatelessWidget {
  const _BannerPill({required this.icon, required this.label, required this.onTap, this.ink = false});

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool ink;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = ink ? Colors.white : colors.text;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: ink ? colors.ink : colors.bg,
            borderRadius: BorderRadius.circular(22),
          ),
          // Shrinks rather than overflows on a 320pt phone, where the two
          // pills share about 260pt.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ic(icon, size: 19, color: fg),
                const SizedBox(width: 6),
                Text(label, style: AppText.sans(size: 15, weight: FontWeight.w700, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
