// LupyCore — LupyEngine: the executive core used by the app shell.
// Every mutation goes through the event store (durable, auditable). Methods return effects
// (notifications, model calls, GitHub checks, clipboard) that the shell performs and feeds back.

public enum EngineError: Error, Equatable, CustomStringConvertible, Sendable {
    case notFound(String)
    case invalid(String)
    case notAllowed(String)
    case storage(String)
    public var description: String {
        switch self {
        case .notFound(let m): return "Not found: \(m)"
        case .invalid(let m): return m
        case .notAllowed(let m): return m
        case .storage(let m): return m
        }
    }
}

public enum Effect: Equatable, Sendable {
    case notify(Notice)
    case callModel(ModelJob)
    case checkGitHub(GitHubJob)
    case copyToClipboard(String)
}

public final class LupyEngine {
    public let store: EventStore
    public let clock: LupyClock
    public let ids: IDGenerator
    public var appVersion = "0.1.0"
    var pendingModelJobs: [LupyID: ModelJob] = [:]
    var pendingGitHubJobs: [LupyID: GitHubJob] = [:]
    /// Model calls waiting for an approval decision (approval ID → prepared job).
    var parkedModelJobs: [LupyID: ModelJob] = [:]

    public init(store: EventStore, clock: LupyClock, ids: IDGenerator) {
        self.store = store
        self.clock = clock
        self.ids = ids
    }

    public var state: LupyState { store.state }
    public var now: Timestamp { clock.now() }

    // MARK: Event helpers

    @discardableResult
    func commit(_ drafts: [EventDraft], key: String? = nil) throws -> [LupyEvent] {
        do { return try store.append(drafts, idempotencyKey: key) }
        catch StoreError.duplicate { return [] }
        catch let e as StoreError { throw EngineError.storage(e.description) }
    }

    func ev(_ by: Principal, _ summary: String, _ payload: EventPayload) -> EventDraft { EventDraft(by: by, summary: summary, payload: payload) }

    func requireFounder(_ by: Principal, _ what: String) throws {
        guard by == .founder else { throw EngineError.notAllowed("Only you can \(what).") }
    }

    func task(_ id: LupyID) throws -> LupyTask {
        guard let t = state.tasks[id] else { throw EngineError.notFound("task \(id.raw)") }
        return t
    }

    func project(_ id: LupyID) throws -> Project {
        guard let p = state.projects[id] else { throw EngineError.notFound("project \(id.raw)") }
        return p
    }

    // MARK: Bootstrap

