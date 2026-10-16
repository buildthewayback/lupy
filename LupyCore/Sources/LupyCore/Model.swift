// LupyCore — domain model. All types are value types, Codable and Sendable.
// Naming rule: avoid SwiftUI/Foundation/Concurrency names (State, Settings, Task, Actor, Text…)
// because the app target compiles these sources in the same module as its SwiftUI code.

// MARK: - Who did something

public enum Principal: Codable, Hashable, Sendable {
    case founder
    case lupy                                   // Lupy's deterministic logic
    case model(provider: String, model: String) // cloud model output — untrusted
    case worker(LupyID)                         // external agent/worker — untrusted
    case connector(String)                      // observation from a tool/API
    case system                                 // recovery, migration, scheduler

    public var label: String {
        switch self {
        case .founder: return "You"
        case .lupy: return "Lupy"
        case .model(let p, let m): return "Model \(p)/\(m)"
        case .worker(let id): return "Worker \(id.raw)"
        case .connector(let c): return "Connector \(c)"
        case .system: return "System"
        }
    }

    /// Only the founder may grant or widen permissions.
    public var mayGrantPermissions: Bool { self == .founder }

    /// Content from these principals is data, never instructions.
    public var isUntrustedContentSource: Bool {
        switch self {
        case .model, .worker: return true
        default: return false
        }
    }
}

// MARK: - Projects

public enum ProjectStatus: String, Codable, CaseIterable, Sendable { case active, paused, archived }

public struct ProjectWeights: Codable, Equatable, Sendable {
    public var importance: Double = 1.0
    public var income: Double = 1.0
    public var strategic: Double = 1.0
    /// Days without progress before Lupy flags the project as neglected.
    public var neglectAfterDays: Int = 7
    public init(importance: Double = 1.0, income: Double = 1.0, strategic: Double = 1.0, neglectAfterDays: Int = 7) {
        self.importance = importance; self.income = income; self.strategic = strategic; self.neglectAfterDays = neglectAfterDays
    }
}

public struct ProjectRule: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var text: String
    public var createdAt: Timestamp
    public init(id: LupyID, text: String, createdAt: Timestamp) { self.id = id; self.text = text; self.createdAt = createdAt }
}

public struct Project: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var name: String
    public var summary: String
    public var colorHex: String
    public var symbol: String
    public var status: ProjectStatus
    public var weights: ProjectWeights
    public var rules: [ProjectRule]
    /// Action kinds Lupy must never perform automatically in this project, even with a standing approval.
    public var neverAutomate: [ActionKind]
    /// Whether global memory items may be used as context for this project.
    public var shareGlobalMemory: Bool
    /// Optional GitHub repository ("owner/name") used to verify delegated coding work.
    public var repository: String?
    public var tags: [String]
    public var createdAt: Timestamp
    public var updatedAt: Timestamp
    public var lastProgressAt: Timestamp?

    public init(id: LupyID, name: String, summary: String = "", colorHex: String = "#60A5FA", symbol: String = "folder",
                status: ProjectStatus = .active, weights: ProjectWeights = ProjectWeights(), rules: [ProjectRule] = [],
                neverAutomate: [ActionKind] = [], shareGlobalMemory: Bool = true, repository: String? = nil,
                tags: [String] = [], createdAt: Timestamp, updatedAt: Timestamp? = nil) {
        self.id = id; self.name = name; self.summary = summary; self.colorHex = colorHex; self.symbol = symbol
        self.status = status; self.weights = weights; self.rules = rules; self.neverAutomate = neverAutomate
        self.shareGlobalMemory = shareGlobalMemory; self.repository = repository; self.tags = tags
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.lastProgressAt = nil
    }
}

// MARK: - Goals and plans

public enum GoalStatus: String, Codable, Sendable { case captured, planning, planned, active, done, dropped }

public struct Goal: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var projectID: LupyID
    public var statement: String
    public var status: GoalStatus
    public var planID: LupyID?
    public var deadline: Timestamp?
    public var createdAt: Timestamp
    public var updatedAt: Timestamp
    public var source: Principal
}

public enum PlanStatus: String, Codable, Sendable { case proposed, approved, rejected, superseded }

public enum PlanMethod: Codable, Equatable, Sendable {
    case heuristic
    case model(provider: String, model: String)
    case founder
    public var label: String {
        switch self {
        case .heuristic: return "Offline rules (no model)"
        case .model(let p, let m): return "\(p) · \(m)"
        case .founder: return "Written by you"
        }
    }
}

public struct Plan: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var goalID: LupyID
    public var projectID: LupyID
    public var summary: String
    public var rationale: String
    public var risks: [String]
    public var openQuestions: [String]
    public var method: PlanMethod
    public var status: PlanStatus
    public var draftTasks: [LupyTask]
    public var warnings: [String]
    public var createdAt: Timestamp
    public var decidedAt: Timestamp?
    public var decisionNote: String?
}

