// LupyCore — LupyEngine: evidence, verification, delegation/handoffs, GitHub checks, reliability.

public struct GitHubJob: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var query: GitHubQuery
    public var http: HTTPRequestSpec
    public var taskID: LupyID
    public var handoffID: LupyID?
}

public struct DispatchResult: Equatable, Sendable {
    public var handoff: Handoff
    public var briefText: String?
    public var approval: ApprovalRequest?
    public var blockedReason: String?
    public var effects: [Effect]
}

public struct ReplyResult: Equatable, Sendable {
    public var claims: [ExtractedClaim]
    public var injectionWarnings: [String]
    public var effects: [Effect]
    public var newStatus: TaskStatus
}

extension LupyEngine {
    // MARK: Evidence

    func independence(for by: Principal, kind: EvidenceKind) -> EvidenceIndependence {
        if kind.isSelfReportByNature { return .selfReported }
        switch by {
        case .founder: return .founder
        case .connector, .system, .lupy: return .independent
        case .model, .worker: return .selfReported
        }
    }

    @discardableResult
    public func recordEvidence(taskID: LupyID, kind: EvidenceKind, summary: String, verdict: EvidenceVerdict = .supports,
                               reference: String? = nil, by: Principal, criterionIDs: [LupyID] = [], handoffID: LupyID? = nil,
                               check: String? = nil, contentHash: String? = nil) throws -> Evidence {
        _ = try task(taskID)
        let (clean, _) = Redactor.redact(summary)
        var e = Evidence(id: ids.next("evd"), taskID: taskID, kind: kind, summary: TextUtil.truncate(clean, 1000), source: by,
                         independence: independence(for: by, kind: kind), verdict: verdict, reference: reference,
                         criterionIDs: criterionIDs, observedAt: now)
        e.handoffID = handoffID
        e.check = check
        e.contentHash = contentHash
        try commit([ev(by, "Evidence (\(kind.label)): \(TextUtil.truncate(clean, 80))", .evidenceRecorded(e))])
        return e
    }

    public func oversight(for t: LupyTask) -> OversightLevel {
        guard case .worker(let wid) = t.owner else { return .standard }
        return state.reliability["\(wid.raw)|\(t.kind.rawValue)"]?.effective ?? .standard
    }

    /// Evaluates evidence and moves the task accordingly. Returns the verification record.
    @discardableResult
    public func verify(_ taskID: LupyID, by: Principal = .lupy) throws -> VerificationRecord {
        var t = try task(taskID)
        let record = VerificationEngine.evaluate(task: t, evidence: state.evidence(for: taskID), oversight: oversight(for: t), now: now)
        try commit([ev(.lupy, "Verification of \(t.title): \(record.outcome.label)", .verificationRecorded(record))])
        t = try task(taskID)
        let workerID: LupyID? = { if case .worker(let w) = t.owner { return w } else { return nil } }()
        switch record.outcome {
        case .verified:
            if t.status != .verified && Lifecycle.canTransition(t.status, .verified) {
                try transition(taskID, to: .verified, by: .lupy, note: record.summary)
                if let w = workerID, state.evidence(for: taskID).contains(where: { $0.kind == .workerClaim }) {
                    try recordReliability(worker: w, kind: t.kind, outcome: .claimVerified)
                }
                if let hid = t.handoffID { try setHandoff(hid, state: .verified, note: "Verified by evidence") }
                let tt = try task(taskID)
                if !tt.requiresFounderAcceptance && tt.priority.risk <= 1 {
                    try transition(taskID, to: .accepted, by: .lupy, note: "Low-risk work auto-accepted after verification")
                    try transition(taskID, to: .completed, by: .lupy)
                } else {
                    _ = try notify("Verified — please accept", "“\(tt.title)” is verified by evidence. Review and accept it.",
                                   severity: .attention, related: taskID, dedupe: "accept:\(taskID.raw)")
                }
            }
        case .contradicted:
            if let w = workerID, state.evidence(for: taskID).contains(where: { $0.kind == .workerClaim && $0.observedAt >= t.evidenceEpoch }) {
                try recordReliability(worker: w, kind: t.kind, outcome: .claimContradicted)
            }
            if Lifecycle.canTransition(t.status, .waitingFounder) {
                try transition(taskID, to: .waitingFounder, by: .lupy, note: "Evidence contradicts the claim — request rework, accept anyway, or cancel")
            }
            _ = try notify("Claim contradicted by evidence", "“\(t.title)”: \(record.criteria.first { $0.outcome == .contradicted }?.explanation ?? record.summary)",
                           severity: .urgent, related: taskID, dedupe: "contradicted:\(taskID.raw):\(record.at.millis / 3_600_000)")
        case .ambiguous:
            if Lifecycle.canTransition(t.status, .waitingFounder) && t.status != .waitingFounder {
                try transition(taskID, to: .waitingFounder, by: .lupy, note: "Evidence is ambiguous — your judgment needed")
            }
        case .claimOnly, .insufficient:
            if t.status == .submitted && Lifecycle.canTransition(t.status, .verifying) {
                try transition(taskID, to: .verifying, by: .lupy, note: record.summary)
            }
        }
        return record
    }

