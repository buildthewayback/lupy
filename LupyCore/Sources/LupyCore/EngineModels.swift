// LupyCore — LupyEngine: cloud model calls (prepare → shell sends → complete), providers, budget.

public enum ModelJobKind: Codable, Equatable, Sendable {
    case plan(goalID: LupyID)
    case draft(taskID: LupyID)
    case brief(dayKey: String)
    case analyzeReply(handoffID: LupyID)
    case ask(question: String, projectID: LupyID?)
    case testConnection(providerID: String)
}

public struct ModelJob: Codable, Equatable, Sendable, Identifiable {
    public var id: LupyID
    public var kind: ModelJobKind
    public var providerID: String
    public var providerKind: ProviderKind
    public var modelID: String
    public var request: LLMRequest
    public var http: HTTPRequestSpec
    public var estimatedCents: Double
    public var manifest: ContextManifest
    public var taskID: LupyID?
    public var attempt: Int
    public var excluded: [ModelRef]
    public var createdAt: Timestamp
    /// The shell must not send before this time (retry backoff).
    public var notBefore: Timestamp?
    public var routeExplanation: String
}

public enum PreparedCall: Equatable, Sendable {
    case job(ModelJob)
    case needsApproval(ApprovalRequest)
    case unavailable(String)
}

public struct ModelJobResult: Equatable, Sendable {
    public var ok: Bool
    public var message: String
    public var effects: [Effect]
    public var planID: LupyID?
    public var draftID: LupyID?
}

extension LupyEngine {
    // MARK: Preparing calls

    func prepareCall(kind: ModelJobKind, purpose: TaskClass, system: String, projectID: LupyID?, sections: [(title: String, body: String)],
                     untrusted: [(source: String, text: String)], query: String, maxOutput: Int, jsonMode: Bool, taskID: LupyID?,
                     attempt: Int = 1, excluded: [ModelRef] = [], extraMessages: [LLMMessage] = []) throws -> PreparedCall {
        guard let route = ModelRouter.route(purpose, state: state, excluding: Set(excluded)) else {
            let anyProvider = state.providers.values.contains { $0.enabled && $0.hasKey }
            return .unavailable(anyProvider ? "No approved cloud model is available for \(purpose.label.lowercased()). Approve a provider in Settings → Providers."
                                            : "No cloud model is set up. Lupy works offline; add a provider in Settings for richer help.")
        }
        let cap = min(maxOutput, state.budget.maxOutputTokensPerCall, route.model.maxOutputTokens)
        var (req, manifest) = ContextBuilder.build(purpose: purpose, system: system, projectID: projectID, sections: sections, untrusted: untrusted,
                                                   state: state, query: query, maxOutputTokens: cap, jsonMode: jsonMode)
        req.messages += extraMessages
        let estimate = CostEstimator.worstCaseCents(req, model: route.model)
        let budget = BudgetGuard.check(estimatedCents: estimate, taskID: taskID, state: state, now: now)
        let action = makeAction(kind: .modelCall, title: "Ask \(route.model.displayName) (\(route.provider.displayName)) — \(purpose.label.lowercased())",
                                target: route.ref.label, detail: manifest.plainSummary, projectID: projectID, taskID: taskID,
                                cost: estimate, reversible: true, originator: .lupy)
        let decision = PolicyEngine.evaluate(action, context: policyContext(for: action, provider: route.provider, budget: budget))
        let job = ModelJob(id: ids.next("mjb"), kind: kind, providerID: route.provider.id, providerKind: route.provider.kind, modelID: route.model.id,
                           request: req, http: ProviderAPI.buildChat(route.provider, modelID: route.model.id, request: req), estimatedCents: estimate,
                           manifest: manifest, taskID: taskID, attempt: attempt, excluded: excluded, createdAt: now, notBefore: nil,
                           routeExplanation: route.explanation)
        switch decision.verdict {
        case .allow:
            pendingModelJobs[job.id] = job
            return .job(job)
        case .deny:
            return .unavailable(decision.explanation)
        case .requireApproval:
            let req = try requestApproval(action, reasons: decision.reasons, risk: decision.risk,
                                          consequence: "Sends the context described above to \(route.provider.displayName). Estimated cost up to \(TextUtil.formatCents(estimate)).")
            parkedModelJobs[req.id] = job
            return .needsApproval(req)
        }
    }

