// LupyCore — the conversation layer under the island's interaction surface.
// ChatIntentRouter decides what the founder's message means, offline, with plain rules
// (the same philosophy as Coucou's voice-command parser: deterministic, explainable, no
// hidden model calls). The engine then serves it: local answers for status, real planning
// for goals, and — when the founder has allowed a cloud provider — multi-turn answers with
// the conversation's history included.


// MARK: - What a message means

public enum ChatIntent: Equatable, Sendable {
    /// A goal to plan (works fully offline).
    case goal
    /// A question for the assistant (needs an allowed cloud model for a real answer).
    case question
    /// A question Lupy can answer from its own state, offline (what's next, brief…).
    case status
    /// Work on the screen through the visible Lupy cursor (needs computer control).
    case control
    /// Pause / resume everything; stop what is executing.
    case pause
    case resume
    case stop
    /// Decide the plan Lupy just proposed (only routed while a plan awaits review).
    case approvePlan(note: String)
    case rejectPlan(note: String)
}

public enum ChatIntentRouter {

    /// Routes one message. `hasProposedPlan` matters: while a plan waits for review,
    /// short confirmations ("approve it", "looks good") decide that plan instead of
    /// being read as new goals.
    public static func route(_ raw: String, hasProposedPlan: Bool) -> ChatIntent {
        let text = TextUtil.trimmed(raw)
        guard !text.isEmpty else { return .goal }
        let lower = text.lowercased()
        let words = lower.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let wordCount = words.count

        // 1. Plan decisions — only while a plan is actually on the table.
        if hasProposedPlan {
            if let note = matchApprove(lower) { return .approvePlan(note: note) }
            if let note = matchReject(lower, wordCount: wordCount) { return .rejectPlan(note: note) }
        }

        // 2. Standalone commands (short messages only — "stop for now and write a summary
        //    of the pricing page" is a goal, not a stop command).
        if wordCount <= 4 {
            if isCommand(words, verbs: ["pause", "hold"], subjects: ["lupy", "everything", "work", "tasks", "it", ""]) { return .pause }
            if isCommand(words, verbs: ["resume", "unpause", "continue"], subjects: ["lupy", "everything", "work", "tasks", "it", ""]) { return .resume }
            if isCommand(words, verbs: ["stop", "halt", "cancel"], subjects: ["lupy", "it", "that", "everything", "control", "the", "plan", "task", "work", "run", ""]) { return .stop }
        }

        // 3. Status questions Lupy answers from its own state — never sent to a model.
        if isStatusQuestion(lower) { return .status }

        // 4. Screen work: an action verb aimed at an app / the screen / the browser.
        if isControlCommand(lower) { return .control }

        // 5. Questions (wh-words, "?"…). Everything else is a goal.
        return isQuestion(lower, wordCount: wordCount) ? .question : .goal
    }

    // MARK: Plan decisions

    private static func matchApprove(_ lower: String) -> (String)? {
        // Longest patterns first, so "approve it" is not read as "approve" + note "it".
        let patterns = ["approve it", "green light", "sounds good", "looks good", "looks fine", "that works",
                        "approved", "approve", "go ahead", "ship it", "okay", "yes", "ok", "do it"]
            .sorted { $0.count > $1.count }
        for p in patterns where lower == p || lower.hasPrefix(p + " ") {
            let note = TextUtil.trimmed(String(lower.dropFirst(p.count)))
            return note.isEmpty ? "" : note
        }
        return nil
    }

    private static func matchReject(_ lower: String, wordCount: Int) -> (String)? {
        // A bare "no" only decides the plan when it is genuinely bare.
        if lower == "no" || lower == "nope" { return "" }
        let patterns = ["reject", "don't", "dont", "not right", "change ", "redo", "wrong"]
        if wordCount <= 8 {
            for p in patterns where lower.hasPrefix(p) {
                return TextUtil.trimmed(p) == lower ? "" : lower
            }
        }
        return nil
    }

    // MARK: Commands

    private static func isCommand(_ words: [String], verbs: [String], subjects: [String]) -> Bool {
        guard let first = words.first, verbs.contains(first) else { return false }
        let rest = words.dropFirst()
        if rest.isEmpty { return true }
        guard rest.count <= 3 else { return false }
        return rest.allSatisfy { subjects.contains($0) || $0 == "please" }
    }

    // MARK: Status questions (local, offline, honest)

    private static let statusPatterns = [
        "what's next", "whats next", "what is next", "what now", "what should i do", "what do i do",
        "status", "status update", "how are things", "how's it going", "hows it going",
        "brief", "my brief", "daily brief", "today's brief", "todays brief",
        "what's on my plate", "whats on my plate", "on my plate", "what's happening", "whats happening",
        "what's up", "whats up", "what do i have", "what have i got", "my day", "today",
        "what needs me", "anything for me", "what's waiting", "whats waiting", "waiting on me",
        "what's left", "whats left", "what's open", "whats open", "my tasks", "my priorities",
        "anything urgent", "what's urgent", "whats urgent", "summarize my day", "summarise my day",
        "catch me up", "recap",
    ]