// MARK: - Tasks

public enum TaskKind: String, Codable, CaseIterable, Sendable {
    case general, personal, admin, research, writing, design, coding, communication, publishing, purchase, finance, learning, review

    public var label: String {
        switch self {
        case .general: return "General"
        case .personal: return "Personal"
        case .admin: return "Admin"
        case .research: return "Research"
        case .writing: return "Writing"
        case .design: return "Design & art"
        case .coding: return "Coding"
        case .communication: return "Communication"
        case .publishing: return "Publishing"
        case .purchase: return "Purchase"
        case .finance: return "Finance"
        case .learning: return "Learning"
        case .review: return "Review"
        }
    }
}

public enum TaskOwner: Codable, Hashable, Sendable {
    case founder
    case lupy
    case worker(LupyID)
    case unassigned

    public var label: String {
        switch self {
        case .founder: return "You"
        case .lupy: return "Lupy"
        case .worker(let id): return "Worker \(id.raw)"
        case .unassigned: return "Unassigned"
        }
    }
}

/// Explicit lifecycle states. "Sent", "delivered", "acknowledged", "submitted", "verified" and
/// "accepted" are deliberately distinct — they must never collapse into a generic "done".
public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case planned            // in the plan, not yet actionable
    case ready              // dependencies met, can start
    case inProgress         // owner is working on it (founder or Lupy)
    case dispatched         // handed to a worker; channel accepted the send
    case deliveryUnconfirmed // sent, but the channel cannot observe delivery
    case acknowledged       // worker reply observed
    case progressEvidenced  // independent evidence of progress observed
    case submitted          // deliverable claimed/received — NOT yet verified
    case verifying          // checks running
    case verified           // evidence satisfies acceptance criteria
    case accepted           // founder (or policy for low-risk work) accepted
    case completed          // closed after acceptance
    case waitingDependency
    case waitingApproval
    case waitingFounder     // needs a decision or input from the founder
    case blocked
    case paused
    case failed
    case recovering         // Lupy is retrying or changing strategy
    case escalated          // Lupy gave up its recovery options; founder must decide
    case cancelled

    public var label: String {
        switch self {
        case .planned: return "Planned"
        case .ready: return "Ready"
        case .inProgress: return "In progress"
        case .dispatched: return "Sent"
        case .deliveryUnconfirmed: return "Delivery unconfirmed"
        case .acknowledged: return "Acknowledged"
        case .progressEvidenced: return "Progress evidenced"
        case .submitted: return "Submitted (unverified)"
        case .verifying: return "Verifying"
        case .verified: return "Verified"
        case .accepted: return "Accepted"
        case .completed: return "Completed"
        case .waitingDependency: return "Waiting on another task"
        case .waitingApproval: return "Waiting for your approval"
        case .waitingFounder: return "Needs you"
        case .blocked: return "Blocked"
        case .paused: return "Paused"
        case .failed: return "Failed"
        case .recovering: return "Recovering"
        case .escalated: return "Escalated to you"
        case .cancelled: return "Cancelled"
        }
    }

    public var isTerminal: Bool { self == .completed || self == .cancelled }
    public var isClosedForWork: Bool { isTerminal || self == .accepted || self == .verified }
    public var isDelegationState: Bool {
        [.dispatched, .deliveryUnconfirmed, .acknowledged, .progressEvidenced].contains(self)
    }
    public var needsFounder: Bool { [.waitingApproval, .waitingFounder, .escalated].contains(self) }
    public var isActionable: Bool { [.ready, .inProgress, .recovering].contains(self) }
}

public struct PriorityInputs: Codable, Equatable, Sendable {
    public var urgency: Int = 2        // 0…5 (deadline adds on top)
    public var consequence: Int = 2    // 0…5 cost of not doing it
    public var value: Int = 2          // 0…5 general value
    public var income: Int = 0         // 0…5 direct income impact
    public var strategic: Int = 2      // 0…5
    public var effortHours: Double = 1
    public var confidence: Double = 0.7 // 0…1 chance the approach works
    public var risk: Int = 1           // 0…5
    public var apiCostCents: Double = 0
    public init() {}
    public init(urgency: Int = 2, consequence: Int = 2, value: Int = 2, income: Int = 0, strategic: Int = 2,
                effortHours: Double = 1, confidence: Double = 0.7, risk: Int = 1, apiCostCents: Double = 0) {
        self.urgency = urgency; self.consequence = consequence; self.value = value; self.income = income
        self.strategic = strategic; self.effortHours = effortHours; self.confidence = confidence; self.risk = risk
        self.apiCostCents = apiCostCents
    }

