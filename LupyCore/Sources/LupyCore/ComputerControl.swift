// Computer control — the portable rules behind Lupy's visible AI cursor.
//
// The Mac app reads other apps through macOS Accessibility (UISnapshot) and performs the steps;
// everything that decides *what* may happen lives here, so it is tested without a Mac:
//  - ControlStep: the small vocabulary of actions Lupy can take in an app;
//  - ElementMatcher: finds the element a step refers to, or reports it unavailable (never guesses);
//  - ControlSafety: maps each step to an ActionKind for the policy gate. Consequential clicks
//    (send, publish, delete, pay, grant access…) need the founder; Lupy never types passwords or
//    codes and stops at CAPTCHA / two-factor screens (it never bypasses them);
//  - ControlRun: the session state machine — stopping cancels everything still queued; a failed
//    step stops the run; states are only ever set from real outcomes reported by the executor;
//  - ControlAgent: the prompt for a cloud model choosing the next step from a snapshot (screen
//    text fenced as untrusted data) and strict parsing of its reply;
//  - DeliveryPlan: the deterministic routine that types a handoff brief into an agent's chat.

// MARK: - What Lupy sees (built by the app from Accessibility)

public struct UIRect: Codable, Equatable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) { self.x = x; self.y = y; self.width = width; self.height = height }
    public var isEmpty: Bool { width < 1 || height < 1 }
    public var centerX: Double { x + width / 2 }
    public var centerY: Double { y + height / 2 }
    public var area: Double { max(0, width) * max(0, height) }
}

/// One element of an app's Accessibility tree. Frames are in global screen points, origin top-left.
public struct UIElementInfo: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var role: String
    public var subrole: String
    public var title: String
    public var label: String
    public var value: String
    public var placeholder: String
    public var identifier: String
    public var frame: UIRect
    public var enabled: Bool
    public var focused: Bool
    public var editable: Bool
    public var actions: [String]

    public init(id: Int, role: String, subrole: String = "", title: String = "", label: String = "", value: String = "",
                placeholder: String = "", identifier: String = "", frame: UIRect, enabled: Bool = true, focused: Bool = false,
                editable: Bool = false, actions: [String] = []) {
        self.id = id; self.role = role; self.subrole = subrole; self.title = title; self.label = label; self.value = value
        self.placeholder = placeholder; self.identifier = identifier; self.frame = frame; self.enabled = enabled
        self.focused = focused; self.editable = editable; self.actions = actions
    }

    static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
    static let pressRoles: Set<String> = ["AXButton", "AXLink", "AXMenuItem", "AXMenuBarItem", "AXCheckBox", "AXRadioButton",
                                          "AXPopUpButton", "AXMenuButton", "AXDisclosureTriangle", "AXTab"]

    public var isSecure: Bool { role == "AXSecureTextField" || subrole == "AXSecureTextField" }
    public var isTextInput: Bool { Self.textRoles.contains(role) || editable || isSecure }
    public var isPressable: Bool { actions.contains("AXPress") || Self.pressRoles.contains(role) }
    public var isInteractive: Bool { isTextInput || isPressable }

    /// What a person would call it ("Send", "Message", …).
    public var displayName: String {
        for s in [title, label, placeholder, identifier] where !TextUtil.trimmed(s).isEmpty { return TextUtil.truncate(TextUtil.trimmed(s), 60) }
        if isPressable, !TextUtil.trimmed(value).isEmpty { return TextUtil.truncate(TextUtil.trimmed(value), 60) }
        return Self.friendlyRole(role)
    }

    public static func friendlyRole(_ role: String) -> String {
        switch role {
        case "AXButton": return "button"
        case "AXLink": return "link"
        case "AXTextField", "AXSearchField", "AXComboBox": return "text field"
        case "AXTextArea": return "text area"
        case "AXMenuItem", "AXMenuBarItem": return "menu item"
        case "AXCheckBox": return "checkbox"
        default: return role.hasPrefix("AX") ? String(role.dropFirst(2)).lowercased() : role
        }
    }
}

