// LupyCore — task lifecycle rules and evidence-based verification.
//
// Principles (requirements §5–§7):
//  - A worker's (or model's) claim never verifies anything by itself.
//  - Ambiguous or inconclusive evidence is not treated as contradiction.
//  - Evidence observed before the task's evidence epoch (reopened/changed) is stale.
//  - Higher oversight demands more independent evidence; it never changes permissions.

public enum Lifecycle {
    public static let allowed: [TaskStatus: Set<TaskStatus>] = [
        .planned: [.ready, .waitingDependency, .inProgress, .dispatched, .waitingApproval, .waitingFounder, .paused, .cancelled, .blocked],
        .ready: [.inProgress, .dispatched, .waitingApproval, .waitingFounder, .waitingDependency, .paused, .blocked, .cancelled, .planned, .completed],
        .inProgress: [.submitted, .completed, .dispatched, .blocked, .paused, .failed, .waitingFounder, .waitingApproval, .recovering, .cancelled, .ready],
        .dispatched: [.deliveryUnconfirmed, .acknowledged, .progressEvidenced, .submitted, .failed, .recovering, .escalated, .blocked, .paused, .cancelled],
        .deliveryUnconfirmed: [.dispatched, .acknowledged, .progressEvidenced, .submitted, .failed, .recovering, .escalated, .paused, .cancelled],
        .acknowledged: [.progressEvidenced, .submitted, .failed, .recovering, .escalated, .blocked, .paused, .cancelled],
        .progressEvidenced: [.submitted, .failed, .recovering, .escalated, .blocked, .paused, .cancelled],
        .submitted: [.verifying, .verified, .accepted, .inProgress, .dispatched, .failed, .waitingFounder, .escalated, .cancelled],
        .verifying: [.verified, .accepted, .submitted, .inProgress, .dispatched, .failed, .waitingFounder, .escalated],
        .verified: [.accepted, .inProgress, .dispatched, .waitingFounder],
        .accepted: [.completed, .inProgress],
        .completed: [.inProgress, .ready],
        .waitingDependency: [.ready, .planned, .blocked, .paused, .cancelled],
        .waitingApproval: [.ready, .inProgress, .dispatched, .waitingFounder, .blocked, .cancelled],
        .waitingFounder: [.ready, .inProgress, .dispatched, .submitted, .verified, .accepted, .completed, .blocked, .paused, .cancelled],
        .blocked: [.ready, .inProgress, .recovering, .waitingFounder, .escalated, .cancelled],
        .paused: [.planned, .ready, .inProgress, .dispatched, .deliveryUnconfirmed, .acknowledged, .progressEvidenced, .submitted, .waitingDependency, .cancelled],
        .failed: [.recovering, .ready, .inProgress, .escalated, .cancelled],
        .recovering: [.ready, .inProgress, .dispatched, .failed, .escalated, .cancelled],
        .escalated: [.ready, .inProgress, .dispatched, .waitingFounder, .accepted, .cancelled],
        .cancelled: [.planned, .ready],
    ]

    public static func canTransition(_ from: TaskStatus, _ to: TaskStatus) -> Bool {
        from == to || (allowed[from]?.contains(to) ?? false)
    }

    /// Kinds where the founder's own "done" is the natural evidence (personal errands, admin).
    public static func founderSelfCompletable(_ t: LupyTask) -> Bool {
        t.owner == .founder && [.personal, .admin, .general, .learning].contains(t.kind)
    }

    /// Returns nil when the transition is allowed, else a plain-language reason.
    public static func check(_ task: LupyTask, to: TaskStatus, by: Principal, evidence: [Evidence],
                             verification: VerificationRecord?, founderOverride: Bool) -> String? {
        if !canTransition(task.status, to) {
            return "A task that is “\(task.status.label)” cannot move to “\(to.label)”."
        }
        let fresh = evidence.filter { $0.observedAt >= task.evidenceEpoch }
        switch to {
        case .verified:
            guard let v = verification, v.outcome == .verified else {
                return "Not verified: \(verification?.outcome.label ?? "no verification has run")."
            }
        case .accepted:
            if task.status == .verified { break }
            if by == .founder && founderOverride { break }
            return "Only verified work can be accepted (or you can accept it explicitly without verification)."
        case .completed:
            if task.status == .accepted { break }
            if by == .founder && founderSelfCompletable(task) { break }
            if by == .founder && founderOverride { break }
            return "This task needs verification and acceptance before it can be completed."
        case .acknowledged:
            if !fresh.contains(where: { $0.kind == .acknowledgement || $0.kind == .deliveryReceipt }) && !(by == .founder && founderOverride) {
                return "No acknowledgement has been observed from the worker."
            }
        case .progressEvidenced:
            let kinds: Set<EvidenceKind> = [.progressUpdate, .commit, .pullRequest, .artifact, .fileObservation, .ciResult, .apiResponse]
            if !fresh.contains(where: { kinds.contains($0.kind) && $0.independence != .selfReported && $0.verdict == .supports }) {
                return "No independent progress evidence yet (a progress claim is not enough)."
            }
        case .submitted:
            let kinds: Set<EvidenceKind> = [.workerClaim, .modelOutput, .artifact, .pullRequest, .commit, .founderConfirmation]
            if !fresh.contains(where: { kinds.contains($0.kind) }) && by != .founder {
                return "Nothing has been submitted yet."
            }
        case .dispatched, .deliveryUnconfirmed:
            if task.handoffID == nil { return "There is no handoff for this task." }
        default:
            break
        }
        return nil
    }
}

