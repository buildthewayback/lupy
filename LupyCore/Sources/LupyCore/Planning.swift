// LupyCore — turning goals into validated plans (model-produced or offline heuristic),
// dependency graphs and deadline parsing.

public struct PlanDraft: Equatable, Sendable {
    public var summary: String
    public var tasks: [LupyTask]
    public var risks: [String]
    public var questions: [String]
    public var warnings: [String]
}

public enum PlanError: Error, Equatable, CustomStringConvertible, Sendable {
    case notJSON, noTasks, invalid(String)
    public var description: String {
        switch self {
        case .notJSON: return "The model did not return valid JSON."
        case .noTasks: return "The plan contains no tasks."
        case .invalid(let m): return "The plan is invalid: \(m)"
        }
    }
}

public enum PlanBuilder {
    public static let maxTasks = 25

    /// Extracts the first JSON object from model text (models sometimes wrap JSON in prose or fences).
    public static func extractJSON(_ text: String) -> JSONValue? {
        if let v = try? JSONParser.parse(text), v.objectValue != nil { return v }
        let chars = Array(text.utf8)
        guard let start = chars.firstIndex(of: UInt8(ascii: "{")) else { return nil }
        var depth = 0, inString = false, escaped = false
        var i = start
        while i < chars.count {
            let c = chars[i]
            if inString {
                if escaped { escaped = false } else if c == UInt8(ascii: "\\") { escaped = true } else if c == UInt8(ascii: "\"") { inString = false }
            } else if c == UInt8(ascii: "\"") { inString = true }
            else if c == UInt8(ascii: "{") { depth += 1 }
            else if c == UInt8(ascii: "}") {
                depth -= 1
                if depth == 0 { return try? JSONParser.parse(bytes: Array(chars[start...i])) }
            }
            i += 1
        }
        return nil
    }

