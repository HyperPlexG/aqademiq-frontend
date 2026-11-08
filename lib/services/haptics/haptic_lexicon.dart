/// The lexicon — the 22 patterns of the haptic architecture (v2, Nov 2026,
/// "Aqademiq haptic architecture" §2). **The only file in the app that says
/// what a vibration physically is.**
///
/// Every pattern is something ice does: it sets (`Aq.crystallise`), softens
/// (`Aq.melt`), holds (`Aq.knock`), breaks (`Aq.crack`) and rings (`Aq.bloom`). Nothing
/// here is a generic motor buzz.
///
/// Each pattern carries three renderings, as the spec's cards do:
///
///  * **iOS** — Core Haptics transients and continuous events, intensity (I)
///    and sharpness (S) from 0 to 1, read straight off the spec.
///  * **Android** — `VibrationEffect.Composition` primitives with their scale
///    and delay, a `performHapticFeedback` constant or predefined effect for
///    phones without primitives, and an amplitude waveform where the spec asks
///    for one (the thaw breath, the drill's rumble).
///  * **Fallback** — the closest preset a phone can play when neither of the
///    above is available (the spec's "Fallback" row).
///
/// The spec's engineering notes ask for a `haptics.json` registry consumed by
/// web code. Aqademiq is Flutter, so the registry is this file: the same one
/// name → three renderings mapping, but checked by the compiler, so a pattern
/// cannot be called by a misspelt name or lose a platform.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

// ─── iOS events ────────────────────────────────────────────────────────────

/// One Core Haptics event.
@immutable
sealed class IosEvent {
  const IosEvent(this.at);

  /// Offset from the start of the pattern.
  final Duration at;

  /// When the event is over. A transient has no length; 10 ms is what the
  /// governor allows for it.
  Duration get end;

  IosEvent scaled(double k);

  /// The spec's desk-safe treatment (§3, "Phone face down"): S ≤ .2, I × .7.
  IosEvent deskSafe();

  Map<String, Object> toWire();
}

/// A `hapticTransient`: one strike.
class IosTap extends IosEvent {
  const IosTap({Duration at = Duration.zero, required this.intensity, required this.sharpness}) : super(at);

  final double intensity;
  final double sharpness;

  @override
  Duration get end => at + const Duration(milliseconds: 10);

  @override
  IosTap scaled(double k) => IosTap(at: at, intensity: _unit(intensity * k), sharpness: sharpness);

  @override
  IosTap deskSafe() => IosTap(at: at, intensity: intensity * 0.7, sharpness: math.min(sharpness, 0.2));

  @override
  Map<String, Object> toWire() => {
        'type': 'tap',
        'at': at.inMilliseconds,
        'i': intensity,
        's': sharpness,
      };
}

/// A `hapticContinuous` event whose intensity follows [points] — `(t, I)`
/// pairs with `t` from 0 to 1 across [duration], linear in between.
///
/// Optional [sharpnessTo] ramps sharpness linearly from [sharpness] to it
/// (the ratchet's S .2 → .7).
class IosCurve extends IosEvent {
  const IosCurve({
    Duration at = Duration.zero,
    required this.duration,
    required this.sharpness,
    required this.points,
    this.sharpnessTo,
  }) : super(at);

  final Duration duration;
  final double sharpness;
  final double? sharpnessTo;
  final List<(double, double)> points;

  @override
  Duration get end => at + duration;

  double get peak => points.fold(0, (m, p) => math.max(m, p.$2));

  /// Intensity at [t] (0–1 through the event), for a fade that starts from
  /// wherever the curve is when it is interrupted.
  double intensityAt(double t) {
    if (points.isEmpty) return 0;
    if (t <= points.first.$1) return points.first.$2;
    for (var i = 1; i < points.length; i++) {
      final (t1, v1) = points[i];
      if (t <= t1) {
        final (t0, v0) = points[i - 1];
        final span = t1 - t0;
        return span <= 0 ? v1 : v0 + (v1 - v0) * (t - t0) / span;
      }
    }
    return points.last.$2;
  }

  @override
  IosCurve scaled(double k) => IosCurve(
        at: at,
        duration: duration,
        sharpness: sharpness,
        sharpnessTo: sharpnessTo,
        points: [for (final (t, v) in points) (t, _unit(v * k))],
      );

