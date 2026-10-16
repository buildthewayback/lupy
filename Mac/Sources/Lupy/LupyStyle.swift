// Lupy — the small visual vocabulary of Lupy's pages, drawn with Coucou's window components and
// colours (HubTheme, HubButtonStyle, HubLabel, HubEmptyState in FlowHub.swift / FlowHubMochis.swift),
// so Lupy's pages look like the rest of the Coucou window. Names keep the ported screens readable.

import AppKit
import LupyCore
import SwiftUI

/// Lupy: true while Lupy is the frontmost app. The window's Mochis and band particles pause when
/// it is not (Coucou's Flow window is occasional, so upstream animates whenever the window is
/// visible; Lupy's main window stays open all day, and a background app must not burn CPU/battery).
@MainActor
final class LupyAppFrontmost: ObservableObject {
    static let shared = LupyAppFrontmost()
    @Published private(set) var value: Bool

    private var observers: [NSObjectProtocol] = []

    private init() {
        value = NSApp?.isActive ?? true
        for (name, v) in [(NSApplication.didBecomeActiveNotification, true), (NSApplication.didResignActiveNotification, false)] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.value = v }
            })
        }
    }
}

enum LupyTheme {
    static let window = HubTheme.window
    static let panel = HubTheme.panel
    static let card = HubTheme.card
    static let cardDeep = Color(hex: "#141518")
    static let field = HubTheme.field
    static let line = HubTheme.line
    static let text = HubTheme.text
    static let body = HubTheme.body
    static let secondary = HubTheme.secondary
    static let muted = HubTheme.muted
    static let accent = HubTheme.accent          // Coucou orange
    static let onAccent = HubTheme.onAccent
    static let green = HubTheme.green
    static let red = HubTheme.red
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

/// A Coucou window card (HubCard's fill and border) with an optional colour wash from below,
/// the same wash Coucou's island cards use for their state.
struct LupyCardBackground: View {
    enum Wash { case red, green, pink, amber, cyan, indigo, soft, none }
    var wash: Wash = .none
    var radius: CGFloat = 14

    private var washColor: Color {
        switch wash {
        case .red: return Color(hex: "#F4505E").opacity(0.32)
        case .green: return Color(hex: "#34D399").opacity(0.28)
        case .pink: return Color(hex: "#F472B6").opacity(0.32)
        case .amber: return Color(hex: "#F5A524").opacity(0.28)
        case .cyan: return Color(hex: "#22D3EE").opacity(0.24)
        case .indigo: return Color(hex: "#6366F1").opacity(0.3)
        case .soft: return Color.white.opacity(0.04)
        case .none: return Color.clear
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(HubTheme.card)
            .overlay(
                RadialGradient(gradient: Gradient(stops: [.init(color: washColor, location: 0), .init(color: .clear, location: 0.75)]),
                               center: UnitPoint(x: 0.5, y: 1.3), startRadius: 0, endRadius: 320)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(HubTheme.line))
    }
}

/// Coucou's orange window button.
struct LupyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HubButtonStyle(primary: true).makeBody(configuration: configuration)
    }
}

/// Coucou's dark window button.
struct LupySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HubButtonStyle().makeBody(configuration: configuration)
    }
}

/// Coucou's window button shape, tinted red, for cancelling or accepting without proof.
struct LupyDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(HubTheme.text)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(HubTheme.red.opacity(configuration.isPressed ? 0.35 : 0.22)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(HubTheme.red.opacity(0.35)))
            .contentShape(Rectangle())
    }
}

/// Small coloured capsule with a status label.
struct LupyStatusChip: View {
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

/// Coucou's small capitals above a list.
struct LupySectionTitle: View {
    let text: String
    var body: some View { HubLabel(text) }
}

/// An empty list: Coucou's sleeping Mochi, a title and a plain-language line.
struct LupyEmptyHint: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 6) {
            HubLiveMochi(size: 46, state: .sleeping)
                .frame(height: 46)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(HubTheme.body)
            Text(detail).font(.system(size: 12.5)).foregroundColor(HubTheme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .accessibilityElement(children: .combine)
    }
}

/// Lupy's short messages ("Copied", "Plan approved"…), at the bottom of its pages.
struct LupyToast: View {
    var body: some View {
        let model = LupyModel.shared
        if let toast = model.toast {
            Text(toast)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(HubTheme.text)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: "#1D1E22")))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
                .padding(.bottom, 18)
                .onTapGesture { LupyModel.shared.toast = nil }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
    }
}
