// Computer control (the rules behind the visible Lupy cursor): target matching, safety
// classification and the policy gate, the session state machine (stop / fail / pause), strict
// parsing of model-chosen steps, and handoff delivery.

private func el(_ id: Int, _ role: String, title: String = "", label: String = "", value: String = "", placeholder: String = "",
                subrole: String = "", enabled: Bool = true, focused: Bool = false, editable: Bool = false,
                w: Double = 80, h: Double = 24) -> UIElementInfo {
    UIElementInfo(id: id, role: role, subrole: subrole, title: title, label: label, value: value, placeholder: placeholder,
                  frame: UIRect(x: Double(id) * 10, y: 100, width: w, height: h), enabled: enabled, focused: focused,
                  editable: editable, actions: role == "AXButton" || role == "AXLink" ? ["AXPress"] : [])
}

private func chatScreen(extra: [UIElementInfo] = []) -> UISnapshot {
    UISnapshot(appName: "Safari", bundleID: "com.apple.Safari", windowTitle: "Arena",
               elements: [el(1, "AXButton", title: "New chat"),
                          el(2, "AXTextArea", placeholder: "Message Arena", editable: true, w: 600, h: 80),
                          el(3, "AXButton", label: "Send message"),
                          el(4, "AXButton", title: "Send feedback", enabled: false),
                          el(5, "AXLink", title: "Settings"),
                          el(6, "AXTextField", title: "Search", w: 120)] + extra)
}

