import CoreHaptics
import Flutter
import UIKit

/// Renders the app's haptic patterns on the Taptic Engine.
///
/// Dart sends a list of beats — `{shape, at, ms, intensity, sharpness}` — and
/// this plays them on Core Haptics, where intensity and sharpness are first
/// class and a pattern is a real timeline. That is the whole point of the
/// channel: `HapticFeedback` could express none of it, so twenty-three distinct
/// events arrived on the motor as five.
///
/// Two fallbacks, because Core Haptics needs an iPhone 8 or newer:
///
///  * no haptic engine, but a feedback generator → play the strongest beat
///    through `UIImpactFeedbackGenerator`, which takes an intensity on iOS 13+.
///    Sharpness and timing are lost; weight survives.
///  * nothing at all (iPad, Simulator) → report failure and let Dart fall back.
///
/// Never throws across the channel. A missing motor is not an app error.
final class HapticsPlugin {
  static let channelName = "aqademiq/haptics"

  private let channel: FlutterMethodChannel
  private var engine: CHHapticEngine?
  private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "play":
        let beats = (call.arguments as? [String: Any])?["beats"] as? [[String: Any]] ?? []
        self.play(beats: beats)
        result(nil)
      case "capabilities":
        result(["coreHaptics": self.supportsHaptics])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if supportsHaptics { prepareEngine() }
  }

  // MARK: - engine

  /// Start the engine once and keep it.
  ///
  /// iOS stops it on its own — an interruption, a route change, the app going
  /// to the background — and a stopped engine plays nothing silently, which
  /// would look exactly like "haptics stopped working after a phone call". The
  /// two handlers below are what make it come back.
  private func prepareEngine() {
    do {
      let engine = try CHHapticEngine()
      engine.isAutoShutdownEnabled = true
      engine.stoppedHandler = { [weak self] _ in
        // Do not restart from in here; the next play() will, and restarting
        // eagerly from a background stop just wakes the engine to idle.
        self?.engine = nil
      }
      engine.resetHandler = { [weak self] in
        try? self?.engine?.start()
      }
      try engine.start()
      self.engine = engine
    } catch {
      engine = nil
    }
  }

  // MARK: - playback

  private func play(beats: [[String: Any]]) {
    guard !beats.isEmpty else { return }
    guard supportsHaptics else { return playFallback(beats: beats) }

    if engine == nil { prepareEngine() }
    guard let engine else { return playFallback(beats: beats) }

    do {
      let events = beats.compactMap(Self.event(from:))
      guard !events.isEmpty else { return }
      let pattern = try CHHapticPattern(events: events, parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      // A pattern the engine refused, or an engine that died between the guard
      // and the play. One beat through the generator still beats nothing.
      playFallback(beats: beats)
    }
  }

  private static func event(from beat: [String: Any]) -> CHHapticEvent? {
    let intensity = Float(beat["intensity"] as? Double ?? 0)
    let sharpness = Float(beat["sharpness"] as? Double ?? 0.5)
    let at = Double(beat["at"] as? Int ?? 0) / 1000.0
    let parameters = [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
    ]

    if (beat["shape"] as? String) == "hold" {
      // `ms` is the Android pulse length for a tap and the real duration for a
      // hold; only the latter reaches here.
      let seconds = Double(beat["ms"] as? Int ?? 0) / 1000.0
      guard seconds > 0 else { return nil }
      return CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: parameters,
        relativeTime: at,
        duration: seconds
      )
    }

    // A transient has no duration on iOS — strength is intensity. This is why
    // the Dart side carries a separate Android pulse length and why nothing
    // here reads it.
    return CHHapticEvent(
      eventType: .hapticTransient,
      parameters: parameters,
      relativeTime: at
    )
  }

  /// iPhone 7 and older, or an engine that will not play.
  ///
  /// Plays only the strongest beat: the generators have no timeline, and firing
  /// several on a `DispatchQueue.asyncAfter` ladder produces a rattle rather
  /// than a pattern.
  private func playFallback(beats: [[String: Any]]) {
    var peak = 0.0
    var sharpness = 0.5
    for beat in beats {
      let intensity = beat["intensity"] as? Double ?? 0
      if intensity > peak {
        peak = intensity
        sharpness = beat["sharpness"] as? Double ?? 0.5
      }
    }
    guard peak > 0 else { return }

    DispatchQueue.main.async {
      // Sharp and light is a selection tick; everything else is an impact
      // whose style follows weight and whose intensity is carried exactly.
      if peak < 0.45 && sharpness >= 0.7 {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        return
      }
      let style: UIImpactFeedbackGenerator.FeedbackStyle =
        peak >= 0.8 ? .heavy : (peak >= 0.5 ? .medium : .light)
      let generator = UIImpactFeedbackGenerator(style: style)
      generator.prepare()
      generator.impactOccurred(intensity: CGFloat(peak))
    }
  }
}