    /// Validates a model plan: {"summary","tasks":[{"key","title","details","kind","dependsOn":[keys],"acceptance":[...],
    /// "urgency","consequence","value","income","strategic","effortHours","confidence","risk","deadline","owner"}],"risks","questions"}
    public static func fromModelJSON(_ json: JSONValue, projectID: LupyID, goalID: LupyID, now: Timestamp, ids: IDGenerator, source: Principal) throws -> PlanDraft {
        guard let rawTasks = json["tasks"]?.arrayValue else { throw PlanError.invalid("missing \"tasks\" array") }
        var warnings: [String] = []
        if rawTasks.isEmpty { throw PlanError.noTasks }
        var list = rawTasks
        if list.count > maxTasks {
            warnings.append("The model proposed \(list.count) tasks; only the first \(maxTasks) were kept.")
            list = Array(list.prefix(maxTasks))
        }
        var tasks: [LupyTask] = []
        var keyToID: [String: LupyID] = [:]
        var rawDeps: [LupyID: [String]] = [:]
        for (idx, raw) in list.enumerated() {
            let title = TextUtil.trimmed(raw["title"]?.stringValue ?? "")
            guard !title.isEmpty else { warnings.append("Dropped task #\(idx + 1): it had no title."); continue }
            var key = raw["key"]?.stringValue ?? "t\(idx + 1)"
            if keyToID[key] != nil { warnings.append("Duplicate task key “\(key)” renamed."); key += "_\(idx + 1)" }
            let id = ids.next("tsk")
            keyToID[key] = id
            var t = LupyTask(id: id, projectID: projectID, title: TextUtil.truncate(title, 200),
                             details: TextUtil.truncate(raw["details"]?.stringValue ?? "", 4000),
                             kind: TaskKind(rawValue: raw["kind"]?.stringValue ?? "") ?? HeuristicPlanner.guessKind(title),
                             createdAt: now, source: source)
            t.goalID = goalID
            t.planKey = key
            t.owner = parseOwner(raw["owner"]?.stringValue)
            var p = PriorityInputs()
            p.urgency = raw["urgency"]?.intValue ?? p.urgency
            p.consequence = raw["consequence"]?.intValue ?? p.consequence
            p.value = raw["value"]?.intValue ?? p.value
            p.income = raw["income"]?.intValue ?? p.income
            p.strategic = raw["strategic"]?.intValue ?? p.strategic
            p.effortHours = raw["effortHours"]?.doubleValue ?? p.effortHours
            p.confidence = raw["confidence"]?.doubleValue ?? p.confidence
            p.risk = raw["risk"]?.intValue ?? p.risk
            p.clamp()
            t.priority = p
            if let d = raw["deadline"]?.stringValue, !d.isEmpty {
                if let ts = Timestamp(iso8601: d) ?? DeadlineParser.parse(d, now: now, utcOffsetMinutes: 0) { t.deadline = ts }
                else { warnings.append("Could not read deadline “\(d)” for “\(t.title)”.") }
            }
            let acc = (raw["acceptance"]?.arrayValue ?? []).compactMap(\.stringValue).map(TextUtil.trimmed).filter { !$0.isEmpty }
            t.acceptance = acc.prefix(6).map { AcceptanceCriterion(id: ids.next("crt"), text: TextUtil.truncate($0, 300), requirement: requirement(for: $0, kind: t.kind)) }
            if t.acceptance.isEmpty {
                t.acceptance = [AcceptanceCriterion(id: ids.next("crt"), text: "You confirm the result is what you wanted", requirement: .founderConfirmation)]
                warnings.append("“\(t.title)” had no acceptance criteria; Lupy will ask you to confirm the result.")
            }
            rawDeps[id] = (raw["dependsOn"]?.arrayValue ?? []).compactMap(\.stringValue)
            tasks.append(t)
        }
        if tasks.isEmpty { throw PlanError.noTasks }
        for i in tasks.indices {
            var deps: [LupyID] = []
            for k in rawDeps[tasks[i].id] ?? [] {
                if let d = keyToID[k], d != tasks[i].id { deps.append(d) }
                else { warnings.append("“\(tasks[i].title)” depended on unknown step “\(k)”; dependency ignored.") }
            }
            tasks[i].dependsOn = deps
        }
        let cycles = DependencyGraph.cycleMembers(tasks)
        if !cycles.isEmpty {
            // Break cycles by dropping dependencies among cycle members (keeps the plan usable, reports it).
            for i in tasks.indices where cycles.contains(tasks[i].id) {
                tasks[i].dependsOn.removeAll { cycles.contains($0) }
            }
            warnings.append("The plan had circular dependencies between \(cycles.count) steps; those links were removed.")
        }
        let risks = (json["risks"]?.arrayValue ?? []).compactMap(\.stringValue).prefix(10).map { TextUtil.truncate($0, 300) }
        let questions = (json["questions"]?.arrayValue ?? []).compactMap(\.stringValue).prefix(10).map { TextUtil.truncate($0, 300) }
        let summary = TextUtil.truncate(json["summary"]?.stringValue ?? "Plan with \(tasks.count) steps", 600)
        return PlanDraft(summary: summary, tasks: tasks, risks: Array(risks), questions: Array(questions), warnings: warnings)
    }

    static func parseOwner(_ s: String?) -> TaskOwner {
        switch (s ?? "").lowercased() {
        case "lupy", "assistant", "ai": return .lupy
        case "founder", "me", "user", "you": return .founder
        default: return .founder
        }
    }

    /// Chooses what counts as evidence for a criterion from its wording and the task kind.
    public static func requirement(for text: String, kind: TaskKind) -> EvidenceRequirement {
        let w = Set(TextUtil.words(text))
        if !w.isDisjoint(with: ["pr", "pull", "merged", "commit", "branch", "ci", "tests", "build", "repository", "repo"]) {
            return .independent([.pullRequest, .commit, .ciResult, .testResult])
        }
        if !w.isDisjoint(with: ["file", "folder", "saved", "exported", "document", "pdf"]) {
            return .independent([.fileObservation, .artifact])
        }
        if !w.isDisjoint(with: ["published", "posted", "live", "listed", "uploaded", "deployed"]) {
            return .independent([.apiResponse, .artifact, .observation])
        }
        if kind == .coding { return .independent([.pullRequest, .commit, .ciResult, .testResult]) }
        return .founderConfirmation
    }
}

// MARK: - Offline heuristic planner (works with no model configured)

