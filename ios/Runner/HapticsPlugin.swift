import CoreHaptics
import CoreMotion
import Flutter
import UIKit

/// Plays the haptic lexicon (`lib/services/haptics/haptic_lexicon.dart`) on
/// the Taptic Engine.
///
/// Dart sends one pattern per call:
///
///     { id, name, ios: [event], iosSystem, fallback, spanMs, faceDownAlt }
///
/// where an event is a transient `{type: tap, at, i, s}` or a continuous
/// event with an intensity curve `{type: curve, at, ms, s, s2?, pts: [[t, i]]}`.
///
/// Each curve plays on its own player, because a Core Haptics parameter curve
/// applies to everything in its pattern and holds its last value afterwards:
/// a melt's swell would otherwise silence the drips that follow it. All the
/// players of one pattern start against the same engine clock.
///
/// Three rungs: Core Haptics; the system feedback generators for
/// `aq.success` / `aq.error` / phones without Core Haptics (playing the
/// spec's "Fallback" preset); and nothing at all on a device with no motor.
/// Never throws across the channel — a missing motor is not an app error.
final class HapticsPlugin {
  static let channelName = "aqademiq/haptics"

  private let channel: FlutterMethodChannel
  private var engine: CHHapticEngine?
  private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

  /// Players by pattern id, so a later signature or a released hold can stop
  /// one that is still playing.
  private var active: [Int: [CHHapticPatternPlayer]] = [:]