  @override
  IosCurve deskSafe() => IosCurve(
        at: at,
        duration: duration,
        sharpness: math.min(sharpness, 0.2),
        sharpnessTo: sharpnessTo == null ? null : math.min(sharpnessTo!, 0.2),
        points: [for (final (t, v) in points) (t, v * 0.7)],
      );

  @override
  Map<String, Object> toWire() => {
        'type': 'curve',
        'at': at.inMilliseconds,
        'ms': duration.inMilliseconds,
        's': sharpness,
        's2': ?sharpnessTo,
        'pts': [
          for (final (t, v) in points) [t, v],
        ],
      };
}

// ─── Android ───────────────────────────────────────────────────────────────

/// `VibrationEffect.Composition` primitives (API 30+, some 31+).
enum Prim { click, tick, lowTick, thud, spin, slowRise, quickFall }

/// One primitive in a composition. [delay] is Android's own meaning: the wait
/// after the previous primitive. [alt] stands in when this primitive is not
/// supported on the phone (the spec's "LOW_TICK if THUD unsupported").
@immutable
class APrim {
  const APrim(this.prim, this.scale, {this.delay = Duration.zero, this.alt});

  final Prim prim;
  final double scale;
  final Duration delay;
  final Prim? alt;

  APrim scaled(double k) => APrim(prim, _unit(scale * k), delay: delay, alt: alt);

  Map<String, Object> toWire() => {
        'p': prim.name,
        'scale': scale,
        'delay': delay.inMilliseconds,
        if (alt != null) 'alt': alt!.name,
      };
}

/// An amplitude waveform: [timings] in ms, [amplitudes] 0–255.
@immutable
class AWave {
  const AWave(this.timings, this.amplitudes);

  final List<int> timings;
  final List<int> amplitudes;

  AWave scaled(double k) => AWave(timings, [for (final a in amplitudes) (a * k).round().clamp(0, 255)]);

  Map<String, Object> toWire() => {'t': timings, 'a': amplitudes};
}

// ─── fallback ──────────────────────────────────────────────────────────────

/// The spec's "Fallback" row: what a phone with neither Core Haptics nor
/// Android primitives plays.
enum Fallback { none, selection, light, medium, heavy, success, error }

// ─── the pattern ───────────────────────────────────────────────────────────

/// One pattern, rendered three ways.
@immutable
class HapticSpec {
  const HapticSpec({
    required this.name,
    required this.ios,
    required this.android,
    required this.fallback,
    this.iosSystem,
    this.androidConstant,
    this.androidWave,
    this.preferWave = false,
    this.waveOnly = false,
    this.signature = false,
  });

  /// `aq.tick`, `aq.crystallise` … — the spec's own names. Also the key the
  /// repetition rule counts by.
  final String name;

  final List<IosEvent> ios;

  /// `selection`, `success` or `error`: iOS plays the system generator rather
  /// than [ios] (`aq.success` / `aq.error` are never restyled, §2 "System").
  final String? iosSystem;

  final List<APrim> android;

  /// A `performHapticFeedback` constant (`fb:SEGMENT_TICK`) or a predefined
  /// effect (`fx:HEAVY_CLICK`) for phones without the primitives.
  final String? androidConstant;

  /// An explicit waveform. Derived from [ios] when absent.
  final AWave? androidWave;

  /// Play [androidWave] first where amplitude control exists (breath,
  /// drill's rumble, wind-down) rather than the primitives.
  final bool preferWave;

  /// Without amplitude control, play nothing (the breath is warmth, and an
  /// on/off buzz for ten seconds is the opposite of it).
  final bool waveOnly;

  final Fallback fallback;

  /// Crystallise, melt, bloom, drill, crack: kept 2 s apart (§3).
  final bool signature;

  /// How long the pattern occupies the motor.
  Duration get span {
    var longest = Duration.zero;
    for (final e in ios) {
      if (e.end > longest) longest = e.end;
    }
    if (iosSystem != null && longest < const Duration(milliseconds: 60)) {
      longest = const Duration(milliseconds: 60);
    }
    return longest;
  }

  /// The same pattern with Android's own constant for the moment, where the
  /// spec names one (a sheet's dismiss threshold).
  HapticSpec withAndroidConstant(String constant) => HapticSpec(
        name: name,
        ios: ios,
        iosSystem: iosSystem,
        android: android,
        androidConstant: constant,
        androidWave: androidWave,
        preferWave: preferWave,
        waveOnly: waveOnly,
        fallback: fallback,
        signature: signature,
      );

