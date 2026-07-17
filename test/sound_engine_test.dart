import 'package:aqademiq/sound_engine/models/bio_inputs.dart';
import 'package:aqademiq/sound_engine/models/layer_type.dart';
import 'package:aqademiq/sound_engine/models/preset_mode.dart';
import 'package:aqademiq/sound_engine/models/soundscape_params.dart';
import 'package:aqademiq/sound_engine/parameter_mapper.dart';
import 'package:aqademiq/sound_engine/sound_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gain helpers', () {
    test('dbToLinear matches 10^(db/20)', () {
      expect(dbToLinear(0), closeTo(1.0, 1e-9));
      expect(dbToLinear(-6), closeTo(0.501187, 1e-5));
      expect(dbToLinear(-18), closeTo(0.125892, 1e-5));
      expect(dbToLinear(-30), closeTo(0.031623, 1e-5));
    });

    test('linearToDb inverts dbToLinear and clamps at silence', () {
      expect(linearToDb(dbToLinear(-18)), closeTo(-18, 1e-6));
      expect(linearToDb(0), lessThan(-170)); // clamped, not -inf
    });
  });

  group('presets (§6.1)', () {
    test('focus preset seeds BPM from heart rate + 5, clamped 60-90', () {
      expect(SoundscapeParams.focus().pulseBpm, 77); // default HR 72

      expect(SoundscapeParams.focus(heartRate: 40).pulseBpm, 60);
      expect(SoundscapeParams.focus(heartRate: 120).pulseBpm, 90);
      final p = SoundscapeParams.focus();
      expect(p.masterLpfCutoff, 18000);
      expect(p.pulseDensity, 2.0);
      expect(p.pulseVolume, 0.8);
      expect(p.sparkTriggerProb, 0.3);
      expect(p.masterGain, 1.0);
      expect(p.textureBrownNoise, isFalse);
    });

    test('relax preset mutes rhythm and darkens the LPF', () {
      final p = SoundscapeParams.relax(); // default HR 72
      expect(p.pulseBpm, 62);
      expect(p.pulseVolume, 0);
      expect(p.masterLpfCutoff, 600);
      expect(p.masterGain, 0.5);
      expect(p.textureBrownNoise, isTrue);
      expect(p.padReverbWet, 0.55);
    });

    test('break preset is slow and wet', () {
      final p = SoundscapeParams.breakMode();
      expect(p.pulseBpm, 60);
      expect(p.pulseVolume, 0.3);
      expect(p.masterLpfCutoff, 3000);
      expect(p.padReverbWet, 0.6);
      expect(p.textureVolumeDb, -24);
    });

    test('mapper short-circuits to presets for non-manual modes', () {
      const inputs = BioInputs(heartRate: 80);
      expect(
        ParameterMapper.map(inputs, mode: PresetMode.focus).pulseBpm,
        85,
      );
      expect(
        ParameterMapper.map(inputs, mode: PresetMode.relax).pulseBpm,
        70,
      );
      expect(
        ParameterMapper.map(inputs, mode: PresetMode.breakMode).pulseBpm,
        60,
      );
    });
  });

  group('manual bio mapping (§6.2)', () {
    test('high heart rate triggers the calming override', () {
      const inputs = BioInputs(heartRate: 120, ultradianOverride: 0.5);
      final p = ParameterMapper.map(inputs);
      expect(p.padCutoff, 400);
      expect(p.pulseVolume, 0.3);
      expect(p.sparkTriggerProb, 0.35);
    });

    test('pulse follows iso-principle: HR - 10, clamped 50-150', () {
      const inputs = BioInputs(ultradianOverride: 0.5);
      expect(ParameterMapper.map(inputs).pulseBpm, 62);
      expect(
        ParameterMapper.map(inputs.copyWith(heartRate: 40)).pulseBpm,
        50,
      );
    });

    test('movement raises texture level within -30..-12 dB', () {
      const still = BioInputs(movementLevel: 0, ultradianOverride: 0.5);
      const moving = BioInputs(movementLevel: 1, ultradianOverride: 0.5);
      expect(ParameterMapper.map(still).textureVolumeDb, -30);
      expect(ParameterMapper.map(moving).textureVolumeDb, -12);
    });

    test('heartRateNormalised spans 40-160 BPM', () {
      expect(const BioInputs(heartRate: 40).heartRateNormalised, 0);
      expect(const BioInputs(heartRate: 100).heartRateNormalised, 0.5);
      expect(const BioInputs(heartRate: 200).heartRateNormalised, 1);
    });
  });

  group('params lerp (§5.5)', () {
    test('continuous fields interpolate, bool switches at t=0.5', () {
      final a = SoundscapeParams.focus(); // brown=false, lpf 18000
      final b = SoundscapeParams.relax(); // brown=true,  lpf 600
      final mid = a.lerp(b, 0.5);
      expect(mid.masterLpfCutoff, closeTo(9300, 1e-6));
      expect(a.lerp(b, 0.49).textureBrownNoise, isFalse);
      expect(a.lerp(b, 0.5).textureBrownNoise, isTrue);
      expect(a.lerp(b, 0).masterGain, 1.0);
      expect(a.lerp(b, 1).masterGain, 0.5);
    });

    test('sparkOctave lerps then rounds', () {
      final a = SoundscapeParams.focus(); // octave 2
      final b = SoundscapeParams.relax(); // octave 0
      expect(a.lerp(b, 0.5).sparkOctave, 1);
      expect(a.lerp(b, 0.9).sparkOctave, 0);
    });
  });

  group('manifests (§11.6)', () {
    test('focus: 2 pads, 3 textures, 2 pulses, 5 sparks', () {
      final m = SoundManifest.focusMode();
      expect(m.pads, hasLength(2));
      expect(m.textures, hasLength(3));
      expect(m.pulses, hasLength(2));
      expect(m.sparks, hasLength(5));
      expect(m.allStems, hasLength(12));
    });

    test('relax: choir pad + sea, no pulses, one warm spark', () {
      final m = SoundManifest.relaxMode();
      expect(m.pads.single.assetPath, contains('choir'));
      expect(m.textures.single.assetPath, contains('sea'));
      expect(m.pulses, isEmpty);
      expect(m.sparks.single.assetPath, contains('warm'));
    });

    test('break: slow pad + rain + one bass pulse, no sparks', () {
      final m = SoundManifest.breakMode();
      expect(m.pads.single.assetPath, contains('slow-f-sharp'));
      expect(m.textures.single.assetPath, contains('rain'));
      expect(m.pulses.single.assetPath, contains('Dreams'));
      expect(m.sparks, isEmpty);
    });

    test('textures carry noise-colour metadata in noteName (§18.1 fix)', () {
      final textures = SoundManifest.focusMode().textures;
      expect(
        textures.map((t) => t.noteName),
        containsAll(<String>['pink', 'brown']),
      );
      for (final t in textures) {
        expect(t.type, LayerType.texture);
      }
    });

    test('pulse probabilities sum to 1 for weighted picking', () {
      final pulses = SoundManifest.focusMode().pulses;
      final sum = pulses.fold<double>(0, (s, p) => s + p.probability);
      expect(sum, closeTo(1.0, 1e-9));
    });
  });
}
