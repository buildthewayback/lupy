// LupyCore — LupyEngine: scheduler tick and read-only queries for the UI.

public enum AttentionKind: String, Equatable, Sendable {
    case approval, contradiction, escalation, needsInput, acceptance, relay, planReview, memoryConflict, budget, recovery
}

public struct AttentionItem: Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: AttentionKind
    public var title: String
    public var detail: String
    public var relatedID: LupyID?
    public var projectID: LupyID?
    public var severity: NoticeSeverity
    public var at: Timestamp
}

public struct AttentionSummary: Equatable, Sendable {
    public var items: [AttentionItem]
    public var activeCount: Int
    public var waitingOnOthers: Int
    public var unverifiedCount: Int
    public var budget: BudgetStatus
    public var paused: Bool
    public var nextUp: [LupyID]

    public init(items: [AttentionItem], activeCount: Int, waitingOnOthers: Int, unverifiedCount: Int,
                budget: BudgetStatus, paused: Bool, nextUp: [LupyID]) {
        self.items = items; self.activeCount = activeCount; self.waitingOnOthers = waitingOnOthers
        self.unverifiedCount = unverifiedCount; self.budget = budget; self.paused = paused; self.nextUp = nextUp
    }
}

public struct DiagnosticsReport: Equatable, Sendable {
    public var lines: [String]
    public var healthy: Bool
}

extension LupyEngine {
    // MARK: Scheduler

    /// Process everything that is due. Each item is committed with its idempotency key, so a crash
    /// or restart never repeats a follow-up or notification. Returns effects for the shell.
    @discardableResult
    public func tick() throws -> [Effect] {
        var effects: [Effect] = []
        let items = Scheduler.due(state, now: now, isProcessed: { self.store.hasProcessed($0) })
        for item in items.prefix(100) {
            effects += try process(item)
        }
        return effects
    }

