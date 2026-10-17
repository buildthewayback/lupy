// Lupy — computer-control self-test (CI and support):
//   Lupy.app/Contents/MacOS/Lupy --control-self-test [--report path] [--status path] [--data-dir dir]
// Real checks with the real executor, Accessibility and the Lupy cursor:
//  1. the overlay is click-through and above apps (always);
//  2. typing into TextEdit with the read-back verified, and the steps recorded in the action ledger;
//  3. Stop cancels the queued step: its text never reaches the document;
//  4. a target that is not on screen fails honestly and nothing is clicked;
//  5. on a local chat page in Safari: a declined Send is not sent; an approved Send is sent and
//     observed on screen; a password field is refused.
// Without Accessibility permission the checks that need it are reported BLOCKED, never PASS.
// `--status` receives one line per phase so CI can take screenshots of the cursor at work.

import AppKit
import LupyCore

@MainActor
enum LupyControlSelfTest {
    private static var keepAlive: AnyObject?

    static func runAndExit(arguments: [String]) -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = LupyControlSelfTestDelegate(arguments: arguments)
        keepAlive = delegate
        app.delegate = delegate
        app.run()
        exit(2)
    }

    static func run(arguments: [String]) async -> Int32 {
        var lines: [String] = []
        var failures = 0
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            lines.append("\(ok ? "PASS" : "FAIL") \(name)\(detail.isEmpty ? "" : " — \(detail)")")
            if !ok { failures += 1 }
        }
        func blocked(_ name: String, _ why: String) { lines.append("BLOCKED \(name) — \(why)") }
        let statusPath = arguments.firstIndex(of: "--status").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        func phase(_ p: String) {
            guard let statusPath else { return }
            if let h = FileHandle(forWritingAtPath: statusPath) {
                _ = h.seekToEndOfFile()
                h.write(Data("\(p)\n".utf8))
                try? h.close()
            } else {
                try? "\(p)\n".write(toFile: statusPath, atomically: false, encoding: .utf8)
            }
        }

        lines.append("INFO Lupy control self-test · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        let control = LupyControlCenter.shared
        control.enabled = true
        control.testHoldSeconds = 1.4
        control.testPhase = { phase($0) }
        let trusted = LupyAX.isTrusted()
        lines.append("INFO Accessibility allowed for Lupy: \(trusted ? "yes" : "no")")

        // 1. The overlay: click-through and above every app.
        LupyCursorOverlay.shared.show()
        if let screen = NSScreen.main ?? NSScreen.screens.first, let primary = NSScreen.screens.first {
            let r = UIRect(x: Double(screen.frame.midX - 60), y: Double(primary.frame.maxY - screen.frame.midY - 20), width: 120, height: 40)
            await LupyCursorOverlay.shared.move(to: r, label: "Overlay check")
        }
        phase("overlay")
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        check("the Lupy cursor overlay never takes the founder's clicks (click-through windows)", LupyCursorOverlay.shared.allPanelsClickThrough,
              "\(LupyCursorOverlay.shared.panelCount) display(s)")
        check("the overlay is drawn above apps", LupyCursorOverlay.shared.allPanelsAboveApps)
        LupyCursorOverlay.shared.hide()

        guard trusted else {
            for name in ["typing into TextEdit with read-back", "Stop cancels queued steps", "missing target fails honestly",
                         "declined Send is not sent", "approved Send is sent and observed", "password field refused"] {
                blocked(name, "macOS has not allowed Accessibility for Lupy on this machine")
            }
            lines.append("CONTROLTEST BLOCKED (Accessibility is not allowed for Lupy here, so the checks that use other apps could not run; the overlay checks above did run)")
            let text = lines.joined(separator: "\n")
            print(text)
            if let i = arguments.firstIndex(of: "--report"), i + 1 < arguments.count {
                try? text.write(toFile: arguments[i + 1], atomically: true, encoding: .utf8)
            }
            return 0
        }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lupy-control-selftest", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 2. Typing into TextEdit, read back.
        let note = dir.appendingPathComponent("note.txt")
        try? Data().write(to: note)
        let line = "Hello from Lupy's cursor — control self-test \(Int(Date().timeIntervalSince1970))"
        phase("textedit")
        let run1 = await runToEnd(control, title: "Self-test: type in TextEdit", steps: [
            .openURL(note.absoluteString),
            .waitFor(ElementQuery([], role: .textInput), seconds: 25),
            .setText(ElementQuery([], role: .textInput), text: line),
            .read(ElementQuery([], role: .textInput)),
        ])
        let typed = run1?.steps.last?.detail.contains(String(line.prefix(30))) == true
        check("typing into TextEdit with the result read back", run1?.state == .finished && typed,
              run1.map { "\($0.summary); read-back: \($0.steps.last?.detail ?? "")" } ?? "no run")
        if let r = run1, let engine = LupyModel.shared.engine {
            let recs = engine.state.actions.values.filter { $0.action.idempotencyKey.hasPrefix("ctl:\(r.id):") }
            let verified = recs.filter { $0.state == .succeeded }.count
            check("every executed step is in the action ledger with its verified result", recs.count >= 2 && verified == recs.count,
                  "\(verified)/\(recs.count) recorded and verified")
        }

        // 3. Stop cancels what is still queued.
        let marker = "SHOULD-NOT-APPEAR-\(Int(Date().timeIntervalSince1970))"
        phase("stop")
        control.testHoldSeconds = 0
        let stopTask = Task { @MainActor in
            for _ in 0..<200 {
                if let r = control.run, r.steps.first?.state == .succeeded {
                    control.stop(reason: "self-test pressed Stop")
                    return
                }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }
        let run2 = await runToEnd(control, title: "Self-test: stop", steps: [
            .waitFor(ElementQuery([], role: .textInput), seconds: 10),
            .setText(ElementQuery([], role: .textInput), text: marker),
        ])
        stopTask.cancel()
        let textNow = currentTextAreaValue()
        check("Stop cancels the queued step and its text never reaches the document",
              run2?.state == .stopped && run2?.steps.last?.state == .stopped && !textNow.contains(marker),
              run2.map { "run: \($0.state.rawValue); queued step: \($0.steps.last?.state.rawValue ?? "?")" } ?? "no run")
        control.testHoldSeconds = 1.4

        // 4. A target that is not there.
        phase("missing")
        let run3 = await runToEnd(control, title: "Self-test: missing target", steps: [
            .press(ElementQuery(["Definitely Not A Button 7"], role: .button)),
        ])
        check("a target that is not on screen fails honestly and nothing is clicked",
              run3?.state == .failed && run3?.steps.first?.detail.contains("not on screen") == true, run3?.summary ?? "no run")

        // 5. A chat page in Safari: the Send click waits for the founder.
        let page = dir.appendingPathComponent("chat.html")
        try? chatPage.write(to: page, atomically: true, encoding: .utf8)
        let brief = "Please write the PENGLAI City teaser script, three scenes. (Lupy self-test \(Int(Date().timeIntervalSince1970)))"
        control.autoDecision = false
        phase("declined")
        let run4 = await runToEnd(control, title: "Self-test: declined Send", steps: DeliveryPlan.steps(
            brief: brief, to: DeliveryTarget(appName: "Safari", url: page.absoluteString), send: true))
        if let r = run4, r.steps.count >= 3, r.steps[2].state != .succeeded {
            blocked("declined Send is not sent", "the browser's message box could not be used here: \(r.summary)")
            blocked("approved Send is sent and observed", "same reason")
        } else {
            let sentAfterDecline = LupyDelivery.observeDelivery(brief: brief)
            check("a Send you decline is not sent (the policy gate holds it)",
                  run4?.steps.last?.state == .failed && run4?.steps.last?.detail.contains("declined") == true && !sentAfterDecline,
                  run4?.summary ?? "no run")
            control.autoDecision = true
            phase("approved")
            // A different brief for the approved run: the declined run's text stays in the
            // message box, so observing the SAME string could never prove a send happened.
            let sentBrief = brief + " — approved run"
            let run5 = await runToEnd(control, title: "Self-test: approved Send", steps: [
                .waitFor(ElementQuery(DeliveryPlan.messageBox, role: .textInput), seconds: 10),
                .setText(ElementQuery(DeliveryPlan.messageBox, role: .textInput), text: sentBrief),
                .press(ElementQuery(DeliveryPlan.sendButton, role: .button)),
            ])
            try? await Task.sleep(nanoseconds: 800_000_000)
            let observed = LupyDelivery.observeDelivery(brief: sentBrief)
            phase("sent")
            check("a Send you approve is clicked and the message is then seen on screen", run5?.state == .finished && observed,
                  "run: \(run5?.state.rawValue ?? "none"); \(run5?.summary ?? "no run"); seen on screen: \(observed)")
            // Password field: refused even when asked by element number (as a model would).
            if let app = NSWorkspace.shared.frontmostApplication {
                let (snap, _) = LupyAX.snapshot(of: app)
                if let pw = snap.elements.first(where: { $0.isSecure }) {
                    let run6 = await runToEnd(control, title: "Self-test: password", steps: [.setTextElement(pw.id, text: "not-a-real-password")])
                    check("Lupy refuses to type into a password field", run6?.state == .failed
                          && run6?.steps.first?.detail.contains("never types passwords") == true, run6?.summary ?? "no run")
                } else {
                    blocked("password field refused", "the page's password field was not exposed by the browser")
                }
            }
        }
        control.autoDecision = nil
        phase("done")
        return finish(lines, failures, arguments)
    }

    /// Starts a founder-style run and waits until it is over (60 s at most).
    private static func runToEnd(_ control: LupyControlCenter, title: String, steps: [ControlStep],
                                 note: @escaping (String) -> Void = { print($0) }) async -> ControlRun? {
        // The previous run's finish handler may still be running its last frame. On a
        // slow runner start() then refuses with "already using your Mac", and the test
        // reported "no run" — which blames the feature for the harness's impatience.
        var waited = 0
        while control.isActive && waited < 50 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }
        if let why = control.blocker() {
            note("INFO could not start “\(title)”: \(why)")
            return nil
        }
        guard control.start(title: title, steps: steps, byFounder: true) else { return nil }
        for _ in 0..<600 {
            if !control.isActive { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        if control.isActive { control.stop(reason: "self-test timeout") }
        try? await Task.sleep(nanoseconds: 300_000_000)
        return control.lastRun
    }

    private static func currentTextAreaValue() -> String {
        guard let app = NSWorkspace.shared.frontmostApplication else { return "" }
        let (snap, _) = LupyAX.snapshot(of: app)
        return snap.elements.filter { $0.isTextInput }.map(\.value).joined(separator: "\n")
    }

    private static func finish(_ lines: [String], _ failures: Int, _ arguments: [String]) -> Int32 {
        var out = lines
        out.append("CONTROLTEST \(failures == 0 ? "PASSED" : "FAILED") (\(failures) failure(s))")
        let text = out.joined(separator: "\n")
        print(text)
        if let i = arguments.firstIndex(of: "--report"), i + 1 < arguments.count {
            try? text.write(toFile: arguments[i + 1], atomically: true, encoding: .utf8)
        }
        return failures == 0 ? 0 : 1
    }

    /// A tiny chat page: a message box, a Send button that posts the message into the conversation,
    /// and a password field (which Lupy must refuse to fill).
    static let chatPage = """
    <!doctype html><html><head><meta charset="utf-8"><title>Lupy test chat</title>
    <style>body{font:16px -apple-system;margin:40px;background:#111;color:#eee}#log div{margin:8px 0;padding:10px;background:#222;border-radius:8px}
    textarea{width:520px;height:90px;font-size:15px}button{font-size:15px;padding:8px 18px}</style></head>
    <body><h2>Agent chat (local test page)</h2><div id="log" aria-label="Conversation"></div>
    <textarea id="box" placeholder="Message the agent" aria-label="Message"></textarea><br>
    <button id="send" onclick="var b=document.getElementById('box');if(b.value){var d=document.createElement('div');d.textContent=b.value;document.getElementById('log').appendChild(d);b.value='';}">Send</button>
    <p><label>Account password <input type="password" aria-label="Password"></label></p></body></html>
    """
}

@MainActor
final class LupyControlSelfTestDelegate: NSObject, NSApplicationDelegate {
    let arguments: [String]
    init(arguments: [String]) { self.arguments = arguments }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = arguments
        Task { @MainActor in
            let code = await LupyControlSelfTest.run(arguments: args)
            exit(code)
        }
    }
}