    /// Founder accepts. Without verification it is recorded as an explicit override (honest audit trail).
    public func accept(_ taskID: LupyID, withoutVerification: Bool = false, note: String = "", by: Principal = .founder) throws {
        try requireFounder(by, "accept work")
        let t = try task(taskID)
        if t.status != .verified && !withoutVerification {
            throw EngineError.notAllowed("“\(t.title)” is not verified yet. You can accept it explicitly without verification.")
        }
        try transition(taskID, to: .accepted, by: by, note: withoutVerification && t.status != .verified ? "Accepted by you WITHOUT verification\(note.isEmpty ? "" : ": \(note)")" : note,
                       founderOverride: withoutVerification)
        if case .worker(let w) = t.owner {
            let reworked = state.handoffs.values.contains { $0.taskID == taskID && $0.notes.contains { $0.text.hasPrefix("Rework requested") } }
            try recordReliability(worker: w, kind: t.kind, outcome: reworked ? .reworkRequired : .acceptedFirstTime)
        }
        if let hid = t.handoffID { try setHandoff(hid, state: .accepted, note: "Accepted", close: true) }
        try transition(taskID, to: .completed, by: by)
    }

    /// Send the work back. For delegated work Lupy prepares a rework message (you relay it).
    @discardableResult
    public func requestRework(_ taskID: LupyID, note: String, by: Principal = .founder) throws -> [Effect] {
        try requireFounder(by, "request rework")
        var t = try task(taskID)
        t.evidenceEpoch = now
        t.attempts += 1
        try commit([ev(by, "Rework requested for \(t.title)", .taskUpserted(t))])
        if let hid = t.handoffID, var h = state.handoffs[hid] {
            h.state = .reworkRequested
            h.notes.append(HandoffNote(at: now, by: by, text: "Rework requested: \(note)"))
            h.nextFollowUpAt = Scheduler.nextFollowUp(after: 0, from: now, policy: state.settings.followUp)
            try commit([ev(by, "Handoff: rework requested", .handoffUpserted(h))])
            if Lifecycle.canTransition(t.status, .dispatched) { try transition(taskID, to: .dispatched, by: by, note: "Rework requested") }
            let text = "Re: \(h.brief.reference) — rework needed on “\(t.title)”.\n\n\(note)\n\nPlease reply with evidence (links, commits, files) when done."
            return [.copyToClipboard(text)]
        }
        if Lifecycle.canTransition(t.status, .inProgress) { try transition(taskID, to: .inProgress, by: by, note: "Rework: \(note)") }
        return []
    }

    // MARK: Delegation

