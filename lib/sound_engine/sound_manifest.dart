import 'models/layer_type.dart';
import 'models/stem.dart';

const String _base = 'assets/audio/stems/focus_mode';

// The full stem catalogue (PRISM_SOUND_ENGINE_ARCHITECTURE §11). All modes
// reuse the same Focus WAV files with different subsets.

const Stem _padSlowFsharp = Stem(
  assetPath: '$_base/pads/572778__deadrobotmusic__fubfmf-slow-f-sharp-minor.wav',
  type: LayerType.pad,
  noteName: 'F#',
);
const Stem _padChoirFsharp = Stem(
  assetPath:
      '$_base/pads/808032__deadrobotmusic__ambient-f-sharp-minor-ethereal-choir-pad-1.wav',
  type: LayerType.pad,
  noteName: 'F#',
);

const Stem _textureRain = Stem(
  assetPath: '$_base/textures/mixkit-light-rain-loop-2393.wav',
  type: LayerType.texture,
  noteName: 'pink',
);
const Stem _textureHum = Stem(
  assetPath: '$_base/textures/mixkit-space-ship-hum-2136.wav',
  type: LayerType.texture,
  noteName: 'brown',
);
const Stem _textureSea = Stem(
  assetPath: '$_base/textures/mixkit-windy-sea-loop-1200.wav',
  type: LayerType.texture,
  noteName: 'pink',
);

const Stem _pulseDreamsBass = Stem(
  assetPath: '$_base/pulses/Cymatics - Dreams Synth Bass - E.wav',
  type: LayerType.pulse,
  probability: 0.6,
  noteName: 'E',
);
const Stem _pulseEternity808 = Stem(
  assetPath: '$_base/pulses/Cymatics - Eternity 808 - E.wav',
  type: LayerType.pulse,
  probability: 0.4,
  noteName: 'E',
);

const Stem _sparkKalimba = Stem(
  assetPath: '$_base/sparks/kalimba-hit-note-high-f_F_minor.wav',
  type: LayerType.spark,
  noteName: 'F',
);
const Stem _sparkPluck = Stem(
  assetPath: '$_base/sparks/pluck-shot-c-key.wav',
  type: LayerType.spark,
  noteName: 'C',
);
const Stem _sparkRhodesBassy = Stem(
  assetPath: '$_base/sparks/rhodes-piano-one-shots-bassy_F.wav',
  type: LayerType.spark,
  noteName: 'F',
);
const Stem _sparkRhodesFull = Stem(
  assetPath: '$_base/sparks/rhodes-piano-one-shots-full_F.wav',
  type: LayerType.spark,
  noteName: 'F',
);
const Stem _sparkRhodesWarm = Stem(
  assetPath: '$_base/sparks/rhodes-piano-one-shots-warm-fat_F.wav',
  type: LayerType.spark,
  noteName: 'F',
);

/// Per-mode stem registry (PRISM_SOUND_ENGINE_ARCHITECTURE §11.6).
class SoundManifest {
  const SoundManifest({
    required this.pads,
    required this.textures,
    required this.pulses,
    required this.sparks,
  });

  /// Focus: 2 pads, 3 textures, 2 pulses, 5 sparks.
  factory SoundManifest.focusMode() => const SoundManifest(
        pads: [_padSlowFsharp, _padChoirFsharp],
        textures: [_textureRain, _textureHum, _textureSea],
        pulses: [_pulseDreamsBass, _pulseEternity808],
        sparks: [
          _sparkKalimba,
          _sparkPluck,
          _sparkRhodesBassy,
          _sparkRhodesFull,
          _sparkRhodesWarm,
        ],
      );

  /// Relax / Mellow: choir pad + sea texture, no pulses, one warm spark.
  factory SoundManifest.relaxMode() => const SoundManifest(
        pads: [_padChoirFsharp],
        textures: [_textureSea],
        pulses: [],
        sparks: [_sparkRhodesWarm],
      );

  /// Break: slow pad + rain, one bass pulse, no sparks.
  factory SoundManifest.breakMode() => const SoundManifest(
        pads: [_padSlowFsharp],
        textures: [_textureRain],
        pulses: [_pulseDreamsBass],
        sparks: [],
      );

  final List<Stem> pads;
  final List<Stem> textures;
  final List<Stem> pulses;
  final List<Stem> sparks;

  /// Every stem across all layers (for preloading).
  Iterable<Stem> get allStems =>
      [...pads, ...textures, ...pulses, ...sparks];

  /// Intended octave filter for sparks. The current asset set carries no
  /// octave metadata, so this returns all sparks (documented no-op, §18.2).
  List<Stem> sparksByOctave(int octave) => sparks;
}
