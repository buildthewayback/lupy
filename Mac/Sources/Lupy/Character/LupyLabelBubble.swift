import SwiftUI

//  The words that go with the face.
//
//  A state is three things at once: a colour, an eye shape, and a sentence. The colour
//  is read in a quarter second from across the room; the sentence is read when you lean
//  in; the icon is read in between. None of them is decoration — "Working…" is the
//  answer to "is it doing anything?", which is the question this character exists to
//  answer.
//
//    ┌───────────────────────────────┐
//    │  Working…                 ⚙️  │   ← the text animates, the icon is this
//    └───────────────────────────────┘      state's own glyph in its own colour

struct LupyLabelBubble: View {
    var state: LupyCharacterState
    /// The machine's own facts, shown under the bubble.
    var detail: String? = nil
    /// The island grows the bubble when there is something to add.
    var compact = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: compact ? 7 : 9) {
                AnimatedStatusText(state: state, compact: compact)
                if let icon = state.icon {
                    LupyStateIconBadge(icon: icon, tint: state.tint,
                                       size: compact ? 17 : 21,
                                       darkInk: state.iconInkIsDark)
                }
            }
            .padding(.leading, compact ? 9 : 11)
            .padding(.trailing, compact ? 3 : 4)
            .frame(height: compact ? 24 : 29)
            .background(
                Capsule(style: .continuous).fill(Color.white.opacity(0.055))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Lupy is \(state.label.lowercased())")

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .monospacedDigit()
                    .lineLimit(1)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: state)
        .animation(.easeOut(duration: 0.22), value: detail)
    }
}

// MARK: - the sentence

/// The status text, with the trailing dots animating while something is still going.
/// "Working" with a frozen "…" reads as a dead app; "Working · · ·" reads as alive.
struct AnimatedStatusText: View {
    var state: LupyCharacterState
    var compact = false

    private var isOngoing: Bool {
        switch state {
        case .working, .thinking, .searching: return true
        default: return false
        }
    }

    var body: some View {
        Group {
            if isOngoing {
                TimelineView(.periodic(from: .now, by: 0.34)) { timeline in
                    let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 0.34) % 4
                    HStack(spacing: 2.5) {
                        Text(state.label)
                        // Three dots that fill in, one every third of a second, then
                        // start again: the cheapest possible "still going" signal.
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.white.opacity(i < phase ? 0.85 : 0.22))
                                .frame(width: 2.6, height: 2.6)
                        }
                    }
                }
            } else {
                Text(state.label)
            }
        }
        .font(.system(size: compact ? 11 : 12.5, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.93))
        .tracking(0.2)
        .lineLimit(1)
    }
}

// MARK: - the icon

/// This state's glyph, in ink, inside a circle of the state's own colour — so the
/// bubble carries the same colour message as the light around the body.
struct LupyStateIconBadge: View {
    var icon: LupyStateIcon
    var tint: (r: Double, g: Double, b: Double)
    var size: CGFloat = 21
    /// Black on a bright circle, white on a deep one.
    var darkInk = true

    private var colour: Color {
        Color(red: tint.r, green: tint.g, blue: tint.b)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(colour)
                .shadow(color: colour.opacity(0.55), radius: size * 0.22)
            LupyStateIconShape(icon: icon)
                .stroke(darkInk
                            ? Color(red: 0.07, green: 0.07, blue: 0.09)
                            : Color.white,
                        style: StrokeStyle(lineWidth: size * 0.115,
                                           lineCap: .round, lineJoin: .round))
                .padding(size * 0.20)
        }
        .frame(width: size, height: size)
    }
}

