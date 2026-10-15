// LupyCore — events (the single source of truth) and the deterministic state reducer.

public enum EventPayload: Codable, Equatable, Sendable {
    case settingsUpdated(LupySettings)
    case projectUpserted(Project)
    case goalUpserted(Goal)
    case planUpserted(Plan)
    case taskUpserted(LupyTask)
    case taskStatusChanged(taskID: LupyID, from: TaskStatus, to: TaskStatus, note: String)
    case evidenceRecorded(Evidence)
    case verificationRecorded(VerificationRecord)
    case handoffUpserted(Handoff)
    case workerUpserted(Worker)
    case reliabilityUpdated(ReliabilityRecord)
    case memoryUpserted(MemoryItem)
    case decisionUpserted(DecisionRecord)
    case approvalUpserted(ApprovalRequest)
    case standingApprovalUpserted(StandingApproval)
    case actionUpserted(ActionRecord)
    case providerUpserted(ProviderConfig)
    case providerRemoved(id: String)
    case routingUpdated(RoutingPolicy)
    case budgetUpdated(BudgetPolicy)
    case usageRecorded(UsageRecord)
    case noticeUpserted(Notice)
    case connectorUpdated(ConnectorStatus)
    case note(text: String, relatedID: LupyID?)
    case recovery(RecoveryReport)
    case migration(from: Int, to: Int)

    /// Short machine name for filtering and diagnostics.
    public var name: String {
        switch self {
        case .settingsUpdated: return "settingsUpdated"
        case .projectUpserted: return "projectUpserted"
        case .goalUpserted: return "goalUpserted"
        case .planUpserted: return "planUpserted"
        case .taskUpserted: return "taskUpserted"
        case .taskStatusChanged: return "taskStatusChanged"
        case .evidenceRecorded: return "evidenceRecorded"
        case .verificationRecorded: return "verificationRecorded"
        case .handoffUpserted: return "handoffUpserted"
        case .workerUpserted: return "workerUpserted"
        case .reliabilityUpdated: return "reliabilityUpdated"
        case .memoryUpserted: return "memoryUpserted"
        case .decisionUpserted: return "decisionUpserted"
        case .approvalUpserted: return "approvalUpserted"
        case .standingApprovalUpserted: return "standingApprovalUpserted"
        case .actionUpserted: return "actionUpserted"
        case .providerUpserted: return "providerUpserted"
        case .providerRemoved: return "providerRemoved"
        case .routingUpdated: return "routingUpdated"
        case .budgetUpdated: return "budgetUpdated"
        case .usageRecorded: return "usageRecorded"
        case .noticeUpserted: return "noticeUpserted"
        case .connectorUpdated: return "connectorUpdated"
        case .note: return "note"
        case .recovery: return "recovery"
        case .migration: return "migration"
        }
    }

    /// The project an event belongs to, when it can be determined from the payload alone.
    public var projectID: LupyID? {
        switch self {
        case .projectUpserted(let p): return p.id
        case .goalUpserted(let g): return g.projectID
        case .planUpserted(let p): return p.projectID
        case .taskUpserted(let t): return t.projectID
        case .memoryUpserted(let m): return m.scope.projectID
        case .decisionUpserted(let d): return d.projectID
        default: return nil
        }
    }
}

public struct LupyEvent: Codable, Equatable, Sendable, Identifiable {
    public static let currentSchema = 1
    public var id: LupyID
    public var seq: Int64
    public var at: Timestamp
    public var by: Principal
    public var summary: String
    public var payload: EventPayload
    public var schema: Int

    public init(id: LupyID, seq: Int64, at: Timestamp, by: Principal, summary: String, payload: EventPayload, schema: Int = LupyEvent.currentSchema) {
        self.id = id; self.seq = seq; self.at = at; self.by = by; self.summary = summary; self.payload = payload; self.schema = schema
    }
}

