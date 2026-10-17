import SwiftUI

//  The words that go with the face.
//
//  A state is three things at once: a colour, an eye shape, and a sentence. The colour
//  is read in a quarter second from across the room; the sentence is read when you
//  lean in. Neither is decoration — "Working…" is the answer to "is it doing anything?",
//  which is the question this character exists to answer.

struct LupyLabelBubble: View {
    var state: LupyCharacterState
    /// The machine's own facts, shown under the bubble while hovering.
    var detail: String? = nil

    private var tint: Color {
        let t = state.tint
        return Color(red: t.r, green: t.g, blue: t.b)
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .shadow(color: tint.opacity(0.9), radius: 3)
                Text(state.bubbleText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.93))
                    .tracking(0.2)
            }
            .padding(.horizontal, 12)
            .frame(height: 27)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.055))
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

#if DEBUG
#Preview("Bubbles") {
    VStack(spacing: 14) {
        LupyLabelBubble(state: .working, detail: "CPU 84 % · Xcode, node")
        LupyLabelBubble(state: .thinking)
        LupyLabelBubble(state: .approval)
        LupyLabelBubble(state: .finished)
    }
    .padding(28)
    .background(Color(red: 0.07, green: 0.07, blue: 0.08))
}
#endif
