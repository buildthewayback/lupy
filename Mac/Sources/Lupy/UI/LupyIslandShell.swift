// THE SHELL — puts the island canvas in a real window, on both kinds of Mac.
//
// Two jobs, both straight from the law:
//   1. PLACEMENT. Notch Mac: the band wraps the housing (top = 0). Bare Mac (the
//      founder's M1 2020): a software capsule `softwareGap` under the menu bar.
//      One code path, decided by the hardware, exactly like Coucou's pill.
//   2. THE JUMP. Every state change re-reads the canvas from the kernel and the
//      window morphs to it with one spring — capsule to line to open card — so
//      LUPY grows from himself instead of teleporting. The spring is the jump;
//      the rig's own hop rides inside it.
//
// Deliberately tiny. The v0.2 controller (IslandWindowController, 2000+ lines of
// polling and screen-following) keeps running the old UI until the swap-over;
// this file is the new UI's home, so nothing proven gets edited blind.

import AppKit
import SwiftUI

// MARK: - Where the island hangs

enum LupyIslandAnchor: Equatable {
    case notch      // the band wraps the camera housing
    case software   // a capsule floating under the menu bar (no-notch Macs)
}

struct LupyIslandPlacement: Equatable {
    let anchor: LupyIslandAnchor
    /// Points from the top edge of the screen to the top edge of the island.
    let top: CGFloat

    static func forScreen(_ screen: NSScreen) -> LupyIslandPlacement {
        // A notch shows up as a safe-area inset at the top of the screen.
        if screen.safeAreaInsets.top > 0 {
            return LupyIslandPlacement(anchor: .notch, top: 0)
        }
        return LupyIslandPlacement(
            anchor: .software,
            top: NSStatusBar.system.thickness + CGFloat(LupyIslandLayout.softwareGap))
    }

    /// The window frame, in AppKit's bottom-left coordinates, centred horizontally.
    func frame(for canvas: LupyCanvas, on screen: NSScreen) -> NSRect {
        let sf = screen.frame
        let x = sf.midX - canvas.width / 2
        let y = sf.maxY - top - canvas.height
        return NSRect(x: x, y: y, width: canvas.width, height: canvas.height)
    }
}

// MARK: - The window

/// A borderless, non-activating panel that lives above the menu bar, joins every
/// Space, and morphs with a spring whenever the kernel says the canvas changed.
final class LupyIslandShellController: NSObject {
    private var panel: NSPanel?
    private var hosting: NSHostingView<AnyView>?

    /// The spring that IS the jump: quick out, settles without wobbling away.
    private static let jump = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1.0)

    func show<Surface: View>(canvas: LupyCanvas,
                             on screen: NSScreen,
                             @ViewBuilder surface: () -> Surface) {
        let placement = LupyIslandPlacement.forScreen(screen)
        let frame = placement.frame(for: canvas, on: screen)

        if panel == nil {
            let p = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false)
            p.isFloatingPanel = true
            p.becomesKeyOnlyIfNeeded = true
            p.level = NSWindow.Level(rawValue:
                Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                    .stationary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false                    // the glass carries its own shadow
            p.acceptsMouseMovedEvents = true
            p.hidesOnDeactivate = false
            let host = NSHostingView<AnyView>(rootView: AnyView(EmptyView()))
            host.frame = NSRect(origin: .zero, size: frame.size)
            host.layer?.backgroundColor = .clear
            p.contentView = host
            hosting = host
            panel = p
            p.orderFrontRegardless()
        }

        guard let panel, let hosting else { return }
        hosting.rootView = AnyView(
            surface()
                .frame(width: canvas.width, height: canvas.height)
        )

        // Morph, don't teleport: frame and corner ride the same spring.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.42
            ctx.timingFunction = Self.jump
            ctx.allowsImplicitAnimation = true
            panel.setFrame(frame, display: true)
            hosting.frame = NSRect(origin: .zero, size: frame.size)
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

// MARK: - The morphing surface wrapper

/// Clips the surface to the canvas corner and lets SwiftUI animate the corner
/// itself, so the capsule's roundness melts into the open card's 24 pt.
struct LupyIslandMorph<Surface: View>: View {
    let canvas: LupyCanvas
    @ViewBuilder var surface: () -> Surface

    var body: some View {
        surface()
            .frame(width: canvas.width, height: canvas.height)
            .clipShape(RoundedRectangle(cornerRadius: canvas.corner,
                                        style: .continuous))
            .animation(.spring(response: 0.42, dampingFraction: 0.86),
                       value: canvas.corner)
    }
}