  /// The same feel at [k] of its strength (60% knocks, the repetition rule).
  HapticSpec scaled(double k) {
    if (k >= 0.999) return this;
    return HapticSpec(
      name: name,
      ios: [for (final e in ios) e.scaled(k)],
      iosSystem: iosSystem,
      android: [for (final p in android) p.scaled(k)],
      androidConstant: androidConstant,
      androidWave: androidWave?.scaled(k),
      preferWave: preferWave,
      waveOnly: waveOnly,
      fallback: fallback,
      signature: signature,
    );
  }

  /// §3 "Phone face down": hums instead of rattling on a desk.
  HapticSpec deskSafe() => HapticSpec(
        name: name,
        ios: [for (final e in ios) e.deskSafe()],
        iosSystem: iosSystem,
        android: [for (final p in android) p.scaled(0.7)],
        androidConstant: androidConstant,
        androidWave: androidWave?.scaled(0.7),
        preferWave: preferWave,
        waveOnly: waveOnly,
        fallback: fallback,
        signature: signature,
      );

  /// This pattern, then [next] starting [gap] after this one's span.
  HapticSpec then(HapticSpec next, {Duration gap = Duration.zero, String? name}) {
    final offset = span + gap;
    return HapticSpec(
      name: name ?? this.name,
      ios: [...ios, for (final e in next.ios) shiftEvent(e, offset)],
      iosSystem: iosSystem,
      android: [
        ...android,
        for (final (i, p) in next.android.indexed)
          i == 0 ? APrim(p.prim, p.scale, delay: p.delay + gap, alt: p.alt) : p,
      ],
      androidConstant: androidConstant,
      fallback: _strongest(fallback, next.fallback),
      signature: signature || next.signature,
    );
  }

  /// This pattern repeated [count] times, [gap] between starts.
  HapticSpec repeated(int count, Duration gap, {List<double>? strengths}) {
    final events = <IosEvent>[];
    final prims = <APrim>[];
    for (var i = 0; i < count; i++) {
      final k = strengths == null ? 1.0 : strengths[i];
      final s = scaled(k);
      events.addAll([for (final e in s.ios) shiftEvent(e, gap * i)]);
      for (final (j, p) in s.android.indexed) {
        prims.add(i > 0 && j == 0 ? APrim(p.prim, p.scale, delay: gap - _primLength(s), alt: p.alt) : p);
      }
    }
    return HapticSpec(
      name: name,
      ios: events,
      iosSystem: iosSystem,
      android: prims,
      androidConstant: androidConstant,
      fallback: fallback,
      signature: signature,
    );
  }

  /// What this pattern sends to the native side for [platform].
  Map<String, Object?> toWire({required TargetPlatform platform, HapticSpec? faceDownAlt}) => {
        'name': name,
        if (platform == TargetPlatform.iOS) ...{
          'ios': [for (final e in ios) e.toWire()],
          'iosSystem': iosSystem,
        } else ...{
          'prims': [for (final p in android) p.toWire()],
          'constant': androidConstant,
          'wave': (androidWave ?? deriveWave(ios))?.toWire(),
          'preferWave': preferWave,
          'waveOnly': waveOnly,
        },
        'fallback': fallback.name,
        'spanMs': span.inMilliseconds,
        if (faceDownAlt != null) 'faceDownAlt': faceDownAlt.toWire(platform: platform),
      };
}

double _unit(double v) => v.clamp(0.0, 1.0);

IosEvent shiftEvent(IosEvent e, Duration by) => switch (e) {
      IosTap(:final intensity, :final sharpness) => IosTap(at: e.at + by, intensity: intensity, sharpness: sharpness),
      IosCurve(:final duration, :final sharpness, :final sharpnessTo, :final points) =>
        IosCurve(at: e.at + by, duration: duration, sharpness: sharpness, sharpnessTo: sharpnessTo, points: points),
    };

/// Roughly how long a primitive run lasts, so a repeat's delay lands on the
/// intended start rather than after it.
Duration _primLength(HapticSpec s) {
  var ms = 0;
  for (final p in s.android) {
    ms += p.delay.inMilliseconds + 12;
  }
  return Duration(milliseconds: ms);
}

Fallback _strongest(Fallback a, Fallback b) => a.index >= b.index ? a : b;