public struct UISnapshot: Codable, Equatable, Sendable {
    public var appName: String
    public var bundleID: String
    public var windowTitle: String
    public var elements: [UIElementInfo]
    public var truncated: Bool
    public init(appName: String, bundleID: String, windowTitle: String, elements: [UIElementInfo], truncated: Bool = false) {
        self.appName = appName; self.bundleID = bundleID; self.windowTitle = windowTitle; self.elements = elements; self.truncated = truncated
    }
    public func element(_ id: Int) -> UIElementInfo? { elements.first { $0.id == id } }
    /// All visible text, lowercased (used to recognise security checks).
    public var visibleTextLowercased: String {
        ([windowTitle] + elements.flatMap { [$0.title, $0.label, $0.value, $0.placeholder] }).joined(separator: " ").lowercased()
    }
}

// MARK: - What Lupy can do

public enum ElementRole: String, Codable, Sendable { case any, button, textInput, link, menuItem }

/// How a step names its target: alternatives of visible text, plus a role.
public struct ElementQuery: Equatable, Sendable {
    public var texts: [String]
    public var role: ElementRole
    public var exact: Bool
    public init(_ texts: [String], role: ElementRole = .any, exact: Bool = false) { self.texts = texts; self.role = role; self.exact = exact }
    public var describe: String {
        let t = texts.first.map { "“\($0)”" } ?? (role == .textInput ? "the text field" : "an element")
        return t
    }
}

public enum ControlKey: String, Equatable, Sendable { case returnKey = "return", tab, escape }

public enum ControlStep: Equatable, Sendable {
    case openApp(bundleID: String, name: String)
    case openURL(String)
    case waitFor(ElementQuery, seconds: Int)
    case press(ElementQuery)
    case pressElement(Int)
    case setText(ElementQuery, text: String)
    case setTextElement(Int, text: String)
    case pressKey(ControlKey)
    case read(ElementQuery)

    /// The line shown next to the Lupy cursor and in the session log.
    public func title(target: UIElementInfo? = nil) -> String {
        let name = target.map { "“\($0.displayName)”" }
        switch self {
        case .openApp(_, let n): return "Open \(n)"
        case .openURL(let u): return "Open \(TextUtil.truncate(u, 60))"
        case .waitFor(let q, _): return "Wait for \(name ?? q.describe)"
        case .press(let q): return "Click \(name ?? q.describe)"
        case .pressElement: return "Click \(name ?? "the element")"
        case .setText(let q, let t): return "Type \(t.count) characters into \(name ?? q.describe)"
        case .setTextElement(_, let t): return "Type \(t.count) characters into \(name ?? "the field")"
        case .pressKey(let k): return "Press \(k == .returnKey ? "Return" : (k == .tab ? "Tab" : "Escape"))"
        case .read(let q): return "Read \(name ?? q.describe)"
        }
    }

    public var needsTarget: Bool {
        switch self {
        case .waitFor, .press, .pressElement, .setText, .setTextElement, .read: return true
        case .openApp, .openURL, .pressKey: return false
        }
    }
}

// MARK: - Finding the target

public enum ElementMatcher {
    public struct Match: Equatable, Sendable {
        public var element: UIElementInfo
        public var score: Int
    }

    public static let threshold = 40

    /// The best element for the query, or nil when nothing matches well enough (the step then fails
    /// honestly as "target unavailable" — Lupy never clicks a guess).
    public static func best(_ q: ElementQuery, in elements: [UIElementInfo]) -> Match? {
        var bestMatch: Match?
        for e in elements where e.enabled && !e.frame.isEmpty && roleFits(q.role, e) {
            var score = q.texts.isEmpty ? (q.role == .textInput ? 45 : 0) : textScore(q, e)
            guard score > 0 else { continue }
            if q.role != .any { score += 10 }
            if q.role == .textInput, e.focused { score += 8 }
            if q.role == .textInput, q.texts.isEmpty { score += min(20, Int(e.frame.area / 4000)) }   // the main field, not a tiny one
            guard score >= threshold else { continue }
            if let b = bestMatch, b.score >= score { continue }
            bestMatch = Match(element: e, score: score)
        }
        return bestMatch
    }

    static func roleFits(_ role: ElementRole, _ e: UIElementInfo) -> Bool {
        switch role {
        case .any: return e.isInteractive
        case .button: return e.isPressable && e.role != "AXLink"
        case .textInput: return e.isTextInput && !e.isSecure
        case .link: return e.role == "AXLink"
        case .menuItem: return e.role == "AXMenuItem" || e.role == "AXMenuBarItem"
        }
    }