    public mutating func clamp() {
        urgency = min(5, max(0, urgency)); consequence = min(5, max(0, consequence)); value = min(5, max(0, value))
        income = min(5, max(0, income)); strategic = min(5, max(0, strategic)); risk = min(5, max(0, risk))
        effortHours = min(1000, max(0.05, effortHours.isFinite ? effortHours : 1))
        confidence = min(1, max(0, confidence.isFinite ? confidence : 0.5))
        apiCostCents = max(0, apiCostCents.isFinite ? apiCostCents : 0)
    }
}

/// What kind of evidence satisfies a criterion.
public enum EvidenceRequirement: Codable, Equatable, Sendable {
    case founderConfirmation
    case independent([EvidenceKind])
    case automatedCheck(String)

    public var label: String {
        switch self {
        case .founderConfirmation: return "Your confirmation"
        case .independent(let kinds): return "Independent evidence: " + kinds.map(\.label).joined(separator: " or ")
        case .automatedCheck(let c): return "Automated check: \(c)"
        }
    }
}

public struct AcceptanceCriterion: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var text: String
    public var requirement: EvidenceRequirement
    public init(id: LupyID, text: String, requirement: EvidenceRequirement) { self.id = id; self.text = text; self.requirement = requirement }
}

public struct Checkpoint: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var title: String
    public var due: Timestamp
    public var met: Bool = false
    public var metAt: Timestamp?
    public var missedFlagged: Bool = false
    public init(id: LupyID, title: String, due: Timestamp) { self.id = id; self.title = title; self.due = due }
}

public struct LupyTask: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var projectID: LupyID
    public var goalID: LupyID?
    public var title: String
    public var details: String
    public var kind: TaskKind
    public var owner: TaskOwner
    public var status: TaskStatus
    public var statusNote: String
    public var priority: PriorityInputs
    /// Founder override: +1 pinned to top, -1 pushed down, 0 none.
    public var pin: Int
    public var deadline: Timestamp?
    public var dependsOn: [LupyID]
    public var acceptance: [AcceptanceCriterion]
    public var checkpoints: [Checkpoint]
    public var handoffID: LupyID?
    /// For tasks that consist of an external action (send, publish, buy…).
    public var action: ProposedAction?
    public var budgetCents: Double?
    public var spentCents: Double
    public var attempts: Int
    public var requiresFounderAcceptance: Bool
    public var createdAt: Timestamp
    public var updatedAt: Timestamp
    public var startedAt: Timestamp?
    public var completedAt: Timestamp?
    public var lastProgressAt: Timestamp?
    public var nextCheckAt: Timestamp?
    /// Evidence observed before this instant is stale (task was reopened or materially changed).
    public var evidenceEpoch: Timestamp
    public var tags: [String]
    public var source: Principal
    /// Key used while the task was a plan draft, to resolve dependencies.
    public var planKey: String?
    /// Status to return to when a paused task is resumed.
    public var resumeStatus: TaskStatus?

    public init(id: LupyID, projectID: LupyID, title: String, details: String = "", kind: TaskKind = .general,
                owner: TaskOwner = .founder, status: TaskStatus = .planned, priority: PriorityInputs = PriorityInputs(),
                deadline: Timestamp? = nil, dependsOn: [LupyID] = [], acceptance: [AcceptanceCriterion] = [],
                requiresFounderAcceptance: Bool = true, createdAt: Timestamp, source: Principal = .founder) {
        self.id = id; self.projectID = projectID; self.goalID = nil; self.title = title; self.details = details
        self.kind = kind; self.owner = owner; self.status = status; self.statusNote = ""; self.priority = priority
        self.pin = 0; self.deadline = deadline; self.dependsOn = dependsOn; self.acceptance = acceptance
        self.checkpoints = []; self.handoffID = nil; self.action = nil; self.budgetCents = nil; self.spentCents = 0
        self.attempts = 0; self.requiresFounderAcceptance = requiresFounderAcceptance
        self.createdAt = createdAt; self.updatedAt = createdAt; self.startedAt = nil; self.completedAt = nil
        self.lastProgressAt = nil; self.nextCheckAt = nil; self.evidenceEpoch = createdAt; self.tags = []
        self.source = source; self.planKey = nil; self.resumeStatus = nil
    }
}

/// A deliverable or text produced for the founder (model drafts, daily briefs, answers).
public struct DraftDocument: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var taskID: LupyID?
    public var projectID: LupyID?
    public var title: String
    public var body: String
    public var source: Principal
    public var createdAt: Timestamp
    public var contentHash: String
}

// MARK: - Evidence

public enum EvidenceKind: String, Codable, CaseIterable, Sendable {
    case workerClaim, deliveryReceipt, acknowledgement, progressUpdate, artifact, commit, pullRequest, ciResult,
         testResult, apiResponse, fileObservation, founderConfirmation, automatedCheck, modelOutput, observation

