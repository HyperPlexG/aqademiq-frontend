import 'layer_type.dart';

/// One playable audio asset in a `SoundManifest`
/// (PRISM_SOUND_ENGINE_ARCHITECTURE §5.3).
class Stem {
  const Stem({
    required this.assetPath,
    required this.type,
    this.probability = 1.0,
    this.noteName,
  });

  /// Flutter asset path, e.g. `assets/audio/stems/focus_mode/pads/...wav`.
  final String assetPath;

  final LayerType type;

  /// Weighted-pick weight for pulses (sparks pick uniformly).
  final double probability;

  /// Harmony / noise-type metadata: a note name for tonal stems ("F#", "E",
  /// "F", "C") or a noise colour ("pink" / "brown") for textures.
  final String? noteName;
}