    static func textScore(_ q: ElementQuery, _ e: UIElementInfo) -> Int {
        var best = 0
        let fields = [e.title, e.label, e.placeholder, e.identifier] + (e.isPressable ? [e.value] : [])
        for needleRaw in q.texts {
            let needle = TextUtil.trimmed(needleRaw).lowercased()
            guard !needle.isEmpty else { continue }
            for f in fields {
                let hay = TextUtil.trimmed(f).lowercased()
                guard !hay.isEmpty else { continue }
                var s = 0
                if hay == needle { s = 100 }
                else if q.exact { s = 0 }
                else if hay.hasPrefix(needle) { s = 72 }
                else if TextUtil.words(hay).contains(needle) { s = 60 }
                else if needle.count >= 3 && hay.contains(needle) { s = 45 }
                best = max(best, s)
            }
        }
        return best
    }
}

// MARK: - Safety: what each step means for the policy gate

public struct ControlClassification: Equatable, Sendable {
    public var kind: ActionKind
    public var consequential: Bool
    public var reason: String
}

public enum ControlSafety {
    static let deleteWords = ["delete", "remove", "erase", "trash", "discard", "empty", "uninstall", "wipe", "destroy", "unsubscribe", "clear all"]
    static let payWords = ["buy", "pay", "purchase", "checkout", "check out", "place order", "order now", "subscribe", "upgrade", "donate",
                           "transfer", "send money", "confirm payment", "add to cart"]
    static let publishWords = ["publish", "post", "tweet", "share", "go live", "broadcast", "make public", "upload"]
    static let sendWords = ["send", "submit", "reply", "forward", "message", "email", "comment", "request", "invite"]
    static let accessWords = ["allow", "grant", "authorize", "authorise", "give access", "add member", "permissions", "share with"]
    static let securityWords = ["password", "passcode", "two-factor", "2fa", "two-step", "security key", "recovery", "sign out of all", "authenticator"]
    static let confirmWords = ["sign in", "log in", "login", "continue with", "confirm", "accept", "agree", "approve", "install", "run", "execute",
                               "merge", "deploy", "close account", "yes", "ok"]
    static let challengeWords = ["captcha", "recaptcha", "hcaptcha", "verify you are human", "i'm not a robot", "i am not a robot",
                                 "verification code", "one-time code", "one time code", "enter the code", "two-factor", "2-step verification",
                                 "security check", "authenticator app"]

    /// True when the screen looks like a CAPTCHA or a two-factor / verification-code check.
    public static func looksLikeSecurityChallenge(_ snapshot: UISnapshot) -> Bool {
        let text = snapshot.visibleTextLowercased
        return challengeWords.contains { text.contains($0) }
    }

    static func matches(_ text: String, _ words: [String]) -> String? {
        let t = text.lowercased()
        let tokens = TextUtil.words(t)
        for w in words {
            if w.contains(" ") { if t.contains(w) { return w } }
            else if tokens.contains(w) || t == w { return w }
        }
        return nil
    }