    public func prepareModelPlan(goalID: LupyID) throws -> PreparedCall {
        guard var g = state.goals[goalID] else { throw EngineError.notFound("goal") }
        let open = state.tasks(in: g.projectID).filter { !$0.status.isTerminal }.prefix(15)
            .map { "- \($0.title) [\($0.status.label)]" }.joined(separator: "\n")
        let today = Timestamp(millis: now.millis + Int64(state.settings.utcOffsetMinutes) * 60_000).dateOnly
        let result = try prepareCall(kind: .plan(goalID: goalID), purpose: .planning, system: Prompts.planning, projectID: g.projectID,
                                     sections: [("Today (founder's local date)", today), ("Goal", g.statement), ("Existing open tasks in this project", open)],
                                     untrusted: [], query: g.statement, maxOutput: 1500, jsonMode: true, taskID: nil)
        if case .job = result {
            g.status = .planning
            g.updatedAt = now
            try commit([ev(.lupy, "Planning with a cloud model", .goalUpserted(g))])
        }
        return result
    }

    public func prepareDraft(taskID: LupyID, instructions: String = "") throws -> PreparedCall {
        let t = try task(taskID)
        let acc = VerificationEngine.criteria(for: t).map { "- \($0.text)" }.joined(separator: "\n")
        return try prepareCall(kind: .draft(taskID: taskID), purpose: .drafting, system: Prompts.drafting, projectID: t.projectID,
                               sections: [("Task", t.title), ("Details", t.details), ("Done means", acc), ("Instructions", instructions)],
                               untrusted: [], query: t.title + " " + t.details, maxOutput: 1500, jsonMode: false, taskID: taskID)
    }

    public func prepareBrief() throws -> PreparedCall {
        let key = now.dayKey(utcOffsetMinutes: state.settings.utcOffsetMinutes)
        return try prepareCall(kind: .brief(dayKey: key), purpose: .summarizing, system: Prompts.briefing, projectID: nil,
                               sections: [("Today's data", templateBrief())], untrusted: [], query: "", maxOutput: 400, jsonMode: false, taskID: nil)
    }

    public func prepareReplyAnalysis(handoffID: LupyID, text: String) throws -> PreparedCall {
        guard let h = state.handoffs[handoffID] else { throw EngineError.notFound("handoff") }
        let t = try task(h.taskID)
        return try prepareCall(kind: .analyzeReply(handoffID: handoffID), purpose: .classifying, system: Prompts.replyAnalysis, projectID: t.projectID,
                               sections: [("Delegated task", t.title), ("Acceptance criteria", h.brief.acceptance.joined(separator: "\n"))],
                               untrusted: [("reply from \(state.workers[h.workerID]?.name ?? "worker")", text)], query: t.title,
                               maxOutput: 500, jsonMode: true, taskID: t.id)
    }

    public func prepareQuestion(_ question: String, projectID: LupyID?) throws -> PreparedCall {
        try prepareCall(kind: .ask(question: TextUtil.truncate(question, 2000), projectID: projectID), purpose: .conversation, system: Prompts.identity,
                        projectID: projectID, sections: [("Question", question)], untrusted: [], query: question, maxOutput: 800, jsonMode: false, taskID: nil)
    }