/// Complete in-memory state, rebuilt by folding events. Named `LupyState` (not `State`) to avoid
/// clashing with SwiftUI in the app module.
public struct LupyState: Codable, Equatable, Sendable {
    public var settings = LupySettings()
    public var projects: [LupyID: Project] = [:]
    public var goals: [LupyID: Goal] = [:]
    public var plans: [LupyID: Plan] = [:]
    public var tasks: [LupyID: LupyTask] = [:]
    public var evidence: [LupyID: Evidence] = [:]
    public var verifications: [LupyID: VerificationRecord] = [:]   // latest per task
    public var handoffs: [LupyID: Handoff] = [:]
    public var workers: [LupyID: Worker] = [:]
    public var reliability: [String: ReliabilityRecord] = [:]
    public var memory: [LupyID: MemoryItem] = [:]
    public var decisions: [LupyID: DecisionRecord] = [:]
    public var approvals: [LupyID: ApprovalRequest] = [:]
    public var standingApprovals: [LupyID: StandingApproval] = [:]
    public var actions: [LupyID: ActionRecord] = [:]
    public var providers: [String: ProviderConfig] = [:]
    public var routing = RoutingPolicy()
    public var budget = BudgetPolicy()
    public var usage: [UsageRecord] = []
    public var notices: [LupyID: Notice] = [:]
    public var connectors: [String: ConnectorStatus] = [:]
    public var lastSeq: Int64 = 0
    public var lastEventAt: Timestamp?
    public var schema: Int = LupyEvent.currentSchema

    public init() {}

    /// Pure reducer. Must stay deterministic: no clocks, no randomness, no I/O.
    public mutating func apply(_ e: LupyEvent) {
        lastSeq = max(lastSeq, e.seq)
        lastEventAt = e.at
        switch e.payload {
        case .settingsUpdated(let s): settings = s
        case .projectUpserted(let p): projects[p.id] = p
        case .goalUpserted(let g): goals[g.id] = g
        case .planUpserted(let p): plans[p.id] = p
        case .taskUpserted(let t):
            tasks[t.id] = t
        case .taskStatusChanged(let id, _, let to, let note):
            if var t = tasks[id] {
                t.status = to
                t.statusNote = note
                t.updatedAt = e.at
                switch to {
                case .inProgress, .dispatched: if t.startedAt == nil { t.startedAt = e.at }
                case .completed, .cancelled: t.completedAt = e.at
                default: break
                }
                if [.acknowledged, .progressEvidenced, .submitted, .verified].contains(to) { t.lastProgressAt = e.at }
                tasks[id] = t
                if [.progressEvidenced, .submitted, .verified, .accepted, .completed].contains(to),
                   var p = projects[t.projectID] {
                    p.lastProgressAt = e.at
                    projects[t.projectID] = p
                }
            }
        case .evidenceRecorded(let ev): evidence[ev.id] = ev
        case .verificationRecorded(let v): verifications[v.taskID] = v
        case .handoffUpserted(let h): handoffs[h.id] = h
        case .workerUpserted(let w): workers[w.id] = w
        case .reliabilityUpdated(let r): reliability[r.key] = r
        case .memoryUpserted(let m): memory[m.id] = m
        case .decisionUpserted(let d): decisions[d.id] = d
        case .approvalUpserted(let a): approvals[a.id] = a
        case .standingApprovalUpserted(let s): standingApprovals[s.id] = s
        case .actionUpserted(let a): actions[a.id] = a
        case .providerUpserted(let p): providers[p.id] = p
        case .providerRemoved(let id): providers[id] = nil
        case .routingUpdated(let r): routing = r
        case .budgetUpdated(let b): budget = b
        case .usageRecorded(let u):
            usage.append(u)
            if let tid = u.taskID, var t = tasks[tid] { t.spentCents += u.costCents; tasks[tid] = t }
        case .noticeUpserted(let n): notices[n.id] = n
        case .connectorUpdated(let c): connectors[c.id] = c
        case .note: break
        case .recovery: break
        case .migration(_, let to): schema = to
        }
    }

    // MARK: Convenience queries

    public func tasks(in projectID: LupyID) -> [LupyTask] {
        tasks.values.filter { $0.projectID == projectID }.sorted { $0.createdAt < $1.createdAt }
    }

    public func evidence(for taskID: LupyID) -> [Evidence] {
        evidence.values.filter { $0.taskID == taskID }.sorted { $0.observedAt < $1.observedAt }
    }

    public var pendingApprovals: [ApprovalRequest] {
        approvals.values.filter { $0.status == .pending }.sorted { $0.requestedAt < $1.requestedAt }
    }

    public var activeProjects: [Project] {
        projects.values.filter { $0.status != .archived }.sorted { $0.name < $1.name }
    }

    public var openHandoffs: [Handoff] {
        handoffs.values.filter { $0.state.isOpen }.sorted { $0.createdAt < $1.createdAt }
    }
}