    /// Classifies a step against its resolved target. `snapshot` is the screen it will act on.
    public static func classify(_ step: ControlStep, target: UIElementInfo?, snapshot: UISnapshot?) -> ControlClassification {
        func c(_ k: ActionKind, _ consequential: Bool, _ why: String) -> ControlClassification {
            ControlClassification(kind: k, consequential: consequential, reason: why)
        }
        if case .read = step { return c(.readInformation, false, "Reading only.") }
        if case .waitFor = step { return c(.readInformation, false, "Waiting only.") }
        if let snap = snapshot, looksLikeSecurityChallenge(snap) {
            return c(.bypassSecurityControl, true, "This looks like a security check (CAPTCHA or a verification code). Lupy never gets past those for you — please complete it yourself, then tell Lupy to continue.")
        }
        switch step {
        case .openApp(_, let name):
            return c(.uiNavigate, false, "Opening \(name) changes nothing by itself.")
        case .openURL(let url):
            let lower = url.lowercased()
            if !(lower.hasPrefix("https://") || lower.hasPrefix("file:///")) {
                return c(.bypassSecurityControl, true, "Lupy only opens https:// pages (or a local file).")
            }
            return c(.openURL, false, "Opening a page changes nothing by itself.")
        case .setText, .setTextElement:
            if let t = target {
                let words = [t.title, t.label, t.placeholder, t.identifier].joined(separator: " ")
                if t.isSecure || matches(words, securityWords + ["verification code", "one-time code", "pin"]) != nil {
                    return c(.bypassSecurityControl, true, "Lupy never types passwords, PINs or verification codes — please enter it yourself.")
                }
            }
            return c(.uiInput, false, "Typing into a field sends nothing until something is submitted.")
        case .pressKey(let key):
            if key == .returnKey {
                return c(.computerControl, true, "Return can send or submit what was typed, so Lupy asks first.")
            }
            return c(.uiNavigate, false, "Moving focus changes nothing by itself.")
        case .press, .pressElement:
            let name = target.map { [$0.title, $0.label, $0.value, $0.identifier].joined(separator: " ") } ?? ""
            if let w = matches(name, securityWords) { return c(.changeAccountSecurity, true, "“\(w)” touches account security.") }
            if let w = matches(name, accessWords) { return c(.grantAccess, true, "“\(w)” would grant access to someone or something.") }
            if let w = matches(name, payWords) { return c(.spendMoney, true, "“\(w)” could spend money.") }
            if let w = matches(name, deleteWords) { return c(.deleteData, true, "“\(w)” deletes or removes something.") }
            if let w = matches(name, publishWords) { return c(.publishContent, true, "“\(w)” publishes or shares something.") }
            if let w = matches(name, sendWords) { return c(.sendExternalMessage, true, "“\(w)” sends something to someone.") }
            if let w = matches(name, confirmWords) { return c(.computerControl, true, "“\(w)” confirms or commits something.") }
            if target == nil { return c(.computerControl, true, "The target could not be identified, so Lupy asks first.") }
            return c(.uiNavigate, false, "Clicking “\(target?.displayName ?? "")” only moves around the app.")
        case .read, .waitFor:
            return c(.readInformation, false, "Reading only.")
        }
    }
}

// MARK: - A session

public enum ControlStepState: String, Equatable, Sendable {
    case pending, locating, awaitingApproval, executing, succeeded, failed, skipped, stopped
    public var isFinished: Bool { [.succeeded, .failed, .skipped, .stopped].contains(self) }
    public var label: String {
        switch self {
        case .pending: return "Queued"
        case .locating: return "Finding the target"
        case .awaitingApproval: return "Waiting for your OK"
        case .executing: return "Doing it"
        case .succeeded: return "Done"
        case .failed: return "Failed"
        case .skipped: return "Not attempted"
        case .stopped: return "Stopped"
        }
    }
}

public struct ControlStepRecord: Equatable, Sendable, Identifiable {
    public var id: Int
    public var step: ControlStep
    public var title: String
    public var state: ControlStepState
    public var detail: String
    public var kind: ActionKind?
}

public enum ControlRunState: String, Equatable, Sendable { case running, paused, stopped, finished, failed }

/// One computer-control session: a list of steps and their truthful states. The executor (the app)
/// drives it; only real outcomes change a step to succeeded or failed.
public struct ControlRun: Equatable, Sendable {
    public var id: String
    public var title: String
    public var byFounder: Bool
    public private(set) var steps: [ControlStepRecord]
    public private(set) var state: ControlRunState
    public private(set) var stopReason: String

    public init(id: String, title: String, steps: [ControlStep], byFounder: Bool) {
        self.id = id; self.title = title; self.byFounder = byFounder
        self.steps = steps.enumerated().map { ControlStepRecord(id: $0.offset, step: $0.element, title: $0.element.title(), state: .pending, detail: "", kind: nil) }
        self.state = .running
        self.stopReason = ""
    }

    /// The step to work on next, if the run may continue.
    public var nextIndex: Int? {
        guard state == .running else { return nil }
        return steps.firstIndex { !$0.state.isFinished }
    }

    public var isOver: Bool { [.stopped, .finished, .failed].contains(state) }

    /// Agent runs add steps one at a time.
    public mutating func append(_ step: ControlStep) {
        guard !isOver else { return }
        steps.append(ControlStepRecord(id: steps.count, step: step, title: step.title(), state: .pending, detail: "", kind: nil))
    }