    /// A tiny call to check a key works. The founder pressing "Test" consents to this one call.
    public func prepareConnectionTest(providerID: String, by: Principal = .founder) throws -> PreparedCall {
        try requireFounder(by, "test providers")
        guard let p = state.providers[providerID] else { throw EngineError.notFound("provider") }
        guard p.hasKey else { return .unavailable("Add an API key for \(p.displayName) first.") }
        guard let m = p.models.first(where: \.enabled) ?? p.models.first else { return .unavailable("Add a model for \(p.displayName) first.") }
        if state.settings.globalPause { return .unavailable("Lupy is paused.") }
        let req = LLMRequest(purpose: .classifying, messages: [LLMMessage(.user, "Reply with the single word OK.")], maxOutputTokens: 16, temperature: nil, jsonMode: false)
        let manifest = ContextManifest(purpose: .classifying, projectID: nil, includedMemoryIDs: [], excludedSensitiveCount: 0, excludedOtherProjectCount: 0,
                                       redactions: [], untrustedSources: [], injectionWarnings: [], characters: req.characterCount, truncated: false)
        let job = ModelJob(id: ids.next("mjb"), kind: .testConnection(providerID: providerID), providerID: p.id, providerKind: p.kind, modelID: m.id,
                           request: req, http: ProviderAPI.buildChat(p, modelID: m.id, request: req), estimatedCents: CostEstimator.worstCaseCents(req, model: m),
                           manifest: manifest, taskID: nil, attempt: 1, excluded: [], createdAt: now, notBefore: nil, routeExplanation: "Connection test")
        pendingModelJobs[job.id] = job
        return .job(job)
    }

    public func pendingJob(_ id: LupyID) -> ModelJob? { pendingModelJobs[id] }

    // MARK: Completing calls

    /// The shell reports the HTTP result (status 0 = network failure). Records usage exactly once.
    public func completeModelJob(_ jobID: LupyID, status: Int, headers: [String: String] = [:], body: [UInt8], latencyMillis: Int64) throws -> ModelJobResult {
        guard let job = pendingModelJobs.removeValue(forKey: jobID) else {
            return ModelJobResult(ok: false, message: "This request was already handled.", effects: [], planID: nil, draftID: nil)
        }
        let model = state.providers[job.providerID]?.models.first { $0.id == job.modelID }
        let parsed = ProviderAPI.parseChat(job.providerKind, status: status, headers: headers, body: body, modelID: job.modelID, now: now)
        switch parsed {
        case .success(let resp):
            let inTok = resp.inputTokens > 0 ? resp.inputTokens : CostEstimator.tokens(forCharacters: job.request.characterCount)
            let cost = model.map { CostEstimator.cents(inputTokens: inTok, outputTokens: resp.outputTokens, model: $0) } ?? job.estimatedCents
            let usage = UsageRecord(id: ids.next("use"), providerID: job.providerID, modelID: job.modelID, taskID: job.taskID, purpose: job.request.purpose,
                                    inputTokens: inTok, outputTokens: resp.outputTokens, costCents: cost, estimated: resp.inputTokens == 0, at: now,
                                    ok: true, errorCategory: nil, latencyMillis: latencyMillis)
            try commit([ev(.model(provider: job.providerID, model: job.modelID), "Model call \(job.modelID): \(inTok)+\(resp.outputTokens) tokens, \(TextUtil.formatCents(cost))", .usageRecorded(usage))],
                       key: "usage:\(job.id.raw)")
            return try handleSuccess(job, resp)
        case .failure(let err):
            let usage = UsageRecord(id: ids.next("use"), providerID: job.providerID, modelID: job.modelID, taskID: job.taskID, purpose: job.request.purpose,
                                    inputTokens: 0, outputTokens: 0, costCents: 0, estimated: true, at: now, ok: false, errorCategory: err.category,
                                    latencyMillis: latencyMillis)
            try commit([ev(.model(provider: job.providerID, model: job.modelID), "Model call failed: \(err.category.label)", .usageRecorded(usage))],
                       key: "usage:\(job.id.raw)")
            return try handleFailure(job, err)
        }
    }