    public var label: String {
        switch self {
        case .workerClaim: return "Worker's claim"
        case .deliveryReceipt: return "Delivery receipt"
        case .acknowledgement: return "Acknowledgement"
        case .progressUpdate: return "Progress update"
        case .artifact: return "Artifact"
        case .commit: return "Commit"
        case .pullRequest: return "Pull request"
        case .ciResult: return "CI result"
        case .testResult: return "Test result"
        case .apiResponse: return "API response"
        case .fileObservation: return "File check"
        case .founderConfirmation: return "Your confirmation"
        case .automatedCheck: return "Automated check"
        case .modelOutput: return "Model output"
        case .observation: return "Observation"
        }
    }

    /// Claims and model output are self-reports: they never verify anything on their own.
    public var isSelfReportByNature: Bool { self == .workerClaim || self == .modelOutput }
}

public enum EvidenceIndependence: String, Codable, Sendable { case selfReported, independent, founder }
public enum EvidenceVerdict: String, Codable, Sendable { case supports, contradicts, inconclusive }

public struct Evidence: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var taskID: LupyID
    public var handoffID: LupyID?
    public var kind: EvidenceKind
    public var summary: String
    public var source: Principal
    public var independence: EvidenceIndependence
    public var verdict: EvidenceVerdict
    public var reference: String?
    public var contentHash: String?
    /// Criteria this evidence speaks to; empty = applies to the task as a whole.
    public var criterionIDs: [LupyID]
    public var observedAt: Timestamp
    public var recordedAt: Timestamp
    public var validUntil: Timestamp?
    public var check: String?

    public init(id: LupyID, taskID: LupyID, kind: EvidenceKind, summary: String, source: Principal,
                independence: EvidenceIndependence, verdict: EvidenceVerdict = .supports, reference: String? = nil,
                criterionIDs: [LupyID] = [], observedAt: Timestamp, recordedAt: Timestamp? = nil) {
        self.id = id; self.taskID = taskID; self.handoffID = nil; self.kind = kind; self.summary = summary
        self.source = source
        // A self-report can never be upgraded to "independent" by whoever records it.
        self.independence = kind.isSelfReportByNature ? .selfReported : independence
        self.verdict = verdict; self.reference = reference; self.contentHash = nil; self.criterionIDs = criterionIDs
        self.observedAt = observedAt; self.recordedAt = recordedAt ?? observedAt; self.validUntil = nil; self.check = nil
    }
}

// MARK: - Workers and handoffs

public enum WorkerKind: String, Codable, Sendable { case cloudModel, externalAgent, human, tool }

public enum ChannelKind: String, Codable, Sendable {
    case manualRelay   // founder pastes the brief into the agent (Arena, Muse, ChatGPT…)
    case cloudModel    // Lupy calls a model API directly
    case api           // a real connector API
    public var label: String {
        switch self {
        case .manualRelay: return "Manual relay (you paste it)"
        case .cloudModel: return "Cloud model API"
        case .api: return "Connector API"
        }
    }
}

public struct ChannelCapabilities: Codable, Equatable, Sendable {
    public var canSend: Bool
    public var canConfirmDelivery: Bool
    public var canObserveAcknowledgement: Bool
    public var canObserveProgress: Bool
    public var canFetchArtifacts: Bool
    public var requiresManualRelay: Bool
    public init(canSend: Bool, canConfirmDelivery: Bool, canObserveAcknowledgement: Bool, canObserveProgress: Bool,
                canFetchArtifacts: Bool, requiresManualRelay: Bool) {
        self.canSend = canSend; self.canConfirmDelivery = canConfirmDelivery
        self.canObserveAcknowledgement = canObserveAcknowledgement; self.canObserveProgress = canObserveProgress
        self.canFetchArtifacts = canFetchArtifacts; self.requiresManualRelay = requiresManualRelay
    }
    public static let manualRelay = ChannelCapabilities(canSend: false, canConfirmDelivery: false, canObserveAcknowledgement: false,
                                                        canObserveProgress: false, canFetchArtifacts: false, requiresManualRelay: true)
    public static let cloudModel = ChannelCapabilities(canSend: true, canConfirmDelivery: true, canObserveAcknowledgement: true,
                                                       canObserveProgress: false, canFetchArtifacts: true, requiresManualRelay: false)
}

public struct Worker: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var name: String
    public var kind: WorkerKind
    public var channel: ChannelKind
    public var capabilities: ChannelCapabilities
    /// GitHub repositories ("owner/name") where this worker's coding output can be independently observed.
    public var observableRepositories: [String]
    public var notes: String
    public var enabled: Bool
    public var createdAt: Timestamp
}

public enum HandoffState: String, Codable, CaseIterable, Sendable {
    case drafted, awaitingRelay, sent, deliveryUnconfirmed, acknowledged, progressEvidenced, submitted,
         verifying, verified, accepted, reworkRequested, stalled, failed, cancelled