    func process(_ item: DueItem) throws -> [Effect] {
        let key = item.idempotencyKey
        var fx: [Effect] = []
        func mark(_ summary: String, related: LupyID? = nil) throws {
            try commit([ev(.system, summary, .note(text: summary, relatedID: related))], key: key)
        }
        func push(_ title: String, _ body: String, _ sev: NoticeSeverity, _ rel: LupyID?, _ dedupe: String) throws {
            if let e = try notify(title, body, severity: sev, related: rel, dedupe: dedupe) { fx.append(e) }
        }
        switch item {
        case .dependencyResolved(let tid):
            guard let t = state.tasks[tid] else { try mark("skip"); break }
            try commit([ev(.system, "\(t.title) is ready (dependencies done)", .taskStatusChanged(taskID: tid, from: t.status, to: .ready, note: "Dependencies done"))], key: key)
        case .dependencyCancelled(let tid, let deps):
            guard let t = state.tasks[tid] else { try mark("skip"); break }
            let names = deps.compactMap { state.tasks[$0]?.title }.joined(separator: ", ")
            try commit([ev(.system, "\(t.title) blocked: dependency cancelled", .taskStatusChanged(taskID: tid, from: t.status, to: .blocked, note: "Cancelled dependency: \(names)"))], key: key)
            try push("Task blocked", "“\(t.title)” depends on cancelled work (\(names)). Remove the dependency or cancel it.", .attention, tid, key)
        case .handoffFollowUp(let hid, let attempt):
            guard var h = state.handoffs[hid], let t = state.tasks[h.taskID] else { try mark("skip"); break }
            let w = state.workers[h.workerID]?.name ?? "the worker"
            h.followUps = attempt
            h.lastFollowUpAt = now
            h.nextFollowUpAt = Scheduler.nextFollowUp(after: attempt, from: now, policy: state.settings.followUp)
            let since = h.acknowledgedAt ?? h.sentAt ?? h.createdAt
            let hours = Int(now.since(since).hours)
            let what: String
            switch h.state {
            case .awaitingRelay: what = "You haven't confirmed pasting the brief to \(w) yet."
            case .deliveryUnconfirmed, .sent: what = "No reply from \(w) for \(hours)h — delivery is still unconfirmed."
            default: what = "No new evidence from \(w) for \(hours)h."
            }
            h.notes.append(HandoffNote(at: now, by: .lupy, text: "Follow-up #\(attempt): \(what)"))
            try commit([ev(.system, "Follow-up #\(attempt) on \(t.title)", .handoffUpserted(h))], key: key)
            if attempt >= 2, h.acknowledgedAt == nil, case .worker(let wid) = t.owner {
                try recordReliability(worker: wid, kind: t.kind, outcome: .noResponse)
            }
            try push("Follow up with \(w)?", "\(what) Task: “\(t.title)”. Lupy prepared a check-in message.", .attention, hid, "followup:\(hid.raw)")
        case .handoffEscalation(let hid):
            guard var h = state.handoffs[hid], let t = state.tasks[h.taskID] else { try mark("skip"); break }
            h.state = .stalled
            h.nextFollowUpAt = nil
            h.notes.append(HandoffNote(at: now, by: .lupy, text: "Stalled after \(h.followUps) follow-ups. Escalated to you."))
            var drafts = [ev(.system, "Handoff stalled: \(t.title)", .handoffUpserted(h))]
            if Lifecycle.canTransition(t.status, .escalated) {
                drafts.append(ev(.system, "\(t.title) escalated", .taskStatusChanged(taskID: t.id, from: t.status, to: .escalated, note: "No response after \(h.followUps) follow-ups")))
            }
            try commit(drafts, key: key)
            try push("Stalled: \(t.title)", "No usable response after \(h.followUps) follow-ups. Reassign, do it yourself, or cancel.", .urgent, t.id, key)
        case .checkpointMissed(let tid, let cid):
            guard var t = state.tasks[tid], let i = t.checkpoints.firstIndex(where: { $0.id == cid }) else { try mark("skip"); break }
            t.checkpoints[i].missedFlagged = true
            try commit([ev(.system, "Checkpoint missed: \(t.checkpoints[i].title)", .taskUpserted(t))], key: key)
            if case .worker(let wid) = t.owner { try recordReliability(worker: wid, kind: t.kind, outcome: .missedCheckpoint) }
            try push("Checkpoint missed", "“\(t.checkpoints[i].title)” for “\(t.title)” passed without an update.", .attention, tid, key)
        case .deadlineSoon(let tid):
            guard let t = state.tasks[tid] else { try mark("skip"); break }
            try mark("Deadline soon: \(t.title)", related: tid)
            try push("Due soon", "“\(t.title)” is due \(t.deadline.map { "at " + localTime($0) } ?? "soon").", .attention, tid, key)
        case .deadlinePassed(let tid):
            guard let t = state.tasks[tid] else { try mark("skip"); break }
            try mark("Deadline passed: \(t.title)", related: tid)
            try push("Overdue", "“\(t.title)” passed its deadline. Re-plan, extend, or cancel?", .attention, tid, key)
        case .stalled(let tid, let days):
            guard let t = state.tasks[tid] else { try mark("skip"); break }
            try mark("No progress on \(t.title) for \(days) days", related: tid)
            try push("No progress", "“\(t.title)” has had no progress for \(days) day(s).", .info, tid, key)
        case .approvalExpired(let aid):
            guard var a = state.approvals[aid] else { try mark("skip"); break }
            a.status = .expired
            a.decidedAt = now
            try commit([ev(.system, "Approval expired: \(a.action.title)", .approvalUpserted(a))], key: key)
        case .standingApprovalExpired(let sid):
            guard var sa = state.standingApprovals[sid] else { try mark("skip"); break }
            sa.revokedAt = now
            sa.note += " (expired)"
            try commit([ev(.system, "Standing approval expired: \(sa.kind.label)", .standingApprovalUpserted(sa))], key: key)
        case .neglectedProject(let pid, let days):
            guard let p = state.projects[pid] else { try mark("skip"); break }
            try mark("\(p.name) has had no progress for \(days) days", related: pid)
            try push("\(p.name) is drifting", "No verified progress for \(days) days. Want Lupy to propose a next step?", .info, pid, key)
        case .dailyReview:
            try mark("Daily review")
            try push("Today with Lupy", TextUtil.truncate(templateBrief(), 400), .info, nil, key)
        case .recheckCI(let tid, let attempt):
            try mark("Re-checking CI (\(attempt))", related: tid)
            let pendingCI = state.evidence(for: tid).filter { $0.kind == .ciResult && $0.verdict == .inconclusive }.last
            if githubConnected, let ref = pendingCI?.reference, let (repo, sha) = GitHubAPI.repoAndCommit(fromURL: ref),
               let spec = GitHubAPI.request(.checkRuns(repo: repo, ref: sha)) {
                let job = GitHubJob(id: ids.next("ghj"), query: .checkRuns(repo: repo, ref: sha), http: spec, taskID: tid, handoffID: state.tasks[tid]?.handoffID)
                pendingGitHubJobs[job.id] = job
                fx.append(.checkGitHub(job))
            }
        case .budgetWarning:
            let b = BudgetGuard.status(state, now: now)
            try mark("Budget warning")
            try push("Model budget", "Spent \(TextUtil.formatCents(b.spentTodayCents)) today and \(TextUtil.formatCents(b.spentMonthCents)) this month (limits \(TextUtil.formatCents(b.dailyCapCents)) / \(TextUtil.formatCents(b.monthlyCapCents))).", .attention, nil, key)
        }
        return fx
    }