/// An amplitude waveform for a phone without primitives, built from the iOS
/// timeline: every transient becomes a pulse long enough for an Android motor
/// to spin up (shorter for sharp taps, longer for dull ones), every curve is
/// sampled every 25 ms.
AWave? deriveWave(List<IosEvent> events) {
  if (events.isEmpty) return null;
  // Render to a 5 ms grid, taking the loudest thing at each instant.
  var endMs = 0;
  for (final e in events) {
    final end = switch (e) {
      IosTap(:final sharpness) => e.at.inMilliseconds + _pulseMs(sharpness),
      IosCurve() => e.end.inMilliseconds,
    };
    endMs = math.max(endMs, end);
  }
  const step = 5;
  final grid = List<int>.filled(endMs ~/ step + 1, 0);
  for (final e in events) {
    switch (e) {
      case IosTap(:final intensity, :final sharpness):
        final from = e.at.inMilliseconds ~/ step;
        final to = (e.at.inMilliseconds + _pulseMs(sharpness)) ~/ step;
        for (var i = from; i < to && i < grid.length; i++) {
          grid[i] = math.max(grid[i], (intensity * 255).round());
        }
      case IosCurve(:final duration):
        final from = e.at.inMilliseconds ~/ step;
        final len = duration.inMilliseconds ~/ step;
        for (var i = 0; i < len && from + i < grid.length; i++) {
          final v = e.intensityAt(i / math.max(1, len - 1));
          grid[from + i] = math.max(grid[from + i], (v * 255).round());
        }
    }
  }
  // Run-length encode, merging steps of similar amplitude into 25 ms buckets.
  final timings = <int>[];
  final amplitudes = <int>[];
  var i = 0;
  while (i < grid.length) {
    final a = grid[i];
    var j = i + 1;
    while (j < grid.length && (grid[j] - a).abs() <= 8 && (j - i) * step < 25) {
      j++;
    }
    final ms = (j - i) * step;
    if (amplitudes.isNotEmpty && amplitudes.last == a) {
      timings[timings.length - 1] += ms;
    } else {
      timings.add(ms);
      amplitudes.add(a);
    }
    i = j;
  }
  return AWave(timings, amplitudes);
}

/// Android LRAs need ~30–60 ms before a pulse is felt at all; sharp taps get
/// the short end, dull ones the long.
int _pulseMs(double sharpness) => (60 - 30 * sharpness).round();

// ─── the 22 ────────────────────────────────────────────────────────────────


/// The lexicon. Names follow the spec exactly (`aq.tick` → [Aq.tick]).
abstract final class Aq {
  // ── Micro ──────────────────────────────────────────────────────────────

  /// One frost crystal. The smallest unit.
  static const tick = HapticSpec(
    name: 'aq.tick',
    ios: [IosTap(intensity: 0.35, sharpness: 0.6)],
    android: [APrim(Prim.tick, 0.5)],
    androidConstant: 'fb:SEGMENT_TICK',
    fallback: Fallback.selection,
  );

  /// A pebble on ice. Confirms a press.
  static const tap = HapticSpec(
    name: 'aq.tap',
    ios: [IosTap(intensity: 0.5, sharpness: 0.5)],
    android: [APrim(Prim.click, 0.5)],
    fallback: Fallback.light,
  );

  /// The rigid variant (S .9) for a lift: a long-pressed card, a reordered
  /// row. Android's own drag-start feel where it has one.
  static const tapRigid = HapticSpec(
    name: 'aq.tap',
    ios: [IosTap(intensity: 0.5, sharpness: 0.9)],
    android: [APrim(Prim.click, 0.5)],
    androidConstant: 'fb:DRAG_START',
    fallback: Fallback.light,
  );

  /// A lid clicking shut. Something turns on or gets done.
  static const latch = HapticSpec(
    name: 'aq.latch',
    ios: [
      IosTap(intensity: 0.6, sharpness: 0.8),
      IosTap(at: Duration(milliseconds: 28), intensity: 0.3, sharpness: 0.9),
    ],
    android: [APrim(Prim.click, 0.7), APrim(Prim.tick, 0.4, delay: Duration(milliseconds: 28))],
    androidConstant: 'fb:TOGGLE_ON',
    fallback: Fallback.medium,
  );

  /// The lid lifting. Duller and lower, so off never feels like on.
  static const unlatch = HapticSpec(
    name: 'aq.unlatch',
    ios: [IosTap(intensity: 0.4, sharpness: 0.25)],
    android: [APrim(Prim.lowTick, 0.6)],
    androidConstant: 'fb:TOGGLE_OFF',
    fallback: Fallback.light,
  );

