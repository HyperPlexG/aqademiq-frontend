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
    if (!_isEnd(controller.value)) return;
    _marked = true;
    unawaited(ref.read(iceBreakersProvider.notifier).markWatched(widget.id));
  }

  /// Play, pause, or start again from the top once it has finished.
  Future<void> _toggle() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isEnd(controller.value)) {
      await controller.seekTo(Duration.zero);
      await controller.play();
    } else if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  _BackCircle(onTap: () => context.pop()),
                  const SizedBox(width: 12),
                  Text(
                    'Ice Breakers',
                    style: AppText.sans(
                      size: 20,
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
                  // Deliberately not a scroll view. Everything here has to be
                  // on screen at once: a portrait recording at its true ratio
                  // is around 750pt tall, which pushed the transport controls
                  // under the fold — and controls you have to go looking for
                  // are the same as no controls at all. The video takes the
                  // room that is left over instead of dictating the layout.
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Above the video, so the student can see what
                            // they are watching without hunting for a caption
                            // somewhere past the bottom of a tall frame.
                            Text(
                              '${breaker.number} · ${breaker.where}',
                              style: AppText.sans(
                                size: 10.5,
                                weight: FontWeight.w700,
                                color: colors.textDim,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              breaker.title,
                              style: AppText.sans(
                                size: 16,
                                weight: FontWeight.w800,
                                height: 1.2,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Center(
                                child: _Stage(
                                  controller: _controller,
                                  ready: _ready,
                                  failed: _failed,
                                  onToggle: _toggle,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (_ready && _controller != null)
                              _Transport(
                                controller: _controller!,
                                onToggle: _toggle,
                              ),
                            const SizedBox(height: 6),
                            Text(
                              breaker.blurb,
                              style: AppText.sans(
                                size: 12.5,
                                height: 1.45,
                                color: colors.textMed,
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

/// Playback has reached the end.
///
/// Deliberately short of the true end: the final frame is not always reported,
/// and playback stops a few milliseconds early often enough to matter.
bool _isEnd(VideoPlayerValue value) =>
    value.duration > Duration.zero &&
    value.position >= value.duration - const Duration(milliseconds: 400);

/// `0:07`. Minutes never reach two digits here — the longest video is 25s — but
/// the format stays honest if a longer one is ever added.
String _clock(Duration d) {
  final seconds = d.inSeconds.clamp(0, 59 * 60);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// The video itself, at the file's own aspect ratio.
///
/// Taken from the controller rather than assumed: the recordings are 900×1956,
/// which is taller than 9:16, and forcing them into a 9:16 box cropped a strip
/// off the top and bottom of every one — losing the very chrome the tutorial is
/// pointing at.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.controller,
    required this.ready,
    required this.failed,
    required this.onToggle,
  });

  final VideoPlayerController? controller;
  final bool ready;
  final bool failed;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final player = controller;

    if (failed || player == null || !ready) {
      return AspectRatio(
        // The shipped recordings' ratio, so the page does not jump when the
        // first frame arrives.
        aspectRatio: 900 / 1956,
        child: _Frame(
          colors: colors,
          child: Center(
            child: failed || player == null
                ? Icon(
                    Icons.videocam_off_outlined,
                    size: 26,
                    color: colors.textDim,
                  )
                : SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colors.accent,
                    ),
                  ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: player.value.aspectRatio,
      child: _Frame(
        colors: colors,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(onToggle()),
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: player,
            builder: (context, value, child) {
              final paused = !value.isPlaying;
              return Stack(
                fit: StackFit.expand,
                children: [
                  child!,
                  // Tapping the frame used to pause with no sign that anything
                  // had happened — a still tutorial is indistinguishable from a
                  // broken one. A paused video now says so on its face.
                  if (paused)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.28),
                      child: Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isEnd(value) ? Icons.replay : Icons.play_arrow,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            child: VideoPlayer(player),
          ),
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.colors, required this.child});

  final AppColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withValues(alpha: 0.30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Play/pause, a scrubbable bar, and the time.
///
/// Under the video rather than floating over it: an overlay that fades away is
/// exactly what leaves a student unsure whether the thing is playing, and there
/// is nothing here worth hiding the bottom of the frame for.
class _Transport extends StatelessWidget {
  const _Transport({required this.controller, required this.onToggle});

  final VideoPlayerController controller;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final ended = _isEnd(value);
        return Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(onToggle()),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  ended
                      ? Icons.replay
                      : value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                  size: 16,
                  color: colors.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // Scrubbing is on: 25 seconds is short enough that the useful
              // gesture is going back a few to re-read a step, and a bar that
              // only reports position invites a tap that does nothing.
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 11),
                colors: VideoProgressColors(
                  playedColor: colors.accent,
                  bufferedColor: colors.accent.withValues(alpha: 0.22),
                  backgroundColor: colors.bg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${_clock(value.position)} / ${_clock(value.duration)}',
              style: AppText.numeral(size: 11, color: colors.textMed),
            ),
          ],
        );
      },
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
        padding: const EdgeInsets.all(28),
        child: Text(
          "That one isn't here any more.",
          textAlign: TextAlign.center,
          style: AppText.sans(size: 12.5, color: colors.textMed),
        ),
      ),
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
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: colors.cardShadow,
        ),
        child: Icon(Icons.chevron_left, size: 21, color: colors.text),
      ),
    );
  }
}