  private let motion = CMMotionManager()
  private var faceDown = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "play":
        self.play(args)
        result(nil)
      case "stop":
        self.stop(
          id: args["id"] as? Int ?? 0,
          fadeMs: args["fadeMs"] as? Int ?? 0,
          level: args["level"] as? Double ?? 0
        )
        result(nil)
      case "deviceState":
        let thermal = ProcessInfo.processInfo.thermalState
        result([
          "lowPower": ProcessInfo.processInfo.isLowPowerModeEnabled,
          "hot": thermal == .serious || thermal == .critical,
        ])
      case "watchFaceDown":
        self.watchFaceDown(args["on"] as? Bool ?? false)
        result(nil)
      case "capabilities":
        result(["coreHaptics": self.supportsHaptics])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if supportsHaptics {
      prepareEngine()
      // Patterns are ready before the first touch (principle 5): the engine is
      // kept running while the app is in front and restarted the moment it
      // comes back, so even the first play of a session has no start-up delay.
      NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        if self.engine == nil { self.prepareEngine() } else { try? self.engine?.start() }
      }
    }
  }

  // MARK: - engine

  private func prepareEngine() {
    do {
      let engine = try CHHapticEngine()
      engine.playsHapticsOnly = true
      engine.isAutoShutdownEnabled = false
      // Both handlers run on Core Haptics' own queue; play() reads `engine` on
      // main. Hop to main so a stop landing mid-play cannot free it under us.
      engine.stoppedHandler = { [weak self, weak engine] _ in
        DispatchQueue.main.async {
          guard let self, self.engine === engine else { return }
          self.engine = nil
          self.active.removeAll()
        }
      }
      engine.resetHandler = { [weak self] in
        DispatchQueue.main.async {
          try? self?.engine?.start()
        }
      }
      try engine.start()
      self.engine = engine
    } catch {
      engine = nil
    }
  }

  // MARK: - playback

  private func play(_ args: [String: Any]) {
    var pattern = args
    if faceDown, let alt = args["faceDownAlt"] as? [String: Any] {
      pattern = alt
    }
    let id = args["id"] as? Int ?? 0

    if let system = pattern["iosSystem"] as? String {
      return playSystem(system)
    }
    let events = pattern["ios"] as? [[String: Any]] ?? []
    guard !events.isEmpty else { return }
    let fallback = pattern["fallback"] as? String ?? "light"
    guard supportsHaptics else { return playSystem(fallback) }

    if engine == nil { prepareEngine() }
    guard let engine else { return playSystem(fallback) }

    do {
      var players: [CHHapticPatternPlayer] = []
      let now = engine.currentTime

      let taps = events.filter { ($0["type"] as? String) == "tap" }.compactMap(Self.transient(from:))
      if !taps.isEmpty {
        let player = try engine.makePlayer(with: CHHapticPattern(events: taps, parameters: []))
        try player.start(atTime: now)
        players.append(player)
      }
      for curve in events where (curve["type"] as? String) == "curve" {
        guard let built = Self.continuous(from: curve) else { continue }
        let player = try engine.makePlayer(with: built.pattern)
        try player.start(atTime: now + built.at)
        players.append(player)
      }

      if id != 0 && !players.isEmpty {
        active[id] = players
        let span = Double(pattern["spanMs"] as? Int ?? 0) / 1000.0
        DispatchQueue.main.asyncAfter(deadline: .now() + span + 0.2) { [weak self] in
          self?.active[id] = nil
        }
      }
    } catch {
      playSystem(fallback)
    }
  }

  private static func transient(from e: [String: Any]) -> CHHapticEvent? {
    CHHapticEvent(
      eventType: .hapticTransient,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(e["i"] as? Double ?? 0)),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(e["s"] as? Double ?? 0.5)),
      ],
      relativeTime: Double(e["at"] as? Int ?? 0) / 1000.0
    )
  }

  /// One continuous event at full intensity, shaped by an intensity-control
  /// curve carrying the spec's values — so the curve *is* the intensity — and
  /// optionally a sharpness ramp (the ratchet's S .2 → .7).
  private static func continuous(from e: [String: Any]) -> (pattern: CHHapticPattern, at: TimeInterval)? {
    let seconds = Double(e["ms"] as? Int ?? 0) / 1000.0
    guard seconds > 0 else { return nil }
    let sharpness = Float(e["s"] as? Double ?? 0.5)
    let event = CHHapticEvent(
      eventType: .hapticContinuous,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
      ],
      relativeTime: 0,
      duration: seconds
    )
    let raw = (e["pts"] as? [[Double]] ?? []).filter { $0.count == 2 }
    // Core Haptics allows 16 control points per curve.
    let points = raw.prefix(16).map {
      CHHapticParameterCurve.ControlPoint(relativeTime: $0[0] * seconds, value: Float($0[1]))
    }
    var curves = [
      CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: Array(points), relativeTime: 0),
    ]
    if let to = e["s2"] as? Double {
      curves.append(CHHapticParameterCurve(
        parameterID: .hapticSharpnessControl,
        controlPoints: [
          .init(relativeTime: 0, value: 0),
          .init(relativeTime: seconds, value: Float(to) - sharpness),
        ],
        relativeTime: 0
      ))
    }
    guard let pattern = try? CHHapticPattern(events: [event], parameterCurves: curves) else { return nil }
    return (pattern, Double(e["at"] as? Int ?? 0) / 1000.0)
  }

  // MARK: - stop

  /// Stop pattern [id]. With a fade, a short continuous event takes over from
  /// [level] down to nothing — the breath "fades out over 150 ms", a ratchet
  /// lifted early "ends with a soft fall".
  private func stop(id: Int, fadeMs: Int, level: Double) {
    guard let players = active.removeValue(forKey: id) else { return }
    for player in players {
      try? player.stop(atTime: CHHapticTimeImmediate)
    }
    guard fadeMs > 0, level > 0.01, let engine else { return }
    let seconds = Double(fadeMs) / 1000.0
    let event = CHHapticEvent(
      eventType: .hapticContinuous,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
      ],
      relativeTime: 0,
      duration: seconds
    )
    let curve = CHHapticParameterCurve(
      parameterID: .hapticIntensityControl,
      controlPoints: [.init(relativeTime: 0, value: Float(level)), .init(relativeTime: seconds, value: 0)],
      relativeTime: 0
    )
    if let pattern = try? CHHapticPattern(events: [event], parameterCurves: [curve]),
       let player = try? engine.makePlayer(with: pattern) {
      try? player.start(atTime: CHHapticTimeImmediate)
    }
  }

  // MARK: - system feedback

  /// `aq.success` and `aq.error` are the platform's own (never restyled), and
  /// the spec's Fallback row for phones without Core Haptics.
  private func playSystem(_ kind: String) {
    DispatchQueue.main.async {
      switch kind {
      case "success":
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      case "error":
        UINotificationFeedbackGenerator().notificationOccurred(.error)
      case "selection":
        UISelectionFeedbackGenerator().selectionChanged()
      case "heavy":
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
      case "medium":
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      case "light":
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      default:
        break
      }
    }
  }

  // MARK: - face down

  /// While the timer is on screen, sample gravity five times a second. Face
  /// down (z > 0.9 g; the screen towards the desk) switches bloom to its
  /// desk-safe version, which hums instead of rattling.
  private func watchFaceDown(_ on: Bool) {
    guard motion.isAccelerometerAvailable else { return }
    if on {
      guard !motion.isAccelerometerActive else { return }
      motion.accelerometerUpdateInterval = 0.2
      motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
        guard let z = data?.acceleration.z else { return }
        self?.faceDown = z > 0.9
      }
    } else {
      motion.stopAccelerometerUpdates()
      faceDown = false
    }
  }
}