    func handleFailure(_ job: ModelJob, _ err: ErrorInfo) throws -> ModelJobResult {
        let failedRef = ModelRef(providerID: job.providerID, modelID: job.modelID)
        if case .testConnection(let pid) = job.kind {
            return ModelJobResult(ok: false, message: "\(state.providers[pid]?.displayName ?? pid): \(err.category.label). \(err.message)", effects: [], planID: nil, draftID: nil)
        }
        let alternative = ModelRouter.route(job.request.purpose, state: state, excluding: Set(job.excluded + [failedRef])) != nil
        let decision = RetryPolicy.decide(err, attempt: job.attempt, maxRetries: state.budget.maxRetriesPerCall, hasAlternative: alternative && state.routing.allowFallback,
                                          seed: UInt64(truncatingIfNeeded: job.createdAt.millis))
        var effects: [Effect] = []
        for p in FailurePatterns.detect(state.usage, now: now) {
            if let e = try notify("Recurring model failures", p.advice, severity: .attention, related: nil, dedupe: "pattern:\(p.signature):\(now.dayKey())") { effects.append(e) }
        }
        switch decision {
        case .retry(let after, let reason):
            var next = job
            next.id = ids.next("mjb")
            next.attempt += 1
            next.notBefore = now.adding(after)
            pendingModelJobs[next.id] = next
            return ModelJobResult(ok: false, message: reason, effects: effects + [.callModel(next)], planID: nil, draftID: nil)
        case .switchRoute(let reason):
            let again = try reprepare(job, excluding: job.excluded + [failedRef])
            switch again {
            case .job(let j): return ModelJobResult(ok: false, message: reason, effects: effects + [.callModel(j)], planID: nil, draftID: nil)
            case .needsApproval: return ModelJobResult(ok: false, message: reason + " Waiting for your approval to use another provider.", effects: effects, planID: nil, draftID: nil)
            case .unavailable(let why): return try escalate(job, reason: "\(reason) \(why)", effects: effects)
            }
        case .escalate(let reason):
            return try escalate(job, reason: reason, effects: effects)
        }
    }

    func reprepare(_ job: ModelJob, excluding: [ModelRef]) throws -> PreparedCall {
        switch job.kind {
        case .plan(let gid):
            guard let g = state.goals[gid] else { return .unavailable("goal missing") }
            return try prepareCall(kind: job.kind, purpose: .planning, system: Prompts.planning, projectID: g.projectID, sections: [("Goal", g.statement)],
                                   untrusted: [], query: g.statement, maxOutput: 1500, jsonMode: true, taskID: nil, attempt: 1, excluded: excluding)
        default:
            let sys = job.request.messages.first { $0.role == .system }?.content ?? Prompts.identity
            let user = job.request.messages.filter { $0.role != .system }.map(\.content).joined(separator: "\n\n")
            return try prepareCall(kind: job.kind, purpose: job.request.purpose, system: sys, projectID: job.manifest.projectID,
                                   sections: [("Request", user)], untrusted: [], query: "", maxOutput: job.request.maxOutputTokens,
                                   jsonMode: job.request.jsonMode, taskID: job.taskID, attempt: 1, excluded: excluding)
        }
    }

    func escalate(_ job: ModelJob, reason: String, effects: [Effect]) throws -> ModelJobResult {
        var fx = effects
        switch job.kind {
        case .plan(let gid):
            let plan = try planHeuristically(goalID: gid, extraWarning: "The cloud model could not be used (\(reason)). This is an offline plan.")
            return ModelJobResult(ok: false, message: reason, effects: fx, planID: plan.id, draftID: nil)
        case .draft(let tid):
            if let t = state.tasks[tid], Lifecycle.canTransition(t.status, .escalated) {
                try transition(tid, to: .escalated, by: .lupy, note: "Drafting failed: \(reason)")
            }
            if let e = try notify("Lupy needs you", "Drafting “\(state.tasks[tid]?.title ?? "")” failed: \(reason)", severity: .attention, related: tid, dedupe: "draftfail:\(tid.raw)") { fx.append(e) }
        default:
            if let e = try notify("Model request failed", reason, severity: .attention, related: job.taskID, dedupe: "modelfail:\(job.id.raw)") { fx.append(e) }
        }
        return ModelJobResult(ok: false, message: reason, effects: fx, planID: nil, draftID: nil)
    }