    /// Creates the founder's starting projects, honest worker/connector records and the provider catalog.
    /// Safe to call on every launch (idempotent).
    @discardableResult
    public func bootstrap(founderName: String = "", utcOffsetMinutes: Int = 330) throws -> Bool {
        guard state.projects.isEmpty, !store.hasProcessed("bootstrap-v1") else { return false }
        let t = now
        var drafts: [EventDraft] = []
        var settings = state.settings
        settings.founderName = founderName
        settings.utcOffsetMinutes = utcOffsetMinutes
        drafts.append(ev(.system, "Initial settings", .settingsUpdated(settings)))
        let noMerge = "No merge into main/master and no production deploy without your explicit authorization."
        let defs: [(String, String, String, String, ProjectWeights, [String], [ActionKind])] = [
            ("PENGLAI City", "Flagship worldbuilding / game project.", "#F59E0B", "building.2", ProjectWeights(importance: 1.3, income: 1.0, strategic: 1.5, neglectAfterDays: 5), [noMerge], [.mergeProtectedBranch, .deployProduction, .publishContent]),
            ("Orin / ChatGPT", "Work done with Orin in ChatGPT.", "#10B981", "brain", ProjectWeights(), [], []),
            ("Muse / Arena", "Agent-built software via Muse and Arena.", "#8B5CF6", "sparkles", ProjectWeights(importance: 1.1, strategic: 1.2), [noMerge], [.mergeProtectedBranch, .deployProduction]),
            ("AI research", "Reading, experiments and notes on AI.", "#3B82F6", "magnifyingglass", ProjectWeights(strategic: 1.1, neglectAfterDays: 14), [], []),
            ("Design, art & content", "Illustration, art and content production.", "#EC4899", "paintpalette", ProjectWeights(income: 1.2), [], [.publishContent]),
            ("Urgent income & clients", "Paid work, invoices, client communication.", "#22C55E", "dollarsign.circle", ProjectWeights(importance: 1.4, income: 1.8, strategic: 1.0, neglectAfterDays: 2), ["Never send anything to a client without your approval."], [.sendExternalMessage, .spendMoney]),
            ("Files & notes", "Organising files, notes and references.", "#94A3B8", "doc.text", ProjectWeights(importance: 0.8, neglectAfterDays: 21), [], [.deleteData]),
            ("Social media & Displate", "Posts, listings and shop presence.", "#F97316", "photo.on.rectangle", ProjectWeights(income: 1.2), ["Publishing always needs your approval."], [.publishContent, .sendExternalMessage]),
            ("Learning", "Courses, practice and skills.", "#06B6D4", "book", ProjectWeights(importance: 0.9, neglectAfterDays: 14), [], []),
            ("Personal admin", "Life admin, accounts and errands.", "#A3A3A3", "person.crop.circle", ProjectWeights(importance: 1.0, neglectAfterDays: 10), [], [.spendMoney, .changeAccountSecurity]),
        ]
        for (name, summary, color, symbol, weights, rules, never) in defs {
            let pid = ids.next("prj")
            let p = Project(id: pid, name: name, summary: summary, colorHex: color, symbol: symbol, weights: weights,
                            rules: rules.map { ProjectRule(id: ids.next("rul"), text: $0, createdAt: t) }, neverAutomate: never, createdAt: t)
            drafts.append(ev(.system, "Created project \(name)", .projectUpserted(p)))
        }
        let workers: [(String, WorkerKind, ChannelKind, ChannelCapabilities, String)] = [
            ("Arena", .externalAgent, .manualRelay, .manualRelay, "Coding agent. Lupy cannot message Arena directly: you paste the handoff. Coding progress can be verified on GitHub."),
            ("Muse", .externalAgent, .manualRelay, .manualRelay, "Agent. Manual relay only; Lupy cannot observe delivery."),
            ("Orin (ChatGPT)", .externalAgent, .manualRelay, .manualRelay, "ChatGPT conversation. Manual relay only."),
            ("Lupy (cloud model)", .cloudModel, .cloudModel, .cloudModel, "Lupy drafts text with your approved cloud model. Output always needs your review."),
        ]
        for (name, kind, channel, caps, notes) in workers {
            drafts.append(ev(.system, "Registered worker \(name)", .workerUpserted(Worker(id: ids.next("wrk"), name: name, kind: kind, channel: channel,
                capabilities: caps, observableRepositories: [], notes: notes, enabled: true, createdAt: t))))
        }
        for c in ConnectorCatalog.defaults() { drafts.append(ev(.system, "Connector \(c.name)", .connectorUpdated(c))) }
        for p in ProviderCatalog.defaults(now: t) { drafts.append(ev(.system, "Provider \(p.displayName) (not set up)", .providerUpserted(p))) }
        try commit(drafts, key: "bootstrap-v1")
        _ = try notify("Welcome to Lupy", "Tell Lupy a goal, or add a cloud model in Settings for richer planning. Nothing is sent anywhere until you set it up.",
                       severity: .info, related: nil, dedupe: "welcome")
        return true
    }

    // MARK: Settings

    public func updateSettings(_ s: LupySettings, by: Principal = .founder) throws {
        try requireFounder(by, "change settings")
        try commit([ev(by, "Settings updated", .settingsUpdated(s))])
    }

    public func setAutonomy(_ mode: AutonomyMode, by: Principal = .founder) throws {
        try requireFounder(by, "change Lupy's autonomy")
        var s = state.settings
        s.autonomy = mode
        try commit([ev(by, "Autonomy set to \(mode.label)", .settingsUpdated(s))])
    }

    /// Global pause: stops all actions except reading/record-keeping. Model calls and dispatches are denied.
    public func setGlobalPause(_ paused: Bool, reason: String = "", by: Principal = .founder) throws {
        try requireFounder(by, "pause or resume Lupy")
        var s = state.settings
        s.globalPause = paused
        s.pauseReason = paused ? reason : ""
        try commit([ev(by, paused ? "Lupy paused\(reason.isEmpty ? "" : ": \(reason)")" : "Lupy resumed", .settingsUpdated(s))])
    }

    // MARK: Projects

