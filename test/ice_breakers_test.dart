import 'package:aqademiq/features/ice_breakers/ice_breaker.dart';
import 'package:aqademiq/features/ice_breakers/ice_breakers_providers.dart';
import 'package:flutter_test/flutter_test.dart';

IceBreakersState _state(List<String> watched) =>
    IceBreakersState(watchedIds: watched.toSet());

void main() {
  group('the catalogue', () {
    test('ships six, numbered in teaching order', () {
      expect(kIceBreakers.length, 6);
      expect(
        kIceBreakers.map((b) => b.number).toList(),
        ['01', '02', '03', '04', '05', '06'],
      );
    });

    test('every id is unique — a watched flag is keyed on it', () {
      final ids = kIceBreakers.map((b) => b.id).toSet();
      expect(ids.length, kIceBreakers.length);
    });

    test('every video points at a declared asset', () {
      for (final breaker in kIceBreakers) {
        expect(breaker.asset, startsWith('assets/ice_breakers/'));
        expect(breaker.asset, endsWith('.mp4'));
      }
    });

    test('an unknown id resolves to nothing rather than throwing', () {
      // The router has no errorBuilder, so a bad deep link lands here.
      expect(iceBreakerById('no-such-video'), isNull);
      expect(iceBreakerById('add-one-small-thing'), isNotNull);
    });
  });

  group('the shelf', () {
    test('offers at most three, however many are left', () {
      // A wall of tutorials would recreate the overwhelm the empty planner
      // creates, which is the thing this feature exists to fight.
      expect(_state([]).shelf.length, kMaxShelfRows);
      expect(_state(['add-one-small-thing']).shelf.length, kMaxShelfRows);
    });

    test('leads with the first unwatched, in curriculum order', () {
      expect(_state([]).next?.number, '01');
      expect(_state(['add-one-small-thing']).next?.number, '02');
      expect(
        _state(['add-one-small-thing', 'too-big-break-it-down']).next?.number,
        '03',
      );
    });

    test('order is the teaching, so watching out of order does not reshuffle',
        () {
      // Watch the last one first: the shelf still offers 01, 02, 03.
      final state = _state(['start-a-session-from-a-task']);
      expect(state.shelf.map((b) => b.number).toList(), ['01', '02', '03']);
    });

    test('watched items move to the collapsed group, never disappear', () {
      final state = _state(['add-one-small-thing', 'freeze-dont-quit']);
      expect(state.watched.map((b) => b.number).toList(), ['01', '04']);
      expect(state.unwatched.length, 4);
      expect(state.watched.length + state.unwatched.length, 6);
    });

    test('runs empty when everything is watched', () {
      final all = kIceBreakers.map((b) => b.id).toList();
      final state = _state(all);
      expect(state.shelf, isEmpty);
      expect(state.next, isNull);
      expect(state.allWatched, isTrue);
    });
  });

  group('progress', () {
    test('counts against the whole series, not the unlocked part', () {
      final state = _state(['add-one-small-thing', 'too-big-break-it-down']);
      expect(state.watchedCount, 2);
      expect(state.total, 6);
      expect(state.percent, 33);
    });

    test('matches the design frames at the states they show', () {
      // 04-shelf-card-profile.png reads "3 of 6 watched · 50%".
      expect(_state(kIceBreakers.take(3).map((b) => b.id).toList()).percent, 50);
      // 05-one-left-watched-collapsed.png reads "5 of 6 watched · 83%".
      expect(_state(kIceBreakers.take(5).map((b) => b.id).toList()).percent, 83);
      // 06-guest-shelf.png reads "0 of 6 watched · 0%".
      expect(_state([]).percent, 0);
    });

    test('names the one-left state, which gets its own copy', () {
      expect(_state(kIceBreakers.take(5).map((b) => b.id).toList()).oneLeft,
          isTrue);
      expect(_state(kIceBreakers.take(4).map((b) => b.id).toList()).oneLeft,
          isFalse);
      // All six watched is not "one left".
      expect(_state(kIceBreakers.map((b) => b.id).toList()).oneLeft, isFalse);
    });

    test('an unknown stored id cannot inflate the count past the series', () {
      // A renamed video would otherwise leave a stale id on disk forever.
      final state = _state(['add-one-small-thing', 'deleted-video']);
      expect(state.unwatched.length, 5);
      expect(state.watched.length, 1);
    });
  });
}
