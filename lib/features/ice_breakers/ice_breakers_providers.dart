import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ice_breakers_service.dart';
import 'ice_breaker.dart';

/// The most unwatched suggestions any surface may show at once.
///
/// The feature exists to fight the overwhelm an empty planner creates. A wall
/// of tutorials would recreate that overwhelm somewhere new, so the shelf shows
/// three and the rest live behind "See all".
const int kMaxShelfRows = 3;

/// What the shelf and the section both render from.
@immutable
class IceBreakersState {
  const IceBreakersState({required this.watchedIds});

  final Set<String> watchedIds;

  /// Still to watch, in curriculum order — the order is the teaching, so it is
  /// never sorted by anything else.
  List<IceBreaker> get unwatched =>
      kIceBreakers.where((b) => !watchedIds.contains(b.id)).toList();

  /// Already watched, collapsed behind a disclosure so the card's height is
  /// stable forever rather than shrinking as the student progresses.
  List<IceBreaker> get watched =>
      kIceBreakers.where((b) => watchedIds.contains(b.id)).toList();

  /// The three the shelf offers.
  List<IceBreaker> get shelf => unwatched.take(kMaxShelfRows).toList();

  /// The one the section leads with — "START HERE" on a fresh install.
  IceBreaker? get next => unwatched.isEmpty ? null : unwatched.first;

  int get watchedCount => watchedIds.length;
  int get total => kIceBreakers.length;

  /// 0..1, for the progress track.
  double get progress => total == 0 ? 0 : watchedCount / total;

  /// Right-aligned on the track, matching the frames.
  int get percent => (progress * 100).round();

  bool get allWatched => watchedCount >= total;

  /// The section changes its own copy at five of six — the last one gets a
  /// line of encouragement rather than another identical row.
  bool get oneLeft => total - watchedCount == 1;
}

/// Reads the local store. Kept as a notifier rather than a plain provider so
/// marking one watched refreshes every surface showing the shelf at once.
final iceBreakersProvider =
    NotifierProvider<IceBreakersController, IceBreakersState>(
  IceBreakersController.new,
);

class IceBreakersController extends Notifier<IceBreakersState> {
  @override
  IceBreakersState build() =>
      IceBreakersState(watchedIds: IceBreakersService.instance.watched);

  /// Called when a video actually finishes, not when it is opened.
  Future<void> markWatched(String id) async {
    if (state.watchedIds.contains(id)) return;
    await IceBreakersService.instance.markWatched(id);
    state = IceBreakersState(watchedIds: IceBreakersService.instance.watched);
  }

  @visibleForTesting
  Future<void> reset() async {
    await IceBreakersService.instance.clear();
    state = const IceBreakersState(watchedIds: {});
  }
}
