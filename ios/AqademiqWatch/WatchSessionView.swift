import SwiftUI

/// The one screen.
///
/// §7 draws it as Ada, the clock, and two round buttons — freeze and end. That
/// is the whole surface, and the restraint is the point: a watch face is read
/// in about a second, and anything competing with the countdown loses.
struct WatchSessionView: View {
    @ObservedObject var link: WatchLink

    var body: some View {
        Group {
            if let session = link.session {
                running(session)
            } else {
                idle
            }
        }
        .containerBackground(for: .navigation) {
            // Near-black, as every mock in the spec is: purple ice needs
            // somewhere dark to read.
            Color(red: 0.055, green: 0.051, blue: 0.078)
        }
    }

    // MARK: - Running

    private func running(_ session: WatchSession) -> some View {
        VStack(spacing: 6) {
            AdaView(stage: session.meltStage, frozen: session.frozen)
                .frame(width: 46, height: 46)

            TimeReadout(session: session)

            if let title = session.taskTitle {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 4)
            }

            HStack(spacing: 14) {
                // Freeze is the characteristic press, so it wears the colour
                // and sits on the left where a right-handed thumb lands first.
                RoundControl(
                    system: session.frozen ? "play.fill" : "snowflake",
                    ink: .frostLit,
                    fill: Color.frostLit.opacity(0.18),
                    busy: link.pending == (session.frozen ? "resume" : "freeze")
                ) {
                    link.send(session.frozen ? "resume" : "freeze")
                }

                // End is a square, not a cross: stopping, not cancelling.
                RoundControl(
                    system: "stop.fill",
                    ink: .white.opacity(0.75),
                    fill: Color.white.opacity(0.10),
                    busy: link.pending == "end"
                ) {
                    link.send("end")
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Nothing running

    /// No session is not a failure and never says so — the same rule the lock
    /// screen keeps. No streak, no "you haven't studied", no red.
    private var idle: some View {
        VStack(spacing: 10) {
            AdaView(stage: 0, showsFace: true)
                .frame(width: 44, height: 44)
                .opacity(0.65)
            Text("No session")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text("Start one on your phone")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.32))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
    }
}

/// The countdown, or the held time.
///
/// The same distinction as every other surface: running, the system ticks an
/// end date for free and this app never wakes to update it; frozen, a live
/// timer would count down a session that is not running, so it becomes static
/// frost-blue text.
private struct TimeReadout: View {
    let session: WatchSession

    var body: some View {
        Group {
            if session.frozen {
                Text(staticRemaining).foregroundStyle(Color.frostLit)
            } else {
                Text(timerInterval: Date.now...session.endsAt,
                     pauseTime: nil,
                     countsDown: true)
                    .foregroundStyle(.white)
            }
        }
        .font(.system(size: 30, weight: .bold).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var staticRemaining: String {
        let safe = max(0, session.remainingSec)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }
}

/// A round control, sized for a thumb rather than for the glyph inside it.
private struct RoundControl: View {
    let system: String
    let ink: Color
    let fill: Color
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(fill)
                if busy {
                    ProgressView().controlSize(.mini).tint(ink)
                } else {
                    Image(systemName: system)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ink)
                }
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }
}

extension Color {
    static let frostLit = AdaPalette.frostLit
}