    func handleSuccess(_ job: ModelJob, _ resp: LLMResponse) throws -> ModelJobResult {
        let by = Principal.model(provider: job.providerID, model: job.modelID)
        switch job.kind {
        case .plan(let gid):
            guard var g = state.goals[gid] else { return ModelJobResult(ok: false, message: "Goal no longer exists.", effects: [], planID: nil, draftID: nil) }
            let parsed: PlanDraft?
            var problem = ""
            if let json = PlanBuilder.extractJSON(resp.text) {
                do { parsed = try PlanBuilder.fromModelJSON(json, projectID: g.projectID, goalID: gid, now: now, ids: ids, source: by) }
                catch { parsed = nil; problem = "\(error)" }
            } else { parsed = nil; problem = "The answer was not JSON." }
            guard var draft = parsed else {
                if job.attempt < 2 {
                    // One bounded repair attempt with the error explained.
                    let fix = [LLMMessage(.assistant, TextUtil.truncate(resp.text, 3000)),
                               LLMMessage(.user, "That did not match the required JSON format (\(problem)). Return only the JSON object described in the instructions.")]
                    let again = try prepareCall(kind: job.kind, purpose: .planning, system: Prompts.planning, projectID: g.projectID, sections: [("Goal", g.statement)],
                                                untrusted: [], query: g.statement, maxOutput: 1500, jsonMode: true, taskID: nil, attempt: job.attempt + 1,
                                                excluded: job.excluded, extraMessages: fix)
                    if case .job(let j) = again { return ModelJobResult(ok: false, message: "Asking the model to fix its plan format.", effects: [.callModel(j)], planID: nil, draftID: nil) }
                }
                let plan = try planHeuristically(goalID: gid, extraWarning: "The model's plan was unusable (\(problem)); this is an offline plan instead.")
                return ModelJobResult(ok: false, message: "Model plan unusable; offline plan created.", effects: [], planID: plan.id, draftID: nil)
            }
            if resp.truncated { draft.warnings.insert("The model's answer was cut off; the plan may be incomplete.", at: 0) }
            let plan = try storePlan(goal: &g, draft: draft, method: .model(provider: job.providerID, model: job.modelID))
            return ModelJobResult(ok: true, message: "Plan ready for review.", effects: [], planID: plan.id, draftID: nil)

        case .draft(let tid):
            let t = try task(tid)
            let doc = DraftDocument(id: ids.next("drf"), taskID: tid, projectID: t.projectID, title: "Draft: \(t.title)", body: resp.text,
                                    source: by, createdAt: now, contentHash: SHA256Digest.hex(resp.text))
            try commit([ev(by, "Draft produced for \(t.title)", .draftUpserted(doc))])
            _ = try recordEvidence(taskID: tid, kind: .modelOutput, summary: "Model draft (\(resp.text.count) characters).", by: by, handoffID: t.handoffID,
                                   contentHash: doc.contentHash)
            // Deterministic checks by Lupy (independent of the model's own opinion).
            let nonEmpty = TextUtil.trimmed(resp.text).count >= 40
            _ = try recordEvidence(taskID: tid, kind: .automatedCheck, summary: nonEmpty ? "Draft has substantive content." : "Draft is empty or too short.",
                                   verdict: nonEmpty ? .supports : .contradicts, by: .lupy, check: "nonEmpty")
            _ = try recordEvidence(taskID: tid, kind: .automatedCheck, summary: resp.truncated ? "Draft was cut off by the output limit." : "Draft is complete (not cut off).",
                                   verdict: resp.truncated ? .contradicts : .supports, by: .lupy, check: "complete")
            if let hid = t.handoffID { try setHandoff(hid, state: .submitted, note: "Draft received from model") }
            let cur = try task(tid)
            if Lifecycle.canTransition(cur.status, .submitted) { try transition(tid, to: .submitted, by: .lupy, note: "Model draft ready for your review") }
            _ = try verify(tid)
            _ = try notify("Draft ready", "Review the draft for “\(t.title)”.", severity: .attention, related: tid, dedupe: "draft:\(doc.id.raw)")
            return ModelJobResult(ok: true, message: "Draft ready for review.", effects: [], planID: nil, draftID: doc.id)

        case .brief(let day):
            let doc = DraftDocument(id: ids.next("drf"), taskID: nil, projectID: nil, title: "Daily brief \(day)", body: resp.text, source: by,
                                    createdAt: now, contentHash: SHA256Digest.hex(resp.text))
            try commit([ev(by, "Daily brief written", .draftUpserted(doc))])
            return ModelJobResult(ok: true, message: "Brief ready.", effects: [], planID: nil, draftID: doc.id)

        case .analyzeReply(let hid):
            guard var h = state.handoffs[hid] else { return ModelJobResult(ok: false, message: "Handoff missing.", effects: [], planID: nil, draftID: nil) }
            if let json = PlanBuilder.extractJSON(resp.text) {
                let summary = json["summary"]?.stringValue ?? ""
                let blockers = (json["blockers"]?.arrayValue ?? []).compactMap(\.stringValue)
                let questions = (json["questions"]?.arrayValue ?? []).compactMap(\.stringValue)
                var note = "Model reading of the reply (not evidence): \(TextUtil.truncate(summary, 300))"
                if !blockers.isEmpty { note += " Blockers: \(blockers.prefix(3).joined(separator: "; "))." }
                if !questions.isEmpty { note += " Questions for you: \(questions.prefix(3).joined(separator: "; "))." }
                h.notes.append(HandoffNote(at: now, by: by, text: note))
                try commit([ev(by, "Reply analysed", .handoffUpserted(h))])
            }
            return ModelJobResult(ok: true, message: "Reply analysed.", effects: [], planID: nil, draftID: nil)

        case .ask(let q, let pid):
            let doc = DraftDocument(id: ids.next("drf"), taskID: nil, projectID: pid, title: "Answer: \(TextUtil.truncate(q, 80))", body: resp.text,
                                    source: by, createdAt: now, contentHash: SHA256Digest.hex(resp.text))
            try commit([ev(by, "Answered a question", .draftUpserted(doc))])
            return ModelJobResult(ok: true, message: resp.text, effects: [], planID: nil, draftID: doc.id)

        case .testConnection(let pid):
            return ModelJobResult(ok: true, message: "\(state.providers[pid]?.displayName ?? pid) works (model \(resp.modelID)).", effects: [], planID: nil, draftID: nil)
        }
    }

