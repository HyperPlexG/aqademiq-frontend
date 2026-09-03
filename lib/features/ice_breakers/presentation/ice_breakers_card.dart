import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/app_card.dart';
import '../ice_breaker.dart';
import '../ice_breakers_providers.dart';

/// The Ice Breakers shelf, as it appears on the profile.
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
      // No padding override: the app's standard card padding, which is what
      // every other card on this screen sits at.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ice Breakers',
                style: AppText.sans(
                  size: 14,
                  weight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(context.push(Routes.iceBreakers)),
                child: Row(
                  children: [
                    Text(
                      'See all',
                      style: AppText.sans(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 13, color: colors.accent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final breaker in state.shelf) ...[
            IceBreakerRow(breaker: breaker),
            if (breaker != state.shelf.last)
              Divider(height: 1, thickness: 1, color: colors.border),
          ],
          if (state.shelf.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Text(
                "That's all of them, for now.",
                style: AppText.sans(size: 11.5, color: colors.textMed),
              ),
            ),
          const SizedBox(height: 10),
          IceBreakersProgress(state: state),
        ],
      ),
    );
  }
}

/// One row: play affordance, title, `01 · Plan`, and the runtime.
///
/// The runtime is on every row on purpose — "22s" does more to earn a tap than
/// any thumbnail could, and it is the honest answer to the only question a
/// student has about a tutorial when they are avoiding work.
class IceBreakerRow extends ConsumerWidget {
  const IceBreakerRow({required this.breaker, super.key});

  final IceBreaker breaker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final watched = ref.watch(
      iceBreakersProvider.select((s) => s.watchedIds.contains(breaker.id)),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(context.push(Routes.iceBreaker(breaker.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: watched ? 0.12 : 0.28),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                watched ? Icons.check : Icons.play_arrow,
                size: watched ? 14 : 16,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    breaker.title,
                    style: AppText.sans(
                      size: 12.5,
                      weight: FontWeight.w800,
                      height: 1.2,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${breaker.number} · ${breaker.where}',
                    style: AppText.sans(size: 10.5, color: colors.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              breaker.runtime,
              style: AppText.sans(
                size: 11.5,
                weight: FontWeight.w800,
                color: colors.textMed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The track, the count and the percentage.
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
          height: 6,
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: state.progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${state.watchedCount} of ${state.total} watched',
              style: AppText.sans(size: 10.5, color: colors.textMed),
            ),
            const Spacer(),
            Text(
              '${state.percent}%',
              style: AppText.sans(
                size: 11,
                weight: FontWeight.w800,
                color: colors.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