    @discardableResult
    public func createProject(name: String, summary: String = "", colorHex: String = "#60A5FA", symbol: String = "folder", by: Principal = .founder) throws -> Project {
        let n = TextUtil.trimmed(name)
        guard !n.isEmpty else { throw EngineError.invalid("A project needs a name.") }
        guard !state.projects.values.contains(where: { $0.name.lowercased() == n.lowercased() && $0.status != .archived }) else {
            throw EngineError.invalid("A project called “\(n)” already exists.")
        }
        let p = Project(id: ids.next("prj"), name: n, summary: summary, colorHex: colorHex, symbol: symbol, createdAt: now)
        try commit([ev(by, "Created project \(n)", .projectUpserted(p))])
        return p
    }

    public func updateProject(_ p: Project, by: Principal = .founder) throws {
        try requireFounder(by, "edit projects")
        var q = p
        q.updatedAt = now
        if let repo = q.repository, !repo.isEmpty, !GitHubAPI.isValidRepo(repo) {
            throw EngineError.invalid("Repository must look like owner/name.")
        }
        try commit([ev(by, "Updated project \(p.name)", .projectUpserted(q))])
    }

    public func addProjectRule(_ projectID: LupyID, text: String, by: Principal = .founder) throws {
        try requireFounder(by, "add project rules")
        var p = try project(projectID)
        p.rules.append(ProjectRule(id: ids.next("rul"), text: text, createdAt: now))
        p.updatedAt = now
        try commit([ev(by, "Rule added to \(p.name)", .projectUpserted(p))])
    }

    // MARK: Goals and plans

    @discardableResult
    public func captureGoal(_ statement: String, projectID: LupyID, by: Principal = .founder) throws -> Goal {
        let s = TextUtil.trimmed(statement)
        guard !s.isEmpty else { throw EngineError.invalid("Tell Lupy what you want to achieve.") }
        _ = try project(projectID)
        let g = Goal(id: ids.next("gol"), projectID: projectID, statement: TextUtil.truncate(s, 4000), status: .captured, planID: nil,
                     deadline: DeadlineParser.find(in: s, now: now, utcOffsetMinutes: state.settings.utcOffsetMinutes),
                     createdAt: now, updatedAt: now, source: by)
        try commit([ev(by, "Captured goal: \(TextUtil.truncate(s, 80))", .goalUpserted(g))])
        return g
    }

    /// Offline plan from the goal text (always available, no model, no cost).
    @discardableResult
    public func planHeuristically(goalID: LupyID, extraWarning: String? = nil) throws -> Plan {
        guard var g = state.goals[goalID] else { throw EngineError.notFound("goal") }
        let draft = HeuristicPlanner.plan(goal: g.statement, projectID: g.projectID, goalID: g.id, now: now,
                                          utcOffsetMinutes: state.settings.utcOffsetMinutes, ids: ids)
        var warnings = draft.warnings
        if let w = extraWarning { warnings.insert(w, at: 0) }
        return try storePlan(goal: &g, draft: PlanDraft(summary: draft.summary, tasks: draft.tasks, risks: draft.risks, questions: draft.questions, warnings: warnings), method: .heuristic)
    }

    func storePlan(goal g: inout Goal, draft: PlanDraft, method: PlanMethod) throws -> Plan {
        // Supersede any earlier proposed plan for this goal.
        var drafts: [EventDraft] = []
        for var old in state.plans.values where old.goalID == g.id && old.status == .proposed {
            old.status = .superseded
            old.decidedAt = now
            drafts.append(ev(.lupy, "Superseded earlier plan", .planUpserted(old)))
        }
        let plan = Plan(id: ids.next("pln"), goalID: g.id, projectID: g.projectID, summary: draft.summary, rationale: "",
                        risks: draft.risks, openQuestions: draft.questions, method: method, status: .proposed,
                        draftTasks: draft.tasks, warnings: draft.warnings, createdAt: now, decidedAt: nil, decisionNote: nil)
        g.status = .planned
        g.planID = plan.id
        g.updatedAt = now
        drafts.append(ev(.lupy, "Proposed a plan with \(draft.tasks.count) step(s)", .planUpserted(plan)))
        drafts.append(ev(.lupy, "Goal planned", .goalUpserted(g)))
        try commit(drafts)
        _ = try notify("Plan ready for review", "\(draft.tasks.count) step(s) for “\(TextUtil.truncate(g.statement, 60))”. Nothing starts until you approve.",
                       severity: .attention, related: plan.id, dedupe: "plan:\(plan.id.raw)")
        return plan
    }