    public mutating func mark(_ i: Int, _ s: ControlStepState, detail: String = "", title: String? = nil, kind: ActionKind? = nil) {
        guard steps.indices.contains(i), !steps[i].state.isFinished else { return }
        // After a stop, nothing new may start; an executing step may still report its real outcome.
        if state == .stopped, ![ControlStepState.succeeded, .failed, .stopped].contains(s) { return }
        steps[i].state = s
        if !detail.isEmpty { steps[i].detail = detail }
        if let title { steps[i].title = title }
        if let kind { steps[i].kind = kind }
        if s == .failed {
            state = .failed
            stopReason = detail
            for j in steps.indices where j > i && !steps[j].state.isFinished {
                steps[j].state = .skipped
                steps[j].detail = "Not attempted: an earlier step failed."
            }
        }
        if state == .running, steps.allSatisfy({ $0.state.isFinished }) { state = .finished }
    }

    /// Stops the run: every queued step is cancelled and will never execute.
    public mutating func stop(reason: String) {
        guard !isOver else { return }
        state = .stopped
        stopReason = reason
        for j in steps.indices where !steps[j].state.isFinished && steps[j].state != .executing {
            steps[j].state = .stopped
            steps[j].detail = "Cancelled: \(reason)"
        }
    }

    public mutating func pause() { if state == .running { state = .paused } }
    public mutating func resume() { if state == .paused { state = .running } }

    /// Agent runs: the model said the goal is reached.
    public mutating func finish() {
        guard !isOver else { return }
        for j in steps.indices where !steps[j].state.isFinished { steps[j].state = .skipped; steps[j].detail = "Not needed." }
        state = .finished
    }

    public var summary: String {
        let done = steps.filter { $0.state == .succeeded }.count
        switch state {
        case .running: return "Working — \(done) of \(steps.count) steps done"
        case .paused: return "Paused — \(done) of \(steps.count) steps done"
        case .finished: return "Finished — \(done) of \(steps.count) steps done"
        case .failed: return "Failed: \(stopReason)"
        case .stopped: return "Stopped: \(stopReason) — \(done) of \(steps.count) steps done"
        }
    }
}

// MARK: - A cloud model choosing the next step

public enum ControlAgent {
    public static let maxSteps = 15
    public static let maxElementsInPrompt = 120

    public static let systemPrompt = """
    You operate apps on the founder's Mac for Lupy, one step at a time, while the founder watches. \
    You see the current app as a numbered list of interactive elements from macOS Accessibility. \
    Reply with ONE JSON object and nothing else, one of:
    {"action":"click","element":<number>,"reason":"…"}
    {"action":"type","element":<number>,"text":"…","reason":"…"}
    {"action":"key","key":"return"|"tab"|"escape","reason":"…"}
    {"action":"open_app","bundle_id":"…","name":"…","reason":"…"}
    {"action":"open_url","url":"https://…","reason":"…"}
    {"action":"done","summary":"…"}
    {"action":"ask","question":"…"}
    Rules: use only element numbers from the list. Never type passwords, PINs or verification codes and never try to get past a \
    CAPTCHA or two-factor check: reply "ask" instead. Sending, publishing, deleting, paying or granting access will be shown to the \
    founder for approval before it happens. Stop with "done" as soon as the goal is reached.
    """ + "\n" + UntrustedContent.systemRule

    /// The screen as the model sees it: interactive elements first, fenced as untrusted data.
    public static func observation(_ snap: UISnapshot) -> String {
        var lines: [String] = ["App: \(snap.appName) — window: \(snap.windowTitle)"]
        let interactive = snap.elements.filter { $0.isInteractive && !$0.frame.isEmpty }
        for e in interactive.prefix(maxElementsInPrompt) {
            var line = "[\(e.id)] \(UIElementInfo.friendlyRole(e.role)) “\(e.displayName)”"
            if e.isTextInput, !e.value.isEmpty, !e.isSecure { line += " value: “\(TextUtil.truncate(e.value, 80))”" }
            if !e.enabled { line += " (disabled)" }
            if e.focused { line += " (focused)" }
            lines.append(line)
        }
        if interactive.count > maxElementsInPrompt || snap.truncated { lines.append("(more elements not shown)") }
        return UntrustedContent.fence(lines.joined(separator: "\n"), source: "screen of \(snap.appName)")
    }

