// LupyCore — bounded, deterministic scheduling. Pure function of (state, now): no timers here.
// The shell calls `LupyEngine.tick()` on a single low-frequency timer (and on wake/foreground).
// Every due item carries an idempotency key so a restart never repeats a follow-up or notification.

public enum DueItem: Equatable, Sendable {
    case dependencyResolved(taskID: LupyID)
    case dependencyCancelled(taskID: LupyID, deps: [LupyID])
    case handoffFollowUp(handoffID: LupyID, attempt: Int)
    case handoffEscalation(handoffID: LupyID)
    case checkpointMissed(taskID: LupyID, checkpointID: LupyID)
    case deadlineSoon(taskID: LupyID)
    case deadlinePassed(taskID: LupyID)
    case stalled(taskID: LupyID, days: Int)
    case approvalExpired(approvalID: LupyID)
    case standingApprovalExpired(approvalID: LupyID)
    case neglectedProject(projectID: LupyID, days: Int)
    case dailyReview(dayKey: String)
    case budgetWarning(monthKey: String)
    case recheckCI(taskID: LupyID, attempt: Int)

    public var idempotencyKey: String {
        switch self {
        case .dependencyResolved(let t): return "dep-ready:\(t.raw)"
        case .dependencyCancelled(let t, let d): return "dep-cancelled:\(t.raw):\(d.map(\.raw).joined(separator: ","))"
        case .handoffFollowUp(let h, let a): return "followup:\(h.raw):\(a)"
        case .handoffEscalation(let h): return "handoff-escalate:\(h.raw)"
        case .checkpointMissed(let t, let c): return "checkpoint:\(t.raw):\(c.raw)"
        case .deadlineSoon(let t): return "deadline-soon:\(t.raw)"
        case .deadlinePassed(let t): return "deadline-passed:\(t.raw)"
        case .stalled(let t, let d): return "stalled:\(t.raw):\(d / 7)"
        case .approvalExpired(let a): return "approval-expired:\(a.raw)"
        case .standingApprovalExpired(let a): return "standing-expired:\(a.raw)"
        case .neglectedProject(let p, let d): return "neglected:\(p.raw):\(d / 7)"
        case .dailyReview(let k): return "daily-review:\(k)"
        case .budgetWarning(let m): return "budget-warn:\(m)"
        case .recheckCI(let t, let a): return "recheck-ci:\(t.raw):\(a)"
        }
    }
}

public enum Scheduler {
    public static let deadlineSoonHours: Double = 24

