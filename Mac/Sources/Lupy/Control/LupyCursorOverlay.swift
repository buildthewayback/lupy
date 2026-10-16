// Lupy — the Lupy cursor: a visual overlay (not a second macOS pointer) that shows where Lupy is
// acting while it operates an app. It is drawn in transparent, click-through windows above every
// app (one per display) so it never intercepts the founder's clicks; the founder's own pointer is
// never moved. The cursor only moves to a target Lupy has actually located, and the click ripple
// is drawn only when a real click has been sent (LupyControlCenter drives it).
// A small banner (bottom centre, clear of the island) says what Lupy is doing and has Stop.

import AppKit
import LupyCore
import Observation
import SwiftUI

@MainActor
@Observable
final class LupyCursorModel {
    enum Phase: Equatable { case idle, moving, locating, executing, succeeded, failed, awaitingApproval, stopped }

    var visible = false
    /// Global screen point, origin top-left of the primary display (Accessibility's space).
    var position = CGPoint(x: 0, y: 0)
    /// Frame of the element Lupy located (same space), highlighted while it acts on it.
    var target: UIRect?
    var phase: Phase = .idle
    var label = ""
    /// Incremented once per real click sent by Lupy: drives the ripple.
    var clicks = 0
    var bannerTitle = ""
    var bannerDetail = ""
    var paused = false
}

@MainActor
final class LupyCursorOverlay {
    static let shared = LupyCursorOverlay()
    let model = LupyCursorModel()
    private var panels: [NSPanel] = []
    private var banner: NSPanel?
    private var screensObserver: NSObjectProtocol?

    private init() {}

    func show(startAt start: CGPoint? = nil) {
        if panels.isEmpty { build() }
        if let start { model.position = start } else { model.position = Self.islandPoint() }
        model.visible = true
        model.phase = .idle
        model.target = nil
        for p in panels { p.orderFrontRegardless() }
        banner?.orderFrontRegardless()
    }

    /// For the control self-test: the overlay never takes the founder's clicks.
    var panelCount: Int { panels.count }
    var allPanelsClickThrough: Bool { !panels.isEmpty && panels.allSatisfy { $0.ignoresMouseEvents } }
    var allPanelsAboveApps: Bool { !panels.isEmpty && panels.allSatisfy { $0.level.rawValue >= NSWindow.Level.statusBar.rawValue } }

    func hide() {
        model.visible = false
        model.target = nil
        for p in panels { p.orderOut(nil) }
        banner?.orderOut(nil)
    }

    /// Glides to the centre of `rect` (a located element); returns when the cursor has arrived.
    func move(to rect: UIRect, label: String) async {
        let dest = CGPoint(x: rect.centerX, y: rect.centerY)
        let dx = dest.x - model.position.x, dy = dest.y - model.position.y
        let distance = (dx * dx + dy * dy).squareRoot()
        let duration = min(0.75, max(0.25, distance / 1500))
        model.label = label
        model.phase = .moving
        withAnimation(.easeInOut(duration: 0.18)) { model.target = rect }
        withAnimation(.timingCurve(0.3, 0.0, 0.2, 1.0, duration: duration)) { model.position = dest }
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    func set(_ phase: LupyCursorModel.Phase, label: String? = nil) {
        withAnimation(.easeInOut(duration: 0.15)) {
            model.phase = phase
            if let label { model.label = label }
        }
    }

    /// Only called right after a real click (AXPress or key) was sent to the app.
    func click() { model.clicks &+= 1 }

    func setBanner(_ title: String, _ detail: String, paused: Bool = false) {
        model.bannerTitle = title
        model.bannerDetail = detail
        model.paused = paused
    }

    /// Top centre of the island's screen: Lupy's cursor comes out of the notch.
    static func islandPoint() -> CGPoint {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
        guard let s = screen, let primary = NSScreen.screens.first else { return CGPoint(x: 400, y: 40) }
        let midX = s.frame.midX
        let topY = primary.frame.maxY - s.frame.maxY + 40
        return CGPoint(x: midX, y: topY)
    }

    private func build() {
        for p in panels { p.orderOut(nil) }
        panels.removeAll()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for screen in NSScreen.screens {
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true          // never intercepts the founder's clicks
            panel.level = .screenSaver               // above apps, menus and the island
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.contentView = NSHostingView(rootView: LupyCursorLayer(model: model, screenFrame: screen.frame, primaryHeight: primaryHeight))
            panel.setFrame(screen.frame, display: false)
            panels.append(panel)
        }
        if banner == nil {
            let b = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 64), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            b.isOpaque = false
            b.backgroundColor = .clear
            b.hasShadow = true
            b.level = .statusBar
            b.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            b.isReleasedWhenClosed = false
            b.hidesOnDeactivate = false
            b.becomesKeyOnlyIfNeeded = true
            b.contentView = NSHostingView(rootView: LupyControlBanner(model: model))
            banner = b
        }
        if let main = NSScreen.main ?? NSScreen.screens.first, let b = banner {
            let vf = main.visibleFrame
            b.setFrameOrigin(NSPoint(x: vf.midX - 260, y: vf.minY + 18))
        }
        if screensObserver == nil {
            screensObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                     object: nil, queue: .main) { _ in
                Task { @MainActor in
                    let o = LupyCursorOverlay.shared
                    let wasVisible = o.model.visible
                    o.build()
                    if wasVisible { for p in o.panels { p.orderFrontRegardless() } }
                }
            }
        }
    }
}