    public enum Reply: Equatable, Sendable {
        case step(ControlStep, reason: String)
        case done(String)
        case askFounder(String)
        case invalid(String)
    }

    /// Strict parsing: unknown actions, missing elements, non-https URLs and oversized text are rejected.
    public static func parse(_ text: String, snapshot: UISnapshot) -> Reply {
        guard let json = PlanBuilder.extractJSON(text), let action = json["action"]?.stringValue?.lowercased() else {
            return .invalid("The model's answer was not the JSON step Lupy asked for.")
        }
        let reason = TextUtil.truncate(json["reason"]?.stringValue ?? "", 200)
        func element() -> Int? {
            guard let n = json["element"]?.intValue, snapshot.element(n) != nil else { return nil }
            return n
        }
        switch action {
        case "click":
            guard let n = element() else { return .invalid("The model chose an element that is not on screen.") }
            return .step(.pressElement(n), reason: reason)
        case "type":
            guard let n = element() else { return .invalid("The model chose an element that is not on screen.") }
            let t = json["text"]?.stringValue ?? ""
            guard !t.isEmpty, t.count <= 4000 else { return .invalid("The text to type was empty or too long.") }
            return .step(.setTextElement(n, text: t), reason: reason)
        case "key":
            guard let k = json["key"]?.stringValue.flatMap({ ControlKey(rawValue: $0.lowercased()) }) else { return .invalid("Unknown key.") }
            return .step(.pressKey(k), reason: reason)
        case "open_app":
            guard let b = json["bundle_id"]?.stringValue, !b.isEmpty else { return .invalid("No app given.") }
            return .step(.openApp(bundleID: b, name: json["name"]?.stringValue ?? b), reason: reason)
        case "open_url":
            guard let u = json["url"]?.stringValue, u.lowercased().hasPrefix("https://") else { return .invalid("Lupy only opens https:// pages.") }
            return .step(.openURL(u), reason: reason)
        case "done":
            return .done(TextUtil.truncate(json["summary"]?.stringValue ?? "Done.", 300))
        case "ask":
            return .askFounder(TextUtil.truncate(json["question"]?.stringValue ?? "The model needs you.", 300))
        default:
            return .invalid("Unknown action “\(action)”.")
        }
    }
}

// MARK: - Delivering a handoff into an agent's chat

public struct DeliveryTarget: Equatable, Sendable {
    /// An app to open (bundle id) or a page (https URL).
    public var bundleID: String?
    public var appName: String
    public var url: String?
    public init(bundleID: String? = nil, appName: String, url: String? = nil) { self.bundleID = bundleID; self.appName = appName; self.url = url }
}

public enum DeliveryPlan {
    /// Words that name a chat's message box and its send button, across common agent UIs.
    public static let messageBox = ["Message", "Ask anything", "Send a message", "Type a message", "Ask", "Prompt", "Chat",
                                    "What can I help with", "Describe", "Write", "Reply"]
    public static let sendButton = ["Send", "Send message", "Send prompt", "Submit", "Run"]

    /// Open the agent, find its message box, type the brief, then click Send. The Send click is
    /// consequential (ControlSafety → sendExternalMessage) and waits for the founder's approval.
    public static func steps(brief: String, to target: DeliveryTarget, send: Bool) -> [ControlStep] {
        var s: [ControlStep] = []
        if let url = target.url { s.append(.openURL(url)) }
        else if let b = target.bundleID { s.append(.openApp(bundleID: b, name: target.appName)) }
        s.append(.waitFor(ElementQuery(messageBox, role: .textInput), seconds: 20))
        s.append(.setText(ElementQuery(messageBox, role: .textInput), text: brief))
        if send { s.append(.press(ElementQuery(sendButton, role: .button))) }
        return s
    }

    /// After sending: the brief's first words should appear on screen (the conversation) and the box
    /// should be empty again. This is UI observation — evidence of delivery, not of the work.
    public static func deliveryObserved(brief: String, after snap: UISnapshot) -> Bool {
        let probe = TextUtil.truncate(TextUtil.trimmed(brief), 40).lowercased()
        let head = probe.hasSuffix("…") ? String(probe.dropLast()) : probe
        guard head.count >= 8 else { return false }
        return snap.elements.contains { e in
            !e.isTextInput && ([e.value, e.title, e.label].contains { $0.lowercased().contains(head) })
        }
    }
}