    /// Called after a founder decision on any approval.
    func onApprovalDecided(_ req: ApprovalRequest) throws -> [Effect] {
        if let job = parkedModelJobs.removeValue(forKey: req.id) {
            if req.status == .approved {
                // Re-check hard caps at execution time; an approval cannot override a hard budget cap.
                if case .blocked(let why) = BudgetGuard.check(estimatedCents: job.estimatedCents, taskID: job.taskID, state: state, now: now) {
                    _ = try notify("Budget limit", why, severity: .attention, related: nil, dedupe: "budgetblock:\(req.id.raw)")
                    return []
                }
                pendingModelJobs[job.id] = job
                return [.callModel(job)]
            }
            if case .plan(let gid) = job.kind {
                _ = try planHeuristically(goalID: gid, extraWarning: "You chose not to send this goal to a cloud model, so this is an offline plan.")
            }
            return []
        }
        if req.status == .approved, req.action.kind == .dispatchToWorker, let tid = req.action.taskID,
           let hid = state.tasks[tid]?.handoffID, let h = state.handoffs[hid], h.state == .drafted {
            return try dispatch(hid, by: .founder).effects
        }
        return []
    }

    // MARK: Providers and budget

    public func upsertProvider(_ p: ProviderConfig, by: Principal = .founder) throws {
        try requireFounder(by, "configure providers")
        guard p.baseURL.hasPrefix("https://") else { throw EngineError.invalid("Provider address must start with https://") }
        guard p.keychainAccount.hasPrefix("provider.") else { throw EngineError.invalid("Invalid key reference.") }
        for m in p.models where m.inputCentsPerMTok < 0 || m.outputCentsPerMTok < 0 { throw EngineError.invalid("Prices cannot be negative.") }
        try commit([ev(by, "Provider \(p.displayName) updated", .providerUpserted(p))])
    }

