// Verification, lifecycle, reliability, planning, priority, scheduling and retry tests.

func ev(_ kind: EvidenceKind, _ verdict: EvidenceVerdict = .supports, by: Principal, at: Timestamp = T0, criteria: [LupyID] = [],
        indep: EvidenceIndependence? = nil, task: LupyID = "tsk_1", check: String? = nil) -> Evidence {
    let i: EvidenceIndependence = indep ?? {
        switch by { case .founder: return .founder; case .worker, .model: return .selfReported; default: return .independent }
    }()
    var e = Evidence(id: LupyID("evd_\(kind.rawValue)_\(at.millis)_\(verdict.rawValue)"), taskID: task, kind: kind, summary: "\(kind.label) \(verdict.rawValue)",
                     source: by, independence: i, verdict: verdict, criterionIDs: criteria, observedAt: at)
    e.check = check
    return e
}

func codingTask() -> LupyTask {
    var t = LupyTask(id: "tsk_1", projectID: "prj_1", title: "Add login", kind: .coding, owner: .worker("wrk_arena"), status: .submitted, createdAt: T0)
    t.acceptance = [AcceptanceCriterion(id: "crt_1", text: "PR merged with passing CI", requirement: .independent([.pullRequest, .ciResult]))]
    t.evidenceEpoch = T0
    t.handoffID = "hnd_1"
    return t
}