  /// A fingernail on Ada's cube. Ada's physical signature.
  static const clink = HapticSpec(
    name: 'aq.clink',
    ios: [
      IosTap(intensity: 0.4, sharpness: 1),
      IosTap(at: Duration(milliseconds: 35), intensity: 0.25, sharpness: 1),
    ],
    android: [APrim(Prim.tick, 0.6), APrim(Prim.tick, 0.4, delay: Duration(milliseconds: 35))],
    fallback: Fallback.light,
  );

  /// Melted puddle (0) to crisp cube (4). Every 5-step melt rating.
  static HapticSpec texture(int step) {
    final s = step.clamp(0, 4);
    final t = s / 4;
    return HapticSpec(
      name: 'aq.texture',
      ios: [IosTap(intensity: 0.40 + 0.15 * t, sharpness: 0.10 + 0.70 * t)],
      android: [
        switch (s) {
          0 => const APrim(Prim.lowTick, 0.5),
          1 => const APrim(Prim.lowTick, 0.7),
          2 => const APrim(Prim.tick, 0.6),
          3 => const APrim(Prim.tick, 0.8),
          _ => const APrim(Prim.click, 0.6),
        },
      ],
      fallback: s <= 2 ? Fallback.light : Fallback.medium,
    );
  }

  /// A dial that stiffens: I .35 until 5 minutes, then +.03 per step; S .5 →
  /// .8 across 2–15 minutes. [minutes] is where the dial now sits.
  static HapticSpec friction(int minutes) {
    final m = minutes.clamp(2, 15);
    final i = m <= 5 ? 0.35 : 0.35 + 0.03 * (m - 5);
    final s = 0.5 + 0.3 * (m - 2) / 13;
    return HapticSpec(
      name: 'aq.friction',
      ios: [IosTap(intensity: i, sharpness: s)],
      android: [APrim(Prim.tick, _unit(i / 0.35 * 0.5))],
      fallback: Fallback.selection,
    );
  }

  // ── Material ───────────────────────────────────────────────────────────

  /// Knuckles on thick ice. It holds. Used instead of an error.
  static const knock = HapticSpec(
    name: 'aq.knock',
    ios: [
      IosTap(intensity: 0.7, sharpness: 0.15),
      IosTap(at: Duration(milliseconds: 95), intensity: 0.55, sharpness: 0.15),
    ],
    android: [
      APrim(Prim.thud, 0.6, alt: Prim.lowTick),
      APrim(Prim.thud, 0.45, delay: Duration(milliseconds: 95), alt: Prim.lowTick),
    ],
    fallback: Fallback.heavy,
  );

  /// A block set down on a desk. Something lands.
  static const thud = HapticSpec(
    name: 'aq.thud',
    ios: [
      IosTap(intensity: 0.8, sharpness: 0.3),
      IosCurve(duration: Duration(milliseconds: 150), sharpness: 0.1, points: [(0, 0.3), (1, 0)]),
    ],
    android: [APrim(Prim.thud, 0.8)],
    androidConstant: 'fx:HEAVY_CLICK',
    fallback: Fallback.heavy,
  );

  /// A clean fracture. A threshold is crossed.
  static const crack = HapticSpec(
    name: 'aq.crack',
    ios: [
      IosTap(intensity: 1, sharpness: 1),
      IosCurve(duration: Duration(milliseconds: 45), sharpness: 0.8, points: [(0, 0.4), (1, 0)]),
    ],
    android: [APrim(Prim.click, 1), APrim(Prim.tick, 0.6, delay: Duration(milliseconds: 20))],
    fallback: Fallback.heavy,
    signature: true,
  );

  // ── Ice signatures ─────────────────────────────────────────────────────

  /// Water setting into ice. Grains that speed up, then lock. Means freeze.
  ///
  /// Six grains by default (gaps 70 → 24 ms, I .2 → .9, S .9, then an 80 ms
  /// tail at I .3 S .2). "Keep only these" asks for 8: a bigger freeze takes
  /// slightly longer to set.
  static HapticSpec crystallise({int grains = 6}) {
    final n = math.max(2, grains);
    final gaps = n == 6 ? const [70, 55, 42, 32, 24] : _geometric(70, 24, n - 1);
    final ios = <IosEvent>[];
    final prims = <APrim>[];
    var at = 0;
    for (var k = 0; k < n; k++) {
      final t = k / (n - 1);
      ios.add(IosTap(at: Duration(milliseconds: at), intensity: 0.2 + 0.7 * t, sharpness: 0.9));
      if (k < n - 1) {
        prims.add(APrim(Prim.tick, 0.3 + 0.4 * t, delay: Duration(milliseconds: k == 0 ? 0 : gaps[k - 1])));
      } else {
        prims.add(APrim(Prim.click, 1, delay: Duration(milliseconds: gaps[k - 1])));
      }
      if (k < n - 1) at += gaps[k];
    }
    ios.add(IosCurve(at: Duration(milliseconds: at), duration: const Duration(milliseconds: 80), sharpness: 0.2, points: const [(0, 0.3), (1, 0.3)]));
    return HapticSpec(name: 'aq.crystallise', ios: ios, android: prims, fallback: Fallback.medium, signature: true);
  }

