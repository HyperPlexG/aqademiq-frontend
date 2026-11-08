// The lexicon against the spec (haptic architecture §2, §3).
//
// The numbers here are read off the PDF's cards. If one of these fails after
// a retune, the retune and the spec disagree — change both or neither.

import 'package:aqademiq/services/haptics/haptic_lexicon.dart';
import 'package:aqademiq/services/haptics/haptic_moments.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

List<IosTap> _taps(HapticSpec s) => s.ios.whereType<IosTap>().toList();
List<IosCurve> _curves(HapticSpec s) => s.ios.whereType<IosCurve>().toList();

void main() {
  test('the micro patterns carry the spec values', () {
    expect((_taps(Aq.tick).single.intensity, _taps(Aq.tick).single.sharpness), (0.35, 0.6));
    expect((_taps(Aq.tap).single.intensity, _taps(Aq.tap).single.sharpness), (0.5, 0.5));
    expect(_taps(Aq.tapRigid).single.sharpness, 0.9);
    expect(_taps(Aq.latch).map((e) => (e.intensity, e.sharpness, e.at.inMilliseconds)), [(0.6, 0.8, 0), (0.3, 0.9, 28)]);
    expect((_taps(Aq.unlatch).single.intensity, _taps(Aq.unlatch).single.sharpness), (0.4, 0.25));
    expect(_taps(Aq.clink).map((e) => (e.intensity, e.at.inMilliseconds)), [(0.4, 0), (0.25, 35)]);
  });

  test('texture runs from a melted puddle to a crisp cube', () {
    final t0 = _taps(Aq.texture(0)).single;
    final t4 = _taps(Aq.texture(4)).single;
    expect((t0.intensity, t0.sharpness), (0.40, 0.10));
    expect(t4.intensity, closeTo(0.55, 1e-9));
    expect(t4.sharpness, closeTo(0.80, 1e-9));
    expect(Aq.texture(1).android.single.prim, Prim.lowTick);
    expect(Aq.texture(4).android.single.prim, Prim.click);
    expect(Aq.texture(2).fallback, Fallback.light);
    expect(Aq.texture(3).fallback, Fallback.medium);
  });

  test('friction holds at .35 until 5 minutes, then stiffens by .03 a step', () {
    expect(_taps(Aq.friction(2)).single.intensity, 0.35);
    expect(_taps(Aq.friction(5)).single.intensity, 0.35);
    expect(_taps(Aq.friction(6)).single.intensity, closeTo(0.38, 1e-9));
    expect(_taps(Aq.friction(15)).single.intensity, closeTo(0.65, 1e-9));
    expect(_taps(Aq.friction(2)).single.sharpness, 0.5);
    expect(_taps(Aq.friction(15)).single.sharpness, closeTo(0.8, 1e-9));
  });

  test('crystallise: six grains speeding up 70 → 24 ms and rising .2 → .9, then a tail', () {
    final grains = _taps(Aq.crystallise());
    expect(grains, hasLength(6));
    final gaps = [for (var i = 1; i < grains.length; i++) (grains[i].at - grains[i - 1].at).inMilliseconds];
    expect(gaps, [70, 55, 42, 32, 24]);
    expect(grains.first.intensity, closeTo(0.2, 1e-9));
    expect(grains.last.intensity, closeTo(0.9, 1e-9));
    final tail = _curves(Aq.crystallise()).single;
    expect((tail.duration.inMilliseconds, tail.sharpness, tail.peak), (80, 0.2, 0.3));
    expect(Aq.crystallise().span.inMilliseconds, inInclusiveRange(300, 340));
    expect(Aq.crystallise().android.last.prim, Prim.click);
  });

  test('keep only these extends crystallise to eight grains', () {
    expect(_taps(Aq.crystallise(grains: 8)), hasLength(8));
    expect(_taps(specFor(HapticMoment.keepOnlyThese)), hasLength(8));
  });

  test('the breath swells 4 s and ebbs 6 s, and is skipped on Android without amplitude control', () {
    final b = _curves(Aq.breath).single;
    expect(b.duration, const Duration(seconds: 10));
    expect(b.peak, 0.28);
    expect(b.intensityAt(0.4), closeTo(0.28, 1e-9));
    expect(Aq.breath.waveOnly, isTrue);
    expect(Aq.breath.androidWave!.amplitudes.reduce((a, b) => a > b ? a : b), 70);
    expect(Aq.breath.androidWave!.timings.toSet(), {100});
    expect(Aq.breath.fallback, Fallback.none);
  });

  test('three long breaths at 100%, 80% and 60%', () {
    final peaks = _curves(Aq.breathLong).map((c) => c.peak).toList();
    expect(peaks[0], closeTo(0.28, 1e-9));
    expect(peaks[1], closeTo(0.28 * 0.8, 1e-9));
    expect(peaks[2], closeTo(0.28 * 0.6, 1e-9));
    expect(Aq.breathLong.span, const Duration(seconds: 30));
  });

  test('a ratchet closes from 180 to 28 ms and lands on the release point', () {
    for (final hold in const [Duration(milliseconds: 1200), Duration(seconds: 2)]) {
      final taps = _taps(Aq.ratchet(hold));
      final gaps = [for (var i = 1; i < taps.length; i++) (taps[i].at - taps[i - 1].at).inMilliseconds];
      expect(gaps.first, 180);
      expect(gaps.reduce((a, b) => a + b), hold.inMilliseconds);
      expect(taps.first.intensity, closeTo(0.2, 1e-9));
      expect(taps.last.intensity, closeTo(0.6, 1e-9));
      final under = _curves(Aq.ratchet(hold)).single;
      expect((under.sharpness, under.sharpnessTo, under.peak), (0.2, 0.7, 0.4));
    }
  });

  test('continuous vibration never runs past 1.4 s, except the breath', () {
    for (final s in [...Aq.all, for (final m in HapticMoment.values) specFor(m, count: 5)]) {
      if (s.name == 'aq.breath' || s.name == 'aq.ratchet') continue;
      for (final c in _curves(s)) {
        expect(c.duration, lessThanOrEqualTo(const Duration(milliseconds: 1400)), reason: s.name);
      }
    }
  });

  test('exactly five signatures: crystallise, melt, bloom, drill, crack', () {
    final signatures = {
      for (final s in Aq.all)
        if (s.signature) s.name,
    };
    expect(signatures, {'aq.crystallise', 'aq.melt', 'aq.bloom', 'aq.drill', 'aq.crack'});
  });

  test('bloom on a desk: S ≤ .2 and I × .7', () {
    final safe = Aq.bloom.deskSafe();
    for (final e in safe.ios) {
      switch (e) {
        case IosTap(:final sharpness):
          expect(sharpness, lessThanOrEqualTo(0.2));
        case IosCurve(:final sharpness):
          expect(sharpness, lessThanOrEqualTo(0.2));
      }
    }
    expect(_taps(safe).map((e) => e.intensity).reduce((a, b) => a > b ? a : b), closeTo(0.7, 1e-9));
  });

  test('success and error are the platform own', () {
    expect(Aq.success.iosSystem, 'success');
    expect(Aq.error.iosSystem, 'error');
    expect(Aq.success.androidConstant, 'fb:CONFIRM');
    expect(Aq.error.androidConstant, 'fb:REJECT');
  });

  test('every Prism mode name the app uses has its own feel', () {
    expect(Aq.prism('Deep Work').name, 'aq.prism.deep');
    expect(Aq.prism('Flow').name, 'aq.prism.flow');
    expect(Aq.prism('Review').name, 'aq.prism.review');
    expect(Aq.prism('Wind-down').name, 'aq.prism.winddown');
    expect(Aq.prism('No sound').name, 'aq.prism.none');
  });

  test('the session start is a thud, then the Prism pattern 120 ms later', () {
    final s = specFor(HapticMoment.sessionStart, mode: 'Review');
    expect(_taps(s).first.intensity, 0.8);
    final beats = _taps(s).where((e) => e.intensity == 0.45).map((e) => e.at.inMilliseconds);
    expect(beats, [120, 350, 580]);
  });

  test('percent-strength moments are the spec percentages', () {
    double peak(HapticSpec s) => [
          ..._taps(s).map((e) => e.intensity),
          ..._curves(s).map((c) => c.peak),
        ].reduce((a, b) => a > b ? a : b);
    expect(peak(specFor(HapticMoment.tabLocked)), closeTo(0.7 * 0.6, 1e-9));
    expect(peak(specFor(HapticMoment.sessionEndEarly)), closeTo(0.5 * 0.6, 1e-9));
    expect(peak(specFor(HapticMoment.moodSave)), closeTo(0.8 * 0.5, 1e-9));
    expect(peak(specFor(HapticMoment.frostSaved)), closeTo(0.9 * 0.5, 1e-9));
    expect(peak(specFor(HapticMoment.coreThawedCubes, count: 3)), closeTo(0.35, 1e-9));
    expect(_taps(specFor(HapticMoment.referralChar, step: 3)).single.intensity, 0.5);
  });

  test('approve all lands one latch per proposal 70 ms apart, then a 40% thud', () {
    final s = specFor(HapticMoment.approveAll, count: 3);
    final strikes = _taps(s).where((e) => e.intensity == 0.6).map((e) => e.at.inMilliseconds).toList();
    expect(strikes, [0, 70, 140]);
    expect(_taps(s).last.intensity, closeTo(0.8 * 0.4, 1e-9));
  });

  test('every moment resolves and serialises for both platforms', () {
    for (final m in HapticMoment.values) {
      final s = specFor(m, step: 2, count: 3, mode: 'Flow');
      expect(s.ios, isNotEmpty, reason: '$m');
      final ios = s.toWire(platform: TargetPlatform.iOS);
      final android = s.toWire(platform: TargetPlatform.android, faceDownAlt: s.deskSafe());
      expect(ios['ios'], isA<List<Object?>>());
      expect(android.containsKey('prims'), isTrue);
      expect(android['faceDownAlt'], isA<Map<String, Object?>>());
    }
  });

  test('the derived Android waveform keeps every pulse long enough to be felt', () {
    for (final spec in [Aq.tick, Aq.latch, Aq.clink, Aq.knock, Aq.crystallise()]) {
      final wave = deriveWave(spec.ios)!;
      expect(wave.timings.length, wave.amplitudes.length);
      // A pulse is a run of non-zero amplitude; an LRA needs ~30 ms to be felt.
      var run = 0;
      for (var i = 0; i <= wave.timings.length; i++) {
        if (i < wave.timings.length && wave.amplitudes[i] > 0) {
          run += wave.timings[i];
        } else if (run > 0) {
          expect(run, greaterThanOrEqualTo(30), reason: spec.name);
          run = 0;
        }
      }
    }
  });

  test('a hold fades from wherever it was', () {
    expect(levelAt(Aq.breath, const Duration(seconds: 4)), closeTo(0.28, 1e-9));
    expect(levelAt(Aq.breath, const Duration(seconds: 2)), closeTo(0.14, 1e-9));
    expect(levelAt(Aq.ratchet(deleteAccountHoldTime), const Duration(seconds: 1)), closeTo(0.2, 1e-9));
  });
}
