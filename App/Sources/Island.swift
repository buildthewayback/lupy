// Lupy macOS shell — the notch island.
// Adapted from Coucou (MIT, (c) 2026 Louis Raillé): IslandScreenGeometry (CoucouKit),
// IslandShape (App/IslandRootView.swift) and the IslandPanel/window-level pattern
// (App/IslandWindowController.swift). Lupy's controller is much smaller: click to open,
// auto-close when the pointer leaves, no drag/voice/file-drop features.

import AppKit
import SwiftUI

struct IslandGeometry {
    let hasNotch: Bool
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let screenFrame: CGRect

    static let wing: CGFloat = 74
    static let expandedSize = CGSize(width: 460, height: 250)

    init(screen: NSScreen) {
        screenFrame = screen.frame
        let safeTop = screen.safeAreaInsets.top
        hasNotch = safeTop > 0
        if hasNotch {
            if let l = screen.auxiliaryTopLeftArea?.width, let r = screen.auxiliaryTopRightArea?.width {
                let w = screen.frame.width - l - r
                notchWidth = (w > 0 && w < screen.frame.width) ? w : 184
            } else {
                notchWidth = 184
            }
            notchHeight = safeTop
        } else {
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            notchWidth = 0
            notchHeight = min(26, max(22, menuBar > 0 ? menuBar - 2 : 24))
        }
    }

    var compactSize: CGSize {
        hasNotch ? CGSize(width: notchWidth + IslandGeometry.wing * 2, height: notchHeight)
                 : CGSize(width: 190, height: notchHeight)
    }

    func size(expanded: Bool) -> CGSize { expanded ? IslandGeometry.expandedSize : compactSize }

    func frame(expanded: Bool) -> CGRect {
        let s = size(expanded: expanded)
        return CGRect(x: screenFrame.midX - s.width / 2, y: screenFrame.maxY - s.height, width: s.width, height: s.height)
    }
}

/// Black island shape: square top (merges with the notch), rounded bottom corners.
struct IslandShape: Shape {
    var cornerRadius: CGFloat
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let cr = min(cornerRadius, rect.height / 2, rect.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cr))
        p.addArc(center: CGPoint(x: rect.maxX - cr, y: rect.maxY - cr), radius: cr, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + cr, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + cr, y: rect.maxY - cr), radius: cr, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Hosting view that reacts to the first click even though the panel never activates Lupy.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    /// Allow the panel to sit over the menu bar / notch area.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor
final class IslandController {
    static var shared: IslandController?

    let panel: IslandPanel
    private(set) var geometry: IslandGeometry
    private var timer: Timer?
    private var outsideSince: Date?
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        geometry = IslandGeometry(screen: screen)
        panel = IslandPanel(contentRect: geometry.frame(expanded: false), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let root = IslandRootView().environment(model)
        let host = FirstMouseHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: geometry.compactSize)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        model.islandGeometry = geometry
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.relocate() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func relocate() {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        geometry = IslandGeometry(screen: screen)
        model.islandGeometry = geometry
        panel.setFrame(geometry.frame(expanded: model.islandExpanded), display: true)
    }

    func setVisible(_ visible: Bool) {
        if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    /// Called by the model when the island opens/closes.
    func apply(expanded: Bool) {
        if expanded {
            panel.setFrame(geometry.frame(expanded: true), display: true)
            panel.makeKey()
            outsideSince = nil
        } else {
            // Let the SwiftUI shape animate closed before shrinking the window.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
                Task { @MainActor in
                    guard let self, !self.model.islandExpanded else { return }
                    self.panel.setFrame(self.geometry.frame(expanded: false), display: true)
                }
            }
        }
    }

    /// Auto-close when the pointer has been away from the open island for a moment.
    private func poll() {
        guard model.islandExpanded, !model.islandPinned else { outsideSince = nil; return }
        let inside = panel.frame.insetBy(dx: -12, dy: -12).contains(NSEvent.mouseLocation)
        if inside { outsideSince = nil; return }
        if outsideSince == nil { outsideSince = Date() }
        if let since = outsideSince, Date().timeIntervalSince(since) > 1.6 {
            outsideSince = nil
            model.setIsland(expanded: false)
        }
    }
}

