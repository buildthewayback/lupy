// Lupy — drives Coucou's own island from Lupy's state, without changing its views:
// - a "Lupy" pill (an agent, like a coding-agent session) whose character state and step ticker show
//   what needs you, what is delegated and what Lupy is doing (including computer control);
// - Lupy's policy approvals on Coucou's approval card (Deny / Allow), answered through
//   HookServer.sendApprovalDecision, which hands Lupy's cards back here;
// - notices as Coucou's transient note, with Coucou's sounds — only when the engine's notification
//   budget allows interrupting (Notice.pushed) or the notice is urgent; otherwise a pill badge.
// Coucou's own approvals (Claude Code, Codex…) always keep priority on the card.

import AppKit
import LupyCore
import SwiftUI

@MainActor
final class LupyIslandBridge {
    static let shared = LupyIslandBridge()
    /// Pill id (a stable contract value, like Coucou's pill ids). The island's pill tap and the
    /// approval card's Always button check this literal.
    static let pillId = "agent_lupy"
    static let pillColor = "#FB923C"

    private var syncScheduled = false
    private var started = false
    /// The Lupy approval currently on Coucou's card, and the card's id.
    private var card: (approvalID: LupyID, cardID: UUID)?
    private var focusBeforeApproval: String?

    private init() {}

    /// Starts after Coucou's launch greeting so the first sync never interrupts it.
    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(forName: .greetComplete, object: nil, queue: .main) { _ in
            Task { @MainActor in LupyIslandBridge.shared.scheduleSync() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            Task { @MainActor in LupyIslandBridge.shared.scheduleSync() }
        }
    }

    /// Coalesces bursts of engine changes into one island update.
    func scheduleSync() {
        guard started, !syncScheduled else { return }
        syncScheduled = true
        DispatchQueue.main.async {
            Task { @MainActor in
                LupyIslandBridge.shared.syncScheduled = false
                LupyIslandBridge.shared.sync()
            }
        }
    }

    // MARK: - Pill

    func sync() {
        let model = LupyModel.shared
        guard model.engine != nil else { return }
        let st = AppState.shared
        let a = model.attention
        let pending = model.state.pendingApprovals.sorted { $0.requestedAt < $1.requestedAt }
        let control = LupyControlCenter.shared
        let wanted = !pending.isEmpty || !a.items.isEmpty || model.isBusy || a.waitingOnOthers > 0 || control.isActive

        if wanted {
            let botState = pillState(attention: a, pending: pending, control: control, busy: model.isBusy)
            let lines = steps(attention: a, control: control, busy: model.isBusy)
            if let idx = st.tasks.firstIndex(where: { $0.id == Self.pillId }) {
                if st.tasks[idx].state != botState { st.tasks[idx].state = botState }
                if st.tasks[idx].steps != lines {
                    st.tasks[idx].steps = lines
                    st.tasks[idx].stepIndex = max(0, lines.count - 1)
                }
            } else {
                let task = AgentTask(id: Self.pillId, name: "Lupy", color: Self.pillColor, state: botState,
                                     stepIndex: max(0, lines.count - 1), steps: lines, source: .agent)
                st.addTask(task)
                if st.mode == .hidden { NotificationCenter.default.post(name: .hookReveal, object: nil) }
            }
        } else if let idx = st.tasks.firstIndex(where: { $0.id == Self.pillId }), card == nil {
            // LUPY white-label: this pill is the island's HOME now (the main pill) —
            // at rest it stays, calm, instead of vanishing and leaving an
            // editor's card as the island's face.
            if st.tasks[idx].state != .idle { st.tasks[idx].state = .idle }
            let quiet = ["All quiet"]
            if st.tasks[idx].steps != quiet { st.tasks[idx].steps = quiet; st.tasks[idx].stepIndex = 0 }
        }
        syncApprovalCard(pending)
    }

    private func pillState(attention a: AttentionSummary, pending: [ApprovalRequest],
                           control: LupyControlCenter, busy: Bool) -> BotState {
        if control.isActive { return control.isLocating ? .searching : .working }
        if a.paused { return .sleeping }
        if !pending.isEmpty { return .approval }
        if a.items.contains(where: { $0.kind == .contradiction || $0.kind == .escalation }) { return .error }
        if busy { return .thinking }
        if !a.items.isEmpty { return .question }
        return .idle
    }

    /// The pill's ticker: newest last (Coucou shows the step at stepIndex).
    private func steps(attention a: AttentionSummary, control: LupyControlCenter, busy: Bool) -> [String] {
        var lines: [String] = []
        let s = LupyModel.shared.state
        for id in a.nextUp.prefix(2) {
            if let t = s.tasks[id] { lines.append("Next: \(TextUtil.truncate(t.title, 60))") }
        }
        if a.waitingOnOthers > 0 { lines.append("\(a.waitingOnOthers) delegated — Lupy is following up") }
        for item in a.items.prefix(3) { lines.append(TextUtil.truncate(item.title, 70)) }
        if busy { lines.append("Thinking with your cloud model…") }
        if control.isActive { lines.append(control.statusLine) }
        return lines.isEmpty ? ["All quiet"] : lines
    }

    // MARK: - Approvals on Coucou's card

