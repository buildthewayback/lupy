// Lupy — computer control: runs a list of steps (or steps a cloud model proposes one at a time)
// in other apps through Accessibility, with the Lupy cursor showing every real action.
//
// Each step: locate the target for real (or fail: "not on screen") → classify it (ControlSafety)
// → policy gate through the engine's action ledger (beginAction): consequential steps (send,
// delete, pay, publish, grant access…) wait for the founder's approval on Coucou's approval card /
// Lupy → Needs you; security checks and passwords are refused → do it → read the result back →
// finishAction(verified:) with what was actually observed. Stop (banner, Esc, menu bar, Pause
// Lupy) cancels everything still queued; the founder typing pauses the run so Lupy never types over
// them. Nothing here moves the founder's pointer.

import AppKit
import ApplicationServices
import LupyCore
import Observation

@MainActor
@Observable
final class LupyControlCenter {
    static let shared = LupyControlCenter()
    static let enabledKey = "lupyComputerControlEnabled"

    /// Off until the founder turns it on (Lupy → Computer control).
    var enabled: Bool = UserDefaults.standard.bool(forKey: LupyControlCenter.enabledKey) {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }
    }
    private(set) var run: ControlRun?
    private(set) var lastRun: ControlRun?
    private(set) var isLocating = false
    private(set) var appName = ""
    var trusted: Bool { LupyAX.isTrusted() }
    var isActive: Bool { run.map { !$0.isOver } ?? false }

    var statusLine: String {
        guard let r = run else { return "" }
        if let i = r.steps.firstIndex(where: { !$0.state.isFinished }) {
            return "\(appName.isEmpty ? "Using your Mac" : "Using \(appName)"): \(r.steps[i].title)"
        }
        return r.summary
    }

    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var table: [AXUIElement] = []
    @ObservationIgnored private var snapshot: UISnapshot?
    @ObservationIgnored private var targetApp: NSRunningApplication?
    @ObservationIgnored private var keyMonitor: Any?
    @ObservationIgnored private var localKeyMonitor: Any?
    @ObservationIgnored private var ignoreKeysUntil = Date.distantPast
    @ObservationIgnored private var agentGoal: String?
    @ObservationIgnored private var agentHistory: [String] = []
    @ObservationIgnored private var projectID: LupyID?
    @ObservationIgnored private var onFinish: ((ControlRun) -> Void)?
    /// Test hooks (the control self-test runs without a person): approvals decided automatically,
    /// phase reports for screenshot timing, and a pause at each target so screenshots catch the cursor.
    @ObservationIgnored var autoDecision: Bool?
    @ObservationIgnored var testPhase: ((String) -> Void)?
    @ObservationIgnored var testHoldSeconds: Double = 0

    private init() {}

    // MARK: Starting and stopping

    /// Why a run cannot start now, in plain words (nil = it can).
    func blocker() -> String? {
        if !enabled { return "Computer control is off. Turn it on in Lupy → Computer control." }
        if !LupyAX.isTrusted() { return "macOS has not allowed Lupy to use Accessibility yet (System Settings → Privacy & Security → Accessibility → Lupy)." }
        if LupyModel.shared.state.settings.globalPause { return "Lupy is paused. Resume it first." }
        if isActive { return "Lupy is already using your Mac. Stop it first." }
        return nil
    }

    /// Runs `steps` (byFounder: the founder pressed the button that starts this routine).
    @discardableResult
    func start(title: String, steps: [ControlStep], byFounder: Bool, projectID: LupyID? = nil,
               onFinish: ((ControlRun) -> Void)? = nil) -> Bool {
        if let why = blocker() { LupyModel.shared.say(why); return false }
        begin(ControlRun(id: "ctl_\(UUID().uuidString.prefix(8))", title: title, steps: steps, byFounder: byFounder),
              goal: nil, projectID: projectID, onFinish: onFinish)
        return true
    }

    /// A cloud model chooses each step towards `goal`; every step is still classified and gated.
    @discardableResult
    func startAgent(goal: String, projectID: LupyID? = nil) -> Bool {
        if let why = blocker() { LupyModel.shared.say(why); return false }
        guard LupyModel.shared.hasUsableModel else {
            LupyModel.shared.say("Doing a goal on screen needs a cloud model you approved (Lupy → Assistant). Routines like delivering a handoff work without one.")
            return false
        }
        begin(ControlRun(id: "ctl_\(UUID().uuidString.prefix(8))", title: goal, steps: [], byFounder: false),
              goal: goal, projectID: projectID, onFinish: nil)
        return true
    }

    private func begin(_ r: ControlRun, goal: String?, projectID: LupyID?, onFinish: ((ControlRun) -> Void)?) {
        run = r
        agentGoal = goal
        agentHistory = []
        self.projectID = projectID
        self.onFinish = onFinish
        appName = ""
        targetApp = NSWorkspace.shared.frontmostApplication
        LupyCursorOverlay.shared.show()
        LupyCursorOverlay.shared.setBanner("Lupy: \(TextUtil.truncate(r.title, 48))", "Starting")
        installKeyMonitors()
        LupyIslandBridge.shared.flash("Lupy is using your Mac — watch its cursor. Esc stops it.", sound: "work")
        LupyIslandBridge.shared.scheduleSync()
        worker = Task { @MainActor in await self.loop() }
    }

    func stop(reason: String) {
        guard var r = run, !r.isOver else { return }
        r.stop(reason: reason)
        run = r
        worker?.cancel()
        LupyCursorOverlay.shared.set(.stopped, label: "Stopped")
        LupyCursorOverlay.shared.setBanner("Stopped", reason)
        finishRun()
    }

    func pause(_ why: String) {
        guard var r = run, r.state == .running else { return }
        r.pause()
        run = r
        LupyCursorOverlay.shared.setBanner("Paused", why, paused: true)
        LupyIslandBridge.shared.scheduleSync()
    }

    func resume() {
        guard var r = run, r.state == .paused else { return }
        r.resume()
        run = r
        LupyCursorOverlay.shared.setBanner("Lupy: \(TextUtil.truncate(r.title, 48))", "Resuming")
        LupyIslandBridge.shared.scheduleSync()
    }

    // MARK: The loop

    private func loop() async {
        while !Task.isCancelled, let r = run, !r.isOver {
            if r.state == .paused { try? await Task.sleep(nanoseconds: 300_000_000); continue }
            if LupyModel.shared.state.settings.globalPause { stop(reason: "Lupy was paused"); return }
            if let i = r.nextIndex {
                await perform(i)
            } else if agentGoal != nil {
                await askModelForNextStep()
            } else {
                break
            }
        }
        if let r = run, !r.isOver, r.state != .paused { finishRun() }
        else if run?.isOver == true, keyMonitor != nil { finishRun() }
    }

    private func finishRun() {
        removeKeyMonitors()
        guard let r = run else { return }
        lastRun = r
        let done = onFinish
        onFinish = nil
        done?(r)
        let ok = r.state == .finished
        LupyCursorOverlay.shared.set(ok ? .succeeded : (r.state == .stopped ? .stopped : .failed), label: ok ? "Done" : r.summary)
        LupyCursorOverlay.shared.setBanner(ok ? "Done" : (r.state == .stopped ? "Stopped" : "Couldn't finish"), r.summary)
        LupyIslandBridge.shared.flash(ok ? "Lupy finished: \(TextUtil.truncate(r.title, 60))" : r.summary, sound: ok ? "finish" : "error")
        run = r.isOver ? r : nil
        LupyModel.shared.changed()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            Task { @MainActor in
                let c = LupyControlCenter.shared
                if !c.isActive { LupyCursorOverlay.shared.hide(); c.run = nil; LupyIslandBridge.shared.scheduleSync() }
            }
        }
    }

    // MARK: One step

    private func mark(_ i: Int, _ s: ControlStepState, _ detail: String = "", title: String? = nil, kind: ActionKind? = nil) {
        guard var r = run else { return }
        r.mark(i, s, detail: detail, title: title, kind: kind)
        run = r
        if let t = title ?? (r.steps.indices.contains(i) ? r.steps[i].title : nil) { LupyCursorOverlay.shared.setBanner("Lupy: \(TextUtil.truncate(r.title, 40))", t) }
        LupyIslandBridge.shared.scheduleSync()
    }

    private var isStopped: Bool { run.map { $0.state == .stopped || $0.state == .failed } ?? true }

    private func perform(_ i: Int) async {
        guard let r = run else { return }
        let step = r.steps[i].step
        var target: UIElementInfo?
        var element: AXUIElement?

        // 1. Where: open the app or page, then find the target on screen.
        if step.needsTarget {
            mark(i, .locating, "Looking for it on screen")
            isLocating = true
            LupyCursorOverlay.shared.set(.locating, label: step.title())
            let found = await locate(step)
            isLocating = false
            guard !isStopped else { return }
            guard let f = found else {
                let what = step.title().replacingOccurrences(of: "Click ", with: "").replacingOccurrences(of: "Wait for ", with: "")
                mark(i, .failed, "\(what) is not on screen in \(appName.isEmpty ? "the app" : appName). Lupy did not click anything.")
                LupyCursorOverlay.shared.set(.failed, label: "Not found")
                return
            }
            target = f.0
            element = f.1
            if case .waitFor = step {
                await LupyCursorOverlay.shared.move(to: f.0.frame, label: "Found “\(f.0.displayName)”")
                mark(i, .succeeded, "“\(f.0.displayName)” is on screen.", title: step.title(target: f.0), kind: .readInformation)
                return
            }
        }

        // 2. What it means: classify for the policy gate.
        let cls = ControlSafety.classify(step, target: target, snapshot: snapshot)
        let title = step.title(target: target)
        mark(i, .pending, cls.reason, title: title, kind: cls.kind)
        if cls.kind == .bypassSecurityControl {
            mark(i, .failed, cls.reason)
            LupyCursorOverlay.shared.set(.failed, label: "Needs you")
            return
        }

        // 3. May it happen: the engine's policy gate and action ledger.
        guard let engine = LupyModel.shared.engine else { mark(i, .failed, "Lupy's assistant is not running."); return }
        let r2 = run!
        let founderActs = r2.byFounder && !cls.consequential
        let action = engine.makeAction(kind: cls.kind, title: title, target: "\(appName)\(target.map { " · \($0.displayName)" } ?? "")",
                                       detail: Self.detail(step), projectID: projectID, reversible: !cls.consequential,
                                       originator: founderActs ? .founder : .lupy, idempotencyKey: "ctl:\(r2.id):\(i)")
        var record: ActionRecord?
        if cls.kind == .readInformation {
            record = nil
        } else {
            do {
                record = try engine.beginAction(action, by: founderActs ? .founder : .lupy)
            } catch {
                // Waiting for the founder (consequential), or refused (paused, project rule…).
                if let pending = engine.state.approvals.values.first(where: { $0.action.idempotencyKey == action.idempotencyKey && $0.status == .pending }) {
                    if let t = target { await LupyCursorOverlay.shared.move(to: t.frame, label: "Waiting for your OK: \(title)") }
                    LupyCursorOverlay.shared.set(.awaitingApproval, label: "Waiting for your OK")
                    mark(i, .awaitingApproval, "\(cls.reason) Approve it on the notch or in Lupy → Needs you.")
                    LupyModel.shared.changed()
                    testPhase?("awaiting")
                    if testHoldSeconds > 0 { try? await Task.sleep(nanoseconds: UInt64(testHoldSeconds * 1_000_000_000)) }
                    let approved = await waitForDecision(pending.id)
                    guard !isStopped else { return }
                    if !approved {
                        mark(i, .failed, "You declined: \(title). Lupy did not do it.")
                        return
                    }
                    do { record = try engine.beginAction(action, by: .founder) } catch {
                        mark(i, .failed, "\(error)")
                        return
                    }
                } else {
                    mark(i, .failed, "Not allowed: \(error)")
                    LupyCursorOverlay.shared.set(.failed, label: "Not allowed")
                    return
                }
            }
        }
        guard !isStopped else {
            if let rec = record { try? engine.finishAction(rec.id, verified: false, summary: "Cancelled before it ran (stopped).") }
            return
        }

        // 4. Do it — the cursor shows the real target — then read the result back.
        if let t = target { await LupyCursorOverlay.shared.move(to: t.frame, label: title) }
        guard !isStopped else {
            if let rec = record { try? engine.finishAction(rec.id, verified: false, summary: "Cancelled before it ran (stopped).") }
            return
        }
        mark(i, .executing, "Doing it")
        LupyCursorOverlay.shared.set(.executing, label: title)
        testPhase?("executing:\(i)")
        if testHoldSeconds > 0 { try? await Task.sleep(nanoseconds: UInt64(testHoldSeconds * 1_000_000_000)) }
        guard !isStopped else {
            if let rec = record { try? engine.finishAction(rec.id, verified: false, summary: "Cancelled before it ran (stopped).") }
            mark(i, .stopped, "Cancelled before it ran.")
            return
        }
        let (ok, summary) = await execute(step, target: target, element: element)
        if let rec = record {
            try? engine.finishAction(rec.id, verified: ok, summary: summary, evidenceKind: .observation)
        }
        LupyModel.shared.changed()
        mark(i, ok ? .succeeded : .failed, summary)
        LupyCursorOverlay.shared.set(ok ? .succeeded : .failed, label: ok ? "Done: \(title)" : "Failed: \(title)")
        agentHistory.append("\(ok ? "OK" : "FAILED"): \(title) — \(summary)")
        try? await Task.sleep(nanoseconds: 250_000_000)
    }

    static func detail(_ step: ControlStep) -> String {
        switch step {
        case .setText(_, let t), .setTextElement(_, let t): return "Text (\(t.count) characters): \(TextUtil.truncate(t, 160))"
        case .openURL(let u): return u
        case .openApp(let b, _): return b
        default: return ""
        }
    }

    private func waitForDecision(_ approvalID: LupyID) async -> Bool {
        if let auto = autoDecision {
            LupyModel.shared.act { try $0.decideApproval(approvalID, approve: auto, note: "Decided by the control self-test") }
        }
        while !Task.isCancelled && !isStopped {
            let status = LupyModel.shared.state.approvals[approvalID]?.status
            switch status {
            case .approved?: return true
            case .denied?, .expired?, .cancelled?, nil: return false
            case .pending?: try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
        return false
    }

    // MARK: Locating targets

    private func refreshSnapshot() {
        guard let app = targetApp ?? NSWorkspace.shared.frontmostApplication else { snapshot = nil; table = []; return }
        let (snap, t) = LupyAX.snapshot(of: app)
        snapshot = snap
        table = t
        appName = snap.appName
    }

    private func locate(_ step: ControlStep) async -> (UIElementInfo, AXUIElement)? {
        let seconds: Int
        if case .waitFor(_, let s) = step { seconds = max(1, min(60, s)) } else { seconds = 4 }
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        repeat {
            if isStopped { return nil }
            refreshSnapshot()
            if let snap = snapshot {
                switch step {
                case .pressElement(let n), .setTextElement(let n, _):
                    if let e = snap.element(n), table.indices.contains(n) { return (e, table[n]) }
                    return nil   // model steps refer to the snapshot they saw; no retry on a moving screen
                case .press(let q), .setText(let q, _), .read(let q), .waitFor(let q, _):
                    if let m = ElementMatcher.best(q, in: snap.elements), table.indices.contains(m.element.id) {
                        return (m.element, table[m.element.id])
                    }
                default: return nil
                }
            }
            try? await Task.sleep(nanoseconds: 600_000_000)
        } while Date() < deadline
        return nil
    }

    // MARK: Executing (returns what was actually observed)

    private func execute(_ step: ControlStep, target: UIElementInfo?, element: AXUIElement?) async -> (Bool, String) {
        switch step {
        case .openApp(let bundleID, let name):
            return await openApp(bundleID, name: name)
        case .openURL(let s):
            guard let url = URL(string: s) else { return (false, "That address is not valid.") }
            let browser = NSWorkspace.shared.urlForApplication(toOpen: url)
            guard NSWorkspace.shared.open(url) else { return (false, "macOS could not open \(s).") }
            if let b = browser, let id = Bundle(url: b)?.bundleIdentifier {
                let (ok, _) = await waitFrontmost(id, seconds: 12)
                if ok { try? await Task.sleep(nanoseconds: 1_200_000_000) }
                return ok ? (true, "\(appName) opened \(s).") : (false, "The browser did not come to the front.")
            }
            return (true, "Opened \(s).")
        case .press, .pressElement:
            guard let el = element else { return (false, "No target.") }
            activateTarget()
            let res = LupyAX.press(el)
            guard res == .success else { return (false, "The click was refused: \(LupyAX.describe(res)).") }
            LupyCursorOverlay.shared.click()
            try? await Task.sleep(nanoseconds: 500_000_000)
            return (true, "macOS accepted the click on “\(target?.displayName ?? "")”.")
        case .setText(_, let text), .setTextElement(_, let text):
            guard let el = element else { return (false, "No target.") }
            return await typeText(text, into: el, name: target?.displayName ?? "the field")
        case .pressKey(let k):
            activateTarget()
            ignoreKeysUntil = Date().addingTimeInterval(0.5)
            LupyAX.press(key: k)
            LupyCursorOverlay.shared.click()
            try? await Task.sleep(nanoseconds: 400_000_000)
            return (true, "Key sent to \(appName).")
        case .read:
            guard let el = element else { return (false, "No target.") }
            return (true, "Read: “\(TextUtil.truncate(LupyAX.value(el), 160))”")
        case .waitFor:
            return (true, "On screen.")
        }
    }

    private func typeText(_ text: String, into el: AXUIElement, name: String) async -> (Bool, String) {
        let probe = String(text.prefix(40))
        let res = LupyAX.setValue(el, text)
        try? await Task.sleep(nanoseconds: 250_000_000)
        if res == .success, LupyAX.value(el).contains(probe) {
            return (true, "Typed \(text.count) characters into “\(name)” and read them back.")
        }
        // Web apps often ignore a direct value: focus the field and paste instead (clipboard restored).
        activateTarget()
        _ = LupyAX.focus(el)
        try? await Task.sleep(nanoseconds: 200_000_000)
        ignoreKeysUntil = Date().addingTimeInterval(1.0)
        LupyAX.selectAll()
        LupyAX.paste(text)
        try? await Task.sleep(nanoseconds: 700_000_000)
        let back = LupyAX.value(el)
        if back.contains(probe) { return (true, "Pasted \(text.count) characters into “\(name)” and read them back.") }
        return (false, "“\(name)” did not show the text afterwards, so Lupy reports it as not typed.")
    }

    private func openApp(_ bundleID: String, name: String) async -> (Bool, String) {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            running.activate(options: [.activateIgnoringOtherApps])
        } else {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                return (false, "\(name) is not installed on this Mac.")
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
        }
        let (ok, app) = await waitFrontmost(bundleID, seconds: 15)
        if ok, let app { targetApp = app; appName = app.localizedName ?? name }
        try? await Task.sleep(nanoseconds: 600_000_000)
        return ok ? (true, "\(name) is open and in front.") : (false, "\(name) did not come to the front.")
    }

    private func waitFrontmost(_ bundleID: String, seconds: Int) async -> (Bool, NSRunningApplication?) {
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        while Date() < deadline && !isStopped {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
                    targetApp = app
                    appName = app.localizedName ?? bundleID
                    return (true, app)
                }
                app.activate(options: [.activateIgnoringOtherApps])
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return (false, nil)
    }

    private func activateTarget() {
        if let app = targetApp, NSWorkspace.shared.frontmostApplication != app {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    // MARK: Model-chosen steps

    private func askModelForNextStep() async {
        guard let goal = agentGoal, let engine = LupyModel.shared.engine, var r = run else { return }
        if r.steps.count >= ControlAgent.maxSteps { r.finish(); run = r; stop(reason: "the step limit (\(ControlAgent.maxSteps)) was reached"); return }
        refreshSnapshot()
        guard let snap = snapshot else { stop(reason: "nothing is on screen to work with"); return }
        if ControlSafety.looksLikeSecurityChallenge(snap) {
            stop(reason: "the screen shows a security check (CAPTCHA or a code) — please complete it yourself")
            return
        }
        LupyCursorOverlay.shared.setBanner("Lupy: \(TextUtil.truncate(goal, 40))", "Thinking about the next step")
        let prepared: PreparedCall
        do {
            prepared = try engine.prepareControlStep(runID: r.id, step: r.steps.count, goal: goal,
                                                     observation: ControlAgent.observation(snap), history: agentHistory, projectID: projectID)
        } catch { stop(reason: "\(error)"); return }
        switch prepared {
        case .unavailable(let why): stop(reason: why); return
        case .needsApproval: stop(reason: "the cloud model needs your OK first (Lupy → Needs you)"); LupyModel.shared.changed(); return
        case .job(let job):
            LupyModel.shared.busyJobs.insert(job.id.raw)
            let result = await LupyHTTP.perform(job.http)
            LupyModel.shared.busyJobs.remove(job.id.raw)
            guard !isStopped else { return }
            let outcome: ModelJobResult
            do {
                outcome = try engine.completeModelJob(job.id, status: result.status, headers: result.headers, body: result.body,
                                                      latencyMillis: result.latencyMillis)
            } catch { stop(reason: "\(error)"); return }
            LupyModel.shared.run(outcome.effects)
            guard outcome.ok else { stop(reason: outcome.message); return }
            switch ControlAgent.parse(outcome.message, snapshot: snap) {
            case .step(let s, let why):
                r = run ?? r
                r.append(s)
                run = r
                if !why.isEmpty { agentHistory.append("Plan: \(why)") }
            case .done(let summary):
                r = run ?? r
                r.finish()
                run = r
                agentHistory.append("Done: \(summary)")
                LupyModel.shared.say("Lupy: \(summary)")
            case .askFounder(let q):
                stop(reason: "Lupy needs you: \(q)")
            case .invalid(let why):
                stop(reason: why)
            }
        }
    }

    // MARK: Esc stops; the founder typing pauses

    private func installKeyMonitors() {
        removeKeyMonitors()
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode
            Task { @MainActor in LupyControlCenter.shared.handleKey(code) }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53, LupyControlCenter.shared.isActive {
                LupyControlCenter.shared.stop(reason: "you pressed Esc")
                return nil
            }
            return event
        }
    }

    private func handleKey(_ code: UInt16) {
        guard isActive, Date() > ignoreKeysUntil else { return }
        if code == 53 { stop(reason: "you pressed Esc"); return }
        if run?.state == .running { pause("You're typing, so Lupy paused (it never types over you). Resume when ready.") }
    }

    private func removeKeyMonitors() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
        localKeyMonitor = nil
    }
}

