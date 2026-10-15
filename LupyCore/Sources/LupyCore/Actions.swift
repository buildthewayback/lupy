// LupyCore — the action ledger: every real-world action Lupy performs is recorded as
// intended → executing → succeeded/failed, with an idempotency key (no duplicates) and a
// verification step. An action found "executing" after a crash has an UNKNOWN outcome:
// Lupy never assumes it happened or retries it blindly.

extension LupyEngine {
    /// Starts an action after the policy gate. A founder-initiated action (the founder pressed the
    /// button) counts as that action's approval; anything else needing approval is parked as a request.
    /// Returns nil when an identical action (same idempotency key) already succeeded.
    public func beginAction(_ action: ProposedAction, by: Principal = .founder) throws -> ActionRecord? {
        if let done = state.actions.values.first(where: { $0.action.idempotencyKey == action.idempotencyKey && $0.state == .succeeded }) {
            try commit([ev(.lupy, "Skipped duplicate action: \(action.title)", .note(text: "Duplicate of \(done.id.raw)", relatedID: action.taskID))])
            return nil
        }
        let decision = PolicyEngine.evaluate(action, context: policyContext(for: action))
        switch decision.verdict {
        case .deny:
            throw EngineError.notAllowed(decision.explanation)
        case .requireApproval where by != .founder:
            _ = try requestApproval(action, reasons: decision.reasons, risk: decision.risk, consequence: "")
            throw EngineError.notAllowed("Waiting for your approval: \(decision.explanation)")
        default:
            break
        }
        let rec = ActionRecord(id: ids.next("rec"), action: action, state: .executing, attempts: 1, lastError: nil, createdAt: now,
                               startedAt: now, finishedAt: nil, nextRetryAt: nil, resultSummary: nil)
        var drafts = [ev(by, "Started: \(action.title)", .actionUpserted(rec))]
        if decision.verdict == .requireApproval {
            drafts.insert(ev(by, "You approved by doing it: \(action.title)", .note(text: "Founder-initiated: \(decision.explanation)", relatedID: action.taskID)), at: 0)
        }
        try commit(drafts)
        return rec
    }

    /// Finishes an action with the result of its verification. Evidence (e.g. a file read back and
    /// fingerprinted) is attached to the related task when there is one.
    public func finishAction(_ recordID: LupyID, verified: Bool, summary: String, reference: String? = nil, contentHash: String? = nil,
                             evidenceKind: EvidenceKind = .observation) throws {
        guard var rec = state.actions[recordID] else { throw EngineError.notFound("action") }
        rec.state = verified ? .succeeded : .failed
        rec.finishedAt = now
        rec.resultSummary = summary
        if !verified { rec.lastError = ErrorInfo(category: .unknown, message: summary, at: now) }
        try commit([ev(.lupy, "\(verified ? "Verified" : "Failed"): \(rec.action.title) — \(summary)", .actionUpserted(rec))])
        if let tid = rec.action.taskID, state.tasks[tid] != nil {
            _ = try recordEvidence(taskID: tid, kind: evidenceKind, summary: summary, verdict: verified ? .supports : .contradicts,
                                   reference: reference, by: .lupy, contentHash: contentHash)
        }
    }

    /// After a crash, the founder (or a connector) settles an action whose outcome was unknown.
    public func resolveUnknownAction(_ recordID: LupyID, happened: Bool, note: String, by: Principal = .founder) throws {
        try requireFounder(by, "settle interrupted actions")
        guard var rec = state.actions[recordID], rec.state == .executing || rec.state == .outcomeUnknown else { return }
        rec.state = happened ? .succeeded : .failed
        rec.finishedAt = now
        rec.resultSummary = "Settled by you: \(note)"
        try commit([ev(by, "Settled interrupted action: \(rec.action.title) (\(happened ? "it happened" : "it did not happen"))", .actionUpserted(rec))])
    }
}
