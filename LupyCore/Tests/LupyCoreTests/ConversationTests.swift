// The conversation layer under the island: the offline intent router (what a message means,
// with plain rules), local status answers, and real multi-turn conversation preparation
// (history included, through the same budget/policy gate as every model call).

func conversationSuite() -> TestSuite {
    TestSuite(name: "Conversation", cases: [

        // MARK: Intent routing — goals

        TestCase("a plain instruction is a goal") { t in
            t.equal(ChatIntentRouter.route("Invoice ACME by Friday", hasProposedPlan: false), .goal)
            t.equal(ChatIntentRouter.route("Renew my passport", hasProposedPlan: false), .goal)
            t.equal(ChatIntentRouter.route("open a bank account for the studio", hasProposedPlan: false), .goal,
                    "“open” without an app/screen target stays a goal")
        },

        // MARK: Intent routing — questions

        TestCase("questions are recognised with and without a question mark") { t in
            t.equal(ChatIntentRouter.route("What is Displate's payout threshold?", hasProposedPlan: false), .question)
            t.equal(ChatIntentRouter.route("why did the build fail", hasProposedPlan: false), .question)
            t.equal(ChatIntentRouter.route("can you explain the pricing page", hasProposedPlan: false), .question)
            t.equal(ChatIntentRouter.route("who owns the PENGLAI domain", hasProposedPlan: false), .question)
            t.equal(ChatIntentRouter.route("tell me about the visa process", hasProposedPlan: false), .question)
        },

        // MARK: Intent routing — status (local answers, never a model call)

        TestCase("status questions are answered locally") { t in
            for q in ["what's next", "What's next?", "status", "my brief", "what's on my plate",
                      "what needs me", "catch me up", "today", "anything urgent"] {
                t.equal(ChatIntentRouter.route(q, hasProposedPlan: false), .status, "“\(q)” should be a status question")
            }
            t.equal(ChatIntentRouter.route("what's the VAT rate in France", hasProposedPlan: false), .question,
                    "a real question that mentions nothing local is not a status query")
        },

        // MARK: Intent routing — commands

        TestCase("short commands pause, resume and stop") { t in
            t.equal(ChatIntentRouter.route("pause", hasProposedPlan: false), .pause)
            t.equal(ChatIntentRouter.route("pause lupy", hasProposedPlan: false), .pause)
            t.equal(ChatIntentRouter.route("resume", hasProposedPlan: false), .resume)
            t.equal(ChatIntentRouter.route("unpause everything", hasProposedPlan: false), .resume)
            t.equal(ChatIntentRouter.route("stop", hasProposedPlan: false), .stop)
            t.equal(ChatIntentRouter.route("stop it please", hasProposedPlan: false), .stop)
            t.equal(ChatIntentRouter.route("cancel the control run", hasProposedPlan: false), .stop)
        },

        TestCase("longer messages are never mistaken for commands") { t in
            t.equal(ChatIntentRouter.route("stop for now and write a summary of the pricing page", hasProposedPlan: false), .goal)
            t.equal(ChatIntentRouter.route("pause the video and describe what you see", hasProposedPlan: false), .goal)
            t.equal(ChatIntentRouter.route("continue the campaign plan tomorrow", hasProposedPlan: false), .goal)
        },

        // MARK: Intent routing — control

        TestCase("screen work is routed to computer control") { t in
            t.equal(ChatIntentRouter.route("open Safari and search for Displate artist payouts", hasProposedPlan: false), .control)
            t.equal(ChatIntentRouter.route("type the brief into the ChatGPT message box", hasProposedPlan: false), .control)
            t.equal(ChatIntentRouter.route("click the Send button", hasProposedPlan: false), .control)
            t.equal(ChatIntentRouter.route("deliver this to Arena in the browser", hasProposedPlan: false), .control)
        },

        // MARK: Intent routing — plan decisions

        TestCase("while a plan waits, confirmations decide it; afterwards they do not") { t in
            t.equal(ChatIntentRouter.route("approve it", hasProposedPlan: true), .approvePlan(note: ""))
            t.equal(ChatIntentRouter.route("looks good", hasProposedPlan: true), .approvePlan(note: ""))
            t.equal(ChatIntentRouter.route("approve it but drop the second step", hasProposedPlan: true),
                    .approvePlan(note: "but drop the second step"))
            t.equal(ChatIntentRouter.route("no", hasProposedPlan: true), .rejectPlan(note: ""))
            t.equal(ChatIntentRouter.route("change the deadline to Monday", hasProposedPlan: true),
                    .rejectPlan(note: "change the deadline to monday"))
            // Without a pending plan the same words are goals or questions, never decisions.
            t.equal(ChatIntentRouter.route("approve it", hasProposedPlan: false), .goal)
            t.equal(ChatIntentRouter.route("no", hasProposedPlan: false), .goal)
            t.equal(ChatIntentRouter.route("looks good, can you also plan the launch", hasProposedPlan: true), .goal,
                    "a longer sentence is not a bare confirmation")
        },

        // MARK: Local answers

        TestCase("the status answer reflects real engine state and stays honest") { t in
            let h = try Harness()
            let answer = h.engine.conversationStatusAnswer()
            t.expect(answer.contains("Nothing needs you"), "fresh engine: nothing pending — got: \(answer)")
            let goal = try h.engine.captureGoal("Ship the teaser", projectID: h.project("PENGLAI City").id)
            let plan = try h.engine.planHeuristically(goalID: goal.id)
            _ = try h.engine.approvePlan(plan.id)
            let after = h.engine.conversationStatusAnswer()
            t.expect(after.contains("Next up") || after.contains("Ship the teaser"), "planned work shows as next up — got: \(after)")
            try h.engine.setGlobalPause(true, reason: "test")
            t.expect(h.engine.conversationStatusAnswer().contains("paused"), "pause is reported")
        },

        // MARK: Conversation turns

        TestCase("a conversation turn includes the history, through the policy gate") { t in
            let h = try Harness()
            let history = [LLMMessage(.user, "What is Displate?"),
                           LLMMessage(.assistant, "A print-on-demand art marketplace."),
                           LLMMessage(.user, "And their payouts?")]
            // No provider allowed yet → honest unavailability, no hidden call.
            if case .job = try h.engine.prepareConversationTurn(question: "How often?", history: history, projectID: nil) {
                t.fail("prepared a call with no provider set up")
            }
            try h.enableProvider("openai")
            let prepared = try h.engine.prepareConversationTurn(question: "How often?", history: history, projectID: nil)
            guard case .job(let job) = prepared else { t.fail("expected a prepared job"); return }
            let contents = job.request.messages.map(\.content)
            t.expect(contents.contains { $0.contains("A print-on-demand art marketplace.") }, "assistant history is included")
            t.expect(contents.contains { $0.contains("And their payouts?") }, "user history is included")
            t.expect(contents.contains { $0.contains("How often?") }, "the new question is included")
            t.equal(job.request.purpose, .conversation)
            // The completed turn records usage once and returns the model's words as the answer.
            let result = try h.engine.completeModelJob(job.id, status: 200, body: okChat("Monthly, above €100."),
                                                       latencyMillis: 40)
            t.expect(result.ok && result.message == "Monthly, above €100.", "answer text comes back for the chat surface")
            t.equal(h.engine.state.usage.count, 1, "usage recorded exactly once")
        },

        TestCase("conversation history never grows without bound") { t in
            let h = try Harness()
            try h.enableProvider("openai")
            var history: [LLMMessage] = []
            for i in 0..<40 { history.append(LLMMessage(i % 2 == 0 ? .user : .assistant, "turn \(i)")) }
            guard case .job(let job) = try h.engine.prepareConversationTurn(question: "next", history: history, projectID: nil) else {
                t.fail("expected a prepared job"); return
            }
            t.expect(job.request.messages.count < 20, "history is capped (got \(job.request.messages.count) messages)")
        },

        TestCase("any key just works: a custom provider is usable right after adding it") { t in
            let h = try Harness()
            // The "Another…" flow: name + link + key creates an OpenAI-compatible provider,
            // approved and enabled; discovery then makes a model usable automatically.
            let now = h.clock.now()
            let config = ProviderConfig(id: "custom.codecraft", kind: .openAICompatible, displayName: "CodeCraft",
                                        baseURL: "https://api.codecraft.example/v1", keychainAccount: "provider.custom.codecraft",
                                        models: [], enabled: true, founderApproved: false, hasKey: false,
                                        priceAsOf: "unknown", dataNotice: "test", createdAt: now)
            try h.engine.upsertProvider(config)
            try h.engine.setProviderKeyPresent("custom.codecraft", present: true)
            try h.engine.approveProvider("custom.codecraft", approved: true)
            // No models yet: nothing to route to.
            if case .job = try h.engine.prepareConversationTurn(question: "hi", history: [], projectID: nil) {
                t.fail("routed with zero models")
            }
            // Discovery finds models (all off by default)…
            try h.engine.addDiscoveredModels("custom.codecraft", modelIDs: ["cc-mini", "cc-pro"])
            // …and enableDefaultModelIfNeeded turns the cheapest on so the key just works.
            try h.engine.enableDefaultModelIfNeeded("custom.codecraft")
            guard case .job(let job) = try h.engine.prepareConversationTurn(question: "hi", history: [], projectID: nil) else {
                t.fail("expected a prepared job after auto-enable"); return
            }
            t.equal(job.providerID, "custom.codecraft", "routes to the custom provider")
            t.equal(job.modelID, "cc-mini", "the auto-enabled cheapest model is used")
            t.expect(job.http.url.contains("api.codecraft.example"), "request goes to the custom base URL")
            // A second call to enableDefaultModelIfNeeded changes nothing (a model is already on).
            try h.engine.enableDefaultModelIfNeeded("custom.codecraft")
            t.equal(h.engine.state.providers["custom.codecraft"]!.models.filter(\.enabled).count, 1, "still exactly one enabled model")
        },

        TestCase("auto-failover: a rate-limited API moves over to another allowed one") { t in
            let h = try Harness()
            try h.enableProvider("openai")
            try h.enableProvider("gemini")
            guard case .job(var job) = try h.engine.prepareConversationTurn(question: "hi", history: [], projectID: nil) else {
                t.fail("expected a prepared job"); return
            }
            t.equal(job.providerID, "openai", "first route goes to the cheaper provider")
            // The API answers 429 (limit) every time: bounded retries on the same provider,
            // then the chain switches route — the founder never sees a dead assistant.
            for attempt in 1...3 {
                let r = try h.engine.completeModelJob(job.id, status: 429,
                                                      body: Array(#"{"error":{"message":"rate limit exceeded","type":"rate_limit_error"}}"#.utf8),
                                                      latencyMillis: 8)
                guard case .callModel(let next)? = r.effects.last else { t.fail("expected a retry at attempt \(attempt)"); return }
                if attempt < 3 { t.equal(next.providerID, "openai", "retry stays on the provider first") }
                else { t.equal(next.providerID, "gemini", "switched to the other allowed provider after the limit") }
                job = next
            }
            // The switched job is a Gemini call, so the success body is Gemini-shaped.
            let okBody = Array(#"{"candidates":[{"content":{"parts":[{"text":"Here via the backup."}],"role":"model"},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":30,"candidatesTokenCount":10}}"#.utf8)
            let ok = try h.engine.completeModelJob(job.id, status: 200, body: okBody, latencyMillis: 8)
            t.expect(ok.ok, "the fallback provider answers")
            t.expect(h.engine.state.usage.filter { !$0.ok }.count >= 3, "failed attempts are recorded honestly")
        },
    ])
}