public enum VerificationEngine {
    public static let defaultCriterionID: LupyID = "crit_default"

    public static func criteria(for task: LupyTask) -> [AcceptanceCriterion] {
        if !task.acceptance.isEmpty { return task.acceptance }
        return [AcceptanceCriterion(id: defaultCriterionID, text: "You confirm the outcome is what you wanted",
                                    requirement: .founderConfirmation)]
    }

    public static func evaluate(task: LupyTask, evidence all: [Evidence], oversight: OversightLevel, now: Timestamp) -> VerificationRecord {
        let usable = all.filter { $0.taskID == task.id && $0.observedAt >= task.evidenceEpoch && ($0.validUntil.map { now < $0 } ?? true) }
        let staleCount = all.filter { $0.taskID == task.id && $0.observedAt < task.evidenceEpoch }.count
        var results: [CriterionResult] = []
        for c in criteria(for: task) {
            let relevant = usable.filter { $0.criterionIDs.isEmpty || $0.criterionIDs.contains(c.id) }
            results.append(evaluate(criterion: c, relevant: relevant, oversight: oversight))
        }
        let outcome: VerificationOutcome
        if results.contains(where: { $0.outcome == .contradicted }) { outcome = .contradicted }
        else if results.allSatisfy({ $0.outcome == .verified }) { outcome = .verified }
        else if results.contains(where: { $0.outcome == .ambiguous }) { outcome = .ambiguous }
        else if results.contains(where: { $0.outcome == .claimOnly }) { outcome = .claimOnly }
        else { outcome = .insufficient }
        let met = results.filter { $0.outcome == .verified }.count
        var summary = "\(met) of \(results.count) acceptance criteria verified — \(outcome.label)."
        if staleCount > 0 { summary += " \(staleCount) older piece(s) of evidence ignored as stale." }
        if oversight != .standard { summary += " Oversight: \(oversight.label)." }
        return VerificationRecord(taskID: task.id, outcome: outcome, criteria: results, summary: summary, at: now)
    }

    static func evaluate(criterion c: AcceptanceCriterion, relevant: [Evidence], oversight: OversightLevel) -> CriterionResult {
        func result(_ o: VerificationOutcome, _ why: String, _ ev: [Evidence]) -> CriterionResult {
            CriterionResult(criterionID: c.id, text: c.text, outcome: o, explanation: why, evidenceIDs: ev.map(\.id))
        }
        let claims = relevant.filter { $0.independence == .selfReported }
        switch c.requirement {
        case .founderConfirmation:
            let founder = relevant.filter { $0.independence == .founder && $0.kind == .founderConfirmation }.sorted { $0.observedAt < $1.observedAt }
            if let latest = founder.last {
                switch latest.verdict {
                case .supports: return result(.verified, "You confirmed it.", [latest])
                case .contradicts: return result(.contradicted, "You said it is not right: \(latest.summary)", [latest])
                case .inconclusive: return result(.ambiguous, "Your last review was inconclusive.", [latest])
                }
            }
            if !claims.isEmpty { return result(.claimOnly, "Claimed done, waiting for your confirmation.", claims) }
            return result(.insufficient, "Waiting for your confirmation.", [])

        case .automatedCheck(let name):
            let checks = relevant.filter { $0.kind == .automatedCheck && $0.check == name && $0.independence != .selfReported }
                .sorted { $0.observedAt < $1.observedAt }
            guard let latest = checks.last else {
                return claims.isEmpty ? result(.insufficient, "Check “\(name)” has not run.", [])
                                      : result(.claimOnly, "Claimed, but check “\(name)” has not run.", claims)
            }
            switch latest.verdict {
            case .supports: return result(.verified, "Check “\(name)” passed.", [latest])
            case .contradicts: return result(.contradicted, "Check “\(name)” failed: \(latest.summary)", [latest])
            case .inconclusive: return result(.ambiguous, "Check “\(name)” was inconclusive.", [latest])
            }

        case .independent(let kinds):
            let allowedKinds = Set(kinds)
            let independent = relevant.filter { $0.independence != .selfReported && (allowedKinds.isEmpty || allowedKinds.contains($0.kind) || $0.kind == .founderConfirmation) }
            // Judge each kind of evidence by its latest observation: a failing CI run is only
            // superseded by a later CI result, never by a different fact such as "the PR exists".
            var latestByKind: [EvidenceKind: [Evidence]] = [:]
            for kind in Set(independent.map(\.kind)) {
                let ofKind = independent.filter { $0.kind == kind }
                let maxT = ofKind.map(\.observedAt).max()!
                latestByKind[kind] = ofKind.filter { $0.observedAt == maxT }
            }
            let ordered = latestByKind.sorted { $0.key.rawValue < $1.key.rawValue }
            let contradicting = ordered.filter { $0.value.allSatisfy { $0.verdict == .contradicts } }.flatMap(\.value)
            let conflicted = ordered.filter { Set($0.value.map(\.verdict)).count > 1 }.flatMap(\.value)
            let supporting = ordered.filter { $0.value.allSatisfy { $0.verdict == .supports } }.flatMap(\.value)
            let pending = ordered.filter { $0.value.allSatisfy { $0.verdict == .inconclusive } }.flatMap(\.value)
            if let c = contradicting.max(by: { $0.observedAt < $1.observedAt }) {
                return result(.contradicted, "Independent evidence contradicts it: \(c.summary)", contradicting)
            }
            if !conflicted.isEmpty {
                return result(.ambiguous, "Independent evidence conflicts (observed at the same time).", conflicted)
            }
            if !supporting.isEmpty {
                if !pending.isEmpty {
                    return result(.insufficient, "Partly confirmed; still waiting on: \(pending.map(\.summary).joined(separator: " "))", supporting + pending)
                }
                let latestSupport = supporting.map(\.observedAt).max()!
                switch oversight {
                case .standard:
                    return result(.verified, "Independent evidence: \(supporting.map(\.summary).joined(separator: " "))", supporting)
                case .elevated:
                    // Extra checks: evidence must be newer than the latest claim (no reliance on pre-claim observations).
                    if let lcl = claims.map(\.observedAt).max(), latestSupport < lcl {
                        return result(.insufficient, "Extra checks: need evidence observed after the latest claim.", supporting)
                    }
                    return result(.verified, "Independent evidence (checked after the claim): \(supporting.map(\.summary).joined(separator: " "))", supporting)
                case .strict:
                    let distinctSources = Set(supporting.map { "\($0.source)|\($0.kind.rawValue)" })
                    if distinctSources.count >= 2 || supporting.contains(where: { $0.independence == .founder }) {
                        return result(.verified, "Strict checks: corroborated by \(distinctSources.count) independent sources.", supporting)
                    }
                    return result(.insufficient, "Strict checks: one independent source so far; a second is required.", supporting)
                }
            }
            if !pending.isEmpty { return result(.ambiguous, "Evidence is inconclusive (not treated as a failure).", pending) }
            if !claims.isEmpty { return result(.claimOnly, "Only the worker's own claim — no independent evidence yet.", claims) }
            return result(.insufficient, "No evidence yet.", [])
        }
    }
}

