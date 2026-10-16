// Lupy — the one conversation the founder has with Lupy, shared by the island's interaction
// surface and the window's Today page. Speech and typing are the same assistant: the mic
// dictates into the editable field (nothing is sent until the words are reviewed), and every
// message is routed honestly — offline rules decide what it means, the engine does the work,
// and the reply always reflects what actually happened.

import AppKit
import LupyCore
import Observation
import SwiftUI

// MARK: - Messages

struct LupyChatMessage: Identifiable, Equatable, Codable {
    enum Role: String, Codable { case user, assistant }
    /// text = a spoken/written turn; plan = a plan card awaiting decision (or just decided).
    enum Kind: String, Codable { case text, plan }
    var id: UUID = UUID()
    var role: Role
    var kind: Kind = .text
    var text: String
    var at: Date = Date()
    var relatedID: String? = nil
}

// MARK: - The conversation

@MainActor
@Observable
final class LupyChat {
    static let shared = LupyChat()

    private(set) var messages: [LupyChatMessage] = []
    /// Model jobs whose answer this conversation is still waiting for (shown as “thinking”).
    private(set) var waitingJobIDs: Set<String> = []
    /// Which model the in-flight turn is using, e.g. "gemini-2.5-flash" — shown in the island
    /// so the founder always sees what is actually running (updates when a retry switches route).
    private(set) var waitingModelLabel: String?
    private(set) var lastActivityAt = Date()

    @ObservationIgnored private var storeURL: URL
    @ObservationIgnored private var saveScheduled = false

    private init() {
        // The transcript lives beside the engine's journal (survives restarts; see KNOWN_LIMITATIONS
        // for why it is not part of the engine backup yet).
        storeURL = LupyModel.shared.dataURL.appendingPathComponent("conversation.json")
        load()
        if messages.isEmpty {
            messages.append(LupyChatMessage(role: .assistant, text:
                "Hi — I'm Lupy. Tell me what you want to get done, ask me anything, or say “what's next”. " +
                "Dictate with the mic: your words appear here first, and nothing is sent until you press the arrow."))
            saveSoon()
        }
    }

    var isEmpty: Bool { messages.count <= 1 && messages.allSatisfy { $0.role == .assistant } }

    var isWaiting: Bool { !waitingJobIDs.isEmpty }

    /// The island's live status line — always the real state, never decoration.
    var statusLine: String {
        let control = LupyControlCenter.shared
        if control.isActive { return control.statusLine }
        if isWaiting { return waitingModelLabel.map { "Thinking via \($0)…" } ?? "Thinking with your cloud model…" }
        let model = LupyModel.shared
        if model.attention.paused { return "Paused — say “resume” to continue" }
        let a = model.attention
        if !a.items.isEmpty { return "\(a.items.count) thing\(a.items.count == 1 ? "" : "s") need you" }
        if a.activeCount > 0 { return "\(a.activeCount) task\(a.activeCount == 1 ? "" : "s") active" }
        return "Listening"
    }

    /// The dot colour that goes with `statusLine` — same conditions, same honesty.
    var statusColor: String {
        let control = LupyControlCenter.shared
        if control.isActive { return "#F59E0B" }   // amber: my cursor is working the screen
        if isWaiting { return "#22D3EE" }            // cyan: a cloud-model answer is being prepared
        let model = LupyModel.shared
        if model.attention.paused { return "#8E939C" }   // grey: paused
        let a = model.attention
        if !a.items.isEmpty { return "#FB7185" }     // rose: decisions are waiting for you
        if a.activeCount > 0 { return "#34D399" }    // green: work is running
        return "#A5B4FC"                             // soft indigo: listening
    }

    // MARK: Sending — the interaction loop

    /// Routes one message: understand → do the real work → answer with what actually happened.
    func send(_ raw: String, projectID: LupyID? = nil, useModel: Bool = true) {
        let text = TextUtil.trimmed(raw)
        guard !text.isEmpty else { return }
        append(LupyChatMessage(role: .user, text: text))
        let model = LupyModel.shared
        let hasProposedPlan = model.state.plans.values.contains { $0.status == .proposed }

        switch ChatIntentRouter.route(text, hasProposedPlan: hasProposedPlan) {
        case .pause:
            model.act { try $0.setGlobalPause(true, reason: "Paused from the conversation"); return [] }
            reply("Paused. Follow-ups, model calls and computer control stop until you say “resume”.")

        case .resume:
            model.act { try $0.setGlobalPause(false, reason: ""); return [] }
            reply("Resumed. " + shortStatus())

        case .stop:
            stopEverything()

        case .status:
            var answer = model.engine?.conversationStatusAnswer() ?? (model.startupError ?? "Lupy is not ready.")
            if LupyControlCenter.shared.isActive { answer += "\nComputer control: " + LupyControlCenter.shared.statusLine }
            reply(answer)

        case .approvePlan(let note):
            approveNewestPlan(note: note)

        case .rejectPlan(let note):
            rejectNewestPlan(note: note)

        case .question:
            ask(text: text, projectID: projectID ?? model.defaultCaptureProject)

        case .control:
            startControl(goal: text, projectID: projectID)

        case .goal:
            captureGoal(text: text, projectID: projectID, useModel: useModel && model.hasUsableModel)
        }
    }

