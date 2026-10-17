import AppKit
import SwiftUI

//  A standalone window for judging the character with real eyes and a real mouse.
//
//  `Lupy.app/Contents/MacOS/Lupy --character-preview`
//
//  Two ways to use it:
//    * click a chip at the bottom to see any state, or press ← → to walk through them;
//    * turn on "Live" and the character is driven by this Mac's real processor,
//      thermal state, memory pressure and battery.
//
//  Resize the window from 120 pt to 800 pt: the silhouette is Bézier geometry, so it
//  must stay clean at every size. Nothing here needs an API key or a task.

@MainActor
final class LupyPreviewModel: ObservableObject {
    @Published var state: LupyCharacterState = .idle
    @Published var live = false
    let sampler = LupyVitalsSampler()

    var vitals: LupyVitals? { live ? sampler.vitals : nil }
    var busySamples: Int { live ? sampler.busyStreak : 0 }

    var detail: String? {
        guard live else { return nil }
        let mood = sampler.vitals.mood(busySamples: sampler.busyStreak)
        return sampler.vitals.describe(mood, top: sampler.topProcesses)
            ?? "all quiet"
    }

    func step(_ direction: Int) {
        let all = LupyCharacterState.allCases
        guard let index = all.firstIndex(of: state) else { return }
        let next = (index + direction + all.count) % all.count
        state = all[next]
        live = false
    }

    func toggleLive() {
        live.toggle()
        if live { sampler.start() } else { sampler.stop() }
    }
}

struct LupyPreviewView: View {
    @StateObject private var model = LupyPreviewModel()
    @FocusState private var keysFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            LupyLabelBubble(state: model.state, detail: model.detail)
                .padding(.top, 10)

            LupyCanvasView(state: model.state,
                           vitals: model.vitals,
                           busySamples: model.busySamples)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            chips
        }
        .background(Color(red: 0.065, green: 0.066, blue: 0.075))
        .focusable()
        .focused($keysFocused)
        .onKeyPress(.leftArrow) { model.step(-1); return .handled }
        .onKeyPress(.rightArrow) { model.step(1); return .handled }
        .onAppear { keysFocused = true }
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(LupyCharacterState.allCases, id: \.self) { state in
                chip(state.name, tint: state.tint, selected: model.state == state && !model.live) {
                    model.live = false
                    model.state = state
                }
            }
            Divider().frame(height: 14).overlay(Color.white.opacity(0.12))
            chip("Live", tint: (1, 1, 1), selected: model.live) { model.toggleLive() }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 2)
    }

    private func chip(_ title: String,
                      tint: (r: Double, g: Double, b: Double),
                      selected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: tint.r, green: tint.g, blue: tint.b))
                    .frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(selected ? 0.95 : 0.55))
            }
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(
                Capsule().fill(Color.white.opacity(selected ? 0.13 : 0.05))
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(selected ? 0.22 : 0.07),
                                       lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
enum LupyCharacterPreview {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LUPY — character rig"
        window.minSize = NSSize(width: 260, height: 240)
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.065, green: 0.066, blue: 0.075, alpha: 1)
        window.contentView = NSHostingView(rootView: LupyPreviewView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