    public func updateDraftTask(planID: LupyID, task: LupyTask, by: Principal = .founder) throws {
        guard var plan = state.plans[planID], plan.status == .proposed else { throw EngineError.invalid("Only proposed plans can be edited.") }
        guard let i = plan.draftTasks.firstIndex(where: { $0.id == task.id }) else { throw EngineError.notFound("draft step") }
        var t = task
        t.priority.clamp()
        plan.draftTasks[i] = t
        try commit([ev(by, "Edited plan step \(t.title)", .planUpserted(plan))])
    }

    public func removeDraftTask(planID: LupyID, taskID: LupyID, by: Principal = .founder) throws {
        guard var plan = state.plans[planID], plan.status == .proposed else { throw EngineError.invalid("Only proposed plans can be edited.") }
        plan.draftTasks.removeAll { $0.id == taskID }
        for i in plan.draftTasks.indices { plan.draftTasks[i].dependsOn.removeAll { $0 == taskID } }
        try commit([ev(by, "Removed a plan step", .planUpserted(plan))])
    }

    /// Only the founder approves plans. Approved steps become real tasks.
    @discardableResult
    public func approvePlan(_ planID: LupyID, by: Principal = .founder) throws -> [LupyTask] {
        try requireFounder(by, "approve plans")
        guard var plan = state.plans[planID] else { throw EngineError.notFound("plan") }
        guard plan.status == .proposed else { throw EngineError.invalid("This plan is already \(plan.status.rawValue).") }
        guard !plan.draftTasks.isEmpty else { throw EngineError.invalid("The plan has no steps.") }
        plan.status = .approved
        plan.decidedAt = now
        var drafts = [ev(by, "Approved plan: \(plan.summary)", .planUpserted(plan))]
        let byID = Dictionary(uniqueKeysWithValues: plan.draftTasks.map { ($0.id, $0) })
        var created: [LupyTask] = []
        for var t in DependencyGraph.topologicalOrder(plan.draftTasks) {
            t.createdAt = now; t.updatedAt = now; t.evidenceEpoch = now
            let ready = t.dependsOn.allSatisfy { byID[$0] == nil }
            t.status = ready ? .ready : .waitingDependency
            created.append(t)
            drafts.append(ev(by, "Task: \(t.title)", .taskUpserted(t)))
        }
        if var g = state.goals[plan.goalID] { g.status = .active; g.updatedAt = now; drafts.append(ev(by, "Goal active", .goalUpserted(g))) }
        try commit(drafts, key: "approve-plan:\(planID.raw)")
        return created
    }

    public func rejectPlan(_ planID: LupyID, note: String, by: Principal = .founder) throws {
        try requireFounder(by, "reject plans")
        guard var plan = state.plans[planID], plan.status == .proposed else { throw EngineError.invalid("Only proposed plans can be rejected.") }
        plan.status = .rejected
        plan.decidedAt = now
        plan.decisionNote = note
        var drafts = [ev(by, "Rejected plan\(note.isEmpty ? "" : ": \(note)")", .planUpserted(plan))]
        if var g = state.goals[plan.goalID] { g.status = .captured; g.updatedAt = now; drafts.append(ev(by, "Goal back to captured", .goalUpserted(g))) }
        try commit(drafts)
    }

    // MARK: Tasks

    @discardableResult
    public func addTask(projectID: LupyID, title: String, details: String = "", kind: TaskKind? = nil, owner: TaskOwner = .founder,
                        deadline: Timestamp? = nil, priority: PriorityInputs = PriorityInputs(), dependsOn: [LupyID] = [],
                        acceptance: [String] = [], by: Principal = .founder) throws -> LupyTask {
        let tt = TextUtil.trimmed(title)
        guard !tt.isEmpty else { throw EngineError.invalid("A task needs a title.") }
        _ = try project(projectID)
        for d in dependsOn where state.tasks[d] == nil { throw EngineError.notFound("dependency \(d.raw)") }
        let k = kind ?? HeuristicPlanner.guessKind(tt + " " + details)
        var p = priority
        p.clamp()
        var t = LupyTask(id: ids.next("tsk"), projectID: projectID, title: TextUtil.truncate(tt, 200), details: details, kind: k, owner: owner,
                         status: .planned, priority: p, deadline: deadline ?? DeadlineParser.find(in: tt, now: now, utcOffsetMinutes: state.settings.utcOffsetMinutes),
                         dependsOn: dependsOn, createdAt: now, source: by)
        t.acceptance = acceptance.map { AcceptanceCriterion(id: ids.next("crt"), text: $0, requirement: PlanBuilder.requirement(for: $0, kind: k)) }
        switch DependencyGraph.readiness(of: t, in: state.tasks) {
        case .ready: t.status = .ready
        case .waiting: t.status = .waitingDependency
        case .blockedByCancelled: t.status = .blocked; t.statusNote = "A dependency was cancelled."
        }
        try commit([ev(by, "Added task \(t.title)", .taskUpserted(t))])
        return t
    }