    private static func isStatusQuestion(_ lower: String) -> Bool {
        let trimmed = TextUtil.trimmed(lower)
        if statusPatterns.contains(trimmed) { return true }
        // "… today?" / "what's next?" with punctuation still counts.
        var scalars = Substring(trimmed).unicodeScalars
        while let l = scalars.last, l == "?" || l == "!" || l == "." { scalars.removeLast() }
        return statusPatterns.contains(String(scalars))
    }

    // MARK: Control commands

    private static let controlVerbs = ["open ", "click ", "type ", "press ", "scroll ", "close ",
                                       "switch to ", "navigate ", "go to ", "deliver ", "select ", "tap "]
    private static let controlTargets = ["safari", "chrome", "browser", "screen", "window", "tab",
                                         "website", "web page", "webpage", "url", "http", "https",
                                         "message box", "chatgpt", "arena", "muse", "mail app",
                                         "notes app", "textfield", "text field", "button", "link",
                                         "page", "the app", "my mac"]

    private static func isControlCommand(_ lower: String) -> Bool {
        let padded = " " + lower + " "
        let hasVerb = controlVerbs.contains { padded.contains($0) }
        guard hasVerb else { return false }
        return controlTargets.contains { padded.contains($0) }
    }

    // MARK: Questions

    private static let questionStarters = ["what", "why", "how", "who", "when", "where", "which",
                                           "whose", "whom", "is ", "are ", "am ", "do ", "does ",
                                           "did ", "can ", "could ", "would ", "should ", "will ",
                                           "shall ", "may ", "might ", "what's", "whats",
                                           "how's", "hows", "who's", "whos"]
    private static let questionPhrases = ["tell me", "explain ", "describe ", "summarize ", "summarise "]

    private static func isQuestion(_ lower: String, wordCount: Int) -> Bool {
        if lower.hasSuffix("?") { return true }
        if questionPhrases.contains(where: { lower.hasPrefix($0) }) { return true }
        // The first word carries the intent: "what …", "can you …"; a single imperative
        // word ("write", "renew") never does.
        guard let first = lower.split(separator: " ", maxSplits: 1).first else { return false }
        return questionStarters.contains(String(first) + " ") || questionStarters.contains(String(first))
    }
}

// MARK: - Engine: answering in the conversation

extension LupyEngine {

    /// An honest, offline answer about Lupy's own state — used for status questions and as the
    /// local fallback when no cloud model is allowed. Never claims work that is not real.
    public func conversationStatusAnswer() -> String {
        let a = attention()
        var lines: [String] = []
        if a.paused { lines.append("Lupy is paused — say “resume” to continue.") }
        if !a.items.isEmpty {
            lines.append("\(a.items.count) thing\(a.items.count == 1 ? "" : "s") need you:")
            for item in a.items.prefix(3) { lines.append("• " + item.title) }
        } else if !a.paused {
            lines.append("Nothing needs you right now.")
        }
        if a.waitingOnOthers > 0 { lines.append("\(a.waitingOnOthers) task\(a.waitingOnOthers == 1 ? "" : "s") delegated — Lupy follows up until verified.") }
        if a.unverifiedCount > 0 { lines.append("\(a.unverifiedCount) awaiting verification (a claim is never enough).") }
        let next = a.nextUp.compactMap { state.tasks[$0]?.title }.prefix(3)
        if !next.isEmpty {
            lines.append("Next up:")
            for t in next { lines.append("• " + t) }
        }
        return lines.isEmpty ? "All clear." : lines.joined(separator: "\n")
    }

    /// One turn of a real conversation: the recent history is included as chat messages so
    /// follow-ups and corrections work. Goes through the same routing, budget, policy gate,
    /// manifest and usage ledger as every other model call.
    public func prepareConversationTurn(question: String, history: [LLMMessage], projectID: LupyID?) throws -> PreparedCall {
        let system = Prompts.identity + """

        You are replying in Lupy's conversation surface (a compact island or the Lupy window). \
        Keep answers short — a few sentences, plain language. The founder may correct you, add \
        context or change their mind; treat every message as part of the same conversation. \
        Never claim you did anything on the Mac: when work is needed, describe the plan you will \
        propose for the founder to approve, or say what you cannot do.
        """
        return try prepareCall(kind: .ask(question: TextUtil.truncate(question, 2000), projectID: projectID),
                               purpose: .conversation, system: system, projectID: projectID,
                               sections: [("Question", TextUtil.truncate(question, 2000))], untrusted: [],
                               query: question, maxOutput: 700, jsonMode: false, taskID: nil,
                               // Follow-ups work, but a long afternoon of chat must not grow
                               // into an unbounded prompt: the last 12 turns carry the thread.
                               extraMessages: Array(history.suffix(12)))
    }
}