public enum HeuristicPlanner {
    static let kindKeywords: [(TaskKind, [String])] = [
        (.coding, ["code", "bug", "fix", "deploy", "repo", "github", "branch", "merge", "api", "build", "app", "feature", "test", "ci"]),
        (.research, ["research", "investigate", "compare", "find", "explore", "study", "analyse", "analyze", "look"]),
        (.writing, ["write", "draft", "outline", "article", "post", "copy", "script", "blog", "story", "lore", "bible"]),
        (.design, ["design", "art", "illustration", "logo", "sketch", "render", "mockup", "concept", "displate", "poster"]),
        (.communication, ["email", "message", "reply", "call", "contact", "send", "dm", "follow", "meeting"]),
        (.publishing, ["publish", "upload", "post", "list", "release", "announce"]),
        (.purchase, ["buy", "order", "purchase", "subscribe", "pay"]),
        (.finance, ["invoice", "tax", "bill", "budget", "payment", "income", "client", "quote", "price"]),
        (.learning, ["learn", "course", "tutorial", "practice", "read", "watch"]),
        (.admin, ["renew", "register", "file", "form", "admin", "account", "passport", "visa", "bank"]),
    ]

    public static func guessKind(_ text: String) -> TaskKind {
        let w = Set(TextUtil.words(text))
        var best: (TaskKind, Int) = (.general, 0)
        for (kind, keys) in kindKeywords {
            let hits = keys.filter { w.contains($0) }.count
            if hits > best.1 { best = (kind, hits) }
        }
        return best.0
    }

    /// Splits a goal into ordered steps: bullets/lines, "then"/";" separators, or a single task.
    public static func steps(_ goal: String) -> [String] {
        var parts: [String] = []
        let lines = goal.split(whereSeparator: { $0.isNewline }).map { TextUtil.trimmed(String($0)) }.filter { !$0.isEmpty }
        let source = lines.count > 1 ? lines : [TextUtil.trimmed(goal)]
        for line in source {
            var l = line
            while let f = l.first, f == "-" || f == "*" || f == "•" || f.isNumber || f == "." || f == ")" { l.removeFirst(); l = TextUtil.trimmed(l) }
            let pieces = splitOn(l, separators: [" then ", "; ", " and then ", ", then "])
            parts += pieces.map(TextUtil.trimmed).filter { $0.count >= 3 }
        }
        return Array(parts.prefix(PlanBuilder.maxTasks))
    }

    static func splitOn(_ s: String, separators: [String]) -> [String] {
        var out = [s]
        for sep in separators {
            out = out.flatMap { piece -> [String] in
                var res: [String] = []
                var rest = piece[...]
                while let r = rest.lowercased().firstRange(of: sep) {
                    // map range from lowercased copy back by offset (same length for ASCII separators)
                    let offset = rest.lowercased().distance(from: rest.lowercased().startIndex, to: r.lowerBound)
                    let lo = rest.index(rest.startIndex, offsetBy: offset)
                    let hi = rest.index(lo, offsetBy: sep.count)
                    res.append(String(rest[rest.startIndex..<lo]))
                    rest = rest[hi...]
                }
                res.append(String(rest))
                return res
            }
        }
        return out
    }

    public static func plan(goal: String, projectID: LupyID, goalID: LupyID, now: Timestamp, utcOffsetMinutes: Int, ids: IDGenerator) -> PlanDraft {
        let stepTexts = steps(goal)
        let goalDeadline = DeadlineParser.find(in: goal, now: now, utcOffsetMinutes: utcOffsetMinutes)
        var tasks: [LupyTask] = []
        var warnings: [String] = []
        let lowerGoal = goal.lowercased()
        let incomeSignal = ["client", "invoice", "income", "paid", "payment", "revenue", "sale", "commission", "gig"].contains { lowerGoal.contains($0) }
        for (i, text) in stepTexts.enumerated() {
            let kind = guessKind(text)
            var t = LupyTask(id: ids.next("tsk"), projectID: projectID, title: TextUtil.truncate(capitalizeFirst(text), 200),
                             kind: kind, createdAt: now, source: .lupy)
            t.goalID = goalID
            t.planKey = "s\(i + 1)"
            t.deadline = DeadlineParser.find(in: text, now: now, utcOffsetMinutes: utcOffsetMinutes) ?? goalDeadline
            var p = PriorityInputs()
            if incomeSignal { p.income = 4; p.consequence = 3 }
            if t.deadline != nil { p.urgency = 3 }
            if ["urgent", "asap", "today", "now", "immediately"].contains(where: { text.lowercased().contains($0) }) { p.urgency = 5 }
            t.priority = p
            if i > 0 { t.dependsOn = [tasks[i - 1].id] }
            t.acceptance = [AcceptanceCriterion(id: ids.next("crt"), text: defaultCriterion(kind: kind, title: t.title),
                                                requirement: PlanBuilder.requirement(for: t.title, kind: kind))]
            if [.communication, .publishing, .purchase].contains(kind) {
                t.statusNote = "Sending, publishing or paying will need your approval."
            }
            tasks.append(t)
        }
        if tasks.isEmpty {
            let t = LupyTask(id: ids.next("tsk"), projectID: projectID, title: "Clarify the goal", details: goal, createdAt: now, source: .lupy)
            tasks = [t]
            warnings.append("The goal was too short to split into steps.")
        }
        if stepTexts.count > 1 { warnings.append("Offline plan (no model): steps follow the order you wrote them. Review dependencies.") }
        else { warnings.append("Offline plan (no model): one step. Add a cloud model for richer plans, or edit steps yourself.") }
        return PlanDraft(summary: "Plan for: \(TextUtil.truncate(goal, 120))", tasks: tasks, risks: [], questions: [], warnings: warnings)
    }

