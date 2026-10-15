// Lupy macOS shell — visual language.
// Palette, card wash and capsule buttons adapted from Coucou (MIT, (c) 2026 Louis Raillé):
// HubTheme in App/FlowHub.swift, CardBackground/PrimaryButton/SecondaryButton in App/IslandViewContent.swift.
// Lupy uses its own accent (moon amber) so it is not mistaken for Coucou.

import SwiftUI

extension Color {
    init(hex: String) {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        let v = UInt64(h, radix: 16) ?? 0x808080
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

enum LupyTheme {
    static let window = Color.black
    static let panel = Color(hex: "#0E0F11")
    static let card = Color(hex: "#18191C")
    static let cardDeep = Color(hex: "#141518")
    static let field = Color(hex: "#1F2024")
    static let line = Color.white.opacity(0.07)
    static let text = Color(hex: "#F5F6F8")
    static let body = Color(hex: "#E1E3E6")
    static let secondary = Color(hex: "#8E939C")
    static let muted = Color(hex: "#6B7079")
    static let accent = Color(hex: "#FFB547")      // Lupy moon amber
    static let onAccent = Color(hex: "#1A1206")
    static let green = Color(hex: "#34D399")
    static let red = Color(hex: "#FF453A")
    static let amber = Color(hex: "#F5A524")
    static let cyan = Color(hex: "#22D3EE")
    static let indigo = Color(hex: "#6366F1")
    static let pink = Color(hex: "#F472B6")

    static func statusColor(_ s: TaskStatus) -> Color {
        switch s {
        case .completed, .accepted, .verified: return green
        case .waitingApproval, .waitingFounder, .escalated: return amber
        case .failed, .blocked: return red
        case .submitted, .verifying: return cyan
        case .dispatched, .deliveryUnconfirmed, .acknowledged, .progressEvidenced: return indigo
        case .inProgress, .recovering: return accent
        case .cancelled, .paused: return muted
        default: return secondary
        }
    }

    static func severityColor(_ s: NoticeSeverity) -> Color {
        switch s { case .urgent: return red; case .attention: return amber; case .info: return secondary }
    }
}

/// Dark card with a radial "wash" of colour from below (Coucou's state cards).
struct CardBackground: View {
    enum Wash { case red, green, pink, amber, cyan, indigo, soft, none }
    var wash: Wash = .none
    var radius: CGFloat = 18

    private var washColor: Color {
        switch wash {
        case .red: return Color(hex: "#F4505E").opacity(0.45)
        case .green: return Color(hex: "#34D399").opacity(0.38)
        case .pink: return Color(hex: "#F472B6").opacity(0.45)
        case .amber: return Color(hex: "#F5A524").opacity(0.36)
        case .cyan: return Color(hex: "#22D3EE").opacity(0.32)
        case .indigo: return Color(hex: "#6366F1").opacity(0.4)
        case .soft: return Color.white.opacity(0.06)
        case .none: return Color.clear
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LupyTheme.cardDeep)
            .overlay(
                RadialGradient(gradient: Gradient(stops: [.init(color: washColor, location: 0), .init(color: .clear, location: 0.75)]),
                               center: UnitPoint(x: 0.5, y: 1.3), startRadius: 0, endRadius: 320)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 1))
    }
}

struct LupyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(LupyTheme.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundColor(LupyTheme.onAccent)
            .clipShape(Capsule())
    }
}

struct LupySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.09))
            .foregroundColor(LupyTheme.text)
            .clipShape(Capsule())
    }
}

struct LupyDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(LupyTheme.red.opacity(configuration.isPressed ? 0.35 : 0.22))
            .foregroundColor(LupyTheme.text)
            .clipShape(Capsule())
    }
}

/// Small coloured capsule with a status label.
struct StatusChip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.8)
            .foregroundColor(LupyTheme.muted)
    }
}

/// Plain-language empty state used across screens.
struct EmptyHint: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 26)).foregroundColor(LupyTheme.muted)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(LupyTheme.body)
            Text(detail).font(.system(size: 12)).foregroundColor(LupyTheme.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}