  /// A soft swell that lets go, then two drips. Means thaw or resume.
  static const melt = HapticSpec(
    name: 'aq.melt',
    ios: [
      IosCurve(duration: Duration(milliseconds: 420), sharpness: 0.1, points: [(0, 0.05), (0.4, 0.5), (1, 0)]),
      IosTap(at: Duration(milliseconds: 480), intensity: 0.25, sharpness: 0.5),
      IosTap(at: Duration(milliseconds: 630), intensity: 0.18, sharpness: 0.5),
    ],
    android: [
      APrim(Prim.slowRise, 0.25),
      APrim(Prim.quickFall, 0.5),
      APrim(Prim.lowTick, 0.3, delay: Duration(milliseconds: 120)),
    ],
    fallback: Fallback.light,
    signature: true,
  );

  /// A 4-second swell in and a 6-second ebb out: the thaw wait as a breath.
  /// Felt as warmth, not a buzz — Android plays it only where the motor can
  /// vary its strength, and nowhere else.
  static final breath = HapticSpec(
    name: 'aq.breath',
    ios: const [
      IosCurve(duration: Duration(seconds: 10), sharpness: 0.05, points: [(0, 0), (0.4, 0.28), (1, 0)]),
    ],
    android: const [],
    androidWave: _breathWave(),
    preferWave: true,
    waveOnly: true,
    fallback: Fallback.none,
  );

  /// Three breaths at 100%, 80% and 60% — the 30-second wait. Calmer as it
  /// goes, never more insistent.
  static final breathLong = HapticSpec(
    name: 'aq.breath',
    ios: [
      for (final (i, k) in const [1.0, 0.8, 0.6].indexed)
        shiftEvent(breath.ios.single.scaled(k), Duration(seconds: 10 * i)),
    ],
    android: const [],
    androidWave: AWave(
      [for (var i = 0; i < 3; i++) ..._breathWave().timings],
      [
        for (final k in const [1.0, 0.8, 0.6]) ..._breathWave().scaled(k).amplitudes,
      ],
    ),
    preferWave: true,
    waveOnly: true,
    fallback: Fallback.none,
  );

  /// Pressure building on ice until it gives — hold-to-confirm. Taps closing
  /// from 180 to 28 ms apart (I .2 → .6) over a continuous rise (I 0 → .4,
  /// S .2 → .7), across [hold]. The crack at the release point is played
  /// separately when the hold completes; lifting early stops this with a soft
  /// fall instead.
  static HapticSpec ratchet(Duration hold) {
    final total = hold.inMilliseconds;
    final gaps = _gapsFilling(180, 28, total);
    final ios = <IosEvent>[
      IosCurve(duration: hold, sharpness: 0.2, sharpnessTo: 0.7, points: const [(0, 0), (1, 0.4)]),
    ];
    final prims = <APrim>[];
    var at = 0;
    for (var k = 0; k <= gaps.length; k++) {
      final t = total == 0 ? 1.0 : at / total;
      ios.add(IosTap(at: Duration(milliseconds: at), intensity: 0.2 + 0.4 * t, sharpness: 0.5 + 0.3 * t));
      prims.add(APrim(Prim.tick, 0.3 + 0.5 * t, delay: Duration(milliseconds: k == 0 ? 0 : math.max(0, gaps[k - 1] - 8))));
      if (k < gaps.length) at += gaps[k];
    }
    return HapticSpec(name: 'aq.ratchet', ios: ios, android: prims, fallback: Fallback.selection);
  }