    @discardableResult
    public func delegate(_ taskID: LupyID, to workerID: LupyID, dueInHours: Int? = nil, checkpointInHours: Int? = 24, by: Principal = .founder) throws -> Handoff {
        var t = try task(taskID)
        guard let w = state.workers[workerID], w.enabled else { throw EngineError.notFound("worker") }
        guard !t.status.isClosedForWork else { throw EngineError.invalid("This task is already \(t.status.label.lowercased()).") }
        if let hid = t.handoffID, let h = state.handoffs[hid], h.state.isOpen { throw EngineError.invalid("This task already has an open handoff to \(state.workers[h.workerID]?.name ?? "a worker").") }
        let due = dueInHours.map { now.adding(.hours(Int64($0))) } ?? t.deadline
        let checkpoint = checkpointInHours.map { now.adding(.hours(Int64($0))) }
        let reference = "LUPY-" + String(taskID.raw.suffix(6)).uppercased()
        let brief = HandoffBriefWriter.make(task: t, project: state.projects[t.projectID], worker: w, due: due, checkpoint: checkpoint, reference: reference)
        let h = Handoff(id: ids.next("hnd"), taskID: taskID, workerID: workerID, channel: w.channel, brief: brief, state: .drafted, createdAt: now,
                        sentAt: nil, acknowledgedAt: nil, lastProgressAt: nil, submittedAt: nil, closedAt: nil, followUps: 0, lastFollowUpAt: nil,
                        nextFollowUpAt: nil, notes: [HandoffNote(at: now, by: by, text: "Handoff drafted for \(w.name)")])
        t.owner = .worker(workerID)
        t.handoffID = h.id
        if let c = checkpoint { t.checkpoints.append(Checkpoint(id: ids.next("chk"), title: "Progress update from \(w.name)", due: c)) }
        t.updatedAt = now
        try commit([ev(by, "Handoff drafted: \(t.title) → \(w.name)", .handoffUpserted(h)), ev(by, "Delegated \(t.title) to \(w.name)", .taskUpserted(t))])
        return h
    }

    /// Policy-checked dispatch. Manual relay: Lupy copies the brief; delivery stays unconfirmed until you confirm you sent it.
    public func dispatch(_ handoffID: LupyID, by: Principal = .founder) throws -> DispatchResult {
        guard var h = state.handoffs[handoffID] else { throw EngineError.notFound("handoff") }
        let t = try task(h.taskID)
        guard let w = state.workers[h.workerID] else { throw EngineError.notFound("worker") }
        let action = makeAction(kind: .dispatchToWorker, title: "Send handoff “\(t.title)” to \(w.name)", target: "worker:\(w.name)",
                                detail: h.brief.objective, projectID: t.projectID, taskID: t.id, workerID: w.id, reversible: false,
                                originator: by == .founder ? .founder : .lupy, idempotencyKey: "dispatch:\(handoffID.raw):\(h.notes.count)")
        let (decision, approval) = try propose(action, consequence: "The agent will start work based on this brief.")
        switch decision.verdict {
        case .deny:
            return DispatchResult(handoff: h, briefText: nil, approval: nil, blockedReason: decision.explanation, effects: [])
        case .requireApproval where by != .founder:
            return DispatchResult(handoff: h, briefText: nil, approval: approval, blockedReason: nil, effects: [])
        case .requireApproval:
            // The founder pressing "Send" is itself the approval for this one dispatch.
            if let a = approval, var req = state.approvals[a.id], req.status == .pending {
                req.status = .approved; req.decidedAt = now; req.decidedBy = .founder; req.decisionNote = "Approved by sending"
                try commit([ev(.founder, "Approved by sending: \(action.title)", .approvalUpserted(req))])
            }
        case .allow:
            break
        }
        let text = HandoffBriefWriter.render(h.brief, workerName: w.name, utcOffsetMinutes: state.settings.utcOffsetMinutes)
        if w.channel == .manualRelay {
            h.state = .awaitingRelay
            h.notes.append(HandoffNote(at: now, by: .lupy, text: "Brief copied for manual relay"))
            h.nextFollowUpAt = now.adding(.hours(4))
            try commit([ev(.lupy, "Handoff ready to paste into \(w.name)", .handoffUpserted(h))])
            return DispatchResult(handoff: h, briefText: text, approval: nil, blockedReason: nil, effects: [.copyToClipboard(text)])
        }
        // Cloud-model worker: Lupy itself performs the work via a drafting call.
        h.state = .sent
        h.sentAt = now
        try commit([ev(.lupy, "Handoff sent to \(w.name)", .handoffUpserted(h))])
        if Lifecycle.canTransition(t.status, .dispatched) { try transition(t.id, to: .dispatched, by: .lupy) }
        let prepared = try prepareDraft(taskID: t.id, instructions: text)
        switch prepared {
        case .job(let job): return DispatchResult(handoff: h, briefText: text, approval: nil, blockedReason: nil, effects: [.callModel(job)])
        case .needsApproval(let req): return DispatchResult(handoff: h, briefText: text, approval: req, blockedReason: nil, effects: [])
        case .unavailable(let why): return DispatchResult(handoff: h, briefText: text, approval: nil, blockedReason: why, effects: [])
        }
    }