    private func shortStatus() -> String {
        let a = LupyModel.shared.attention
        if !a.items.isEmpty { return "\(a.items.count) thing\(a.items.count == 1 ? "" : "s") need you — the card in the island has them." }
        if a.activeCount > 0 { return "\(a.activeCount) task\(a.activeCount == 1 ? "" : "s") in motion." }
        return "Nothing needs you right now."
    }

    // MARK: The real work behind each intent

    private func captureGoal(text: String, projectID: LupyID?, useModel: Bool) {
        let model = LupyModel.shared
        switch model.captureInConversation(text, projectID: projectID ?? model.defaultCaptureProject, useModel: useModel) {
        case .offlinePlan(let planID):
            reply("Here's my plan — approve it right here, or change it in Today.")
            planMessage(planID)
        case .modelPlanStarted(let modelName):
            reply("Planning with \(modelName)… the plan appears here for your review.")
        case .needsApproval:
            reply("I need your OK before sending this goal to your cloud model — the island's card (or Needs you) has it. Declining still gives you an offline plan.")
        case .failed(let why):
            reply(why)
        }
    }

    private func ask(text: String, projectID: LupyID?) {
        let model = LupyModel.shared
        guard let engine = model.engine else { reply(model.startupError ?? "Lupy is not ready."); return }
        guard model.hasUsableModel else {
            reply("I can't answer that on my own — no AI API is set up yet. Paste any key under Lupy → Assistant → AI APIs (it stays in your Mac's Keychain) and questions like this get real answers.\n\n"
                + "Offline I can still: plan goals, tell you what's next (“what's next”), and work the screen with my own cursor when computer control is on.")
            return
        }
        do {
            switch try engine.prepareConversationTurn(question: text, history: conversationHistory(), projectID: projectID) {
            case .job(let job):
                waitingJobIDs.insert(job.id.raw)
                waitingModelLabel = job.modelID
                AppState.shared.stateOverride = .thinking
                SoundEngine.shared.play("blip")
                model.run([.callModel(job)])
            case .needsApproval:
                reply("I need your OK to send this to your cloud model — the island's card (or Needs you) has it.")
            case .unavailable(let why):
                reply(why)
            }
        } catch {
            reply("\(error)")
        }
    }

    private func startControl(goal: String, projectID: LupyID?) {
        let control = LupyControlCenter.shared
        let model = LupyModel.shared
        if let why = control.blocker() {
            reply("I can't take over the screen yet: \(why)\nWhen it's on, you watch every move as my own cursor — Esc or “stop” cancels what's queued.")
            return
        }
        if control.startAgent(goal: goal, projectID: projectID) {
            reply("I'm on it — watch my cursor work. Esc or “stop” cancels the queued steps; I report what actually happened.")
        } else {
            reply("I couldn't start that. Try it from Lupy → Computer control and check the model setup there.")
        }
    }

    private func approveNewestPlan(note: String) {
        let model = LupyModel.shared
        guard let plan = newestProposedPlan() else { reply("No plan is waiting right now."); return }
        var created = 0
        model.act { engine in
            let tasks = try engine.approvePlan(plan.id)
            created = tasks.count
            return []
        }
        replyAfterDecision(rejected: false, created: created, note: note)
    }

    /// The plan card's own buttons report back through here (same words as the routed intents).
    func replyAfterDecision(rejected: Bool, created: Int = 0, note: String = "") {
        if rejected {
            reply("Rejected. Tell me what to change and I'll plan again.")
        } else {
            reply("Plan approved\(note.isEmpty ? "" : " (“\(note)”)") — \(created) step\(created == 1 ? "" : "s") created and queued. "
                + "I follow up on each; “done” still needs evidence.")
        }
    }