    public var label: String {
        switch self {
        case .drafted: return "Drafted"
        case .awaitingRelay: return "Waiting for you to paste it"
        case .sent: return "Sent"
        case .deliveryUnconfirmed: return "Delivery unconfirmed"
        case .acknowledged: return "Acknowledged"
        case .progressEvidenced: return "Progress evidenced"
        case .submitted: return "Submitted (unverified)"
        case .verifying: return "Verifying"
        case .verified: return "Verified"
        case .accepted: return "Accepted"
        case .reworkRequested: return "Rework requested"
        case .stalled: return "Stalled"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    public var isOpen: Bool { ![.accepted, .failed, .cancelled].contains(self) }
}

public struct HandoffBrief: Codable, Equatable, Sendable {
    public var objective: String
    public var scope: String
    public var constraints: [String]
    public var projectRules: [String]
    public var acceptance: [String]
    public var evidenceRequested: [String]
    public var due: Timestamp?
    public var checkpoint: Timestamp?
    public var contextNotes: String
    public var reference: String
}

public struct HandoffNote: Codable, Equatable, Sendable {
    public var at: Timestamp
    public var by: Principal
    public var text: String
}

public struct Handoff: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var taskID: LupyID
    public var workerID: LupyID
    public var channel: ChannelKind
    public var brief: HandoffBrief
    public var state: HandoffState
    public var createdAt: Timestamp
    public var sentAt: Timestamp?
    public var acknowledgedAt: Timestamp?
    public var lastProgressAt: Timestamp?
    public var submittedAt: Timestamp?
    public var closedAt: Timestamp?
    public var followUps: Int
    public var lastFollowUpAt: Timestamp?
    public var nextFollowUpAt: Timestamp?
    public var notes: [HandoffNote]
}

// MARK: - Reliability (task-specific, transparent, never affects permissions)

public enum ReliabilityOutcome: String, Codable, CaseIterable, Sendable {
    case claimVerified, claimContradicted, claimUnverifiable, onTime, missedCheckpoint, noResponse, acceptedFirstTime, reworkRequired
}

public enum OversightLevel: String, Codable, Comparable, CaseIterable, Sendable {
    case standard, elevated, strict
    private var rank: Int { switch self { case .standard: return 0; case .elevated: return 1; case .strict: return 2 } }
    public static func < (a: OversightLevel, b: OversightLevel) -> Bool { a.rank < b.rank }
    public var label: String {
        switch self {
        case .standard: return "Standard checks"
        case .elevated: return "Extra checks"
        case .strict: return "Strict: verify every claim independently"
        }
    }
}

public struct ReliabilityRecord: Codable, Equatable, Sendable {
    public var workerID: LupyID
    public var taskKind: TaskKind
    public var recent: [ReliabilityOutcome]
    public var totals: [String: Int]
    public var computed: OversightLevel
    public var founderOverride: OversightLevel?
    public var overrideNote: String?
    public var explanation: String
    public var updatedAt: Timestamp
    public var effective: OversightLevel { founderOverride ?? computed }
    public var key: String { "\(workerID.raw)|\(taskKind.rawValue)" }
}

// MARK: - Memory and decisions

public enum MemoryScope: Codable, Hashable, Sendable {
    case global
    case project(LupyID)
    public var projectID: LupyID? { if case .project(let id) = self { return id }; return nil }
}

public enum MemoryKind: String, Codable, CaseIterable, Sendable {
    case preference, standingInstruction, rule, decision, fact, lesson, contact
    public var label: String {
        switch self {
        case .preference: return "Preference"
        case .standingInstruction: return "Standing instruction"
        case .rule: return "Rule"
        case .decision: return "Decision"
        case .fact: return "Fact"
        case .lesson: return "Lesson learned"
        case .contact: return "Contact"
        }
    }
}

public enum MemoryStatus: String, Codable, Sendable { case active, contested, superseded, archived }

public struct MemoryItem: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var scope: MemoryScope
    public var kind: MemoryKind
    public var title: String
    public var body: String
    /// Optional subject key ("preferred-model", "work-hours"); two active items with the same key and
    /// different bodies are a conflict that the founder must reconcile.
    public var key: String?
    public var status: MemoryStatus
    public var supersededBy: LupyID?
    public var source: Principal
    public var confidence: Double
    /// Sensitive items are never sent to cloud models.
    public var sensitive: Bool
    public var createdAt: Timestamp
    public var updatedAt: Timestamp
    public var lastConfirmedAt: Timestamp?
}

public enum DecisionStatus: String, Codable, Sendable { case proposed, decided, revisited, superseded }

public struct DecisionRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var projectID: LupyID?
    public var title: String
    public var decision: String
    public var rationale: String
    public var status: DecisionStatus
    public var decidedBy: Principal
    public var createdAt: Timestamp
    public var relatedTaskIDs: [LupyID]
}