    /// Called by the shell after saving/removing a key in the Keychain (the key itself never comes here).
    public func setProviderKeyPresent(_ id: String, present: Bool) throws {
        guard var p = state.providers[id] else { throw EngineError.notFound("provider") }
        guard p.hasKey != present else { return }
        p.hasKey = present
        if !present { p.enabled = false }
        try commit([ev(.system, present ? "Key stored in Keychain for \(p.displayName)" : "Key removed for \(p.displayName)", .providerUpserted(p))])
    }

    /// Founder consent to send data to this provider (and enable it).
    public func approveProvider(_ id: String, approved: Bool, by: Principal = .founder) throws {
        try requireFounder(by, "approve providers")
        guard var p = state.providers[id] else { throw EngineError.notFound("provider") }
        p.founderApproved = approved
        p.enabled = approved && p.hasKey
        try commit([ev(by, approved ? "You allowed Lupy to use \(p.displayName)" : "You withdrew permission for \(p.displayName)", .providerUpserted(p))])
    }

    /// Adds models discovered via "Refresh models" (disabled by default, priced conservatively until edited).
    public func addDiscoveredModels(_ providerID: String, modelIDs: [String], by: Principal = .founder) throws {
        guard var p = state.providers[providerID] else { throw EngineError.notFound("provider") }
        let maxIn = p.models.map(\.inputCentsPerMTok).max() ?? 300
        let maxOut = p.models.map(\.outputCentsPerMTok).max() ?? 1500
        var added = 0
        for id in modelIDs.prefix(200) where !p.models.contains(where: { $0.id == id }) {
            p.models.append(ModelSpec(id: id, displayName: id, inputCentsPerMTok: maxIn, outputCentsPerMTok: maxOut, contextTokens: 128_000, maxOutputTokens: 4000, enabled: false))
            added += 1
        }
        guard added > 0 else { return }
        try commit([ev(by, "Found \(added) model(s) for \(p.displayName)", .providerUpserted(p))])
    }

    public func setRouting(_ r: RoutingPolicy, by: Principal = .founder) throws {
        try requireFounder(by, "change model routing")
        try commit([ev(by, "Model routing updated", .routingUpdated(r))])
    }

    public func setBudget(_ b: BudgetPolicy, by: Principal = .founder) throws {
        try requireFounder(by, "change budgets")
        guard b.monthlyCapCents >= 0, b.dailyCapCents >= 0, b.perTaskCapCents >= 0, b.maxOutputTokensPerCall >= 64, b.maxRetriesPerCall >= 0,
              b.maxRetriesPerCall <= 5, b.maxModelCallsPerTask >= 1 else { throw EngineError.invalid("Budget values are out of range.") }
        try commit([ev(by, "Budget: \(TextUtil.formatCents(b.dailyCapCents))/day, \(TextUtil.formatCents(b.monthlyCapCents))/month", .budgetUpdated(b))])
    }
}
