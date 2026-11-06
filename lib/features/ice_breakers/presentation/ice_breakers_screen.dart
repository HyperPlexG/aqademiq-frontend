import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/circle_back_button.dart';
import '../../../shared/widgets/ic.dart';
import '../ice_breaker.dart';
import '../ice_breakers_providers.dart';
import 'ice_breakers_card.dart';

/// The whole series, behind "See all" (v11 `ib-section-s` / `ib-watched`).
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
    final rest = _rest(state);
    // Day 0 is six items in order and nothing else: no tally of zero, no
    // promise of more. Both arrive once something has been watched.
    final started = state.watchedCount > 0;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IceBreakersHead(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (state.allWatched)
                    const _AllWatchedBanner()
                  else if (state.oneLeft)
                    const _OneLeftBanner()
                  else if (state.next != null && !started)
                    _StartHereHero(breaker: state.next!),

                  // On a first visit the hero already carries #01, so it is not
                  // repeated in the list beneath it.
                  if (rest.isNotEmpty || started) ...[
                    SizedBox(height: started ? 10 : 9),
                    AppCard(
                      padding: started
                          ? const EdgeInsets.fromLTRB(14, 6, 14, 12)
                          : const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      child: Column(
                        children: [
                          for (final breaker in rest) ...[
                            IceBreakerRow(breaker: breaker, tight: !started),
                            if (breaker != rest.last) const IceBreakerRowDivider(),
                          ],
                          if (started) ...[
                            if (rest.isNotEmpty) const SizedBox(height: 2),
                            _WatchedDisclosure(state: state, first: rest.isEmpty),
                            const SizedBox(height: 8),
                            IceBreakersProgress(state: state),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (started) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'More coming soon',
                        style: AppText.sans(size: 13, weight: FontWeight.w700, color: colors.textDim),
                      ),
                    ),
                  ],
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

/// The section pages' head (v11 `IBHead`): the 44 back button and a 22 title.
class IceBreakersHead extends StatelessWidget {
  const IceBreakersHead({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          CircleBackButton(onTap: onBack),
          const SizedBox(width: 12),
          Text(
            'Ice Breakers',
            style: AppText.sans(size: 22, weight: FontWeight.w800, color: context.colors.text),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(11),
      onTap: () => unawaited(context.push(Routes.iceBreaker(breaker.id))),
      child: Row(
        children: [
          // The poster: a portrait still with the play badge, never a band.
          Container(
            width: 44,
            height: 64,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const AdaMascot(size: 26, bubbles: 2),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xD1111111), shape: BoxShape.circle),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 1),
                      child: Ic('play', size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.ink,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'START HERE',
                        style: AppText.sans(
                          size: 11,
                          weight: FontWeight.w800,
                          letterSpacing: AppText.em(0.08, 11),
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${breaker.number} · ${breaker.runtime}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(
                          size: 12,
                          weight: FontWeight.w800,
                          letterSpacing: AppText.em(0.04, 12),
                          color: colors.textDim,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  breaker.title,
                  style: AppText.sans(
                    size: 17,
                    weight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.2,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  breaker.blurb,
                  style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.4, color: colors.textMed),
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
      child: Row(
        children: [
          const AdaMascot(size: 34, bubbles: 2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.sans(size: 17, weight: FontWeight.w800, height: 1.25, color: colors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.45, color: colors.textMed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Watched items, folded away (v11 `IBWatchedDisclosure`).
///
/// They collapse rather than disappear so the list's height is stable and the
/// student can still find something they have already seen.
class _WatchedDisclosure extends StatefulWidget {
  const _WatchedDisclosure({required this.state, this.first = false});

  final IceBreakersState state;

  /// Nothing above it in the card, so no hairline on top.
  final bool first;

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
        Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: widget.first ? null : Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  Ic(_open ? 'chevron_up' : 'chevron_down', size: 20, color: colors.textDim),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watched (${watched.length})',
                      style: AppText.sans(size: 13, weight: FontWeight.w700, color: colors.textMed),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          for (final breaker in watched) ...[
            if (breaker != watched.first) const IceBreakerRowDivider(),
            IceBreakerRow(breaker: breaker),
          ],
      ],
    );
  }
}