    /// Edits task content. Material changes reset the evidence epoch (older evidence becomes stale).
    public func updateTask(_ updated: LupyTask, by: Principal = .founder) throws {
        let old = try task(updated.id)
        var t = updated
        t.status = old.status            // status only changes through transition()
        t.priority.clamp()
        t.updatedAt = now
        if old.title != t.title || old.details != t.details || old.acceptance != t.acceptance {
            t.evidenceEpoch = now
        }
        if DependencyGraph.cycleMembers(Array(state.tasks.values.filter { $0.id != t.id }) + [t]).contains(t.id) {
            throw EngineError.invalid("That dependency would create a loop.")
        }
        try commit([ev(by, "Edited task \(t.title)", .taskUpserted(t))])
    }

    /// The single way task status changes. Guards enforce evidence rules.
    public func transition(_ taskID: LupyID, to: TaskStatus, by: Principal, note: String = "", founderOverride: Bool = false) throws {
        let t = try task(taskID)
        if t.status == to { return }
        let evidence = state.evidence(for: taskID)
        let verification = to == .verified
            ? VerificationEngine.evaluate(task: t, evidence: evidence, oversight: oversight(for: t), now: now) : state.verifications[taskID]
        if let reason = Lifecycle.check(t, to: to, by: by, evidence: evidence, verification: verification, founderOverride: founderOverride) {
            throw EngineError.notAllowed(reason)
        }
        try commit([ev(by, "\(t.title): \(t.status.label) → \(to.label)\(note.isEmpty ? "" : " (\(note))")",
                       .taskStatusChanged(taskID: taskID, from: t.status, to: to, note: note))])
    }

    public func startTask(_ taskID: LupyID, by: Principal = .founder) throws {
        let t = try task(taskID)
        if case .waiting(let deps) = DependencyGraph.readiness(of: t, in: state.tasks) {
            let names = deps.compactMap { state.tasks[$0]?.title }.joined(separator: ", ")
            throw EngineError.notAllowed("Waiting on: \(names).")
        }
        if t.status == .planned || t.status == .waitingDependency { try transition(taskID, to: .ready, by: by) }
        try transition(taskID, to: .inProgress, by: by)
    }

    /// Founder marks a task done. Personal/admin tasks complete directly (your word is the evidence);
    /// other tasks record your confirmation and go through verification.
    public func markDone(_ taskID: LupyID, note: String = "", by: Principal = .founder) throws {
        try requireFounder(by, "mark tasks done")
        let t = try task(taskID)
        _ = try recordEvidence(taskID: taskID, kind: .founderConfirmation, summary: note.isEmpty ? "You marked it done." : note, verdict: .supports, by: .founder)
        if Lifecycle.founderSelfCompletable(t) {
            if t.status == .planned || t.status == .waitingDependency { try transition(taskID, to: .ready, by: by) }
            try transition(taskID, to: .completed, by: by, note: "Marked done by you")
            return
        }
        if Lifecycle.canTransition(try task(taskID).status, .submitted) { try transition(taskID, to: .submitted, by: by) }
        _ = try verify(taskID)
    }

    public func pause(_ taskID: LupyID, by: Principal = .founder) throws {
        var t = try task(taskID)
        guard !t.status.isTerminal, t.status != .paused else { return }
        t.resumeStatus = t.status
        try commit([ev(by, "Paused \(t.title)", .taskUpserted(t)),
                    ev(by, "\(t.title) paused", .taskStatusChanged(taskID: taskID, from: t.status, to: .paused, note: "Paused"))])
    }