/// Every icon in one place, as vector paths. Stroke-only and drawn on the same unit
/// square, so gear, bulb, magnifier, bell, ?, !, check, clock, z and spiral all sit on
/// the same optical weight.
struct LupyStateIconShape: Shape {
    var icon: LupyStateIcon

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let cx = rect.midX, cy = rect.midY
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: cx + x * s, y: cy + y * s)
        }
        var path = Path()

        switch icon {
        case .gear:
            // six teeth around a ring, plus the hole
            for i in 0..<6 {
                let a = Double(i) * .pi / 3
                let inner = 0.30, outer = 0.46
                path.move(to: p(cos(a) * inner, sin(a) * inner))
                path.addLine(to: p(cos(a) * outer, sin(a) * outer))
            }
            path.addEllipse(in: CGRect(x: cx - s * 0.17, y: cy - s * 0.17,
                                       width: s * 0.34, height: s * 0.34))

        case .bulb:
            // a bulb: dome, two filaments, a base
            path.addArc(center: p(0, -0.10), radius: s * 0.27,
                        startAngle: .degrees(160), endAngle: .degrees(380),
                        clockwise: false)
            path.move(to: p(-0.09, 0.16))
            path.addLine(to: p(-0.09, 0.26))
            path.move(to: p(0.09, 0.16))
            path.addLine(to: p(0.09, 0.26))
            path.move(to: p(-0.16, 0.40))
            path.addLine(to: p(0.16, 0.40))

        case .magnifier:
            // a lens and a handle, deliberately off-centre like a real one
            path.addEllipse(in: CGRect(x: cx - s * 0.34, y: cy - s * 0.34,
                                       width: s * 0.52, height: s * 0.52))
            path.move(to: p(0.06, 0.06))
            path.addLine(to: p(0.38, 0.38))

        case .standby:
            path.addEllipse(in: CGRect(x: cx - s * 0.26, y: cy - s * 0.26,
                                       width: s * 0.52, height: s * 0.52))

        case .bell:
            path.move(to: p(-0.32, 0.20))
            path.addQuadCurve(to: p(0, -0.34), control: p(-0.28, -0.30))
            path.addQuadCurve(to: p(0.32, 0.20), control: p(0.28, -0.30))
            path.addLine(to: p(-0.32, 0.20))
            path.move(to: p(0, 0.20))
            path.addLine(to: p(0, 0.34))
            path.move(to: p(-0.10, 0.40))
            path.addQuadCurve(to: p(0.10, 0.40), control: p(0, 0.50))

        case .question:
            path.move(to: p(-0.19, -0.18))
            path.addQuadCurve(to: p(0.20, -0.14), control: p(0, -0.46))
            path.addQuadCurve(to: p(0, 0.06), control: p(0.24, 0.10))
            path.move(to: p(0, 0.34))
            path.addLine(to: p(0, 0.35))

        case .exclamation:
            path.move(to: p(0, -0.36))
            path.addLine(to: p(0, 0.12))
            path.move(to: p(0, 0.34))
            path.addLine(to: p(0, 0.35))

        case .check:
            path.move(to: p(-0.34, 0.02))
            path.addLine(to: p(-0.10, 0.26))
            path.addLine(to: p(0.36, -0.26))

        case .clock:
            path.addEllipse(in: CGRect(x: cx - s * 0.36, y: cy - s * 0.36,
                                       width: s * 0.72, height: s * 0.72))
            path.move(to: p(0, -0.20))
            path.addLine(to: p(0, 0))
            path.addLine(to: p(0.16, 0.10))

        case .zzz:
            // one bold z, plus a smaller one above it
            path.move(to: p(-0.30, 0.28))
            path.addLine(to: p(0.06, 0.28))
            path.addLine(to: p(-0.30, 0.02))
            path.addLine(to: p(0.06, 0.02))
            path.move(to: p(0.10, -0.34))
            path.addLine(to: p(0.32, -0.34))
            path.addLine(to: p(0.10, -0.16))
            path.addLine(to: p(0.32, -0.16))

        case .spiral:
            // the same hand-drawn spiral the eyes use when he is dizzy
            var a = 0.0
            var first = true
            while a < 4.4 {
                let r = 0.055 + 0.085 * a
                let point = p(cos(a) * r, sin(a) * r)
                if first { path.move(to: point); first = false }
                else { path.addLine(to: point) }
                a += 0.25
            }
        }
        return path
    }
}

#if DEBUG
#Preview("Bubbles") {
    VStack(spacing: 14) {
        LupyLabelBubble(state: .working, detail: "CPU 84 % · Xcode, node")
        LupyLabelBubble(state: .thinking)
        LupyLabelBubble(state: .approval)
        LupyLabelBubble(state: .finished)
        LupyLabelBubble(state: .error)
        LupyLabelBubble(state: .sleeping)
    }
    .padding(28)
    .background(Color(red: 0.07, green: 0.07, blue: 0.08))
}
#endif
