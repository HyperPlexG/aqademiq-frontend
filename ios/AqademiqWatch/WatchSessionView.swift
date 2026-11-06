import SwiftUI

/// The one screen.
///
/// v11 (la-quick) draws it as the session cube, the clock, and two round
/// buttons — freeze and end — on black. That is the whole surface, and the
/// restraint is the point: a watch face is read in about a second, and anything
/// competing with the countdown loses. The mock is a thumbnail, so its sizes
/// are carried over at a watch's scale (about 1.25x) rather than literally.
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
            // Always black, as the Island and StandBy are: ice needs somewhere
            // dark to read.
            Color.black
        }
    }

    // MARK: - Running

    private func running(_ session: WatchSession) -> some View {
        VStack(spacing: 7) {
            SessionCube(left: session.left, color: AqColor.iceOnDark)
                .frame(width: 42, height: 42)

            TimeReadout(session: session)

            HStack(spacing: 10) {
                // Freeze is the characteristic press, so it wears the ice and
                // sits on the left where a right-handed thumb lands first.
                RoundControl(
                    glyph: session.frozen ? .play : .freeze,
                    ink: AqColor.iceOnDark,
                    fill: AqColor.iceOnDark.opacity(0.18),
                    busy: link.pending == (session.frozen ? "resume" : "freeze")
                ) {
                    link.send(session.frozen ? "resume" : "freeze")
                }

                // End is a square, not a cross: stopping, not cancelling.
                RoundControl(
                    glyph: .end,
                    ink: Color(aqRGB: 0xC9C6D0),
                    fill: Color.white.opacity(0.12),
                    busy: link.pending == "end"
                ) {
                    link.send("end")
                }
            }
            .padding(.top, 3)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Nothing running

    /// No session is not a failure and never says so — the same rule the lock
    /// screen keeps. No streak, no "you haven't studied", no red.
    private var idle: some View {
        VStack(spacing: 10) {
            AqArtView(art: .brandAda)
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
/// text in ice.
private struct TimeReadout: View {
    let session: WatchSession

    var body: some View {
        Group {
            if session.frozen {
                Text(staticRemaining).foregroundStyle(AqColor.iceOnDark)
            } else {
                // Never a reversed range once the end has passed.
                Text(timerInterval: Date.now...max(session.endsAt, Date.now),
                     pauseTime: nil,
                     countsDown: true)
                    .foregroundStyle(.white)
            }
        }
        .font(.system(size: 30, weight: .heavy).monospacedDigit())
        .multilineTextAlignment(.center)
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
    let glyph: AqGlyph
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
                    AqGlyphView(glyph: glyph, color: ink)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }
}