    public func resume(_ taskID: LupyID, by: Principal = .founder) throws {
        let t = try task(taskID)
        guard t.status == .paused else { return }
        var target = t.resumeStatus ?? .ready
        if !Lifecycle.canTransition(.paused, target) { target = .ready }
        if target == .ready, case .waiting = DependencyGraph.readiness(of: t, in: state.tasks) { target = .waitingDependency }
        try transition(taskID, to: target, by: by, note: "Resumed")
    }

    public func cancel(_ taskID: LupyID, note: String = "", by: Principal = .founder) throws {
        let t = try task(taskID)
        guard !t.status.isTerminal else { return }
        var drafts: [EventDraft] = []
        if let hid = t.handoffID, var h = state.handoffs[hid], h.state.isOpen {
            h.state = .cancelled; h.closedAt = now; h.nextFollowUpAt = nil
            drafts.append(ev(by, "Handoff cancelled", .handoffUpserted(h)))
        }
        drafts.append(ev(by, "Cancelled \(t.title)", .taskStatusChanged(taskID: taskID, from: t.status, to: .cancelled, note: note)))
        try commit(drafts)
    }

    public func reopen(_ taskID: LupyID, note: String, by: Principal = .founder) throws {
        var t = try task(taskID)
        guard t.status.isTerminal || t.status == .accepted || t.status == .verified else { return }
        t.evidenceEpoch = now
        t.updatedAt = now
        let target: TaskStatus = t.status == .cancelled ? .ready : .inProgress
        try commit([ev(by, "Reopened \(t.title)", .taskUpserted(t)),
                    ev(by, "\(t.title) reopened", .taskStatusChanged(taskID: taskID, from: t.status, to: target, note: note))])
    }

    public func pin(_ taskID: LupyID, _ value: Int, by: Principal = .founder) throws {
        var t = try task(taskID)
        t.pin = max(-1, min(1, value))
        try commit([ev(by, value > 0 ? "Pinned \(t.title)" : (value < 0 ? "Pushed down \(t.title)" : "Unpinned \(t.title)"), .taskUpserted(t))])
    }

    @discardableResult
    public func addCheckpoint(_ taskID: LupyID, title: String, due: Timestamp, by: Principal = .founder) throws -> Checkpoint {
        var t = try task(taskID)
        let c = Checkpoint(id: ids.next("chk"), title: title, due: due)
        t.checkpoints.append(c)
        try commit([ev(by, "Checkpoint “\(title)” for \(t.title)", .taskUpserted(t))])
        return c
    }

    public func markCheckpointMet(_ taskID: LupyID, _ checkpointID: LupyID, by: Principal = .founder) throws {
        var t = try task(taskID)
        guard let i = t.checkpoints.firstIndex(where: { $0.id == checkpointID }) else { throw EngineError.notFound("checkpoint") }
        t.checkpoints[i].met = true
        t.checkpoints[i].metAt = now
        try commit([ev(by, "Checkpoint met: \(t.checkpoints[i].title)", .taskUpserted(t))])
    }

    // MARK: Memory and decisions

    @discardableResult
    public func remember(scope: MemoryScope, kind: MemoryKind, title: String, body: String = "", key: String? = nil,
                         sensitive: Bool = false, by: Principal = .founder) throws -> MemoryItem {
        let tt = TextUtil.trimmed(title)
        guard !tt.isEmpty else { throw EngineError.invalid("A memory needs a title.") }
        if let pid = scope.projectID { _ = try project(pid) }
        // Content from models/workers is stored as low-confidence and never as a standing instruction.
        var k = kind
        var confidence = 1.0
        if by.isUntrustedContentSource {
            confidence = 0.4
            if k == .standingInstruction || k == .rule || k == .preference { k = .fact }
        }
        var item = MemoryItem(id: ids.next("mem"), scope: scope, kind: k, title: TextUtil.truncate(tt, 200), body: TextUtil.truncate(body, 4000),
                              key: key.map { TextUtil.slug($0) }, status: .active, supersededBy: nil, source: by, confidence: confidence,
                              sensitive: sensitive, createdAt: now, updatedAt: now, lastConfirmedAt: by == .founder ? now : nil)
        var drafts: [EventDraft] = []
        var conflict = false
        if let key = item.key {
            for var other in state.memory.values where other.key == key && other.scope == scope && other.status == .active && other.body != item.body {
                other.status = .contested
                other.updatedAt = now
                drafts.append(ev(.lupy, "Memory conflict on “\(key)”", .memoryUpserted(other)))
                conflict = true
            }
            if conflict { item.status = .contested }
        }
        drafts.insert(ev(by, "Remembered: \(item.title)", .memoryUpserted(item)), at: 0)
        try commit(drafts)
        if conflict {
            _ = try notify("Conflicting memory", "“\(item.title)” disagrees with something Lupy already knew about “\(key ?? "")”. Choose which one is right.",
                           severity: .attention, related: item.id, dedupe: "memconflict:\(key ?? item.id.raw)")
        }
        return item
    }