// MARK: - Drawing

/// The pointer shape: a classic arrow, drawn in Coucou orange with a white outline so it can never
/// be mistaken for the system pointer.
struct LupyPointerShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: 0, y: h * 0.86))
        p.addLine(to: CGPoint(x: w * 0.27, y: h * 0.64))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 1.0))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.93))
        p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.58))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.58))
        p.closeSubpath()
        return p
    }
}

struct LupyCursorLayer: View {
    let model: LupyCursorModel
    let screenFrame: CGRect
    let primaryHeight: CGFloat

    /// Accessibility (top-left, primary display) → this window's local top-left coordinates.
    private func local(_ x: Double, _ y: Double) -> CGPoint {
        let cocoaY = primaryHeight - CGFloat(y)
        return CGPoint(x: CGFloat(x) - screenFrame.minX, y: screenFrame.maxY - cocoaY)
    }

    private var tint: Color {
        switch model.phase {
        case .succeeded: return HubTheme.green
        case .failed, .stopped: return HubTheme.red
        case .awaitingApproval: return Color(hex: "#F5A524")
        default: return HubTheme.accent
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if model.visible {
                if let t = model.target {
                    let o = local(t.x, t.y)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(tint, lineWidth: 2.5)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.opacity(0.10)))
                        .frame(width: CGFloat(t.width) + 8, height: CGFloat(t.height) + 8)
                        .position(x: o.x + CGFloat(t.width) / 2, y: o.y + CGFloat(t.height) / 2)
                        .shadow(color: tint.opacity(0.5), radius: 8)
                }
                let p = local(model.position.x, model.position.y)
                LupyClickRipple(clicks: model.clicks, color: tint)
                    .position(x: p.x, y: p.y)
                ZStack(alignment: .topLeading) {
                    LupyPointerShape()
                        .fill(tint)
                        .overlay(LupyPointerShape().stroke(Color.white, lineWidth: 2))
                        .frame(width: 24, height: 30)
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 1, y: 2)
                    HStack(spacing: 6) {
                        HubLiveMochi(color: "#F5F6F8", size: 16, state: model.phase == .failed ? .error : (model.phase == .awaitingApproval ? .approval : .working))
                            .frame(width: 22, height: 16)
                        if !model.label.isEmpty {
                            Text(model.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.82)))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.9), lineWidth: 1.2))
                    .offset(x: 22, y: 26)
                }
                .position(x: p.x + 12, y: p.y + 15)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// A ring that expands once per real click.
struct LupyClickRipple: View {
    let clicks: Int
    let color: Color
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 3)
            .frame(width: 46, height: 46)
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: clicks) { _, _ in
                scale = 0.2
                opacity = 1
                withAnimation(.easeOut(duration: 0.55)) {
                    scale = 1.4
                    opacity = 0
                }
            }
    }
}

/// "Lupy is using Safari — typing the brief" with Stop (and Resume when paused).
struct LupyControlBanner: View {
    let model: LupyCursorModel

    var body: some View {
        HStack(spacing: 12) {
            HubLiveMochi(size: 26, state: model.paused ? .sleeping : .working)
                .frame(width: 34, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.bannerTitle.isEmpty ? "Lupy is using your Mac" : model.bannerTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HubTheme.text)
                    .lineLimit(1)
                Text(model.bannerDetail.isEmpty ? "Press Esc to stop" : model.bannerDetail + " · Esc to stop")
                    .font(.system(size: 11.5))
                    .foregroundColor(HubTheme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if model.paused {
                Button("Resume") { LupyControlCenter.shared.resume() }
                    .buttonStyle(HubButtonStyle(primary: true))
            }
            Button("Stop") { LupyControlCenter.shared.stop(reason: "you pressed Stop") }
                .buttonStyle(LupyDangerButtonStyle())
                .accessibilityLabel("Stop computer control")
        }
        .padding(.horizontal, 14)
        .frame(width: 520, height: 64)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "#0E0F11").opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(HubTheme.accent.opacity(0.45)))
        .preferredColorScheme(.dark)
    }
}