// MARK: - Actions, policy and approvals

public enum RiskLevel: Int, Codable, Comparable, Sendable {
    case none = 0, low, medium, high, critical, forbidden
    public static func < (a: RiskLevel, b: RiskLevel) -> Bool { a.rawValue < b.rawValue }
    public var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        case .forbidden: return "Never allowed"
        }
    }
}

public enum ActionKind: String, Codable, CaseIterable, Sendable {
    case readInformation, updateLupyState, draftContent, modelCall, localFileWrite, openURL,
         dispatchToWorker, sendExternalMessage, publishContent, spendMoney, deleteData,
         changeAccountSecurity, grantAccess, mergeProtectedBranch, deployProduction, computerControl,
         uiInput, uiNavigate, bypassSecurityControl

    public var risk: RiskLevel {
        switch self {
        case .readInformation, .updateLupyState: return .none
        case .draftContent, .uiInput: return .low
        case .modelCall, .localFileWrite, .openURL, .uiNavigate: return .medium
        case .dispatchToWorker: return .medium
        case .sendExternalMessage, .publishContent, .mergeProtectedBranch, .deployProduction, .computerControl, .deleteData: return .high
        case .spendMoney, .changeAccountSecurity, .grantAccess: return .critical
        case .bypassSecurityControl: return .forbidden
        }
    }

    /// Kinds for which a standing (pre-)approval is never accepted: every instance needs the founder.
    public var neverStanding: Bool {
        [.changeAccountSecurity, .grantAccess, .deleteData, .bypassSecurityControl].contains(self)
    }

    public var label: String {
        switch self {
        case .readInformation: return "Read information"
        case .updateLupyState: return "Update Lupy's own records"
        case .draftContent: return "Draft content (not sent)"
        case .modelCall: return "Send context to a cloud model"
        case .localFileWrite: return "Write a file on this Mac"
        case .openURL: return "Open a web page"
        case .dispatchToWorker: return "Send a handoff to an agent"
        case .sendExternalMessage: return "Send a message to someone"
        case .publishContent: return "Publish content"
        case .spendMoney: return "Spend money"
        case .deleteData: return "Delete data"
        case .changeAccountSecurity: return "Change account security"
        case .grantAccess: return "Grant access"
        case .mergeProtectedBranch: return "Merge into a protected branch"
        case .deployProduction: return "Deploy to production"
        case .computerControl: return "Control apps on this Mac"
        case .uiInput: return "Type into an app (nothing sent yet)"
        case .uiNavigate: return "Open or move around an app"
        case .bypassSecurityControl: return "Bypass a security control"
        }
    }
}

public enum AutonomyMode: String, Codable, CaseIterable, Sendable {
    case observe   // advise only; anything beyond Lupy's own records needs approval
    case prepare   // prepare drafts and plans; external effects need approval
    case bounded   // act within granted, scoped permissions
    public var label: String {
        switch self {
        case .observe: return "Observe & advise"
        case .prepare: return "Prepare, then ask"
        case .bounded: return "Act within limits"
        }
    }
}

public struct ProposedAction: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var kind: ActionKind
    public var title: String
    public var target: String
    public var detail: String
    public var projectID: LupyID?
    public var taskID: LupyID?
    public var workerID: LupyID?
    public var idempotencyKey: String
    public var estimatedCostCents: Double?
    public var reversible: Bool
    public var originator: Principal
    public var createdAt: Timestamp
}

public struct StandingApproval: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var kind: ActionKind
    public var projectID: LupyID?
    /// "*" = any target; otherwise exact match or prefix match when ending in "*".
    public var targetPattern: String
    public var workerID: LupyID?
    public var maxUses: Int?
    public var uses: Int
    public var maxCostCents: Double?
    public var expiresAt: Timestamp
    public var createdAt: Timestamp
    public var createdBy: Principal
    public var revokedAt: Timestamp?
    public var note: String
}

public enum ApprovalStatus: String, Codable, Sendable { case pending, approved, denied, expired, cancelled }

public struct ApprovalRequest: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var action: ProposedAction
    public var reasons: [String]
    public var risk: RiskLevel
    public var consequence: String
    public var status: ApprovalStatus
    public var requestedAt: Timestamp
    public var expiresAt: Timestamp?
    public var decidedAt: Timestamp?
    public var decidedBy: Principal?
    public var decisionNote: String?
}

public enum ActionState: String, Codable, Sendable { case intended, approved, executing, succeeded, failed, outcomeUnknown, skippedDuplicate, cancelled }

public enum ErrorCategory: String, Codable, CaseIterable, Sendable {
    case transient, rateLimited, timeout, network, auth, invalidRequest, contextTooLong, modelUnavailable,
         quotaExceeded, contentFiltered, permanent, unknown