// MARK: - SwiftUI content

struct IslandRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let expanded = model.islandExpanded
        let geo = model.islandGeometry
        ZStack(alignment: .top) {
            IslandShape(cornerRadius: expanded ? 22 : 12)
                .fill(Color.black)
            if expanded {
                IslandExpandedView()
                    .transition(.opacity)
            } else {
                IslandCompactView(notchWidth: geo?.notchWidth ?? 0, hasNotch: geo?.hasNotch ?? false)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: expanded)
        .contentShape(Rectangle())
        .onTapGesture { if !expanded { model.setIsland(expanded: true) } }
    }
}

struct IslandCompactView: View {
    @Environment(AppModel.self) private var model
    let notchWidth: CGFloat
    let hasNotch: Bool

    var body: some View {
        let summary = model.attention
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                LupyCharacterView(mood: model.mood, size: 22, animated: true, fps: 12)
                if !hasNotch {
                    Text(model.islandHeadline).font(.system(size: 11, weight: .semibold)).foregroundColor(LupyTheme.body).lineLimit(1)
                }
            }
            .frame(width: hasNotch ? IslandGeometry.wing : nil, alignment: .leading)
            .padding(.leading, 10)
            if hasNotch { Spacer(minLength: notchWidth) } else { Spacer(minLength: 4) }
            HStack(spacing: 4) {
                if summary.items.count > 0 {
                    Text("\(summary.items.count)")
                        .font(.system(size: 11, weight: .bold)).monospacedDigit()
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(LupyTheme.accent).foregroundColor(LupyTheme.onAccent)
                        .clipShape(Capsule())
                } else if model.isBusy {
                    ProgressView().controlSize(.mini).tint(LupyTheme.accent)
                } else {
                    Circle().fill(summary.paused ? LupyTheme.muted : LupyTheme.green).frame(width: 6, height: 6)
                }
            }
            .frame(width: hasNotch ? IslandGeometry.wing : nil, alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help(model.islandHeadline)
    }
}

struct IslandExpandedView: View {
    @Environment(AppModel.self) private var model
    @State private var quick = ""

    var body: some View {
        let summary = model.attention
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                LupyCharacterView(mood: model.mood, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.greeting).font(.system(size: 14, weight: .semibold)).foregroundColor(LupyTheme.text)
                    Text(model.islandHeadline).font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary).lineLimit(1)
                }
                Spacer()
                Button {
                    model.islandPinned.toggle()
                } label: {
                    Image(systemName: model.islandPinned ? "pin.fill" : "pin").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundColor(LupyTheme.secondary).help("Keep open")
                Button("Open Lupy") { model.openMainWindow(); model.setIsland(expanded: false) }
                    .buttonStyle(LupyPrimaryButtonStyle())
            }
            if summary.items.isEmpty {
                Text(summary.nextUp.isEmpty ? "All clear. Tell Lupy what you want to get done." : "Next: " + (model.state.tasks[summary.nextUp[0]]?.title ?? ""))
                    .font(.system(size: 12)).foregroundColor(LupyTheme.body).lineLimit(2)
            } else {
                ForEach(summary.items.prefix(3)) { item in
                    Button {
                        model.focus(item)
                        model.openMainWindow()
                        model.setIsland(expanded: false)
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(LupyTheme.severityColor(item.severity)).frame(width: 7, height: 7)
                            Text(item.title).font(.system(size: 12, weight: .medium)).foregroundColor(LupyTheme.text).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(LupyTheme.muted)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                TextField("Tell Lupy a goal…", text: $quick)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(LupyTheme.field).clipShape(Capsule())
                    .onSubmit { submitQuick() }
                Button("Plan") { submitQuick() }.buttonStyle(LupySecondaryButtonStyle()).disabled(quick.isEmpty)
            }
        }
        .padding(.horizontal, 16).padding(.top, (model.islandGeometry?.notchHeight ?? 24) + 6).padding(.bottom, 14)
    }

    private func submitQuick() {
        let text = quick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.capture(text, projectID: model.defaultCaptureProject, useModel: model.hasUsableModel)
        quick = ""
        model.openMainWindow()
        model.setIsland(expanded: false)
    }
}