    /// You confirm you pasted the brief. Lupy still cannot observe delivery: state = delivery unconfirmed.
    /// Lupy typed the brief into the agent's chat and sent it with the founder's approval (computer
    /// control). `observed` = the message was seen on screen afterwards: UI evidence of delivery
    /// (state `sent`), never of the work. Not observed = delivery unconfirmed, as for a manual paste.
    public func recordControlDelivery(_ handoffID: LupyID, observed: Bool, app: String, by: Principal = .founder) throws {
        try requireFounder(by, "record a delivery made with computer control")
        guard var h = state.handoffs[handoffID] else { throw EngineError.notFound("handoff") }
        guard [.drafted, .awaitingRelay, .reworkRequested, .deliveryUnconfirmed].contains(h.state) else { return }
        h.state = observed ? .sent : .deliveryUnconfirmed
        h.sentAt = h.sentAt ?? now
        h.followUps = 0
        h.nextFollowUpAt = Scheduler.nextFollowUp(after: 0, from: now, policy: state.settings.followUp)
        h.notes.append(HandoffNote(at: now, by: .lupy, text: observed
            ? "Lupy typed the brief into \(app) and sent it with your approval; the message was seen on screen afterwards (delivery observed, work not yet verified)."
            : "Lupy typed and sent the brief in \(app) with your approval, but could not see it on screen afterwards: delivery unconfirmed."))
        try commit([ev(by, observed ? "Brief delivered in \(app) (seen on screen)" : "Brief sent in \(app) (delivery unconfirmed)", .handoffUpserted(h))])
        let t = try task(h.taskID)
        if Lifecycle.canTransition(t.status, .dispatched) { try transition(t.id, to: .dispatched, by: by) }
        if !observed, let cur = state.tasks[t.id], cur.status != .deliveryUnconfirmed, Lifecycle.canTransition(cur.status, .deliveryUnconfirmed) {
            try transition(t.id, to: .deliveryUnconfirmed, by: .lupy, note: "Sent with computer control but not observed on screen")
        }
    }

    public func confirmRelayed(_ handoffID: LupyID, by: Principal = .founder) throws {
        try requireFounder(by, "confirm a manual relay")
        guard var h = state.handoffs[handoffID] else { throw EngineError.notFound("handoff") }
        guard h.state == .awaitingRelay || h.state == .drafted || h.state == .reworkRequested else { return }
        h.state = .deliveryUnconfirmed
        h.sentAt = h.sentAt ?? now
        h.followUps = 0
        h.nextFollowUpAt = Scheduler.nextFollowUp(after: 0, from: now, policy: state.settings.followUp)
        h.notes.append(HandoffNote(at: now, by: by, text: "You pasted the brief. Delivery cannot be observed by Lupy."))
        try commit([ev(by, "Brief relayed (delivery unconfirmed)", .handoffUpserted(h))])
        let t = try task(h.taskID)
        if t.status != .deliveryUnconfirmed {
            if Lifecycle.canTransition(t.status, .dispatched) { try transition(t.id, to: .dispatched, by: by) }
            try transition(t.id, to: .deliveryUnconfirmed, by: .lupy, note: "Manual relay: no delivery receipt possible")
        }
    }

