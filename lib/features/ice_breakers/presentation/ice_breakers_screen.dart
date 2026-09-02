import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_card.dart';
import '../ice_breaker.dart';
import '../ice_breakers_providers.dart';
import 'ice_breakers_card.dart';

/// The whole series, behind "See all".
///
/// Four states, and the copy is the difference between them: the first visit
/// leads with START HERE, the middle ones just list what is left, the fifth
/// gets a line of encouragement, and a finished series says so rather than
/// showing an empty list.
class IceBreakersScreen extends ConsumerWidget {
  const IceBreakersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(iceBreakersProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _BackCircle(onTap: () => context.pop()),
                  const SizedBox(width: 14),
                  Text(
                    'Ice Breakers',
                    style: AppText.sans(
                      size: 26,
                      weight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  if (state.allWatched)
                    const _AllWatchedBanner()
                  else if (state.oneLeft)
                    const _OneLeftBanner()
                  else if (state.next != null && state.watchedCount == 0)
                    _StartHereHero(breaker: state.next!),

                  // On a first visit the hero already carries #01, so it is not
                  // repeated in the list beneath it.
                  if (_rest(state).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          for (final breaker in _rest(state)) ...[
                            IceBreakerRow(breaker: breaker),
                            if (breaker != _rest(state).last)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: colors.border,
                              ),
                          ],
                          if (state.watchedCount > 0) ...[
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: colors.border,
                            ),
                            _WatchedDisclosure(state: state),
                          ],
                          const SizedBox(height: 14),
                          IceBreakersProgress(state: state),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Center(
                    child: Text(
                      'More coming soon',
                      style: AppText.sans(
                        size: 15,
                        weight: FontWeight.w700,
                        color: colors.textDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What the list shows beneath any banner: everything still to watch, minus
  /// the one already promoted into the START HERE hero.
  List<IceBreaker> _rest(IceBreakersState state) {
    if (state.watchedCount == 0 && state.unwatched.isNotEmpty) {
      return state.unwatched.skip(1).toList();
    }
    return state.unwatched;
  }
}

/// The first visit. One video is singled out so the student has exactly one
/// thing to do — the same argument the whole series makes about tasks.
class _StartHereHero extends StatelessWidget {
  const _StartHereHero({required this.breaker});

  final IceBreaker breaker;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => unawaited(context.push(Routes.iceBreaker(breaker.id))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 74,
            height: 84,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const AdaMascot(size: 40),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2B2B2B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.text,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'START HERE',
                        style: AppText.sans(
                          size: 11,
                          weight: FontWeight.w800,
                          letterSpacing: AppText.em(0.04, 11),
                          color: colors.bg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${breaker.number} · ${breaker.runtime}',
                      style: AppText.sans(
                        size: 13,
                        weight: FontWeight.w700,
                        color: colors.textDim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  breaker.title,
                  style: AppText.sans(
                    size: 18,
                    weight: FontWeight.w800,
                    height: 1.15,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  breaker.blurb,
                  style: AppText.sans(
                    size: 13.5,
                    height: 1.35,
                    color: colors.textMed,
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

/// Five of six. The last one earns a sentence rather than another identical
/// row — and the promise is kept small: "for now", not "you're done".
class _OneLeftBanner extends StatelessWidget {
  const _OneLeftBanner();

  @override
  Widget build(BuildContext context) => const _Banner(
        title: 'One left in the first session',
        body: "Then that's all of them, for now.",
      );
}

class _AllWatchedBanner extends StatelessWidget {
  const _AllWatchedBanner();

  @override
  Widget build(BuildContext context) => const _Banner(
        title: "That's the first session",
        body: 'Ada will add more as you go.',
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const AdaMascot(size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.sans(
                    size: 17,
                    weight: FontWeight.w800,
                    height: 1.2,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: AppText.sans(size: 14, color: colors.textMed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Watched items, folded away.
///
/// They collapse rather than disappear so the list's height is stable and the
/// student can still find something they have already seen.
class _WatchedDisclosure extends StatefulWidget {
  const _WatchedDisclosure({required this.state});

  final IceBreakersState state;

  @override
  State<_WatchedDisclosure> createState() => _WatchedDisclosureState();
}

class _WatchedDisclosureState extends State<_WatchedDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final watched = widget.state.watched;
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: colors.textMed,
                ),
                const SizedBox(width: 10),
                Text(
                  'Watched (${watched.length})',
                  style: AppText.sans(
                    size: 15,
                    weight: FontWeight.w700,
                    color: colors.textMed,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          for (final breaker in watched) IceBreakerRow(breaker: breaker),
      ],
    );
  }
}

class _BackCircle extends StatelessWidget {
  const _BackCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: colors.cardShadow,
        ),
        child: Icon(Icons.chevron_left, size: 24, color: colors.text),
      ),
    );
  }
}