  /// A core drilled out of ice: a grainy rumble, then a lock (a [latch]).
  static final HapticSpec drill = () {
    const rumble = 1200;
    final ios = <IosEvent>[
      const IosCurve(duration: Duration(milliseconds: rumble), sharpness: 0.3, points: [(0, 0.2), (1, 0.5)]),
    ];
    // Grains every 60–90 ms (alternating), I .2 S .4.
    var at = 40;
    var k = 0;
    while (at < rumble - 40) {
      ios.add(IosTap(at: Duration(milliseconds: at), intensity: 0.2, sharpness: 0.4));
      at += k.isEven ? 75 : 65;
      k++;
    }
    for (final e in latch.ios) {
      ios.add(shiftEvent(e, const Duration(milliseconds: rumble + 30)));
    }
    // Android with amplitude control: the rumble with grains as spikes.
    final timings = <int>[];
    final amps = <int>[];
    for (var t = 0; t < rumble; t += 30) {
      final base = (0.2 + 0.3 * t / rumble) * 255;
      final grain = (t ~/ 30).isEven && t % 90 < 30;
      timings.add(30);
      amps.add((grain ? base + 50 : base).round().clamp(0, 255));
    }
    timings.addAll([30, 20, 28, 15]);
    amps.addAll([0, 180, 0, 110]);
    return HapticSpec(
      name: 'aq.drill',
      ios: ios,
      android: const [
        APrim(Prim.spin, 0.4),
        APrim(Prim.spin, 0.4),
        APrim(Prim.click, 1, delay: Duration(milliseconds: 40)),
      ],
      androidWave: AWave(timings, amps),
      preferWave: true,
      fallback: Fallback.medium,
      signature: true,
    );
  }();

  /// Ice setting fully, then ringing like a glass bowl. The one big
  /// celebration in the system.
  static const bloom = HapticSpec(
    name: 'aq.bloom',
    ios: [
      IosTap(intensity: 0.25, sharpness: 0.9),
      IosTap(at: Duration(milliseconds: 55), intensity: 0.35, sharpness: 0.9),
      IosTap(at: Duration(milliseconds: 100), intensity: 0.45, sharpness: 0.9),
      IosTap(at: Duration(milliseconds: 140), intensity: 1, sharpness: 0.8),
      IosCurve(at: Duration(milliseconds: 140), duration: Duration(milliseconds: 1160), sharpness: 0.2, points: [(0, 0.45), (1, 0)]),
    ],
    android: [
      APrim(Prim.tick, 0.4),
      APrim(Prim.tick, 0.5, delay: Duration(milliseconds: 45)),
      APrim(Prim.tick, 0.6, delay: Duration(milliseconds: 35)),
      APrim(Prim.click, 1, delay: Duration(milliseconds: 30)),
      APrim(Prim.quickFall, 0.6),
    ],
    fallback: Fallback.success,
    signature: true,
  );

  // ── Prism ──────────────────────────────────────────────────────────────

  /// Deep Work · Carrier — one low throb, like the low-frequency tone.
  static const prismDeep = HapticSpec(
    name: 'aq.prism.deep',
    ios: [
      IosCurve(duration: Duration(milliseconds: 520), sharpness: 0.05, points: [(0, 0), (120 / 520, 0.55), (1, 0)]),
    ],
    android: [APrim(Prim.slowRise, 0.5), APrim(Prim.quickFall, 0.5)],
    fallback: Fallback.light,
  );

  /// Flow · Current — one long, smooth swell.
  static const prismFlow = HapticSpec(
    name: 'aq.prism.flow',
    ios: [
      IosCurve(duration: Duration(milliseconds: 900), sharpness: 0.15, points: [(0, 0), (0.5, 0.35), (1, 0)]),
    ],
    android: [APrim(Prim.slowRise, 0.35), APrim(Prim.quickFall, 0.3)],
    fallback: Fallback.light,
  );

  /// Review · Metre — three even beats at a steady mid tempo.
  static const prismReview = HapticSpec(
    name: 'aq.prism.review',
    ios: [
      IosTap(intensity: 0.45, sharpness: 0.5),
      IosTap(at: Duration(milliseconds: 230), intensity: 0.45, sharpness: 0.5),
      IosTap(at: Duration(milliseconds: 460), intensity: 0.45, sharpness: 0.5),
    ],
    android: [
      APrim(Prim.tick, 0.5),
      APrim(Prim.tick, 0.5, delay: Duration(milliseconds: 230)),
      APrim(Prim.tick, 0.5, delay: Duration(milliseconds: 230)),
    ],
    fallback: Fallback.light,
  );