func workSuite() -> TestSuite {
    TestSuite(name: "Work", cases: [
        TestCase("a worker's claim alone never verifies") { t in
            let task = codingTask()
            let r = VerificationEngine.evaluate(task: task, evidence: [ev(.workerClaim, by: .worker("wrk_arena"))], oversight: .standard, now: T0)
            t.equal(r.outcome, .claimOnly)
            // Even if someone records a claim as "independent", the model forces it to self-reported.
            let forged = Evidence(id: "evd_x", taskID: "tsk_1", kind: .workerClaim, summary: "done", source: .connector("github"),
                                  independence: .independent, observedAt: T0)
            t.equal(forged.independence, .selfReported)
            t.equal(VerificationEngine.evaluate(task: task, evidence: [forged], oversight: .standard, now: T0).outcome, .claimOnly)
        },
        TestCase("independent supporting evidence verifies; newer contradiction wins; ties are ambiguous") { t in
            let task = codingTask()
            let ok = ev(.pullRequest, by: .connector("github"), at: T0.adding(.minutes(5)))
            t.equal(VerificationEngine.evaluate(task: task, evidence: [ev(.workerClaim, by: .worker("w")), ok], oversight: .standard, now: T0).outcome, .verified)
            let fail = ev(.ciResult, .contradicts, by: .connector("github"), at: T0.adding(.minutes(10)))
            t.equal(VerificationEngine.evaluate(task: task, evidence: [ok, fail], oversight: .standard, now: T0).outcome, .contradicted)
            let laterOK = ev(.ciResult, by: .connector("github"), at: T0.adding(.minutes(20)))
            t.equal(VerificationEngine.evaluate(task: task, evidence: [ok, fail, laterOK], oversight: .standard, now: T0).outcome, .verified)
            let tie = ev(.ciResult, .contradicts, by: .connector("github"), at: T0.adding(.minutes(20)))
            t.equal(VerificationEngine.evaluate(task: task, evidence: [laterOK, tie], oversight: .standard, now: T0).outcome, .ambiguous)
        },
        TestCase("inconclusive evidence is ambiguous, not contradiction; stale evidence is ignored") { t in
            var task = codingTask()
            t.equal(VerificationEngine.evaluate(task: task, evidence: [ev(.ciResult, .inconclusive, by: .connector("github"))], oversight: .standard, now: T0).outcome, .ambiguous)
            task.evidenceEpoch = T0.adding(.hours(1))
            let r = VerificationEngine.evaluate(task: task, evidence: [ev(.pullRequest, by: .connector("github"))], oversight: .standard, now: T0.adding(.hours(2)))
            t.equal(r.outcome, .insufficient)
            t.expect(r.summary.contains("stale"))
        },
        TestCase("elevated and strict oversight demand fresher / corroborated evidence") { t in
            let task = codingTask()
            let early = ev(.pullRequest, by: .connector("github"), at: T0)
            let claim = ev(.workerClaim, by: .worker("w"), at: T0.adding(.minutes(30)))
            t.equal(VerificationEngine.evaluate(task: task, evidence: [early, claim], oversight: .standard, now: T0).outcome, .verified)
            t.equal(VerificationEngine.evaluate(task: task, evidence: [early, claim], oversight: .elevated, now: T0).outcome, .insufficient)
            let one = ev(.pullRequest, by: .connector("github"), at: T0.adding(.hours(1)))
            t.equal(VerificationEngine.evaluate(task: task, evidence: [one], oversight: .strict, now: T0).outcome, .insufficient)
            let two = ev(.ciResult, by: .connector("github"), at: T0.adding(.hours(1)))
            t.equal(VerificationEngine.evaluate(task: task, evidence: [one, two], oversight: .strict, now: T0).outcome, .verified)
        },
        TestCase("founder confirmation criteria and automated checks") { t in
            var task = LupyTask(id: "tsk_1", projectID: "prj_1", title: "Write post", kind: .writing, createdAt: T0)
            task.acceptance = [AcceptanceCriterion(id: "c1", text: "You approve", requirement: .founderConfirmation),
                               AcceptanceCriterion(id: "c2", text: "Not empty", requirement: .automatedCheck("nonEmpty"))]
            t.equal(VerificationEngine.evaluate(task: task, evidence: [ev(.modelOutput, by: .model(provider: "o", model: "m"))], oversight: .standard, now: T0).outcome, .claimOnly)
            let check = ev(.automatedCheck, by: .lupy, check: "nonEmpty")
            let founderYes = ev(.founderConfirmation, by: .founder, at: T0.adding(.minutes(1)))
            t.equal(VerificationEngine.evaluate(task: task, evidence: [check, founderYes], oversight: .standard, now: T0).outcome, .verified)
            let founderNo = ev(.founderConfirmation, .contradicts, by: .founder, at: T0.adding(.minutes(2)))
            t.equal(VerificationEngine.evaluate(task: task, evidence: [check, founderYes, founderNo], oversight: .standard, now: T0).outcome, .contradicted)
        },
        TestCase("lifecycle guards: no verified without evidence, no completed without acceptance") { t in
            var task = codingTask()
            t.notNil(Lifecycle.check(task, to: .verified, by: .lupy, evidence: [], verification: nil, founderOverride: false))
            t.notNil(Lifecycle.check(task, to: .completed, by: .lupy, evidence: [], verification: nil, founderOverride: false))
            t.notNil(Lifecycle.check(task, to: .accepted, by: .founder, evidence: [], verification: nil, founderOverride: false))
            t.expect(Lifecycle.check(task, to: .accepted, by: .founder, evidence: [], verification: nil, founderOverride: true) == nil, "explicit founder override")
            t.notNil(Lifecycle.check(task, to: .accepted, by: .lupy, evidence: [], verification: nil, founderOverride: true), "override is founder-only")
            task.status = .deliveryUnconfirmed
            t.notNil(Lifecycle.check(task, to: .acknowledged, by: .lupy, evidence: [], verification: nil, founderOverride: false))
            t.expect(Lifecycle.check(task, to: .acknowledged, by: .lupy, evidence: [ev(.acknowledgement, by: .founder)], verification: nil, founderOverride: false) == nil)
            t.notNil(Lifecycle.check(task, to: .progressEvidenced, by: .lupy, evidence: [ev(.progressUpdate, by: .worker("w"))], verification: nil, founderOverride: false),
                     "a progress claim is not progress evidence")
            var errand = LupyTask(id: "tsk_2", projectID: "prj_1", title: "Renew passport", kind: .personal, owner: .founder, status: .ready, createdAt: T0)
            t.expect(Lifecycle.check(errand, to: .completed, by: .founder, evidence: [], verification: nil, founderOverride: false) == nil)
            errand.kind = .coding
            t.notNil(Lifecycle.check(errand, to: .completed, by: .founder, evidence: [], verification: nil, founderOverride: false))
            t.expect(!Lifecycle.canTransition(.planned, .verified))
            t.expect(!Lifecycle.canTransition(.completed, .verified))
        },
        TestCase("reliability is per worker × task kind, explained, and decays with good results") { t in
            var r: ReliabilityRecord? = nil
            r = ReliabilityRules.updated(r, worker: "wrk_arena", kind: .coding, outcome: .claimVerified, now: T0)
            t.equal(r!.effective, .standard)
            r = ReliabilityRules.updated(r, worker: "wrk_arena", kind: .coding, outcome: .claimContradicted, now: T0)
            t.equal(r!.effective, .elevated)
            r = ReliabilityRules.updated(r, worker: "wrk_arena", kind: .coding, outcome: .claimContradicted, now: T0)
            t.equal(r!.effective, .strict)
            t.expect(r!.explanation.contains("contradicted"), r!.explanation)
            for _ in 0..<5 { r = ReliabilityRules.updated(r, worker: "wrk_arena", kind: .coding, outcome: .claimVerified, now: T0) }
            t.equal(r!.effective, .elevated, "5 good results relax one level")
            r!.founderOverride = .standard
            t.equal(r!.effective, .standard, "founder can correct")
            let writing = ReliabilityRules.updated(nil, worker: "wrk_arena", kind: .writing, outcome: .claimVerified, now: T0)
            t.equal(writing.effective, .standard, "writing reliability is independent of coding")
        },
        TestCase("model plan JSON is validated: unknown deps, cycles, empty titles, caps, defaults") { t in
            let json = try JSONParser.parse("""
            {"summary":"Ship landing page","tasks":[
              {"key":"a","title":"Write copy","kind":"writing","dependsOn":["c"],"acceptance":["Founder approves copy"],"urgency":9,"confidence":3},
              {"key":"b","title":"Build page","kind":"coding","dependsOn":["a","zzz"]},
              {"key":"c","title":"Pick domain","dependsOn":["b"],"deadline":"2026-10-20"},
              {"key":"d","title":"   "}
            ],"risks":["Domain taken"],"questions":["Budget?"]}
            """)
            let d = try PlanBuilder.fromModelJSON(json, projectID: "prj_1", goalID: "gol_1", now: T0, ids: SequentialIDGenerator(), source: .lupy)
            t.equal(d.tasks.count, 3)
            t.equal(d.tasks[0].priority.urgency, 5, "clamped")
            t.equal(d.tasks[0].priority.confidence, 1, "clamped")
            t.expect(d.warnings.contains { $0.contains("unknown step “zzz”") })
            t.expect(d.warnings.contains { $0.contains("circular") })
            t.expect(DependencyGraph.cycleMembers(d.tasks).isEmpty, "cycles removed")
            t.expect(d.warnings.contains { $0.contains("no title") })
            t.equal(d.tasks[1].acceptance.first?.requirement, .founderConfirmation, "default criterion added")
            t.equal(d.tasks[2].deadline, Timestamp(year: 2026, month: 10, day: 20))
            t.equal(d.risks, ["Domain taken"])
            t.throwsError { _ = try PlanBuilder.fromModelJSON(["tasks": []], projectID: "p", goalID: "g", now: T0, ids: SequentialIDGenerator(), source: .lupy) }
            t.notNil(PlanBuilder.extractJSON("Sure! Here is the plan:\n```json\n{\"tasks\":[{\"title\":\"x\"}]}\n```"))
        },
        TestCase("heuristic planner splits steps, guesses kinds, finds deadlines and income signals") { t in
            let goal = "Invoice the ACME client by Friday\n- draft the invoice\n- email it to the client\n- follow up next week"
            let d = HeuristicPlanner.plan(goal: goal, projectID: "prj_1", goalID: "gol_1", now: T0, utcOffsetMinutes: 330, ids: SequentialIDGenerator())
            t.equal(d.tasks.count, 4)
            t.equal(d.tasks[2].kind, .communication)
            t.expect(d.tasks[2].statusNote.contains("approval"))
            t.equal(d.tasks[1].dependsOn, [d.tasks[0].id])
            t.equal(d.tasks[0].priority.income, 4)
            t.notNil(d.tasks[0].deadline)
            t.equal(HeuristicPlanner.steps("design poster then upload to Displate; announce on Instagram").count, 3)
        },
        TestCase("deadline phrases resolve in the founder's local time zone") { t in
            // 2026-10-15 is a Thursday; T0 = 09:00Z = 14:30 in Sri Lanka (UTC+5:30).
            let eod = DeadlineParser.parse("today", now: T0, utcOffsetMinutes: 330)!
            t.equal(eod, Timestamp(year: 2026, month: 10, day: 15, hour: 18, minute: 29), "23:59 local = 18:29Z")
            t.equal(DeadlineParser.parse("by Friday", now: T0, utcOffsetMinutes: 330), Timestamp(year: 2026, month: 10, day: 16, hour: 18, minute: 29))
            t.equal(DeadlineParser.parse("in 3 hours", now: T0, utcOffsetMinutes: 330), T0.adding(.hours(3)))
            t.equal(DeadlineParser.parse("in two days", now: T0, utcOffsetMinutes: 330), Timestamp(year: 2026, month: 10, day: 17, hour: 18, minute: 29))
            t.equal(DeadlineParser.parse("due 20 Oct", now: T0, utcOffsetMinutes: 0), Timestamp(year: 2026, month: 10, day: 20, hour: 23, minute: 59))
            t.equal(DeadlineParser.parse("March 3", now: T0, utcOffsetMinutes: 0), Timestamp(year: 2027, month: 3, day: 3, hour: 23, minute: 59), "past month → next year")
            t.equal(DeadlineParser.parse("end of month", now: T0, utcOffsetMinutes: 0), Timestamp(year: 2026, month: 10, day: 31, hour: 23, minute: 59))
            t.expect(DeadlineParser.parse("someday maybe", now: T0, utcOffsetMinutes: 0) == nil)
        },
        TestCase("dependency readiness and unblock counts") { t in
            var a = LupyTask(id: "a", projectID: "p", title: "A", status: .inProgress, createdAt: T0)
            let b = LupyTask(id: "b", projectID: "p", title: "B", status: .waitingDependency, dependsOn: ["a"], createdAt: T0)
            let c = LupyTask(id: "c", projectID: "p", title: "C", status: .waitingDependency, dependsOn: ["b"], createdAt: T0)
            var map: [LupyID: LupyTask] = ["a": a, "b": b, "c": c]
            t.equal(DependencyGraph.readiness(of: b, in: map), .waiting(["a"]))
            t.equal(DependencyGraph.unblockCount("a", in: map), 2)
            a.status = .completed; map["a"] = a
            t.equal(DependencyGraph.readiness(of: b, in: map), .ready)
            a.status = .cancelled; map["a"] = a
            t.equal(DependencyGraph.readiness(of: b, in: map), .blockedByCancelled(["a"]))
            t.equal(DependencyGraph.topologicalOrder([c, b, a]).map(\.id), ["a", "b", "c"])
        },
        TestCase("priority is explainable: deadline, income weight, pins and unblocking matter") { t in
            var s = LupyState()
            s.projects["inc"] = Project(id: "inc", name: "Urgent income", weights: ProjectWeights(importance: 1.4, income: 1.8), createdAt: T0)
            s.projects["art"] = Project(id: "art", name: "Art", createdAt: T0)
            var invoice = LupyTask(id: "t1", projectID: "inc", title: "Send invoice", status: .ready, createdAt: T0)
            invoice.priority = PriorityInputs(urgency: 2, consequence: 3, value: 2, income: 5)
            invoice.deadline = T0.adding(.hours(10))
            let sketch = LupyTask(id: "t2", projectID: "art", title: "Sketch idea", status: .ready, createdAt: T0)
            s.tasks = ["t1": invoice, "t2": sketch]
            let ranked = PriorityEngine.rank(Array(s.tasks.values), state: s, now: T0)
            t.equal(ranked.first?.0.id, "t1")
            let a = PriorityEngine.assess(invoice, state: s, now: T0)
            t.expect(a.explanation.contains("Income") && a.explanation.contains("due within 24h"), a.explanation)
            var pinned = sketch; pinned.pin = 1; s.tasks["t2"] = pinned
            t.equal(PriorityEngine.rank(Array(s.tasks.values), state: s, now: T0).first?.0.id, "t2", "founder pin wins")
        },
        TestCase("scheduler: follow-ups back off, escalate after the limit, and respect idempotency keys") { t in
            var s = LupyState()
            var p = FollowUpPolicy(); p.firstCheckAfterMinutes = 60; p.maxFollowUpsBeforeEscalation = 2
            s.settings.followUp = p
            t.equal(Scheduler.nextFollowUp(after: 0, from: T0, policy: p), T0.adding(.minutes(60)))
            t.equal(Scheduler.nextFollowUp(after: 2, from: T0, policy: p), T0.adding(.minutes(240)))
            t.equal(Scheduler.nextFollowUp(after: 20, from: T0, policy: p), T0.adding(.minutes(Int64(p.maxIntervalMinutes))), "capped")
            let brief = HandoffBrief(objective: "x", scope: "x", constraints: [], projectRules: [], acceptance: [], evidenceRequested: [], due: nil, checkpoint: nil, contextNotes: "", reference: "R")
            var h = Handoff(id: "h1", taskID: "t1", workerID: "w1", channel: .manualRelay, brief: brief, state: .deliveryUnconfirmed, createdAt: T0, sentAt: T0,
                            acknowledgedAt: nil, lastProgressAt: nil, submittedAt: nil, closedAt: nil, followUps: 0, lastFollowUpAt: nil,
                            nextFollowUpAt: T0.adding(.minutes(60)), notes: [])
            s.handoffs["h1"] = h
            func handoffItems(_ now: Timestamp, _ processed: @escaping (String) -> Bool) -> [DueItem] {
                Scheduler.due(s, now: now, isProcessed: processed).filter {
                    switch $0 { case .handoffFollowUp, .handoffEscalation: return true; default: return false }
                }
            }
            t.expect(handoffItems(T0, { _ in false }).isEmpty)
            let later = T0.adding(.minutes(61))
            t.equal(handoffItems(later, { _ in false }).count, 1)
            t.expect(handoffItems(later, { $0 == "followup:h1:1" }).isEmpty, "already processed")
            h.followUps = 2; s.handoffs["h1"] = h
            t.expect(Scheduler.due(s, now: later, isProcessed: { _ in false }).contains(.handoffEscalation(handoffID: "h1")))
        },
        TestCase("notification budget: quiet hours, hourly cap, dedupe, urgent passes") { t in
            var s = LupyState()
            s.settings.utcOffsetMinutes = 0
            let night = Timestamp(year: 2026, month: 10, day: 15, hour: 23)
            t.equal(NotificationBudget.shouldPush(severity: .attention, dedupeKey: "a", state: s, now: night).0, false)
            t.equal(NotificationBudget.shouldPush(severity: .urgent, dedupeKey: "a", state: s, now: night).0, true)
            t.equal(NotificationBudget.shouldPush(severity: .info, dedupeKey: "a", state: s, now: T0).0, false, "info stays in-app")
            for i in 0..<4 {
                s.notices[LupyID("n\(i)")] = Notice(id: LupyID("n\(i)"), title: "x", body: "", severity: .attention, relatedID: nil, createdAt: T0, pushed: true, dismissed: false, dedupeKey: "k\(i)")
            }
            t.equal(NotificationBudget.shouldPush(severity: .attention, dedupeKey: "new", state: s, now: T0.adding(.minutes(5))).0, false, "4/hour cap")
            t.equal(NotificationBudget.shouldPush(severity: .attention, dedupeKey: "k1", state: s, now: T0.adding(.hours(2))).0, false, "deduped within 6h")
            t.equal(NotificationBudget.shouldPush(severity: .attention, dedupeKey: "new", state: s, now: T0.adding(.hours(2))).0, true)
        },
        TestCase("retry policy: bounded backoff, honours retry-after, switches route, escalates auth") { t in
            let transient = ErrorInfo(category: .transient, message: "502", at: T0)
            if case .retry(let after, _) = RetryPolicy.decide(transient, attempt: 1, maxRetries: 2, hasAlternative: false) { t.expect(after.value >= 4000 && after.value <= 4800) } else { t.fail("expected retry") }
            if case .retry(let after, _) = RetryPolicy.decide(transient, attempt: 2, maxRetries: 2, hasAlternative: false) { t.expect(after.value >= 8000 && after.value <= 9600) } else { t.fail("expected retry") }
            if case .escalate = RetryPolicy.decide(transient, attempt: 3, maxRetries: 2, hasAlternative: false) {} else { t.fail("expected escalate after budget") }
            if case .switchRoute = RetryPolicy.decide(transient, attempt: 3, maxRetries: 2, hasAlternative: true) {} else { t.fail("expected route switch") }
            let rl = ErrorInfo(category: .rateLimited, message: "429", at: T0, retryAfterMillis: 7000)
            t.equal(RetryPolicy.decide(rl, attempt: 1, maxRetries: 2, hasAlternative: false), .retry(after: Millis(7000), reason: "Rate limited; waiting as the provider asked."))
            if case .escalate(let why) = RetryPolicy.decide(ErrorInfo(category: .auth, message: "401", at: T0), attempt: 1, maxRetries: 2, hasAlternative: true) {
                t.expect(why.contains("key"))
            } else { t.fail("auth must escalate, never retry") }
            let recs = (0..<3).map { i in UsageRecord(id: LupyID("u\(i)"), providerID: "openai", modelID: "m", taskID: nil, purpose: .planning, inputTokens: 0, outputTokens: 0,
                                                       costCents: 0, estimated: true, at: T0, ok: false, errorCategory: .transient, latencyMillis: 10) }
            t.equal(FailurePatterns.detect(recs, now: T0.adding(.hours(1))).count, 1)
            t.equal(FailurePatterns.detect(recs, now: T0.adding(.hours(30))).count, 0)
        },
    ])
}
