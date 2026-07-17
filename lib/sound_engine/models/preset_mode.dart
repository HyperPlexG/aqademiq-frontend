/// Factory soundscape presets (PRISM_SOUND_ENGINE_ARCHITECTURE §5.2).
///
/// [manual] routes the full bio-driven `ParameterMapper` formulas; the other
/// three short-circuit to fixed presets. The Prism UI maps its mode names onto
/// these (see `prism_audio_provider.dart`):
///
/// * Deep Work / Flow → [focus]
/// * Wind-down        → [relax]
/// * Review           → [breakMode]
enum PresetMode { manual, focus, relax, breakMode }
