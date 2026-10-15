// LupyCore — explainable prioritization.
// Score 0…100 from urgency (incl. deadline), consequence, value, income, strategy, dependencies,
// confidence, effort, risk and API cost, scaled by project weights. Every factor is reported.

public struct PriorityFactor: Equatable, Sendable {
    public var name: String
    public var points: Double
    public var note: String
}

public struct PriorityAssessment: Equatable, Sendable {
    public var taskID: LupyID
    public var score: Double
    public var factors: [PriorityFactor]
    public var headline: String

    public var explanation: String {
        factors.filter { abs($0.points) >= 0.5 }.sorted { abs($0.points) > abs($1.points) }
            .prefix(4).map { "\($0.name) \($0.points >= 0 ? "+" : "")\(TextUtil.fixed($0.points, 0)) (\($0.note))" }
            .joined(separator: ", ")
    }
}

public enum PriorityEngine {
    public static func assess(_ t: LupyTask, state: LupyState, now: Timestamp) -> PriorityAssessment {
        let p = t.priority
        let w = state.projects[t.projectID]?.weights ?? ProjectWeights()
        var f: [PriorityFactor] = []

        // Urgency: manual 0–5 plus deadline proximity.
        var urgency = Double(p.urgency) * 2.4
        var urgencyNote = "urgency \(p.urgency)/5"
        if let d = t.deadline {
            let hours = d.since(now).hours
            let boost: Double
            switch hours {
            case ..<0: boost = 14; urgencyNote = "overdue"
            case ..<24: boost = 11; urgencyNote = "due within 24h"
            case ..<72: boost = 7; urgencyNote = "due within 3 days"
            case ..<168: boost = 4; urgencyNote = "due this week"
            default: boost = 1; urgencyNote = "due \(d.dateOnly)"
            }
            urgency += boost
        }
        f.append(PriorityFactor(name: "Urgency", points: urgency, note: urgencyNote))
        f.append(PriorityFactor(name: "Consequence", points: Double(p.consequence) * 2.2, note: "cost of not doing it \(p.consequence)/5"))
        f.append(PriorityFactor(name: "Value", points: Double(p.value) * 1.4 * w.importance, note: "value \(p.value)/5"))
        if p.income > 0 {
            f.append(PriorityFactor(name: "Income", points: Double(p.income) * 2.6 * w.income, note: "income impact \(p.income)/5"))
        }
        f.append(PriorityFactor(name: "Strategy", points: Double(p.strategic) * 1.2 * w.strategic, note: "strategic \(p.strategic)/5"))
        let unblocks = DependencyGraph.unblockCount(t.id, in: state.tasks)
        if unblocks > 0 {
            f.append(PriorityFactor(name: "Unblocks", points: min(10, Double(unblocks) * 2.5), note: "\(unblocks) task(s) wait on it"))
        }
        f.append(PriorityFactor(name: "Confidence", points: (p.confidence - 0.5) * 6, note: "\(Int(p.confidence * 100))% likely to work"))
        let effortPts: Double = p.effortHours <= 0.5 ? 3 : (p.effortHours <= 2 ? 1.5 : (p.effortHours <= 8 ? 0 : -min(6, (p.effortHours - 8) / 4)))
        f.append(PriorityFactor(name: "Effort", points: effortPts, note: "\(TextUtil.fixed(p.effortHours, 1))h"))
        if p.risk > 0 { f.append(PriorityFactor(name: "Risk", points: -Double(p.risk) * 1.1, note: "risk \(p.risk)/5")) }
        if p.apiCostCents > 0 { f.append(PriorityFactor(name: "API cost", points: -min(5, p.apiCostCents / 20), note: TextUtil.formatCents(p.apiCostCents))) }
        // Waiting long without progress nudges the task up (anti-neglect), capped.
        let idleDays = now.since(t.lastProgressAt ?? t.createdAt).hours / 24
        if idleDays >= 3 && !t.status.isClosedForWork {
            f.append(PriorityFactor(name: "Waiting", points: min(6, idleDays / 2), note: "no progress for \(Int(idleDays)) days"))
        }
        if t.pin != 0 {
            f.append(PriorityFactor(name: "Your pin", points: t.pin > 0 ? 40 : -40, note: t.pin > 0 ? "pinned to top" : "pushed down"))
        }
        let raw = f.reduce(0) { $0 + $1.points }
        let score = max(0, min(100, raw * 1.25))
        let top = f.filter { $0.points > 0 }.max { $0.points < $1.points }
        let headline = top.map { "\($0.name): \($0.note)" } ?? "Low priority"
        return PriorityAssessment(taskID: t.id, score: score, factors: f, headline: headline)
    }

    /// Ranks open tasks: actionable first by score; ties broken by deadline then age.
    public static func rank(_ tasks: [LupyTask], state: LupyState, now: Timestamp) -> [(LupyTask, PriorityAssessment)] {
        tasks.filter { !$0.status.isTerminal }
            .map { ($0, assess($0, state: state, now: now)) }
            .sorted { a, b in
                if a.1.score != b.1.score { return a.1.score > b.1.score }
                let da = a.0.deadline ?? Timestamp(millis: Int64.max), db = b.0.deadline ?? Timestamp(millis: Int64.max)
                if da != db { return da < db }
                return a.0.createdAt < b.0.createdAt
            }
    }
}