    /// You paste the worker's reply. The reply itself proves a response exists (acknowledgement);
    /// anything it *claims* is recorded as a self-report and triggers independent checks.
    public func recordWorkerReply(_ handoffID: LupyID, text: String, by: Principal = .founder) throws -> ReplyResult {
        guard var h = state.handoffs[handoffID] else { throw EngineError.notFound("handoff") }
        let t0 = try task(h.taskID)
        let (clean, _) = Redactor.redact(text)
        let warnings = InjectionDetector.scan(clean).map(\.phrase)
        let claims = ClaimExtractor.extract(clean)
        let worker = Principal.worker(h.workerID)
        _ = try recordEvidence(taskID: t0.id, kind: .acknowledgement, summary: "Reply received from \(state.workers[h.workerID]?.name ?? "worker") (pasted by you).",
                               verdict: .supports, by: by == .founder ? .founder : .system, handoffID: handoffID)
        let claimText = TextUtil.truncate(clean, 900)
        _ = try recordEvidence(taskID: t0.id, kind: .workerClaim, summary: claimText, verdict: .supports, by: worker, handoffID: handoffID)
        h.acknowledgedAt = h.acknowledgedAt ?? now
        h.notes.append(HandoffNote(at: now, by: worker, text: TextUtil.truncate(clean, 600)))
        if !warnings.isEmpty {
            h.notes.append(HandoffNote(at: now, by: .lupy, text: "Warning: the reply contains instruction-like text (\(warnings.joined(separator: ", "))). Treated as data only."))
        }
        var newState: HandoffState = h.state == .reworkRequested ? .acknowledged : (h.state == .submitted ? .submitted : .acknowledged)
        if claims.contains(.completion) || claims.contains(where: { if case .pullRequest = $0 { return true }; return false }) { newState = .submitted; h.submittedAt = now }
        if claims.contains(.blocked) { h.notes.append(HandoffNote(at: now, by: .lupy, text: "Worker reports being blocked.")) }
        h.state = newState
        h.followUps = 0
        h.nextFollowUpAt = newState == .submitted ? nil : Scheduler.nextFollowUp(after: 0, from: now, policy: state.settings.followUp)
        try commit([ev(by, "Worker reply recorded", .handoffUpserted(h))])

        var t = try task(h.taskID)
        if [.dispatched, .deliveryUnconfirmed].contains(t.status) { try transition(t.id, to: .acknowledged, by: .lupy, note: "Reply observed") }
        t = try task(h.taskID)
        if claims.contains(.blocked) && Lifecycle.canTransition(t.status, .blocked) {
            try transition(t.id, to: .blocked, by: .lupy, note: "Worker says they are blocked")
        } else if newState == .submitted && Lifecycle.canTransition(t.status, .submitted) {
            try transition(t.id, to: .submitted, by: .lupy, note: "Worker claims completion — not yet verified")
        }
        var effects: [Effect] = []
        for job in try githubJobs(for: t.id, claims: claims) { effects.append(.checkGitHub(job)) }
        if effects.isEmpty && newState == .submitted {
            _ = try verify(t.id)
        }
        return ReplyResult(claims: claims, injectionWarnings: warnings, effects: effects, newStatus: try task(h.taskID).status)
    }

    func setHandoff(_ id: LupyID, state newState: HandoffState, note: String, close: Bool = false) throws {
        guard var h = state.handoffs[id] else { return }
        h.state = newState
        h.notes.append(HandoffNote(at: now, by: .lupy, text: note))
        if close { h.closedAt = now; h.nextFollowUpAt = nil }
        try commit([ev(.lupy, "Handoff: \(newState.label)", .handoffUpserted(h))])
    }

    // MARK: GitHub verification

    public var githubConnected: Bool { state.connectors["github"]?.state == .connected }

    /// Turns claims (+ the project's repository) into GitHub checks. Requires the GitHub connector.
    public func githubJobs(for taskID: LupyID, claims: [ExtractedClaim]) throws -> [GitHubJob] {
        guard githubConnected else { return [] }
        let t = try task(taskID)
        let defaultRepo = state.projects[t.projectID]?.repository
        var queries: [GitHubQuery] = []
        for c in claims {
            switch c {
            case .pullRequest(let repo, let n):
                queries.append(.pullRequest(repo: repo, number: n))
            case .branch(let name):
                if let r = defaultRepo { queries.append(.branch(repo: r, name: name)); queries.append(.pullsForBranch(repo: r, branch: name)) }
            case .commit(let sha):
                if let r = defaultRepo { queries.append(.commit(repo: r, sha: sha)); queries.append(.checkRuns(repo: r, ref: sha)) }
            default: break
            }
        }
        var jobs: [GitHubJob] = []
        for q in queries {
            guard let spec = GitHubAPI.request(q) else { continue }
            let job = GitHubJob(id: ids.next("ghj"), query: q, http: spec, taskID: taskID, handoffID: t.handoffID)
            pendingGitHubJobs[job.id] = job
            jobs.append(job)
        }
        return jobs
    }