func controlSuite() -> TestSuite {
    TestSuite(name: "Control", cases: [
        TestCase("matcher finds the named element, prefers exact text, and never guesses") { t in
            let s = chatScreen()
            t.equal(ElementMatcher.best(ElementQuery(["Send", "Send message"], role: .button), in: s.elements)?.element.id, 3)
            t.equal(ElementMatcher.best(ElementQuery(["Settings"]), in: s.elements)?.element.id, 5)
            t.equal(ElementMatcher.best(ElementQuery(DeliveryPlan.messageBox, role: .textInput), in: s.elements)?.element.id, 2,
                    "the message box, not the search field")
            t.expect(ElementMatcher.best(ElementQuery(["Publish"], role: .button), in: s.elements) == nil, "no match → unavailable, no guess")
            t.expect(ElementMatcher.best(ElementQuery(["Send feedback"], role: .button, exact: true), in: s.elements) == nil, "disabled elements are never targets")
            t.expect(ElementMatcher.best(ElementQuery(["Sen"], role: .button, exact: true), in: s.elements) == nil, "exact queries need the exact text")
        },
        TestCase("matcher picks the main text field when the query names none, and never a password field") { t in
            let s = UISnapshot(appName: "TextEdit", bundleID: "com.apple.TextEdit", windowTitle: "Untitled",
                               elements: [el(1, "AXTextField", title: "Find", w: 120, h: 20),
                                          el(2, "AXTextArea", editable: true, w: 700, h: 500),
                                          el(3, "AXTextField", title: "Password", subrole: "AXSecureTextField", w: 300)])
            t.equal(ElementMatcher.best(ElementQuery([], role: .textInput), in: s.elements)?.element.id, 2)
            t.expect(ElementMatcher.best(ElementQuery(["Password"], role: .textInput), in: s.elements) == nil)
        },
        TestCase("safety: consequential clicks are classified for the policy gate") { t in
            func kind(_ title: String) -> ActionKind {
                ControlSafety.classify(.press(ElementQuery([title])), target: el(9, "AXButton", title: title), snapshot: chatScreen()).kind
            }
            t.equal(kind("Send"), .sendExternalMessage)
            t.equal(kind("Submit"), .sendExternalMessage)
            t.equal(kind("Delete conversation"), .deleteData)
            t.equal(kind("Move to Trash"), .deleteData)
            t.equal(kind("Buy now"), .spendMoney)
            t.equal(kind("Place order"), .spendMoney)
            t.equal(kind("Post"), .publishContent)
            t.equal(kind("Share"), .publishContent)
            t.equal(kind("Allow"), .grantAccess)
            t.equal(kind("Change password"), .changeAccountSecurity)
            t.equal(kind("Sign in"), .computerControl)
            t.equal(kind("New Document"), .uiNavigate)
            t.equal(kind("Bold"), .uiNavigate)
            for k in ["Send", "Delete conversation", "Buy now", "Allow", "Sign in"] {
                t.expect(ControlSafety.classify(.press(ElementQuery([k])), target: el(9, "AXButton", title: k), snapshot: nil).consequential, k)
            }
            t.expect(!ControlSafety.classify(.press(ElementQuery(["New Document"])), target: el(9, "AXButton", title: "New Document"), snapshot: nil).consequential)
            t.equal(ControlSafety.classify(.press(ElementQuery(["x"])), target: nil, snapshot: nil).kind, .computerControl, "unknown target → ask")
        },
        TestCase("safety: typing, keys and pages") { t in
            let box = el(2, "AXTextArea", placeholder: "Message", editable: true)
            t.equal(ControlSafety.classify(.setText(ElementQuery(["Message"]), text: "hi"), target: box, snapshot: chatScreen()).kind, .uiInput)
            let pw = el(3, "AXTextField", title: "Password", subrole: "AXSecureTextField")
            t.equal(ControlSafety.classify(.setTextElement(3, text: "x"), target: pw, snapshot: nil).kind, .bypassSecurityControl, "never types passwords")
            let code = el(4, "AXTextField", placeholder: "Verification code")
            t.equal(ControlSafety.classify(.setTextElement(4, text: "123456"), target: code, snapshot: nil).kind, .bypassSecurityControl)
            let ret = ControlSafety.classify(.pressKey(.returnKey), target: nil, snapshot: nil)
            t.expect(ret.consequential && ret.kind == .computerControl, "Return may send")
            t.equal(ControlSafety.classify(.pressKey(.tab), target: nil, snapshot: nil).kind, .uiNavigate)
            t.equal(ControlSafety.classify(.openURL("https://chatgpt.com"), target: nil, snapshot: nil).kind, .openURL)
            t.equal(ControlSafety.classify(.openURL("javascript:alert(1)"), target: nil, snapshot: nil).kind, .bypassSecurityControl)
            t.equal(ControlSafety.classify(.read(ElementQuery(["x"])), target: nil, snapshot: nil).kind, .readInformation)
        },
        TestCase("safety: a CAPTCHA or two-factor screen stops every action (Lupy never bypasses it)") { t in
            let snap = chatScreen(extra: [el(20, "AXStaticText", value: "Verify you are human")])
            t.expect(ControlSafety.looksLikeSecurityChallenge(snap))
            t.equal(ControlSafety.classify(.press(ElementQuery(["New chat"])), target: el(1, "AXButton", title: "New chat"), snapshot: snap).kind, .bypassSecurityControl)
            t.equal(ControlSafety.classify(.read(ElementQuery(["x"])), target: nil, snapshot: snap).kind, .readInformation, "reading stays allowed")
            let twoFA = chatScreen(extra: [el(21, "AXStaticText", value: "Enter the code from your authenticator app")])
            t.expect(ControlSafety.looksLikeSecurityChallenge(twoFA))
            t.expect(!ControlSafety.looksLikeSecurityChallenge(chatScreen()))
        },
        TestCase("policy gate: typing flows, operating asks in Prepare mode, consequential always asks, pause and bypass deny") { t in
            func v(_ k: ActionKind, _ mode: AutonomyMode = .prepare, paused: Bool = false) -> PolicyDecision.Verdict {
                PolicyEngine.evaluate(action(k), context: ctx(mode, paused: paused)).verdict
            }
            t.equal(v(.uiInput), .allow)
            t.equal(v(.uiNavigate), .requireApproval)
            t.equal(v(.uiNavigate, .bounded), .allow)
            t.equal(v(.sendExternalMessage, .bounded), .requireApproval)
            t.equal(v(.deleteData, .bounded), .requireApproval)
            t.equal(v(.uiInput, .observe), .requireApproval)
            t.equal(v(.uiInput, paused: true), .deny, "pausing Lupy stops computer control")
            t.equal(v(.bypassSecurityControl, .bounded), .deny)
            t.equal(v(.readInformation, paused: true), .allow)
            t.expect(ActionKind.uiInput.risk == .low && ActionKind.uiNavigate.risk == .medium)
        },
        TestCase("run: stop cancels everything still queued; nothing new starts afterwards") { t in
            var run = ControlRun(id: "r1", title: "Deliver", steps: [.openApp(bundleID: "com.apple.TextEdit", name: "TextEdit"),
                                                                   .setText(ElementQuery([], role: .textInput), text: "hi"),
                                                                   .press(ElementQuery(["Send"]))], byFounder: true)
            t.equal(run.nextIndex, 0)
            run.mark(0, .executing)
            run.mark(0, .succeeded, detail: "TextEdit is frontmost")
            t.equal(run.nextIndex, 1)
            run.mark(1, .executing)
            run.stop(reason: "you pressed Esc")
            t.equal(run.state, .stopped)
            t.equal(run.nextIndex, nil, "a stopped run never hands out another step")
            t.equal(run.steps[2].state, .stopped)
            t.equal(run.steps[1].state, .executing, "the step in flight reports its real outcome")
            run.mark(2, .executing)
            t.equal(run.steps[2].state, .stopped, "a cancelled step cannot be restarted")
            run.mark(1, .succeeded, detail: "typed")
            t.equal(run.steps[1].state, .succeeded)
            t.expect(run.summary.hasPrefix("Stopped: you pressed Esc"))
        },
        TestCase("run: a failed step stops the run and the rest is not attempted; pause holds the queue") { t in
            var run = ControlRun(id: "r2", title: "x", steps: [.press(ElementQuery(["A"])), .press(ElementQuery(["B"])), .press(ElementQuery(["C"]))], byFounder: false)
            run.pause()
            t.equal(run.nextIndex, nil)
            run.resume()
            t.equal(run.nextIndex, 0)
            run.mark(0, .failed, detail: "“A” is not on screen")
            t.equal(run.state, .failed)
            t.equal(run.steps[1].state, .skipped)
            t.equal(run.steps[2].state, .skipped)
            t.expect(run.summary.contains("not on screen"))
            var ok = ControlRun(id: "r3", title: "y", steps: [.pressKey(.tab)], byFounder: true)
            ok.mark(0, .succeeded)
            t.equal(ok.state, .finished)
        },
        TestCase("agent: replies are parsed strictly against what is on screen") { t in
            let s = chatScreen()
            t.equal(ControlAgent.parse(#"{"action":"click","element":3,"reason":"send"}"#, snapshot: s), .step(.pressElement(3), reason: "send"))
            t.equal(ControlAgent.parse("Sure! ```json\n{\"action\":\"type\",\"element\":2,\"text\":\"Hello\"}\n```", snapshot: s),
                    .step(.setTextElement(2, text: "Hello"), reason: ""))
            t.equal(ControlAgent.parse(#"{"action":"key","key":"return"}"#, snapshot: s), .step(.pressKey(.returnKey), reason: ""))
            t.equal(ControlAgent.parse(#"{"action":"done","summary":"Sent."}"#, snapshot: s), .done("Sent."))
            t.equal(ControlAgent.parse(#"{"action":"ask","question":"Which project?"}"#, snapshot: s), .askFounder("Which project?"))
            if case .invalid = ControlAgent.parse(#"{"action":"click","element":99}"#, snapshot: s) {} else { t.fail("element not on screen must be rejected") }
            if case .invalid = ControlAgent.parse(#"{"action":"open_url","url":"http://x.test"}"#, snapshot: s) {} else { t.fail("http must be rejected") }
            if case .invalid = ControlAgent.parse(#"{"action":"format_disk"}"#, snapshot: s) {} else { t.fail("unknown actions rejected") }
            if case .invalid = ControlAgent.parse("I clicked it for you!", snapshot: s) {} else { t.fail("prose is not a step") }
        },
        TestCase("agent: the screen is fenced as untrusted data and passwords are never shown") { t in
            let s = chatScreen(extra: [el(30, "AXTextField", title: "Password", value: "hunter2", subrole: "AXSecureTextField")])
            let o = ControlAgent.observation(s)
            t.expect(o.hasPrefix("<untrusted"), "screen text is data, not instructions")
            t.expect(o.contains("[3] button “Send message”"))
            t.expect(!o.contains("hunter2"))
            t.expect(ControlAgent.systemPrompt.contains("Never type passwords"))
        },
        TestCase("delivery: open, find the box, type, then Send (which waits for the founder)") { t in
            let steps = DeliveryPlan.steps(brief: "Write the PENGLAI teaser", to: DeliveryTarget(appName: "Arena", url: "https://arena.ai"), send: true)
            t.equal(steps.count, 4)
            t.equal(steps.first, .openURL("https://arena.ai"))
            if case .press(let q) = steps.last { t.expect(q.texts.contains("Send")) } else { t.fail("last step sends") }
            t.expect(ControlSafety.classify(steps[3], target: el(3, "AXButton", label: "Send message"), snapshot: chatScreen()).consequential)
            let noSend = DeliveryPlan.steps(brief: "x", to: DeliveryTarget(bundleID: "com.openai.chat", appName: "ChatGPT"), send: false)
            t.equal(noSend.first, .openApp(bundleID: "com.openai.chat", name: "ChatGPT"))
            t.equal(noSend.count, 3)
            let brief = "Please write the PENGLAI City teaser script with three scenes."
            let after = chatScreen(extra: [el(40, "AXStaticText", value: brief)])
            t.expect(DeliveryPlan.deliveryObserved(brief: brief, after: after))
            let stillInBox = UISnapshot(appName: "Safari", bundleID: "x", windowTitle: "x", elements: [el(2, "AXTextArea", value: brief, editable: true)])
            t.expect(!DeliveryPlan.deliveryObserved(brief: brief, after: stillInBox), "text still in the box is not a delivery")
        },
        TestCase("engine: a computer-control delivery is recorded honestly (seen → sent; unseen → unconfirmed)") { t in
            let h = try Harness()
            let p = h.project("Muse / Arena")
            let task = try h.engine.addTask(projectID: p.id, title: "Teaser script", kind: .writing, acceptance: ["Script with three scenes"])
            let hnd = try h.engine.delegate(task.id, to: h.worker("Arena").id)
            _ = try h.engine.dispatch(hnd.id)
            try h.engine.recordControlDelivery(hnd.id, observed: true, app: "Safari")
            t.equal(h.engine.state.handoffs[hnd.id]?.state, .sent)
            t.equal(h.engine.state.tasks[task.id]?.status, .dispatched)
            t.expect(h.engine.state.handoffs[hnd.id]?.notes.last?.text.contains("work not yet verified") == true)
            t.expect(h.engine.state.verifications[task.id]?.outcome != .verified, "delivery is never evidence of the work")
            let task2 = try h.engine.addTask(projectID: p.id, title: "Logo ideas", kind: .writing)
            let h2 = try h.engine.delegate(task2.id, to: h.worker("Arena").id)
            _ = try h.engine.dispatch(h2.id)
            try h.engine.recordControlDelivery(h2.id, observed: false, app: "Safari")
            t.equal(h.engine.state.handoffs[h2.id]?.state, .deliveryUnconfirmed)
            t.equal(h.engine.state.tasks[task2.id]?.status, .deliveryUnconfirmed)
            t.throwsError("only the founder may record it") { try h.engine.recordControlDelivery(h2.id, observed: true, app: "x", by: .lupy) }
        },
        TestCase("engine: a model-driven step needs an approved cloud model (offline: unavailable, no call)") { t in
            let h = try Harness()
            let r = try h.engine.prepareControlStep(runID: "run_1", step: 0, goal: "Open TextEdit", observation: "<untrusted>…</untrusted>", history: [], projectID: nil)
            if case .unavailable = r {} else { t.fail("no provider → unavailable") }
        },
    ])
}
