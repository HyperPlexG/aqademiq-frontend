/// The four psychoacoustic layers of the Prism soundscape
/// (PRISM_SOUND_ENGINE_ARCHITECTURE §4).
///
/// | Layer   | Role                                          |
/// |---------|-----------------------------------------------|
/// | pad     | Tonal anchor / key centre (F#), always-on loop |
/// | texture | Environmental masking (rain/sea/hum), loop     |
/// | pulse   | Rhythmic entrainment one-shots on the BPM clock|
/// | spark   | Stochastic spatial interest (anti-fatigue)     |
enum LayerType { pad, texture, pulse, spark }
