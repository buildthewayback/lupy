// THE DIRECTOR — routes the living app into the island shell.
//
// One observer of AppState, one spring-loaded window, every surface chosen by
// what the machine is actually doing:
//   a queued approval  -> the decision surface (the locked reference)
//   a running task     -> the task list, at its real step
//   an open chat       -> the conversation, last turns, streaming meta
//   working without UI -> the whisper band with his animated sentence
//   idle               -> the capsule, LUPY breathing in it
//
// While the director is alive it keeps the v0.2 island collapsed with the same
// notification the old FSM already obeys, so the two never overlap; the founder
// can flip `lupy3LegacyIsland` in defaults to get the old island back untouched.

import AppKit
import Combine
import SwiftUI

@MainActor
final class LupyIslandDirector: NSObject {
    private let state = AppState.shared
    private let hooks = HookServer.shared
    private let shell = LupyIslandShellController()
    private var bag = Set<AnyCancellable>()
    private var keyMonitor: Any?

    /// The composer's voice out of the island: AppDelegate binds it to chat.
    var onAsk: ((String) -> Void)?

    func start() {
        Publishers.CombineLatest5(
            state.$pendingApproval,
            state.$pendingQuestion,
            state.$tasks,
            state.$chatHistory,
            state.$view
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _, _, _ in self?.refresh() }
        .store(in: &bag)

        // ⌘Y / ⌘N answer the approval without touching the mouse — the shortcuts
        // the chips advertise by staying silent about.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.state.pendingApproval != nil,
                  event.modifierFlags.contains(.command),
                  let ch = event.charactersIgnoringModifiers?.lowercased() else { return event }
            if ch == "y" { self.decide(0); return nil }
            if ch == "n" { self.decide(1); return nil }
            return event
        }
        refresh()
    }

    func stop() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        bag.removeAll()
        shell.hide()
    }

    // MARK: - what the machine is doing -> what the island is

    private func refresh() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        if let info = state.pendingApproval {
            let payload = LupyApprovalPayload(
                meta: info.queueCount > 1
                    ? "\(info.queueCount) waiting" : "1 of 1 waiting",
                lines: [
                    .init(text: "\(info.tool.isEmpty ? "A session" : info.tool) wants to run:"),
                    .init(text: info.command, mono: true),
                    .init(text: "in \(info.projectName.isEmpty ? info.sessionId : info.projectName) · session \(String(info.sessionId.prefix(4)))", mono: true),
                ],
                chips: [
                    .init(label: "Allow once", primary: true),
                    .init(label: "Deny"),
                ])
            show(screen: screen,
                 need: .decision(options: 2, hasEvidence: true, queue: info.queueCount),
                 character: .approval) {
                LupyIslandApprovalView(payload: payload) { [weak self] i in
                    self?.decide(i)
                }
            }
            return
        }

        // A question from an agent: his capsule eyes, the choices as chips.
        if let q = state.pendingQuestion, let item = q.items.first {
            let chips = item.options.prefix(4).map { LupyApprovalChip(label: $0.label) }
            let payload = LupyApprovalPayload(
                meta: "awaiting your choice",
                lines: [
                    .init(text: item.question),
                    .init(text: item.header.isEmpty ? " " : item.header, mono: true),
                ],
                chips: Array(chips))
            show(screen: screen,
                 need: .decision(options: chips.count, hasEvidence: true, queue: 1),
                 character: .question) {
                LupyIslandApprovalView(payload: payload) { [weak self] i in
                    guard let opts = state.pendingQuestion?.items.first?.options,
                          i < opts.count else { return }
                    self?.hooks.sendQuestionAnswers([item.header: opts[i].label])
                    self?.refresh()
                }
            }
            return
        }

        // Something broke: the error card, his dash eyes, the reason in mono.
        if state.view == .error,
           let t = state.tasks.first(where: { $0.state == .error }) {
            show(screen: screen,
                 need: .answer(lines: 2, chips: 0, provenance: true),
                 character: .error) {
                LupyIslandCardView(
                    need: .answer(lines: 2, chips: 0, provenance: true),
                    state: .error,
                    payload: .init(meta: "needs attention",
                                   lines: [
                                       .init(text: t.name),
                                       .init(text: t.finalLine ?? "the session stopped",
                                             mono: true),
                                   ],
                                   provenance: t.sessionCwd ?? nil))
            }
            return
        }

        // Finished with something to say: the answer card, calm and green.
        if state.view == .finished,
           let t = state.tasks.first(where: { $0.state == .finished
                                              && !(t.finalLine ?? "").isEmpty }) {
            show(screen: screen,
                 need: .answer(lines: 2, chips: 0, provenance: true),
                 character: .finished) {
                LupyIslandCardView(
                    need: .answer(lines: 2, chips: 0, provenance: true),
                    state: .finished,
                    payload: .init(meta: "finished",
                                   lines: [
                                       .init(text: t.name),
                                       .init(text: t.finalLine ?? ""),
                                   ],
                                   provenance: t.sessionCwd ?? nil))
            }
            return
        }

        if let task = state.tasks.first(where: { $0.steps.isEmpty == false }) {
            let done = task.stepIndex
            show(screen: screen,
                 need: .task(steps: task.steps.count, hasPlan: true, hasPreview: false),
                 character: .working) {
                LupyIslandTaskView(
                    payload: .init(title: task.name,
                                   meta: "step \(min(done + 1, task.steps.count)) of \(task.steps.count)",
                                   steps: task.steps,
                                   stepIndex: done,
                                   provenance: task.finalLine),
                    state: .working)
            }
            return
        }

        if state.view == .lupyChat, !state.chatHistory.isEmpty {
            let last = state.chatHistory.suffix(6)
            let turns = last.map {
                LupyChatTurn(who: $0.role == .user ? "You:" : "Lupy:", text: $0.content)
            }
            show(screen: screen,
                 need: .chat(turns: turns.count, streaming: true),
                 character: .thinking) {
                LupyIslandChatView(turns: turns, meta: "streaming", state: .thinking)
            }
            return
        }

        // The band: a whisper when he has a sentence, the capsule when he doesn't.
        let label = state.tasks.first?.name ?? ""
        if state.tasks.contains(where: { $0.state == .working || $0.state == .thinking }) {
            show(screen: screen, need: .whisper(textWidth: 138), character: .working) {
                LupyCanvasChrome(need: .whisper(textWidth: 138), state: .working) {
                    EmptyView()
                }
            }
        } else {
            show(screen: screen, need: .rest, character: .idle) {
                LupyCanvasChrome(need: .rest, state: .idle) { EmptyView() }
            }
        }
        _ = label
    }

    private func show<Surface: View>(screen: NSScreen,
                                     need: LupyCanvasNeed,
                                     character: LupyCharacterState,
                                     @ViewBuilder surface: () -> Surface) {
        let canvas = LupyIslandLayout.canvas(need)
        shell.show(canvas: canvas, on: screen) {
            LupyIslandMorph(canvas: canvas) { surface() }
        }
        // The v0.2 island obeys this already; one line keeps the two from overlapping.
        NotificationCenter.default.post(name: .islandCollapse, object: nil)
        _ = character
    }

    private func decide(_ index: Int) {
        hooks.sendApprovalDecision(index == 0 ? "allow" : "deny")
        refresh()
    }
}