    private func rejectNewestPlan(note: String) {
        let model = LupyModel.shared
        guard let plan = newestProposedPlan() else { reply("No plan is waiting right now."); return }
        model.act { try $0.rejectPlan(plan.id, note: note); return [] }
        reply(note.isEmpty
              ? "Plan rejected. Tell me what to change and I'll plan it again."
              : "Plan rejected — “\(note)”. Tell me how you want it instead and I'll plan again.")
    }

    /// Stop what is executing, honestly: the cursor's queued steps, a plan waiting for review,
    /// and (when only follow-up work was in motion) the follow-ups themselves.
    private func stopEverything() {
        var lines: [String] = []
        let control = LupyControlCenter.shared
        if control.isActive {
            control.stop(reason: "you said stop in the conversation")
            lines.append("Stopped the computer control — the queued steps are cancelled, nothing further happens.")
        }
        let model = LupyModel.shared
        if let plan = newestProposedPlan() {
            model.act { try $0.rejectPlan(plan.id, note: "Stopped from the conversation"); return [] }
            lines.append("The proposed plan was rejected.")
        }
        if lines.isEmpty {
            if model.isBusy || model.attention.activeCount > 0 {
                model.act { try $0.setGlobalPause(true, reason: "Stopped from the conversation"); return [] }
                lines.append("Nothing was running on screen. I paused my follow-ups and model calls — say “resume” to continue.")
            } else {
                lines.append("Nothing is executing right now.")
            }
        }
        reply(lines.joined(separator: " "))
    }

    // MARK: Results coming back from the engine

    /// LupyModel.perform reports every completed model job here. Returns true when the
    /// conversation consumed it (so the toast stays quiet). Retries keep the turn waiting.
    func jobCompleted(jobID: LupyID, result: ModelJobResult, retryJobs: [ModelJob]) -> Bool {
        guard waitingJobIDs.contains(jobID.raw) else { return false }
        if !result.ok, let next = retryJobs.first(where: { waitingAppliesTo($0) }) {
            waitingJobIDs.remove(jobID.raw)
            waitingJobIDs.insert(next.id.raw)
            waitingModelLabel = next.modelID   // the island shows the route switch honestly
            return true   // still thinking — the retry's answer will arrive
        }
        waitingJobIDs.remove(jobID.raw)
        if waitingJobIDs.isEmpty {
            AppState.shared.stateOverride = nil
            waitingModelLabel = nil
        }
        if result.ok {
            SoundEngine.shared.play("question")
            reply(result.message)
        } else {
            reply(result.message.isEmpty ? "That didn't work — try again in a moment." : result.message)
        }
        return true
    }

    private func waitingAppliesTo(_ job: ModelJob) -> Bool {
        if case .ask = job.kind { return true }
        return false
    }

    /// A plan finished preparing (model or offline): show it as a card in the conversation.
    func planReady(_ planID: LupyID) {
        guard LupyModel.shared.state.plans[planID] != nil else { return }
        planMessage(planID)
        saveSoon()
    }

    // MARK: History for the model (follow-ups work; the engine caps the prompt)

    func conversationHistory() -> [LLMMessage] {
        messages.suffix(12).compactMap { m in
            guard m.kind == .text else { return nil }
            return LLMMessage(m.role == .user ? .user : .assistant, m.text)
        }
    }

    // MARK: Helpers

    private func newestProposedPlan() -> Plan? {
        LupyModel.shared.state.plans.values
            .filter { $0.status == .proposed }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private func reply(_ text: String) {
        append(LupyChatMessage(role: .assistant, text: text))
    }

    private func planMessage(_ planID: LupyID) {
        append(LupyChatMessage(role: .assistant, kind: .plan, text: LupyModel.shared.state.plans[planID]?.summary ?? "",
                               relatedID: planID.raw))
    }

    private func append(_ m: LupyChatMessage) {
        messages.append(m)
        if messages.count > 300 { messages.removeFirst(messages.count - 300) }
        lastActivityAt = Date()
        saveSoon()
    }

    // MARK: Persistence (the transcript survives restarts; the engine keeps the real work)

    private func saveSoon() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.async { [weak self] in
            Task { @MainActor in self?.flush() }
        }
    }

    private func flush() {
        saveScheduled = false
        struct File: Codable { var messages: [LupyChatMessage] }
        if let data = try? JSONEncoder().encode(File(messages: messages)) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    /// Writes the transcript synchronously (self-test, support).
    func flushNow() { flush() }

    private func load() {
        struct File: Codable { var messages: [LupyChatMessage] }
        guard let data = try? Data(contentsOf: storeURL),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return }
        messages = file.messages
    }
}