    public static func due(_ s: LupyState, now: Timestamp, isProcessed: (String) -> Bool) -> [DueItem] {
        var out: [DueItem] = []
        func add(_ i: DueItem) { if !isProcessed(i.idempotencyKey) { out.append(i) } }
        let policy = s.settings.followUp

        for t in s.tasks.values.sorted(by: { $0.id < $1.id }) {
            if t.status == .planned || t.status == .waitingDependency {
                switch DependencyGraph.readiness(of: t, in: s.tasks) {
                case .ready: add(.dependencyResolved(taskID: t.id))
                case .blockedByCancelled(let deps): add(.dependencyCancelled(taskID: t.id, deps: deps))
                case .waiting: break
                }
            }
            if t.status.isTerminal || t.status == .paused { continue }
            for c in t.checkpoints where !c.met && !c.missedFlagged && c.due < now {
                add(.checkpointMissed(taskID: t.id, checkpointID: c.id))
            }
            if let d = t.deadline, !t.status.isClosedForWork {
                if d < now { add(.deadlinePassed(taskID: t.id)) }
                else if d.since(now).hours <= deadlineSoonHours { add(.deadlineSoon(taskID: t.id)) }
            }
            let watched: Set<TaskStatus> = [.inProgress, .dispatched, .deliveryUnconfirmed, .acknowledged, .progressEvidenced]
            if watched.contains(t.status) {
                let idle = now.since(t.lastProgressAt ?? t.startedAt ?? t.updatedAt)
                if idle.hours >= Double(policy.stallAfterHoursWithoutProgress) {
                    add(.stalled(taskID: t.id, days: Int(idle.hours / 24)))
                }
            }
        }

        // Pending CI checks are re-polled (bounded) instead of bothering the founder.
        for t in s.tasks.values.sorted(by: { $0.id < $1.id }) where t.status == .submitted || t.status == .verifying {
            let ci = s.evidence.values.filter { $0.taskID == t.id && $0.kind == .ciResult && $0.observedAt >= t.evidenceEpoch }
                .sorted { $0.observedAt < $1.observedAt }
            guard let last = ci.last, last.verdict == .inconclusive, ci.count < 8, now.since(last.observedAt) >= .minutes(10) else { continue }
            add(.recheckCI(taskID: t.id, attempt: ci.count))
        }

        for h in s.handoffs.values.sorted(by: { $0.id < $1.id }) where h.state.isOpen {
            let waitingStates: Set<HandoffState> = [.sent, .deliveryUnconfirmed, .acknowledged, .progressEvidenced, .awaitingRelay, .reworkRequested]
            guard waitingStates.contains(h.state), let next = h.nextFollowUpAt, next <= now else { continue }
            if h.followUps >= policy.maxFollowUpsBeforeEscalation { add(.handoffEscalation(handoffID: h.id)) }
            else { add(.handoffFollowUp(handoffID: h.id, attempt: h.followUps + 1)) }
        }

        for a in s.approvals.values.sorted(by: { $0.id < $1.id }) where a.status == .pending {
            if let e = a.expiresAt, e <= now { add(.approvalExpired(approvalID: a.id)) }
        }
        for sa in s.standingApprovals.values.sorted(by: { $0.id < $1.id }) where sa.revokedAt == nil && sa.expiresAt <= now {
            add(.standingApprovalExpired(approvalID: sa.id))
        }
        for p in s.projects.values.sorted(by: { $0.id < $1.id }) where p.status == .active {
            let open = s.tasks.values.contains { $0.projectID == p.id && !$0.status.isTerminal }
            guard open else { continue }
            let last = p.lastProgressAt ?? p.createdAt
            let days = Int(now.since(last).hours / 24)
            if days >= p.weights.neglectAfterDays { add(.neglectedProject(projectID: p.id, days: days)) }
        }
        let off = s.settings.utcOffsetMinutes
        let localMinute = Int(((now.millis + Int64(off) * 60_000) % 86_400_000 + 86_400_000) % 86_400_000 / 60_000)
        if localMinute >= s.settings.dailyReviewMinute { add(.dailyReview(dayKey: now.dayKey(utcOffsetMinutes: off))) }
        let b = BudgetGuard.status(s, now: now)
        if b.warn { add(.budgetWarning(monthKey: now.monthKey(utcOffsetMinutes: off))) }
        return out
    }

    /// Exponential backoff for follow-ups, capped.
    public static func nextFollowUp(after attempt: Int, from: Timestamp, policy: FollowUpPolicy) -> Timestamp {
        var minutes = Double(policy.firstCheckAfterMinutes)
        for _ in 0..<max(0, attempt) { minutes *= policy.backoffFactor }
        minutes = min(minutes, Double(policy.maxIntervalMinutes))
        return from.adding(.minutes(Int64(minutes)))
    }

    /// Minute of the local day for quiet-hours checks.
    public static func localMinute(_ now: Timestamp, offset: Int) -> Int {
        Int(((now.millis + Int64(offset) * 60_000) % 86_400_000 + 86_400_000) % 86_400_000 / 60_000)
    }
}

/// Decides whether a notice becomes a system notification or stays inside Lupy (no spam).
public enum NotificationBudget {
    public static func shouldPush(severity: NoticeSeverity, dedupeKey: String, state: LupyState, now: Timestamp) -> (Bool, String) {
        let recent = state.notices.values.filter { $0.pushed && now.since($0.createdAt) < .hours(1) }
        if state.notices.values.contains(where: { $0.dedupeKey == dedupeKey && $0.pushed && now.since($0.createdAt) < .hours(6) }) {
            return (false, "Already notified about this in the last 6 hours.")
        }
        let minute = Scheduler.localMinute(now, offset: state.settings.utcOffsetMinutes)
        if state.settings.quietHours.contains(minuteOfDay: minute) && severity < .urgent {
            return (false, "Quiet hours — kept inside Lupy.")
        }
        if severity == .info { return (false, "Informational — shown inside Lupy only.") }
        if recent.count >= state.settings.maxNotificationsPerHour && severity < .urgent {
            return (false, "Notification budget reached (\(state.settings.maxNotificationsPerHour)/hour).")
        }
        return (true, "")
    }
}