    public var label: String {
        switch self {
        case .transient: return "Temporary server problem"
        case .rateLimited: return "Rate limited"
        case .timeout: return "Timed out"
        case .network: return "Network unavailable"
        case .auth: return "Key rejected or expired"
        case .invalidRequest: return "Request rejected"
        case .contextTooLong: return "Too much context"
        case .modelUnavailable: return "Model unavailable"
        case .quotaExceeded: return "Provider quota or credit exhausted"
        case .contentFiltered: return "Blocked by provider safety filter"
        case .permanent: return "Permanent failure"
        case .unknown: return "Unknown failure"
        }
    }
}

public struct ErrorInfo: Codable, Equatable, Sendable {
    public var category: ErrorCategory
    public var message: String
    public var at: Timestamp
    public var retryAfterMillis: Int64?
    public init(category: ErrorCategory, message: String, at: Timestamp, retryAfterMillis: Int64? = nil) {
        self.category = category; self.message = message; self.at = at; self.retryAfterMillis = retryAfterMillis
    }
}

public struct ActionRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var action: ProposedAction
    public var state: ActionState
    public var attempts: Int
    public var lastError: ErrorInfo?
    public var createdAt: Timestamp
    public var startedAt: Timestamp?
    public var finishedAt: Timestamp?
    public var nextRetryAt: Timestamp?
    public var resultSummary: String?
}

// MARK: - Providers, routing, budgets, usage

public enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case openAI, anthropic, gemini, openAICompatible
    public var label: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Google Gemini"
        case .openAICompatible: return "OpenAI-compatible (DeepSeek, OpenRouter, Groq, Mistral…)"
        }
    }
}

public enum TaskClass: String, Codable, CaseIterable, Sendable {
    case planning, drafting, summarizing, classifying, verifying, conversation
    public var label: String {
        switch self {
        case .planning: return "Planning"
        case .drafting: return "Drafting"
        case .summarizing: return "Summaries & briefs"
        case .classifying: return "Sorting & triage"
        case .verifying: return "Checking work"
        case .conversation: return "Chat"
        }
    }
}

public struct ModelSpec: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var displayName: String
    /// US cents per million tokens (founder-editable; shown as "estimate").
    public var inputCentsPerMTok: Double
    public var outputCentsPerMTok: Double
    public var contextTokens: Int
    public var maxOutputTokens: Int
    public var enabled: Bool
    public init(id: String, displayName: String, inputCentsPerMTok: Double, outputCentsPerMTok: Double,
                contextTokens: Int, maxOutputTokens: Int, enabled: Bool = true) {
        self.id = id; self.displayName = displayName; self.inputCentsPerMTok = inputCentsPerMTok
        self.outputCentsPerMTok = outputCentsPerMTok; self.contextTokens = contextTokens
        self.maxOutputTokens = maxOutputTokens; self.enabled = enabled
    }
}

public struct ProviderConfig: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: ProviderKind
    public var displayName: String
    public var baseURL: String
    /// Name of the Keychain item holding the key. The key itself never enters LupyCore.
    public var keychainAccount: String
    public var models: [ModelSpec]
    public var enabled: Bool
    /// The founder explicitly allowed Lupy to send data to this provider.
    public var founderApproved: Bool
    public var hasKey: Bool
    public var priceAsOf: String
    public var dataNotice: String
    public var createdAt: Timestamp

    public init(id: String, kind: ProviderKind, displayName: String, baseURL: String, keychainAccount: String,
                models: [ModelSpec], enabled: Bool, founderApproved: Bool, hasKey: Bool,
                priceAsOf: String, dataNotice: String, createdAt: Timestamp) {
        self.id = id; self.kind = kind; self.displayName = displayName; self.baseURL = baseURL
        self.keychainAccount = keychainAccount; self.models = models; self.enabled = enabled
        self.founderApproved = founderApproved; self.hasKey = hasKey; self.priceAsOf = priceAsOf
        self.dataNotice = dataNotice; self.createdAt = createdAt
    }
}

public struct ModelRef: Codable, Hashable, Sendable {
    public var providerID: String
    public var modelID: String
    public init(providerID: String, modelID: String) { self.providerID = providerID; self.modelID = modelID }
    public var label: String { "\(providerID)/\(modelID)" }
}

public struct RoutingPolicy: Codable, Equatable, Sendable {
    /// TaskClass.rawValue → preferred model
    public var preferred: [String: ModelRef]
    /// Fallback to another founder-approved provider when the preferred one fails.
    public var allowFallback: Bool
    public init(preferred: [String: ModelRef] = [:], allowFallback: Bool = true) { self.preferred = preferred; self.allowFallback = allowFallback }
}