    static func defaultCriterion(kind: TaskKind, title: String) -> String {
        switch kind {
        case .coding: return "Change is on GitHub with passing checks"
        case .writing: return "Draft is complete and you approve it"
        case .design: return "Artwork is finished and you approve it"
        case .communication: return "Message is sent and you confirm it went out"
        case .publishing: return "Content is published and visible"
        case .research: return "Findings are written down with sources and you approve them"
        default: return "You confirm “\(TextUtil.truncate(title, 60))” is done"
        }
    }

    static func capitalizeFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return String(f).uppercased() + s.dropFirst()
    }
}

// MARK: - Deadlines in plain language

public enum DeadlineParser {
    static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
    static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    /// Understands: today, tonight, tomorrow, by <weekday>, next week, end of month, in N days/hours/weeks,
    /// YYYY-MM-DD, "20 Oct", "Oct 20". Returns the end of that local day (23:59) unless hours were given.
    public static func parse(_ phrase: String, now: Timestamp, utcOffsetMinutes: Int) -> Timestamp? {
        find(in: phrase, now: now, utcOffsetMinutes: utcOffsetMinutes)
    }

    public static func find(in text: String, now: Timestamp, utcOffsetMinutes off: Int) -> Timestamp? {
        let w = TextUtil.words(text)
        let dayStart = now.startOfDay(utcOffsetMinutes: off)
        func endOfDay(plusDays d: Int64) -> Timestamp { dayStart.adding(.days(d)).adding(Millis(86_400_000 - 60_000)) }
        // ISO date
        for token in text.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "(" || $0 == ")" }) {
            let s = String(token)
            if s.count == 10, let ts = Timestamp(iso8601: s) {
                return ts.adding(.minutes(Int64(-off))).adding(Millis(86_400_000 - 60_000))
            }
        }
        for (i, word) in w.enumerated() {
            switch word {
            case "today", "tonight", "eod": return endOfDay(plusDays: 0)
            case "tomorrow": return endOfDay(plusDays: 1)
            case "in":
                if i + 2 < w.count, let n = Int(w[i + 1]) ?? wordNumber(w[i + 1]) {
                    let unit = w[i + 2]
                    if unit.hasPrefix("hour") { return now.adding(.hours(Int64(n))) }
                    if unit.hasPrefix("day") { return endOfDay(plusDays: Int64(n)) }
                    if unit.hasPrefix("week") { return endOfDay(plusDays: Int64(7 * n)) }
                    if unit.hasPrefix("month") { return endOfDay(plusDays: Int64(30 * n)) }
                }
            case "next":
                if i + 1 < w.count, w[i + 1] == "week" { return endOfDay(plusDays: 7) }
                if i + 1 < w.count, w[i + 1] == "month" { return endOfDay(plusDays: 30) }
            case "end":
                if i + 2 < w.count, w[i + 1] == "of", w[i + 2] == "month" {
                    let c = Timestamp(millis: now.millis + Int64(off) * 60_000).civil
                    let firstNext = c.month == 12 ? Timestamp(year: c.year + 1, month: 1, day: 1) : Timestamp(year: c.year, month: c.month + 1, day: 1)
                    return firstNext.adding(.minutes(Int64(-off))).adding(.minutes(-1))
                }
                if i + 2 < w.count, w[i + 1] == "of", w[i + 2] == "week" {
                    let wd = Timestamp(millis: now.millis + Int64(off) * 60_000).civil.weekday
                    return endOfDay(plusDays: Int64((7 - wd) % 7))
                }
            default:
                if let wdIndex = weekdays.firstIndex(of: word) {
                    let today = Timestamp(millis: now.millis + Int64(off) * 60_000).civil.weekday
                    var delta = (wdIndex - today + 7) % 7
                    if delta == 0 { delta = 7 }
                    return endOfDay(plusDays: Int64(delta))
                }
                if let m = monthIndex(word) {
                    if i + 1 < w.count, let d = Int(w[i + 1]), (1...31).contains(d) { return dateFor(month: m, day: d, now: now, off: off) }
                    if i > 0, let d = Int(w[i - 1]), (1...31).contains(d) { return dateFor(month: m, day: d, now: now, off: off) }
                }
            }
        }
        return nil
    }

    static func monthIndex(_ word: String) -> Int? {
        guard word.count >= 3 else { return nil }
        let p = String(word.prefix(3))
        guard let i = months.firstIndex(of: p) else { return nil }
        let full = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"][i]
        return (word == p || full.hasPrefix(word) || word == "sept") ? i + 1 : nil
    }

    static func dateFor(month: Int, day: Int, now: Timestamp, off: Int) -> Timestamp {
        let c = Timestamp(millis: now.millis + Int64(off) * 60_000).civil
        var year = c.year
        if month < c.month || (month == c.month && day < c.day) { year += 1 }
        return Timestamp(year: year, month: month, day: day).adding(.minutes(Int64(-off))).adding(Millis(86_400_000 - 60_000))
    }

    static func wordNumber(_ w: String) -> Int? {
        ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "ten": 10, "a": 1, "an": 1][w]
    }
}