    /// Founder resolves a conflict: `keep` stays active, the others are superseded by it.
    public func resolveMemoryConflict(keep: LupyID, supersede: [LupyID], by: Principal = .founder) throws {
        try requireFounder(by, "resolve memory conflicts")
        guard var winner = state.memory[keep] else { throw EngineError.notFound("memory") }
        winner.status = .active
        winner.updatedAt = now
        winner.lastConfirmedAt = now
        var drafts = [ev(by, "Confirmed memory: \(winner.title)", .memoryUpserted(winner))]
        for id in supersede where id != keep {
            guard var m = state.memory[id] else { continue }
            m.status = .superseded
            m.supersededBy = keep
            m.updatedAt = now
            drafts.append(ev(by, "Superseded memory: \(m.title)", .memoryUpserted(m)))
        }
        try commit(drafts)
    }

    public func updateMemory(_ m: MemoryItem, by: Principal = .founder) throws {
        try requireFounder(by, "edit memory")
        var x = m
        x.updatedAt = now
        x.lastConfirmedAt = now
        try commit([ev(by, "Edited memory: \(m.title)", .memoryUpserted(x))])
    }

    @discardableResult
    public func recordDecision(projectID: LupyID?, title: String, decision: String, rationale: String = "", relatedTaskIDs: [LupyID] = [], by: Principal = .founder) throws -> DecisionRecord {
        let d = DecisionRecord(id: ids.next("dec"), projectID: projectID, title: title, decision: decision, rationale: rationale,
                               status: by == .founder ? .decided : .proposed, decidedBy: by, createdAt: now, relatedTaskIDs: relatedTaskIDs)
        try commit([ev(by, "Decision: \(title)", .decisionUpserted(d))])
        return d
    }

    // MARK: Approvals

    public func makeAction(kind: ActionKind, title: String, target: String, detail: String = "", projectID: LupyID? = nil,
                           taskID: LupyID? = nil, workerID: LupyID? = nil, cost: Double? = nil, reversible: Bool = false,
                           originator: Principal = .lupy, idempotencyKey: String? = nil) -> ProposedAction {
        let id = ids.next("act")
        let (cleanDetail, _) = Redactor.redact(detail)
        return ProposedAction(id: id, kind: kind, title: title, target: target, detail: TextUtil.truncate(cleanDetail, 2000),
                              projectID: projectID, taskID: taskID, workerID: workerID, idempotencyKey: idempotencyKey ?? "action:\(id.raw)",
                              estimatedCostCents: cost, reversible: reversible, originator: originator, createdAt: now)
    }

    func policyContext(for action: ProposedAction, provider: ProviderConfig? = nil, budget: BudgetVerdict? = nil) -> PolicyContext {
        PolicyContext(settings: state.settings, project: action.projectID.flatMap { state.projects[$0] },
                      standingApprovals: Array(state.standingApprovals.values), provider: provider, budgetVerdict: budget, now: now)
    }

    /// Evaluates an action. If approval is needed, an approval request is recorded for the founder.
    @discardableResult
    public func propose(_ action: ProposedAction, consequence: String = "") throws -> (PolicyDecision, ApprovalRequest?) {
        let decision = PolicyEngine.evaluate(action, context: policyContext(for: action))
        switch decision.verdict {
        case .allow:
            if let sid = decision.matchedStandingApproval, var sa = state.standingApprovals[sid] {
                sa.uses += 1
                try commit([ev(.lupy, "Used standing approval for \(action.title)", .standingApprovalUpserted(sa))])
            }
            return (decision, nil)
        case .deny:
            try commit([ev(.lupy, "Blocked: \(action.title) — \(decision.explanation)", .note(text: decision.explanation, relatedID: action.taskID))])
            return (decision, nil)
        case .requireApproval:
            let req = try requestApproval(action, reasons: decision.reasons, risk: decision.risk, consequence: consequence)
            return (decision, req)
        }
    }