    private func syncApprovalCard(_ pending: [ApprovalRequest]) {
        let st = AppState.shared
        if let c = card, !pending.contains(where: { $0.id == c.approvalID }) {
            // Decided elsewhere (Lupy window) or expired: close our card.
            if st.pendingApproval?.id == c.cardID { closeCard() } else { card = nil }
        }
        guard let next = pending.first else { return }
        // A Coucou approval (a coding agent waiting) keeps the card; Lupy's waits its turn.
        if let shown = st.pendingApproval, shown.pillId != Self.pillId { return }
        if let c = card, c.approvalID == next.id {
            if st.pendingApproval?.queueCount != pending.count { st.pendingApproval?.queueCount = pending.count }
            return
        }
        let cardID = UUID()
        card = (next.id, cardID)
        st.updateTask(id: Self.pillId, state: .approval)
        st.pendingApproval = ApprovalInfo(sessionId: "lupy", tool: next.action.kind.label,
                                          command: Self.cardText(next), inputKey: next.id.raw,
                                          pillId: Self.pillId, id: cardID, queueCount: pending.count,
                                          projectName: Self.projectName(next))
        st.isPinned = true
        if focusBeforeApproval == nil { focusBeforeApproval = st.focusId }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { st.focusId = Self.pillId }
        SoundEngine.shared.play("approval")
        expand(to: .approval)
    }

    static func cardText(_ r: ApprovalRequest) -> String {
        var text = r.action.title
        if !r.consequence.isEmpty { text += "\n" + r.consequence }
        return TextUtil.truncate(text, 240)
    }

    static func projectName(_ r: ApprovalRequest) -> String {
        guard let pid = r.action.projectID, let p = LupyModel.shared.state.projects[pid] else { return "Lupy" }
        return p.name
    }

    /// Called by HookServer.sendApprovalDecision for a card that shows one of Lupy's approvals.
    func decide(_ decision: String, cardID: UUID?) {
        guard let c = card else {
            closeCard()
            return
        }
        if let cardID, cardID != c.cardID { return }   // a click meant for a card that moved on
        card = nil
        let approve = decision == "allow" || decision == "always"
        LupyModel.shared.act { try $0.decideApproval(c.approvalID, approve: approve, note: "Decided from the notch") }
        closeCard()
        scheduleSync()   // the next Lupy approval, if any, takes the card
    }

    private func closeCard() {
        let st = AppState.shared
        st.pendingApproval = nil
        st.isPinned = false
        if let prev = focusBeforeApproval {
            focusBeforeApproval = nil
            if st.focusId == Self.pillId, st.tasks.contains(where: { $0.id == prev }) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { st.focusId = prev }
            }
        }
        st.view = .lupyChat   // Lupy: the conversation continues where the founder was interrupted
    }

    // MARK: - Notices

    func present(_ n: Notice) {
        scheduleSync()
        let st = AppState.shared
        guard n.pushed || n.severity == .urgent else {
            if st.focusId != Self.pillId { st.setPillBadge(n.severity == .urgent ? .error : .finished, for: Self.pillId) }
            return
        }
        // Never cover a card waiting for an answer.
        guard st.pendingApproval == nil, st.pendingQuestion == nil else {
            st.setPillBadge(n.severity == .urgent ? .error : .finished, for: Self.pillId)
            return
        }
        let message = TextUtil.truncate(n.body.isEmpty ? n.title : "\(n.title) — \(n.body)", 200)
        st.noteMessage = message
        SoundEngine.shared.play(n.severity == .urgent ? "error" : "question")
        expand(to: .note)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            Task { @MainActor in
                let s = AppState.shared
                if s.view == .note, s.noteMessage == message, s.pendingApproval == nil {
                    NotificationCenter.default.post(name: .islandCollapse, object: nil)
                }
            }
        }
    }

    /// Short transient message from Lupy (computer control start/stop, delivery results).
    func flash(_ message: String, sound: String? = nil) {
        let st = AppState.shared
        guard st.pendingApproval == nil, st.pendingQuestion == nil else { return }
        st.noteMessage = message
        if let sound { SoundEngine.shared.play(sound) }
        expand(to: .note)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            Task { @MainActor in
                let s = AppState.shared
                if s.view == .note, s.noteMessage == message, s.pendingApproval == nil {
                    NotificationCenter.default.post(name: .islandCollapse, object: nil)
                }
            }
        }
    }

    /// Same rules as HookServer's expandIfNeeded: approvals always win; other alerts never cover a card.
    private func expand(to view: IslandView) {
        let st = AppState.shared
        if st.mode == .expanded {
            if view == .approval || st.pendingApproval == nil { st.view = view }
        } else {
            NotificationCenter.default.post(name: .hookExpand, object: view)
        }
    }

    /// The Lupy pill was clicked in the island: open Lupy's conversation surface right here —
    /// the quick interaction point. The workspace (full detail, tasks, handoffs) opens from the
    /// conversation's own “Open workspace” button, or the Lupy window's sidebar.
    func openFromIsland() {
        let st = AppState.shared
        if st.mode == .expanded {
            st.view = .lupyChat
        } else {
            NotificationCenter.default.post(name: .hookExpand, object: IslandView.lupyChat)
        }
    }
}