// MARK: - Dependency graph

public enum DependencyGraph {
    public static let satisfiedStatuses: Set<TaskStatus> = [.verified, .accepted, .completed]

    /// IDs of tasks that participate in a dependency cycle.
    public static func cycleMembers(_ tasks: [LupyTask]) -> Set<LupyID> {
        let ids = Set(tasks.map(\.id))
        var indegree: [LupyID: Int] = [:]
        var dependents: [LupyID: [LupyID]] = [:]
        for t in tasks {
            indegree[t.id, default: 0] += 0
            for d in t.dependsOn where ids.contains(d) {
                indegree[t.id, default: 0] += 1
                dependents[d, default: []].append(t.id)
            }
        }
        var queue = indegree.filter { $0.value == 0 }.map(\.key)
        var visited = Set<LupyID>()
        while let n = queue.popLast() {
            visited.insert(n)
            for m in dependents[n] ?? [] {
                indegree[m]! -= 1
                if indegree[m] == 0 { queue.append(m) }
            }
        }
        return ids.subtracting(visited)
    }

    public static func topologicalOrder(_ tasks: [LupyTask]) -> [LupyTask] {
        let byID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var result: [LupyTask] = []
        var visited = Set<LupyID>()
        func visit(_ t: LupyTask, _ stack: Set<LupyID>) {
            if visited.contains(t.id) || stack.contains(t.id) { return }
            for d in t.dependsOn { if let dt = byID[d] { visit(dt, stack.union([t.id])) } }
            visited.insert(t.id)
            result.append(t)
        }
        for t in tasks.sorted(by: { $0.createdAt < $1.createdAt || ($0.createdAt == $1.createdAt && $0.id < $1.id) }) { visit(t, []) }
        return result
    }

    public enum Readiness: Equatable, Sendable { case ready, waiting([LupyID]), blockedByCancelled([LupyID]) }

    public static func readiness(of task: LupyTask, in tasks: [LupyID: LupyTask]) -> Readiness {
        var waiting: [LupyID] = []
        var cancelled: [LupyID] = []
        for d in task.dependsOn {
            guard let dt = tasks[d] else { continue }
            if dt.status == .cancelled { cancelled.append(d) }
            else if !satisfiedStatuses.contains(dt.status) { waiting.append(d) }
        }
        if !cancelled.isEmpty { return .blockedByCancelled(cancelled) }
        return waiting.isEmpty ? .ready : .waiting(waiting)
    }

    /// How many open tasks (transitively) depend on this one.
    public static func unblockCount(_ id: LupyID, in tasks: [LupyID: LupyTask]) -> Int {
        var dependents: [LupyID: [LupyID]] = [:]
        for t in tasks.values where !t.status.isTerminal { for d in t.dependsOn { dependents[d, default: []].append(t.id) } }
        var seen = Set<LupyID>()
        var stack = dependents[id] ?? []
        while let n = stack.popLast() {
            if seen.insert(n).inserted { stack += dependents[n] ?? [] }
        }
        return seen.count
    }
}