    func localTime(_ t: Timestamp) -> String {
        let c = Timestamp(millis: t.millis + Int64(state.settings.utcOffsetMinutes) * 60_000).civil
        return "\(pad(c.hour, 2)):\(pad(c.minute, 2)) on \(pad(c.year, 4))-\(pad(c.month, 2))-\(pad(c.day, 2))"
    }

    /// When the shell should next call tick(): the earliest known due time, at most 15 minutes away.
    public func nextWake() -> Timestamp {
        var best = now.adding(.minutes(15))
        for h in state.handoffs.values where h.state.isOpen { if let n = h.nextFollowUpAt, n < best { best = n } }
        for t in state.tasks.values where !t.status.isTerminal {
            if let d = t.deadline {
                let soon = d.adding(Millis(-Int64(Scheduler.deadlineSoonHours * 3_600_000)))
                if soon > now && soon < best { best = soon }
                if d > now && d < best { best = d }
            }
            for c in t.checkpoints where !c.met && c.due > now && c.due < best { best = c.due }
        }
        return max(best, now.adding(.seconds(30)))
    }

    // MARK: Queries

    public func attention() -> AttentionSummary {
        var items: [AttentionItem] = []
        let s = state
        for a in s.pendingApprovals {
            items.append(AttentionItem(id: a.id.raw, kind: .approval, title: a.action.title, detail: a.reasons.joined(separator: " "),
                                       relatedID: a.id, projectID: a.action.projectID, severity: a.risk >= .high ? .urgent : .attention, at: a.requestedAt))
        }
        for p in s.plans.values where p.status == .proposed {
            items.append(AttentionItem(id: p.id.raw, kind: .planReview, title: "Review plan: \(p.summary)", detail: "\(p.draftTasks.count) step(s) · \(p.method.label)",
                                       relatedID: p.id, projectID: p.projectID, severity: .attention, at: p.createdAt))
        }
        for t in s.tasks.values {
            switch t.status {
            case .waitingFounder:
                let v = s.verifications[t.id]
                let kind: AttentionKind = v?.outcome == .contradicted ? .contradiction : .needsInput
                items.append(AttentionItem(id: t.id.raw, kind: kind, title: t.title, detail: t.statusNote, relatedID: t.id, projectID: t.projectID,
                                           severity: kind == .contradiction ? .urgent : .attention, at: t.updatedAt))
            case .escalated:
                items.append(AttentionItem(id: t.id.raw, kind: .escalation, title: t.title, detail: t.statusNote, relatedID: t.id, projectID: t.projectID, severity: .urgent, at: t.updatedAt))
            case .verified where t.requiresFounderAcceptance:
                items.append(AttentionItem(id: t.id.raw, kind: .acceptance, title: "Accept: \(t.title)", detail: s.verifications[t.id]?.summary ?? "", relatedID: t.id,
                                           projectID: t.projectID, severity: .attention, at: t.updatedAt))
            default: break
            }
        }
        for h in s.handoffs.values where h.state == .awaitingRelay {
            items.append(AttentionItem(id: h.id.raw, kind: .relay, title: "Paste handoff to \(s.workers[h.workerID]?.name ?? "worker")", detail: h.brief.objective,
                                       relatedID: h.id, projectID: s.tasks[h.taskID]?.projectID, severity: .attention, at: h.createdAt))
        }
        var seenKeys = Set<String>()
        for m in s.memory.values where m.status == .contested {
            let k = m.key ?? m.id.raw
            if seenKeys.insert(k).inserted {
                items.append(AttentionItem(id: "mem:\(k)", kind: .memoryConflict, title: "Conflicting memory: \(m.title)", detail: "Choose which version is right.",
                                           relatedID: m.id, projectID: m.scope.projectID, severity: .attention, at: m.updatedAt))
            }
        }
        let budget = BudgetGuard.status(s, now: now)
        if budget.hardStopped {
            items.append(AttentionItem(id: "budget", kind: .budget, title: "Model budget reached", detail: "Cloud model calls are stopped until the limit resets or you raise it.",
                                       relatedID: nil, projectID: nil, severity: .attention, at: now))
        }
        if let r = store.lastRecovery, !r.interruptedActions.isEmpty {
            items.append(AttentionItem(id: "recovery", kind: .recovery, title: "Check interrupted actions", detail: "\(r.interruptedActions.count) action(s) were running when Lupy stopped; their outcome is unknown.",
                                       relatedID: nil, projectID: nil, severity: .attention, at: r.at))
        }
        items.sort { a, b in a.severity != b.severity ? a.severity > b.severity : a.at < b.at }
        let open = s.tasks.values.filter { !$0.status.isTerminal }
        let ranked = PriorityEngine.rank(open.filter { $0.status.isActionable || $0.status == .planned }, state: s, now: now)
        return AttentionSummary(items: items, activeCount: open.filter { $0.status.isActionable }.count,
                                waitingOnOthers: open.filter { $0.status.isDelegationState }.count,
                                unverifiedCount: open.filter { $0.status == .submitted || $0.status == .verifying }.count,
                                budget: budget, paused: s.settings.globalPause, nextUp: ranked.prefix(5).map { $0.0.id })
    }

