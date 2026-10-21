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
//  v1 shot every state empty; v2 (this version) seeds founder-shaped payloads
//  (a long shell command, a 4-option question, task ledgers, a chat with a
//  wall of text + emoji + URLs) so overflow, truncation and bleeding show
//  themselves in the photographs instead of on the founder's screen.

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

        // Seed the conversation file BEFORE LupyChat.shared first wakes (its
        // init loads it). Throwaway runner only — the founder's Mac never runs
        // this harness, and the next CI job is a fresh machine.
        struct ConvoFile: Codable { var messages: [LupyChatMessage] }
        let convo: [LupyChatMessage] = [
            .init(role: .user,
                  text: "Invoice ACME by Friday, then chase them if they don't pay 🙏"),
            .init(role: .assistant,
                  text: "Here's my plan — approve it right here, or change it in Today. First I'll draft invoice #1042 from the June receipts (Rent 450,00 € · Software 89,99 € · Travel 1.204,50 €), total 1.744,49 €. Then I'll send it to billing@acme-example.com and watch for the payment confirmation. If nothing lands in 5 days I'll remind you before writing to them. Nothing is sent until you approve."),
            .init(role: .user,
                  text: "looks good — and what about the €2,450 from March?? also check https://billing.example.com/invoices/2026/march/final-final-v3.pdf"),
            .init(role: .assistant,
                  text: "March is still open: €2,450 since 14 Mar — that's 221 days, with two unanswered threads. Want me to prepare a polite chase email for your OK?"),
        ]
        if let data = try? JSONEncoder().encode(ConvoFile(messages: convo)) {
            let url = LupyModel.shared.dataURL.appendingPathComponent("conversation.json")
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? data.write(to: url)
            print("SEEDED conversation.json (\(data.count)B)")
        }

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

        // — LIVE payloads: founder-shaped data at stress lengths —
        func liveReset() {
            state.pendingApproval = nil
            state.pendingQuestion = nil
            state.tasks = []
            state.focusId = nil
            state.stateOverride = nil
        }
        func liveSnap(_ name: String, _ v: IslandView) {
            state.mode = .expanded
            state.view = v
            let (w, h) = islandSize(mode: .expanded, view: v,
                                    nw: state.notchWidth, nh: state.notchHeight)
            snap(name, IslandContainer(state: state).environment(\.colorScheme, .dark),
                 CGSize(width: w, height: h + 40))
        }

        liveReset()
        state.pendingApproval = ApprovalInfo(
            sessionId: "sess-7f3a", tool: "Bash",
            command: "cd ~/Projects/displate && npm run build && rsync -avz --delete dist/ marky@ssh.example.com:/var/www/html/ && curl -s https://example.com/health | head -c 200",
            inputKey: "", pillId: "agent_codex", queueCount: 3, projectName: "displate")
        state.stateOverride = .approval
        liveSnap("live-approval", .approval)

        liveReset()
        state.pendingQuestion = AskQuestion(questions: [
            AskQuestionItem(
                question: "The deploy script wants to replace the live site (2,314 files) with tonight's build. Ship it now, or wait until morning when you can watch it?",
                header: "Deploy",
                options: [
                    .init(label: "Ship now", description: "The site updates in about 40 seconds; rollback is one click."),
                    .init(label: "Tomorrow 9:00", description: ""),
                    .init(label: "Show me the diff first, every file", description: "Slower, but you see exactly what changes."),
                    .init(label: "Cancel", description: ""),
                ],
                multiSelect: false)])
        state.stateOverride = .question
        liveSnap("live-question", .question)

        liveReset()
        let working = AgentTask(id: "shot-work", name: "Publish June invoice pack",
                                color: "#38BDF8", state: .working, stepIndex: 2,
                                steps: ["Gather receipts", "Draft invoice", "Send to ACME", "Watch for payment", "File in Drive"],
                                source: .agent)
        let errored = AgentTask(id: "shot-err", name: "Sync Displate payouts",
                                color: "#F4505E", state: .error, steps: [], source: .agent,
                                finalLine: "The payout file stopped at row 1,024 of 9,870: column 'net_amount' is missing in march_final_FINAL.csv")
        let doneT = AgentTask(id: "shot-done", name: "Back up the studio folder",
                              color: "#34D399", state: .finished, steps: [], source: .agent,
                              finalLine: "4.2 GB copied to the external drive; checksums match.")
        state.tasks = [working, errored, doneT]
        state.focusId = working.id
        liveSnap("live-overview", .overview)

        state.focusId = errored.id
        state.stateOverride = .error
        liveSnap("live-error", .error)

        state.focusId = doneT.id
        state.stateOverride = .finished
        liveSnap("live-finished", .finished)

        state.stateOverride = nil
        liveSnap("live-chat", .lupyChat)

        // The bubbles themselves, minus the ScrollView (a static renderer can
        // leave a ScrollView blank; bubble layout is where overflow lives).
        // Build them from values directly so this shot can never lie about seeding.
        let convoShots: [LupyChatMessage] = [
            .init(role: .user,
                  text: "Invoice ACME by Friday, then chase them if they don't pay 🙏"),
            .init(role: .assistant,
                  text: "Here's my plan — approve it right here, or change it in Today. First I'll draft invoice #1042 from the June receipts (Rent 450,00 € · Software 89,99 € · Travel 1.204,50 €), total 1.744,49 €. Then I'll send it to billing@acme-example.com and watch for the payment confirmation. If nothing lands in 5 days I'll remind you before writing to them. Nothing is sent until you approve."),
            .init(role: .user,
                  text: "looks good — and what about the €2,450 from March?? also check https://billing.example.com/invoices/2026/march/final-final-v3.pdf"),
            .init(role: .assistant,
                  text: "March is still open: €2,450 since 14 Mar — that's 221 days, with two unanswered threads. Want me to prepare a polite chase email for your OK?"),
        ]
        print("CHAT shared messages after file seed: \(LupyChat.shared.messages.count)")
        snap("live-chatbubbles",
             VStack(alignment: .leading, spacing: 6) {
                 ForEach(convoShots) { m in LupyChatBubble(message: m) }
             }
             .frame(width: 500, alignment: .leading)
             .padding(12),
             CGSize(width: 524, height: 470))

        // The pill at work and in trouble: the light talks, no words, no badge noise.
        state.mode = .compact
        state.view = .empty
        state.stateOverride = .working
        snap("live-compact-working",
             IslandContainer(state: state).environment(\.colorScheme, .dark),
             CGSize(width: cw, height: ch + 40))
        state.stateOverride = .error
        snap("live-compact-error",
             IslandContainer(state: state).environment(\.colorScheme, .dark),
             CGSize(width: cw, height: ch + 40))
        liveReset()
        state.mode = .expanded

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
