import AppKit
import SwiftUI

//  A standalone window for looking at the character with a real mouse.
//
//  `Lupy.app/Contents/MacOS/Lupy --character-preview`
//
//  This exists so the rig can be judged on its own, without the island, a task, or
//  an API key. Resize the window from 120 pt up to 800 pt: the silhouette is Bézier
//  geometry, so it must stay clean at every size.

@MainActor
enum LupyCharacterPreview {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LUPY — character rig"
        window.minSize = NSSize(width: 120, height: 110)
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        window.contentView = NSHostingView(rootView:
            LupyCanvasView()
                .frame(minWidth: 120, minHeight: 110)
                .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