    public func rankedTasks(projectID: LupyID? = nil) -> [(LupyTask, PriorityAssessment)] {
        let list = state.tasks.values.filter { projectID == nil || $0.projectID == projectID! }
        return PriorityEngine.rank(Array(list), state: state, now: now)
    }

    /// Plain-language brief without any model (always available, free).
    public func templateBrief() -> String {
        let a = attention()
        var lines: [String] = []
        let top = a.nextUp.compactMap { state.tasks[$0] }.prefix(3)
        if top.isEmpty { lines.append("Nothing urgent is planned. Tell Lupy a goal to get started.") }
        else {
            lines.append("Most important now:")
            for t in top {
                let pa = PriorityEngine.assess(t, state: state, now: now)
                lines.append("• \(t.title) — \(pa.headline) [\(state.projects[t.projectID]?.name ?? "")]")
            }
        }
        if !a.items.isEmpty { lines.append("Waiting on you: \(a.items.count) (\(a.items.prefix(2).map(\.title).joined(separator: "; ")))") }
        if a.waitingOnOthers > 0 { lines.append("Delegated and in motion: \(a.waitingOnOthers).") }
        if a.unverifiedCount > 0 { lines.append("Claimed but not yet verified: \(a.unverifiedCount).") }
        lines.append("Model spend: \(TextUtil.formatCents(a.budget.spentTodayCents)) today, \(TextUtil.formatCents(a.budget.spentMonthCents)) this month.")
        if a.paused { lines.append("Lupy is paused.") }
        return lines.joined(separator: "\n")
    }

