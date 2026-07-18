/// Prism — the Aqademiq Adaptive SoundScape Engine.
///
/// A 4-layer generative ambient engine (pad / texture / pulse / spark) on top
/// of SoLoud, ported per `PRISM_SOUND_ENGINE_ARCHITECTURE.md`. Product code
/// should talk to `AdaptiveSoundEngine.instance` and the models only.
library;

export 'adaptive_sound_engine.dart';
export 'dsp_chain.dart';
export 'models/bio_inputs.dart';
export 'models/layer_type.dart';
export 'models/preset_mode.dart';
export 'models/soundscape_params.dart';
export 'models/stem.dart';
export 'parameter_mapper.dart';
export 'scheduler.dart';
export 'sound_manifest.dart';
export 'stem_layer_manager.dart';