public struct BudgetPolicy: Codable, Equatable, Sendable {
    public var monthlyCapCents: Double = 1000      // $10 / month
    public var dailyCapCents: Double = 150         // $1.50 / day
    public var perTaskCapCents: Double = 50        // $0.50 / task
    public var approvalAboveCentsPerCall: Double = 20
    public var maxOutputTokensPerCall: Int = 1500
    public var maxModelCallsPerTask: Int = 12
    public var maxRetriesPerCall: Int = 2
    public var warnFraction: Double = 0.8
    public init() {}
}

public struct UsageRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var providerID: String
    public var modelID: String
    public var taskID: LupyID?
    public var purpose: TaskClass
    public var inputTokens: Int
    public var outputTokens: Int
    public var costCents: Double
    public var estimated: Bool
    public var at: Timestamp
    public var ok: Bool
    public var errorCategory: ErrorCategory?
    public var latencyMillis: Int64
}

// MARK: - Connectors

public enum ConnectorState: String, Codable, Sendable { case notConnected, connected, error, disabled, planned }

public struct ConnectorStatus: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var state: ConnectorState
    public var capabilities: [String]
    public var limitations: [String]
    public var dataSent: String
    public var lastCheckedAt: Timestamp?
    public var lastError: String?
}

// MARK: - Settings and notices

public struct QuietHours: Codable, Equatable, Sendable {
    public var enabled: Bool = true
    public var startMinute: Int = 22 * 60       // local 22:00
    public var endMinute: Int = 7 * 60 + 30     // local 07:30
    public init() {}
    public func contains(minuteOfDay m: Int) -> Bool {
        guard enabled else { return false }
        return startMinute <= endMinute ? (m >= startMinute && m < endMinute) : (m >= startMinute || m < endMinute)
    }
}

public struct FollowUpPolicy: Codable, Equatable, Sendable {
    public var firstCheckAfterMinutes: Int = 120
    public var backoffFactor: Double = 2.0
    public var maxIntervalMinutes: Int = 24 * 60
    public var maxFollowUpsBeforeEscalation: Int = 4
    public var stallAfterHoursWithoutProgress: Int = 48
    public init() {}
}

public struct DataSharingPolicy: Codable, Equatable, Sendable {
    public var includeMemoryInModelContext: Bool = true
    public var includeSensitiveMemory: Bool = false
    public var maxContextCharacters: Int = 12_000
    public init() {}
}

public struct LupySettings: Codable, Equatable, Sendable {
    public var autonomy: AutonomyMode = .prepare
    public var globalPause: Bool = false
    public var pauseReason: String = ""
    public var quietHours = QuietHours()
    public var maxNotificationsPerHour: Int = 4
    public var utcOffsetMinutes: Int = 330
    public var dailyReviewMinute: Int = 8 * 60 + 30
    public var followUp = FollowUpPolicy()
    public var dataSharing = DataSharingPolicy()
    public var onboardingComplete: Bool = false
    public var founderName: String = ""
    public init() {}
}

public enum NoticeSeverity: String, Codable, Comparable, Sendable {
    case info, attention, urgent
    private var rank: Int { switch self { case .info: return 0; case .attention: return 1; case .urgent: return 2 } }
    public static func < (a: NoticeSeverity, b: NoticeSeverity) -> Bool { a.rank < b.rank }
}

public struct Notice: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var title: String
    public var body: String
    public var severity: NoticeSeverity
    public var relatedID: LupyID?
    public var createdAt: Timestamp
    /// Whether it was pushed as a system notification (vs. only shown inside Lupy) under the notification budget.
    public var pushed: Bool
    public var dismissed: Bool
    public var dedupeKey: String
}

public struct VerificationRecord: Codable, Equatable, Sendable {
    public var taskID: LupyID
    public var outcome: VerificationOutcome
    public var criteria: [CriterionResult]
    public var summary: String
    public var at: Timestamp
}

public enum VerificationOutcome: String, Codable, Sendable {
    case verified, contradicted, ambiguous, claimOnly, insufficient
    public var label: String {
        switch self {
        case .verified: return "Verified by evidence"
        case .contradicted: return "Contradicted by evidence"
        case .ambiguous: return "Ambiguous — evidence conflicts"
        case .claimOnly: return "Only claims, no independent evidence"
        case .insufficient: return "Not enough evidence yet"
        }
    }
}

public struct CriterionResult: Codable, Equatable, Sendable {
    public var criterionID: LupyID
    public var text: String
    public var outcome: VerificationOutcome
    public var explanation: String
    public var evidenceIDs: [LupyID]
}

public struct RecoveryReport: Codable, Equatable, Sendable {
    public var at: Timestamp
    public var truncatedBytes: Int
    public var droppedLines: Int
    public var duplicateEventsSkipped: Int
    public var snapshotUsed: Bool
    public var snapshotRejected: String?
    public var interruptedActions: [LupyID]
    public var notes: [String]
    public var isClean: Bool { truncatedBytes == 0 && droppedLines == 0 && snapshotRejected == nil && interruptedActions.isEmpty }
}
