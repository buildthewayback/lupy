import SwiftUI

//  The status bubble.
//
//  The character carries the state on his body — colour in the light, an icon badge
//  pinned to his right edge. This is the other half: the words, in a bubble that
//  floats *beside* him, never on top of his head.
//
//      ╭──────╮
//      │      │ ⬤   ╭─────────────────╮
//      │  ◕◕  │     │  Working  · · · │
//      ╰──────╯     ╰─────────────────╯
//
//  Motion follows the conventions that make a status indicator feel alive without
//  becoming noise (the same rules the good web loaders use):
//
//  * three dots that light in sequence, never a frozen "…" — a still ellipsis reads
//    as a crashed app;
//  * the resting dots sit at 0.28 opacity rather than 0 — dots that vanish make the
//    bubble look empty for most of the cycle;
//  * the stagger is a third of the cycle, so the three read as one travelling wave
//    rather than three separate blinks;
//  * a new state *slides* in from the left with a short spring; it never pops;
//  * Reduce Motion is honoured: the wave stops, the text stays, nothing is lost.

struct LupyStatusBubble: View {
    var state: LupyCharacterState
    /// The machine's own facts, shown under the bubble.
    var detail: String? = nil
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        let t = state.tint
        return Color(red: t.r, green: t.g, blue: t.b)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            bubble
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: compact ? 9.5 : 10.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.40))
                    .monospacedDigit()
                    .lineLimit(1)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: detail)
    }

    private var bubble: some View {
        HStack(spacing: 7) {
            Text(state.label)
                .font(.system(size: compact ? 11.5 : 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))
                .tracking(0.1)
                .fixedSize()

            if state.isOngoing {
                LupyThreeDots(tint: tint, size: compact ? 3.4 : 4.0)
                    .opacity(0.95)
            }
        }
        .padding(.leading, compact ? 11 : 13)
        .padding(.trailing, compact ? 11 : 13)
        .frame(height: compact ? 26 : 30)
        .background(bubbleFill)
        .overlay(alignment: .leading) { tail }
        .contentShape(Capsule(style: .continuous))
        .id(state)                       // a new state is a new bubble, so it can slide in
        .transition(.asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86),
                   value: state)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.label)
        .accessibilityValue(state.isOngoing ? "in progress" : "")
    }

    // MARK: surface

    /// Glass, not a card: two very close greys, a bright top edge and a soft drop
    /// shadow. The state's colour enters only as a hairline rim, so the bubble reads
    /// as belonging to the character without competing with his light.
    private var bubbleFill: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.155).opacity(0.96),
                             Color(white: 0.105).opacity(0.96)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16),
                                     Color.white.opacity(0.045)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.30), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
            .shadow(color: tint.opacity(0.18), radius: 10)
    }

    /// A tiny notch on the left: the bubble points at him without touching him.
    private var tail: some View {
        Triangle()
            .fill(Color(white: 0.125))
            .frame(width: 6, height: 9)
            .offset(x: -5)
            .overlay(
                Triangle()
                    .stroke(tint.opacity(0.30), lineWidth: 0.8)
                    .frame(width: 6, height: 9)
                    .offset(x: -5)
            )
    }

    private var bubbleRim: some View { EmptyView() }   // kept for symmetry; rim is in the fill
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - the three dots

/// Three dots that light in turn — the standard, well-tested "still working" signal.
/// One cycle is 1.2 s, each dot starts a third of a cycle after the one before it.
/// Under Reduce Motion the dots simply sit at half brightness: the information
/// ("something is still running") stays, the movement goes.
struct LupyThreeDots: View {
    var tint: Color
    var size: CGFloat = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let period: Double = 1.2

    var body: some View {
        HStack(spacing: size * 1.15) {
            ForEach(0..<3, id: \.self) { index in
                dot(index)
            }
        }
        .frame(width: size * 3 + size * 1.15 * 2, alignment: .center)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func dot(_ index: Int) -> some View {
        if reduceMotion {
            Circle()
                .fill(tint.opacity(0.65))
                .frame(width: size, height: size)
        } else {
            // TimelineView rather than three animations: one clock, one truth, no
            // drift between the dots when the window is occluded and resumed.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let phase = (t / period + Double(index) / 3.0).truncatingRemainder(dividingBy: 1)
                // A short bright pulse (0…0.45 of the cycle), then rest.
                let lit = phase < 0.45 ? 1 - phase / 0.45 : 0
                let eased = lit * lit * (3 - 2 * lit)     // smoothstep
                Circle()
                    .fill(tint.opacity(0.28 + 0.62 * eased))
                    .frame(width: size, height: size)
                    .scaleEffect(0.86 + 0.24 * eased)
            }
        }
    }
}

// MARK: - convenience

extension LupyCharacterState {
    /// True while the state is still going, so the bubble knows to animate.
    var isOngoing: Bool {
        switch self {
        case .working, .thinking, .searching: return true
        default: return false
        }
    }
}

#if DEBUG
#Preview("Status bubbles") {
    VStack(alignment: .leading, spacing: 16) {
        LupyStatusBubble(state: .working, detail: "CPU 84 % · Xcode, node")
        LupyStatusBubble(state: .thinking)
        LupyStatusBubble(state: .approval)
        LupyStatusBubble(state: .finished)
    }
    .padding(24)
    .background(Color(red: 0.07, green: 0.07, blue: 0.08))
}
#endif