    func requestApproval(_ action: ProposedAction, reasons: [String], risk: RiskLevel, consequence: String) throws -> ApprovalRequest {
        if let existing = state.approvals.values.first(where: { $0.status == .pending && $0.action.idempotencyKey == action.idempotencyKey }) {
            return existing
        }
        let req = ApprovalRequest(id: ids.next("apr"), action: action, reasons: reasons, risk: risk,
                                  consequence: consequence.isEmpty ? (action.reversible ? "Can be undone." : "May not be reversible.") : consequence,
                                  status: .pending, requestedAt: now, expiresAt: now.adding(.days(7)), decidedAt: nil, decidedBy: nil, decisionNote: nil)
        try commit([ev(.lupy, "Asked for approval: \(action.title)", .approvalUpserted(req))])
        _ = try notify("Approval needed", "\(action.title) — \(reasons.first ?? "")", severity: risk >= .high ? .urgent : .attention,
                       related: req.id, dedupe: "approval:\(req.id.raw)")
        return req
    }

    /// Founder decision. Optionally turns an approval into a narrow standing approval ("always for this").
    @discardableResult
    public func decideApproval(_ approvalID: LupyID, approve: Bool, note: String = "", standingDays: Int? = nil,
                               standingMaxUses: Int? = nil, by: Principal = .founder) throws -> [Effect] {
        try requireFounder(by, "decide approvals")
        guard var req = state.approvals[approvalID] else { throw EngineError.notFound("approval") }
        guard req.status == .pending else { throw EngineError.invalid("This approval is already \(req.status.rawValue).") }
        req.status = approve ? .approved : .denied
        req.decidedAt = now
        req.decidedBy = by
        req.decisionNote = note
        try commit([ev(by, "\(approve ? "Approved" : "Denied"): \(req.action.title)", .approvalUpserted(req))])
        if approve, let days = standingDays {
            let sa = StandingApproval(id: ids.next("sap"), kind: req.action.kind, projectID: req.action.projectID, targetPattern: req.action.target,
                                      workerID: req.action.workerID, maxUses: standingMaxUses, uses: 0, maxCostCents: req.action.estimatedCostCents.map { $0 * 1.5 },
                                      expiresAt: now.adding(.days(Int64(days))), createdAt: now, createdBy: by, revokedAt: nil,
                                      note: "From approval of “\(req.action.title)”")
            try grantStandingApproval(sa, by: by)
        }
        return try onApprovalDecided(req)
    }

    public func grantStandingApproval(_ sa: StandingApproval, by: Principal = .founder) throws {
        var x = sa
        x.createdBy = by
        if let why = PolicyEngine.validateGrant(x, now: now) { throw EngineError.notAllowed(why) }
        try commit([ev(by, "Standing approval: \(x.kind.label) → \(x.targetPattern)", .standingApprovalUpserted(x))])
    }

    public func revokeStandingApproval(_ id: LupyID, by: Principal = .founder) throws {
        try requireFounder(by, "revoke approvals")
        guard var sa = state.standingApprovals[id] else { throw EngineError.notFound("standing approval") }
        sa.revokedAt = now
        try commit([ev(by, "Revoked standing approval: \(sa.kind.label)", .standingApprovalUpserted(sa))])
    }

    // MARK: Notices

    @discardableResult
    func notify(_ title: String, _ body: String, severity: NoticeSeverity, related: LupyID?, dedupe: String) throws -> Effect? {
        let (push, _) = NotificationBudget.shouldPush(severity: severity, dedupeKey: dedupe, state: state, now: now)
        let n = Notice(id: ids.next("ntc"), title: title, body: body, severity: severity, relatedID: related, createdAt: now,
                       pushed: push, dismissed: false, dedupeKey: dedupe)
        try commit([ev(.lupy, "Notice: \(title)", .noticeUpserted(n))])
        return push ? .notify(n) : nil
    }

    public func dismissNotice(_ id: LupyID) throws {
        guard var n = state.notices[id], !n.dismissed else { return }
        n.dismissed = true
        try commit([ev(.founder, "Dismissed notice", .noticeUpserted(n))])
    }
}