// MARK: - Reliability (rule-based, per worker × task kind)

public enum ReliabilityRules {
    public static let window = 20

    public static func updated(_ existing: ReliabilityRecord?, worker: LupyID, kind: TaskKind, outcome: ReliabilityOutcome, now: Timestamp) -> ReliabilityRecord {
        var r = existing ?? ReliabilityRecord(workerID: worker, taskKind: kind, recent: [], totals: [:], computed: .standard,
                                              founderOverride: nil, overrideNote: nil, explanation: "", updatedAt: now)
        r.recent.append(outcome)
        if r.recent.count > window { r.recent.removeFirst(r.recent.count - window) }
        r.totals[outcome.rawValue, default: 0] += 1
        let (level, why) = compute(r.recent, kind: kind)
        r.computed = level
        r.explanation = why
        r.updatedAt = now
        return r
    }

    public static func compute(_ recent: [ReliabilityOutcome], kind: TaskKind) -> (OversightLevel, String) {
        let contradicted = recent.filter { $0 == .claimContradicted }.count
        let unverifiable = recent.filter { $0 == .claimUnverifiable }.count
        let missed = recent.filter { $0 == .missedCheckpoint || $0 == .noResponse }.count
        let verified = recent.filter { $0 == .claimVerified }.count
        let positives: Set<ReliabilityOutcome> = [.claimVerified, .onTime, .acceptedFirstTime]
        let streak = recent.reversed().prefix(while: { positives.contains($0) }).count
        let k = kind.label.lowercased()
        var level: OversightLevel = .standard
        var reasons: [String] = []
        if contradicted >= 2 || (contradicted >= 1 && missed >= 2) {
            level = .strict
            reasons.append("\(contradicted) of the last \(recent.count) \(k) outcomes had claims contradicted by evidence")
        } else if contradicted == 1 || unverifiable >= 3 || missed >= 2 {
            level = .elevated
            if contradicted == 1 { reasons.append("1 recent \(k) claim was contradicted by evidence") }
            if unverifiable >= 3 { reasons.append("\(unverifiable) recent \(k) claims could not be verified") }
            if missed >= 2 { reasons.append("\(missed) missed checkpoints or unanswered follow-ups") }
        }
        if level > .standard && streak >= 5 {
            level = level == .strict ? .elevated : .standard
            reasons.append("then \(streak) consecutive verified/on-time results, so checks were relaxed one level")
        }
        if reasons.isEmpty {
            return (.standard, verified > 0 ? "\(verified) of the last \(recent.count) \(k) claims were verified; standard checks." : "No problems observed for \(k) tasks; standard checks.")
        }
        return (level, reasons.joined(separator: "; ") + ".")
    }
}