    /// The shell reports a GitHub response. Evidence is recorded; PR heads get a CI check; then re-verify.
    public func completeGitHubJob(_ jobID: LupyID, status: Int, body: [UInt8]) throws -> [Effect] {
        guard let job = pendingGitHubJobs.removeValue(forKey: jobID) else { return [] }
        let evidence = GitHubAPI.evidence(for: job.query, status: status, body: body, taskID: job.taskID, handoffID: job.handoffID, ids: ids, now: now)
        try commit(evidence.map { ev(.connector("github"), "GitHub: \($0.summary)", .evidenceRecorded($0)) })
        var effects: [Effect] = []
        for e in evidence where e.kind == .pullRequest && e.verdict == .supports {
            if let head = e.contentHash, let spec = GitHubAPI.request(.checkRuns(repo: job.query.repo, ref: head)) {
                let next = GitHubJob(id: ids.next("ghj"), query: .checkRuns(repo: job.query.repo, ref: head), http: spec, taskID: job.taskID, handoffID: job.handoffID)
                pendingGitHubJobs[next.id] = next
                effects.append(.checkGitHub(next))
            }
        }
        if status == 401 || status == 403 {
            if var c = state.connectors["github"] {
                c.state = .error; c.lastError = "GitHub rejected the token (HTTP \(status))."; c.lastCheckedAt = now
                try commit([ev(.connector("github"), "GitHub token rejected", .connectorUpdated(c))])
            }
        }
        if effects.isEmpty && pendingGitHubJobs.values.allSatisfy({ $0.taskID != job.taskID }) {
            let t = try task(job.taskID)
            if [.submitted, .verifying, .acknowledged, .progressEvidenced, .deliveryUnconfirmed, .dispatched, .waitingFounder].contains(t.status) {
                if evidence.contains(where: { $0.verdict == .supports && [.commit, .pullRequest].contains($0.kind) }),
                   [.acknowledged, .deliveryUnconfirmed, .dispatched].contains(t.status), Lifecycle.canTransition(t.status, .progressEvidenced) {
                    try transition(t.id, to: .progressEvidenced, by: .lupy, note: "Independent progress seen on GitHub")
                }
                if [.submitted, .verifying, .waitingFounder].contains(try task(job.taskID).status) { _ = try verify(job.taskID) }
            }
        }
        return effects
    }

    public func setGitHubConnected(_ connected: Bool, error: String? = nil, by: Principal = .founder) throws {
        guard var c = state.connectors["github"] else { return }
        c.state = connected ? .connected : (error == nil ? .notConnected : .error)
        c.lastError = error
        c.lastCheckedAt = now
        try commit([ev(by, connected ? "GitHub connected" : "GitHub disconnected", .connectorUpdated(c))])
    }

    // MARK: Reliability

    func recordReliability(worker: LupyID, kind: TaskKind, outcome: ReliabilityOutcome) throws {
        let key = "\(worker.raw)|\(kind.rawValue)"
        let before = state.reliability[key]
        let rec = ReliabilityRules.updated(before, worker: worker, kind: kind, outcome: outcome, now: now)
        try commit([ev(.lupy, "Reliability (\(state.workers[worker]?.name ?? worker.raw), \(kind.label)): \(outcome.rawValue) → \(rec.effective.label)", .reliabilityUpdated(rec))])
        if let b = before, b.effective != rec.effective {
            _ = try notify("Oversight changed for \(state.workers[worker]?.name ?? "a worker")", "\(kind.label) tasks: \(rec.effective.label). Why: \(rec.explanation)",
                           severity: .info, related: worker, dedupe: "oversight:\(key):\(rec.effective.rawValue)")
        }
    }

    /// Founder correction of Lupy's oversight level for a worker and task kind.
    public func overrideOversight(worker: LupyID, kind: TaskKind, level: OversightLevel?, note: String, by: Principal = .founder) throws {
        try requireFounder(by, "change oversight levels")
        let key = "\(worker.raw)|\(kind.rawValue)"
        var rec = state.reliability[key] ?? ReliabilityRecord(workerID: worker, taskKind: kind, recent: [], totals: [:], computed: .standard,
                                                              founderOverride: nil, overrideNote: nil, explanation: "No history yet.", updatedAt: now)
        rec.founderOverride = level
        rec.overrideNote = note
        rec.updatedAt = now
        try commit([ev(by, "Oversight override: \(level?.label ?? "automatic")", .reliabilityUpdated(rec))])
    }
}