  /// Wind-down · Ebb — starts gentle and only fades.
  static const prismWindDown = HapticSpec(
    name: 'aq.prism.winddown',
    ios: [
      IosCurve(duration: Duration(milliseconds: 1400), sharpness: 0.05, points: [(0, 0.3), (1, 0)]),
    ],
    android: [APrim(Prim.quickFall, 0.4)],
    preferWave: true,
    fallback: Fallback.light,
  );

  /// No sound — one dull tap. Present, but nothing more.
  static const prismNone = HapticSpec(
    name: 'aq.prism.none',
    ios: [IosTap(intensity: 0.3, sharpness: 0.2)],
    android: [APrim(Prim.lowTick, 0.5)],
    fallback: Fallback.light,
  );

  /// The Prism pattern for a mode name as the app spells it
  /// (`prismModes`: Deep Work, Flow, Review, Wind-down, No sound).
  static HapticSpec prism(String mode) => switch (mode.toLowerCase()) {
        'deep work' || 'deep' => prismDeep,
        'flow' => prismFlow,
        'review' => prismReview,
        'wind-down' || 'wind down' || 'winddown' => prismWindDown,
        _ => prismNone,
      };

  // ── System ─────────────────────────────────────────────────────────────

  /// The platform's own success. Never restyled.
  static const success = HapticSpec(
    name: 'aq.success',
    ios: [IosTap(intensity: 0.6, sharpness: 0.6), IosTap(at: Duration(milliseconds: 100), intensity: 0.9, sharpness: 0.7)],
    iosSystem: 'success',
    android: [APrim(Prim.click, 0.6), APrim(Prim.click, 0.9, delay: Duration(milliseconds: 80))],
    androidConstant: 'fb:CONFIRM',
    fallback: Fallback.success,
  );

  /// The platform's own error. Real failures only: a wrong one-time code, a
  /// failed save, a lost connection.
  static const error = HapticSpec(
    name: 'aq.error',
    ios: [
      IosTap(intensity: 0.8, sharpness: 0.4),
      IosTap(at: Duration(milliseconds: 90), intensity: 0.8, sharpness: 0.4),
      IosTap(at: Duration(milliseconds: 180), intensity: 0.8, sharpness: 0.4),
    ],
    iosSystem: 'error',
    android: [
      APrim(Prim.click, 0.8),
      APrim(Prim.click, 0.8, delay: Duration(milliseconds: 80)),
      APrim(Prim.click, 0.8, delay: Duration(milliseconds: 80)),
    ],
    androidConstant: 'fb:REJECT',
    fallback: Fallback.error,
  );

  /// Every pattern in the lexicon, for the tests and the spec check.
  static List<HapticSpec> get all => [
        tick,
        tap,
        latch,
        unlatch,
        clink,
        for (var s = 0; s < 5; s++) texture(s),
        friction(2),
        knock,
        thud,
        crack,
        crystallise(),
        melt,
        breath,
        ratchet(const Duration(milliseconds: 1200)),
        drill,
        bloom,
        prismDeep,
        prismFlow,
        prismReview,
        prismWindDown,
        prismNone,
        success,
        error,
      ];
}

/// The breath on Android: 0 → 70 → 0 of 255, in 100 ms steps, 4 s in and
/// 6 s out.
AWave _breathWave() {
  final amps = <int>[
    for (var i = 0; i < 40; i++) (70 * i / 40).round(),
    for (var i = 0; i < 60; i++) (70 * (1 - i / 60)).round(),
  ];
  return AWave(List<int>.filled(amps.length, 100), amps);
}

/// [n] gaps from [from] to [to] ms, closing geometrically.
List<int> _geometric(int from, int to, int n) {
  if (n <= 1) return [to];
  return [for (var k = 0; k < n; k++) (from * math.pow(to / from, k / (n - 1))).round()];
}

/// Gaps closing geometrically from [from] to [to] whose sum is exactly
/// [total] ms: the fewest taps whose gaps reach the release point, with the
/// last gap trimmed so the final tap lands on it.
List<int> _gapsFilling(int from, int to, int total) {
  if (total <= 0) return const [];
  for (var n = 2; n < 400; n++) {
    final gaps = _geometric(from, to, n);
    if (gaps.fold<int>(0, (a, b) => a + b) < total) continue;
    final out = <int>[];
    var sum = 0;
    for (final g in gaps) {
      if (sum + g >= total) {
        out.add(total - sum);
        break;
      }
      out.add(g);
      sum += g;
    }
    return out;
  }
  return [total];
}