    public func activity(limit: Int = 200, projectID: LupyID? = nil) -> [LupyEvent] {
        var out: [LupyEvent] = []
        for e in store.recentEvents.reversed() {
            if case .noticeUpserted = e.payload { continue }
            if let pid = projectID {
                let rel: LupyID? = {
                    if let p = e.payload.projectID { return p }
                    switch e.payload {
                    case .taskStatusChanged(let tid, _, _, _): return state.tasks[tid]?.projectID
                    case .evidenceRecorded(let ev): return state.tasks[ev.taskID]?.projectID
                    case .handoffUpserted(let h): return state.tasks[h.taskID]?.projectID
                    default: return nil
                    }
                }()
                if rel != pid { continue }
            }
            out.append(e)
            if out.count >= limit { break }
        }
        return out
    }

    public struct SearchHit: Equatable, Sendable { public var id: LupyID; public var kind: String; public var title: String; public var projectID: LupyID? }

    /// Keyword search; with a project, results never include other projects' data.
    public func search(_ query: String, projectID: LupyID? = nil) -> [SearchHit] {
        let q = Set(TextUtil.words(query))
        guard !q.isEmpty else { return [] }
        func matches(_ text: String) -> Int { Set(TextUtil.words(text)).intersection(q).count }
        var hits: [(SearchHit, Int)] = []
        for t in state.tasks.values where projectID == nil || t.projectID == projectID! {
            let m = matches(t.title + " " + t.details); if m > 0 { hits.append((SearchHit(id: t.id, kind: "task", title: t.title, projectID: t.projectID), m)) }
        }
        for mem in state.memory.values where projectID == nil || mem.scope == .project(projectID!) || (mem.scope == .global && (state.projects[projectID!]?.shareGlobalMemory ?? true)) {
            let m = matches(mem.title + " " + mem.body); if m > 0 { hits.append((SearchHit(id: mem.id, kind: "memory", title: mem.title, projectID: mem.scope.projectID), m)) }
        }
        for d in state.decisions.values where projectID == nil || d.projectID == projectID! {
            let m = matches(d.title + " " + d.decision); if m > 0 { hits.append((SearchHit(id: d.id, kind: "decision", title: d.title, projectID: d.projectID), m)) }
        }
        return hits.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.title < $1.0.title }.prefix(50).map(\.0)
    }

    public func diagnostics(dataSizeBytes: Int? = nil) -> DiagnosticsReport {
        let s = state
        var lines: [String] = []
        var healthy = true
        lines.append("Lupy \(appVersion) · schema \(s.schema) · events \(s.lastSeq) · since last snapshot \(store.eventsSinceSnapshot)")
        if let r = store.lastRecovery {
            if r.isClean { lines.append("Last start: clean.") }
            else {
                healthy = false
                lines.append("Last start recovered: truncated \(r.truncatedBytes) bytes, skipped \(r.droppedLines) entries, \(r.interruptedActions.count) interrupted action(s).")
                lines += r.notes.map { "  · \($0)" }
            }
        }
        lines.append("Projects \(s.projects.count) · tasks \(s.tasks.count) · open handoffs \(s.openHandoffs.count) · memory \(s.memory.count) · evidence \(s.evidence.count)")
        let b = BudgetGuard.status(s, now: now)
        lines.append("Model spend: today \(TextUtil.formatCents(b.spentTodayCents)) / \(TextUtil.formatCents(b.dailyCapCents)), month \(TextUtil.formatCents(b.spentMonthCents)) / \(TextUtil.formatCents(b.monthlyCapCents))")
        let usable = ModelRouter.usable(s)
        lines.append(usable.isEmpty ? "Cloud models: none usable (offline mode)." : "Cloud models usable: " + usable.map { "\($0.0.id)/\($0.1.id)" }.joined(separator: ", "))
        for p in FailurePatterns.detect(s.usage, now: now) { healthy = false; lines.append("Recurring failure: \(p.advice)") }
        for c in s.connectors.values.sorted(by: { $0.id < $1.id }) where c.state == .error { healthy = false; lines.append("Connector \(c.name): \(c.lastError ?? "error")") }
        if s.settings.globalPause { lines.append("Paused: \(s.settings.pauseReason)") }
        if let size = dataSizeBytes { lines.append("Data on disk: \(size / 1024) KB") }
        return DiagnosticsReport(lines: lines, healthy: healthy)
    }
}
