import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/app_card.dart';
import '../ice_breaker.dart';
import '../ice_breakers_providers.dart';

/// One tutorial, played.
///
/// The video is silent by design — the instruction is burned into the frame,
/// because students watch these in libraries and lectures where sound is not an
/// option. So there are no volume controls and nothing to mute.
class IceBreakerScreen extends ConsumerStatefulWidget {
  const IceBreakerScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<IceBreakerScreen> createState() => _IceBreakerScreenState();
}

class _IceBreakerScreenState extends ConsumerState<IceBreakerScreen> {
  VideoPlayerController? _controller;
  IceBreaker? _breaker;
  bool _ready = false;
  bool _failed = false;
  bool _marked = false;

  @override
  void initState() {
    super.initState();
    _breaker = iceBreakerById(widget.id);
    final breaker = _breaker;
    if (breaker != null) unawaited(_open(breaker));
  }

  Future<void> _open(IceBreaker breaker) async {
    final controller = VideoPlayerController.asset(breaker.asset);
    _controller = controller;
    try {
      await controller.initialize();
      controller.addListener(_onTick);
      // Autoplay is right *here* and wrong on the shelf: opening this screen is
      // already the student saying yes.
      //
      // Deliberately not looping. A looping clip wraps its position back to
      // zero the instant it ends, so the end is only ever visible between two
      // listener ticks — the watched flag then depends on winning a race, and
      // usually loses. Stopping on the last frame makes the end unmissable, and
      // a finished tutorial that sits still is better behaviour anyway.
      await controller.setLooping(false);
      await controller.play();
      if (mounted) setState(() => _ready = true);
    } on Object {
      // A missing or unplayable asset must not take the screen down with it.
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Marked watched only once the student has actually reached the end.
  ///
  /// Opening is not watching: a card that ticks itself the moment you tap it
  /// would make the progress bar a lie, and the bar is the one number this
  /// feature asks anyone to trust.
  void _onTick() {
    final controller = _controller;
    if (controller == null || _marked || !controller.value.isInitialized) return;
    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;
    // Slightly short of the end: the final frame is not always reported, and
    // playback stops a few milliseconds early often enough to matter.
    final ended = position >= duration - const Duration(milliseconds: 400);
    if (!ended) return;
    _marked = true;
    unawaited(ref.read(iceBreakersProvider.notifier).markWatched(widget.id));
    if (mounted) setState(() {});
  }

  /// Watch it again from the top.
  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(Duration.zero);
    await controller.play();
    if (mounted) setState(() {});
  }

  bool get _finished {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return false;
    final value = controller.value;
    return value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 400);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final breaker = _breaker;

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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.pop(),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                        boxShadow: colors.cardShadow,
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        size: 24,
                        color: colors.text,
                      ),
                    ),
                  ),
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
              child: breaker == null
                  ? _Missing(colors: colors)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Stage(
                                controller: _controller,
                                ready: _ready,
                                failed: _failed,
                                finished: _finished,
                                onReplay: _replay,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    breaker.number,
                                    style: AppText.sans(
                                      size: 14,
                                      weight: FontWeight.w800,
                                      color: colors.textDim,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      breaker.title,
                                      style: AppText.sans(
                                        size: 21,
                                        weight: FontWeight.w800,
                                        height: 1.15,
                                        color: colors.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    breaker.runtime,
                                    style: AppText.sans(
                                      size: 15,
                                      weight: FontWeight.w800,
                                      color: colors.textMed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                breaker.blurb,
                                style: AppText.sans(
                                  size: 15.5,
                                  height: 1.45,
                                  color: colors.textMed,
                                ),
                              ),
                            ],
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
}

/// The 9:16 stage. Holds its shape before the first frame arrives so the page
/// does not jump when playback starts.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.controller,
    required this.ready,
    required this.failed,
    required this.finished,
    required this.onReplay,
  });

  final VideoPlayerController? controller;
  final bool ready;
  final bool failed;
  final bool finished;
  final Future<void> Function() onReplay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final player = controller;
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Builder(
          builder: (context) {
            if (failed || player == null) {
              return Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  size: 34,
                  color: colors.textDim,
                ),
              );
            }
            if (!ready) {
              return Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: colors.accent,
                  ),
                ),
              );
            }
            return GestureDetector(
              onTap: () {
                if (finished) {
                  unawaited(onReplay());
                } else if (player.value.isPlaying) {
                  unawaited(player.pause());
                } else {
                  unawaited(player.play());
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: player.value.size.width,
                      height: player.value.size.height,
                      child: VideoPlayer(player),
                    ),
                  ),
                  if (finished)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: const Center(
                        child: Icon(
                          Icons.replay,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A deep link to a video that no longer exists. The router has no
/// `errorBuilder`, so this is handled here rather than as a crash.
class _Missing extends StatelessWidget {
  const _Missing({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          "That one isn't here any more.",
          textAlign: TextAlign.center,
          style: AppText.sans(size: 16, color: colors.textMed),
        ),
      ),
    );
  }
}
