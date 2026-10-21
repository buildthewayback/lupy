//  LupySnapshotHarness.swift
//  `Lupy --snapshot-states <dir>` — the island photographs itself.
//
//  Why this exists: the founder's law (2026-10-22) is screenshot-everything QA —
//  no UI claim ships on a guess. CI runs this on a real Mac and pushes the PNGs
//  to the ci-evidence branch, where they are graded by eye (human or agent)
//  against the things he circled in red: two pills, stray word labels, tiny
//  type, bleeding rows. It renders with ImageRenderer, the same idiom the
//  character self-test already proves headless on the CI Macs.
//
//  v1 deliberately seeds NO payload data: first prove every state's frame,
//  empty-state face, and the character at rest. Payload-seeded shots (long
//  text, emoji, queues) layer on once the harness itself is field-proven.

import AppKit
import SwiftUI

enum LupySnapshotHarness {

    @MainActor
    static func run(arguments: [String]) -> Int32 {
        guard let i = arguments.firstIndex(of: "--snapshot-states"),
              i + 1 < arguments.count else {
            FileHandle.standardError.write(Data("usage: Lupy --snapshot-states <dir>\n".utf8))
            return 64
        }
        let dir = URL(fileURLWithPath: arguments[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        var index: [String] = []
        var failed = 0

        func snap<V: View>(_ name: String, _ view: V, _ size: CGSize) {
            let framed = ZStack(alignment: .top) {
                // A desktop-ish backdrop: black glass on black is how bleeding hides.
                LinearGradient(colors: [Color(red: 0.16, green: 0.21, blue: 0.30),
                                        Color(red: 0.05, green: 0.06, blue: 0.09)],
                               startPoint: .top, endPoint: .bottom)
                view
            }
            .frame(width: size.width, height: size.height)

            let renderer = ImageRenderer(content: framed)
            renderer.scale = 2
            guard let img = renderer.nsImage,
                  let tiff = img.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                print("FAIL \(name): no raster")
                failed += 1
                return
            }
            let url = dir.appendingPathComponent(name + ".png")
            do {
                try png.write(to: url)
                index.append("\(name) \(Int(size.width))x\(Int(size.height)) \(png.count)B")
                print("OK \(name)")
            } catch {
                print("FAIL \(name): \(error.localizedDescription)")
                failed += 1
            }
        }

        // The founder's Mac is a no-notch M1: Louis Raillé fake-notch geometry.
        let state = AppState.shared
        state.notchWidth = IslandConst.notchWidth
        state.notchHeight = IslandConst.notchHeight

        // — The one true pill: compact (the face he sees all day) —
        state.mode = .compact
        state.view = .empty
        let (cw, ch) = islandSize(mode: .compact, view: .empty,
                                  nw: state.notchWidth, nh: state.notchHeight)
        snap("island-compact-dark", IslandContainer(state: state).environment(\.colorScheme, .dark),
             CGSize(width: cw, height: ch + 40))
        snap("island-compact-light", IslandContainer(state: state).environment(\.colorScheme, .light),
             CGSize(width: cw, height: ch + 40))

        // — Expanded: every founder-facing surface, both appearances —
        let expandedViews: [IslandView] = [.empty, .overview, .approval, .question,
                                           .error, .finished, .prompt, .lupyChat, .settings]
        state.mode = .expanded
        for v in expandedViews {
            state.view = v
            let (w, h) = islandSize(mode: .expanded, view: v,
                                    nw: state.notchWidth, nh: state.notchHeight)
            let size = CGSize(width: w, height: h + 40)
            snap("island-\(v.rawValue)-dark",
                 IslandContainer(state: state).environment(\.colorScheme, .dark), size)
            snap("island-\(v.rawValue)-light",
                 IslandContainer(state: state).environment(\.colorScheme, .light), size)
        }

        // — The character alone: every mood, WITH its word label (the exhibit) —
        for mood in LupyCharacterState.allCases {
            snap("mood-\(mood)",
                 LupyCanvasView(state: mood, showsStatusLabel: true)
                    .frame(width: 220, height: 220),
                 CGSize(width: 220, height: 260))
        }

        // — Probe: is the yellow composer bar real, or an ImageRenderer quirk? —
        snap("probe-textfield-idle",
             LupyProbeField().frame(width: 420, height: 36),
             CGSize(width: 440, height: 76))
        snap("probe-textfield-focused",
             LupyProbeField(autoFocus: true).frame(width: 420, height: 36),
             CGSize(width: 440, height: 76))

        // — The retired twin, photographed once for the record —
        let twinNeeds: [(String, LupyCanvasNeed, LupyCharacterState)] = [
            ("twin-rest", .rest, .idle),
            ("twin-whisper", .whisper(textWidth: 138), .working),
            ("twin-decision", .decision(options: 2, hasEvidence: true, queue: 1), .approval),
            ("twin-chat", .chat(turns: 4, streaming: false), .thinking),
        ]
        for (name, need, cs) in twinNeeds {
            let c = LupyIslandLayout.canvas(need)
            snap(name,
                 LupyCanvasChrome(need: need, state: cs) { EmptyView() },
                 CGSize(width: c.width, height: c.height + 40))
        }

        let indexText = index.joined(separator: "\n") + "\n"
        try? indexText.write(to: dir.appendingPathComponent("index.txt"),
                             atomically: true, encoding: .utf8)
        print("SNAPSHOTS: \(index.count) written, \(failed) failed -> \(dir.path)")
        return failed == 0 && !index.isEmpty ? 0 : 1
    }
}


/// The chat composer in isolation — settles renderer-artifact questions.
private struct LupyProbeField: View {
    @State private var text = ""
    @FocusState private var focused: Bool
    var autoFocus = false

    var body: some View {
        TextField("Tell Lupy anything…", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 12.5))
            .lineLimit(1...3)
            .focused($focused)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear { if autoFocus { focused = true } }
    }
}
