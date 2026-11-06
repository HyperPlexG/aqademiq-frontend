import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/ic.dart';
import '../ice_breaker.dart';
import '../ice_breakers_providers.dart';

/// The first session's tier tones (v11 `IB_TIERS.S` = `CUBE_TONES[4]`): the
/// vivid end of Ada's ramp, the same in light and dark, like the ice.
abstract final class IceBreakerTone {
  static const Color border = Color(0xFF5A44F1);
  static const Color body = Color(0xFFCBBCFD);
  static const Color ink = Color(0xFF31237C);
}

/// The Ice Breakers shelf, as it appears on the profile (v11 `ib-profile-card`
/// and, for a guest, `ib-guest` — at full contrast, never locked).
///
/// A shelf, not a notification: no autoplay, no badge, no red dot. It sits
/// directly above the share hero and is permanent — never dismissible — because
/// the student who needs it most is the one who has not worked out that it is
/// there.
///
/// Height is deliberately stable. Watched items collapse into a disclosure
/// rather than vanishing, so the card does not shrink as the student
/// progresses and move everything below it around.
class IceBreakersCard extends ConsumerWidget {
  const IceBreakersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(iceBreakersProvider);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: IceBreakerTone.border, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ice Breakers',
                  style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
                ),
              ),
              Semantics(
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(context.push(Routes.iceBreakers)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See all',
                          style: AppText.sans(size: 13, weight: FontWeight.w700, color: colors.accent),
                        ),
                        const SizedBox(width: 1),
                        Ic('chevron_right', size: 15, color: colors.accent),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final breaker in state.shelf) ...[
            IceBreakerRow(breaker: breaker),
            if (breaker != state.shelf.last) const IceBreakerRowDivider(),
          ],
          if (state.shelf.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Text(
                "That's all of them, for now.",
                style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
              ),
            ),
          const SizedBox(height: 9),
          Divider(height: 1, thickness: 1, color: colors.border),
          const SizedBox(height: 10),
          IceBreakersProgress(state: state),
        ],
      ),
    );
  }
}

/// The hairline between rows, starting past the play disc (v11 `IBRow`).
class IceBreakerRowDivider extends StatelessWidget {
  const IceBreakerRowDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Divider(height: 1, thickness: 1, color: context.colors.border),
      );
}

/// One row (v11 `IBRow`): play disc, title, `01 · Plan`, and the runtime.
/// [tight] is the section page's denser rhythm.
///
/// The runtime is on every row on purpose — "22s" does more to earn a tap than
/// any thumbnail could, and it is the honest answer to the only question a
/// student has about a tutorial when they are avoiding work.
class IceBreakerRow extends ConsumerWidget {
  const IceBreakerRow({required this.breaker, this.tight = false, super.key});

  final IceBreaker breaker;
  final bool tight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final watched = ref.watch(
      iceBreakersProvider.select((s) => s.watchedIds.contains(breaker.id)),
    );
    void open() => unawaited(context.push(Routes.iceBreaker(breaker.id)));

    return Semantics(
      button: true,
      label: '${breaker.title}, ${breaker.runtime}${watched ? ', watched' : ''}',
      excludeSemantics: true,
      onTap: open,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.symmetric(vertical: tight ? 7 : 9),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: watched ? colors.hilite : IceBreakerTone.body,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Ic(
                  watched ? 'check' : 'play_arrow',
                  size: 16,
                  color: watched ? colors.textMed : IceBreakerTone.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      breaker.title,
                      style: AppText.sans(
                        size: 15,
                        weight: FontWeight.w800,
                        height: 1.25,
                        color: watched ? colors.textMed : colors.text,
                      ).copyWith(
                        decoration: watched ? TextDecoration.lineThrough : null,
                        decorationColor: colors.textMed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${breaker.number} · ${breaker.where}',
                      style: AppText.sans(
                        size: 12,
                        weight: FontWeight.w700,
                        letterSpacing: AppText.em(0.04, 12),
                        color: colors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                breaker.runtime,
                style: AppText.sans(
                  size: 13,
                  weight: FontWeight.w800,
                  color: watched ? colors.textDim : colors.textMed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The track, the count and the percentage (v11 `IBProgress`).
///
/// Counted against all six rather than against anything unlocked, so the
/// number is never a moving goalpost.
class IceBreakersProgress extends StatelessWidget {
  const IceBreakersProgress({required this.state, super.key});

  final IceBreakersState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 5,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: state.progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${state.watchedCount} of ${state.total} watched',
              style: AppText.sans(size: 12, weight: FontWeight.w700, color: colors.textMed),
            ),
            const Spacer(),
            Text(
              '${state.percent}%',
              style: AppText.sans(size: 12, weight: FontWeight.w800, color: colors.accent),
            ),
          ],
        ),
      ],
    );
  }
}
