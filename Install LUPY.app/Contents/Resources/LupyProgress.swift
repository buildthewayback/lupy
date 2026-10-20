// LupyProgress.swift — the installer's face (v3, the proper Setup window).
//
// Founder law, learned over three field runs on his real Mac:
//   · v3.0/3.1 "disappeared" (an invisible AppleScript progress panel);
//   · v3.2 stayed visible but was glued on top with no minimize and only one
//     overall bar — he asked for "the standard way … not always stays on top
//     but anytime can see … step by step … so we know if did work, show what
//     error so I can show or tell you".
// So this window is STANDARD macOS: normal level, minimize button, lives in
// the Dock with the % on its icon (click to peek any time), close button
// tucks it away (the install continues; Cancel is the explicit stop). It
// shows six named steps, each waiting/doing/done/failed with its own time,
// the live build text, a heartbeat that confesses if the installer goes
// quiet, and a freeze-warning when the build stops moving. At the end it
// becomes the proof screen — all-green checklist, or the exact failed step
// in plain words — and stays until HE closes it, with a Save-report button.
//
// Compiled on the founder's Mac by Install-LUPY at install time with the same
// free Command Line Tools that then build LUPY: nothing extra downloaded, no
// quarantine, Gatekeeper never meets a stranger. If its compile or launch
// fails, the installer falls back to self-refreshing dialogues — never silence.
// Conservative, decades-stable AppKit only: it must compile first-try on a
// Mac nobody here can see. (Syntax-checked in the sandbox via swiftwasm.)
//
// argv: 1 faceStatus  2 doneFile  3 cancelFile  4 heartbeatFile
//       5 buildLog    6 iconPath  7 resultFile  8 reportFile
// face-status v3, single writer = the installer shell:
//   3|<overallPct>|<6 step chars . > + ! ->|<flags>|<detail>
// result file: OK | FAIL|<step1based>|<reason> | CANCELLED
import AppKit
import Foundation

let argv = CommandLine.arguments
func arg(_ i: Int) -> String { i < argv.count ? argv[i] : "" }
let statusPath = arg(1)
let donePath = arg(2)
let cancelPath = arg(3)
let heartPath = arg(4)
let logPath = arg(5)
let iconPath = arg(6)
let resultPath = arg(7)
let reportPath = arg(8)

// The six steps, byte-identical to Install-LUPY's STEP_NAMES
// (scripts/body-checks.sh step 6b greps both files so they cannot drift).
let STEP_NAMES = ["Check this Mac", "Apple's free tools", "Download one small library",
                  "Compile LUPY", "Install into Applications", "Launch & prove he's alive"]

let app = NSApplication.shared
app.setActivationPolicy(.regular)

final class DockView: NSView {
    var image: NSImage?
    var pct: Double = -1
    override func draw(_ dirtyRect: NSRect) {
        if let img = image { img.draw(in: bounds) }
        guard pct >= 0 else { return }
        let bg = NSRect(x: 8, y: 6, width: bounds.width - 16, height: 10)
        NSColor(calibratedWhite: 0, alpha: 0.55).setFill()
        NSBezierPath(roundedRect: bg, xRadius: 5, yRadius: 5).fill()
        let w = (bounds.width - 20) * CGFloat(min(100, max(0, pct))) / 100
        if w > 0 {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: NSRect(x: 10, y: 8, width: w, height: 6),
                         xRadius: 3, yRadius: 3).fill()
        }
    }
}

final class Face: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var win: NSWindow!
    var overallLabel: NSTextField!
    var detailLabel: NSTextField!
    var bar: NSProgressIndicator!
    var logView: NSTextView!
    var hintLabel: NSTextField!
    var cancelBtn: NSButton!
    var finderBtn: NSButton!
    var saveBtn: NSButton!
    var closeBtn: NSButton!
    var symLabels: [NSTextField] = []
    var nameLabels: [NSTextField] = []
    var timeLabels: [NSTextField] = []
    var dockView: DockView!

    let started = Date()
    var finished = false
    var cancelPressed = false
    var lastLogText = ""
    var lastPct = -1
    var etaSmooth: Double = -1
    var prevStates = "......"
    var stepBegan: [Date?] = Array(repeating: nil, count: 6)
    var stepEnded: [Date?] = Array(repeating: nil, count: 6)

    func makeLabel(_ s: String, size: CGFloat, bold: Bool, color: NSColor,
                   rect: NSRect, align: NSTextAlignment = .left) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.frame = rect
        t.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        t.textColor = color
        t.alignment = align
        t.lineBreakMode = .byTruncatingTail
        return t
    }

    func makeButton(_ title: String, action: Selector, rect: NSRect) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.frame = rect
        return b
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let W: CGFloat = 560
        let H: CGFloat = 540
        win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H),
                       styleMask: [.titled, .closable, .miniaturizable],
                       backing: .buffered, defer: false)
        win.title = "Installing LUPY"
        win.level = .normal                    // a standard window, not glued on top
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()
        let v = win.contentView!
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(calibratedRed: 16.0/255.0, green: 16.0/255.0,
                                           blue: 19.0/255.0, alpha: 1).cgColor

        let white = NSColor.white
        let gray = NSColor(calibratedWhite: 0.78, alpha: 1)
        let dim = NSColor(calibratedWhite: 0.5, alpha: 1)

        // always exists (tick/finish poke it); becomes the Dock art only if the icon loads
        dockView = DockView(frame: NSRect(origin: .zero, size: app.dockTile.size))
        if let img = NSImage(contentsOfFile: iconPath) {
            let iv = NSImageView(frame: NSRect(x: 20, y: H - 86, width: 64, height: 64))
            iv.image = img
            iv.imageScaling = .scaleProportionallyUpOrDown
            v.addSubview(iv)
            app.applicationIconImage = img
            dockView.image = img
            app.dockTile.contentView = dockView
        }

        v.addSubview(makeLabel("Installing LUPY", size: 18, bold: true, color: white,
                               rect: NSRect(x: 100, y: H - 58, width: W - 120, height: 24)))
        overallLabel = makeLabel("Starting…", size: 12.5, bold: false, color: gray,
                                 rect: NSRect(x: 100, y: H - 84, width: W - 120, height: 20))
        v.addSubview(overallLabel)

        bar = NSProgressIndicator(frame: NSRect(x: 20, y: H - 110, width: W - 40, height: 12))
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = 100
        bar.isIndeterminate = true
        bar.startAnimation(nil)
        v.addSubview(bar)

        // the six steps, top to bottom
        let rowH: CGFloat = 27
        let stepsTop = H - 138
        for i in 0..<6 {
            let y = stepsTop - CGFloat(i + 1) * rowH + 4
            let sym = makeLabel("○", size: 13, bold: true, color: dim,
                                rect: NSRect(x: 22, y: y, width: 22, height: 20), align: .center)
            let name = makeLabel(STEP_NAMES[i], size: 13, bold: false, color: dim,
                                 rect: NSRect(x: 52, y: y, width: W - 182, height: 20))
            let time = makeLabel("", size: 11.5, bold: false, color: dim,
                                 rect: NSRect(x: W - 118, y: y, width: 98, height: 20), align: .right)
            symLabels.append(sym); nameLabels.append(name); timeLabels.append(time)
            v.addSubview(sym); v.addSubview(name); v.addSubview(time)
        }
        let stepsBottom = stepsTop - 6 * rowH

        detailLabel = makeLabel("", size: 12, bold: false, color: gray,
                                rect: NSRect(x: 20, y: stepsBottom - 26, width: W - 40, height: 18))
        v.addSubview(detailLabel)

        let logRect = NSRect(x: 20, y: 60, width: W - 40, height: stepsBottom - 26 - 60 - 14)
        let scroll = NSScrollView(frame: logRect)
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: logRect.width, height: logRect.height))
        tv.minSize = NSSize(width: 0, height: logRect.height)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.containerSize = NSSize(width: logRect.width, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        tv.isEditable = false
        tv.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 1)
        tv.textColor = NSColor(calibratedWhite: 0.82, alpha: 1)
        tv.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        tv.string = "The build text will flow here…"
        scroll.documentView = tv
        logView = tv
        v.addSubview(scroll)

        hintLabel = makeLabel("You can minimize me — the Dock icon shows the %; click it to peek any time.",
                              size: 11, bold: false, color: dim,
                              rect: NSRect(x: 20, y: 24, width: W - 170, height: 16))
        v.addSubview(hintLabel)

        cancelBtn = makeButton("Cancel", action: #selector(pressedCancel),
                               rect: NSRect(x: W - 124, y: 16, width: 104, height: 30))
        closeBtn = makeButton("Close", action: #selector(pressedClose),
                              rect: NSRect(x: W - 124, y: 16, width: 104, height: 30))
        saveBtn = makeButton("Save report…", action: #selector(pressedSave),
                             rect: NSRect(x: W - 252, y: 16, width: 120, height: 30))
        finderBtn = makeButton("Show in Finder", action: #selector(pressedFinder),
                               rect: NSRect(x: W - 388, y: 16, width: 128, height: 30))
        closeBtn.isHidden = true; saveBtn.isHidden = true; finderBtn.isHidden = true
        v.addSubview(cancelBtn); v.addSubview(closeBtn); v.addSubview(saveBtn); v.addSubview(finderBtn)

        win.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(tick),
                             userInfo: nil, repeats: true)
        tick()
    }

    // ── standard window manners ──────────────────────────────────────────────
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if finished { return true }
        win.miniaturize(nil)          // tuck away; the install continues
        return false
    }
    func windowWillClose(_ notification: Notification) {
        if finished { app.terminate(nil) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if win.isMiniaturized { win.deminiaturize(nil) }
        win.makeKeyAndOrderFront(nil)
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !finished { FileManager.default.createFile(atPath: cancelPath, contents: nil) }
        return .terminateNow
    }

    // ── buttons ──────────────────────────────────────────────────────────────
    @objc func pressedCancel() {
        cancelPressed = true
        FileManager.default.createFile(atPath: cancelPath, contents: nil)
        cancelBtn.isEnabled = false
        overallLabel.stringValue = "Cancelling…"
    }
    @objc func pressedClose() { app.terminate(nil) }
    @objc func pressedFinder() {
        NSWorkspace.shared.selectFile("/Applications/Lupy.app", inFileViewerRootedAtPath: "/Applications")
    }
    @objc func pressedSave() {
        let panel = NSSavePanel()
        panel.title = "Save the install report"
        panel.nameFieldStringValue = "Lupy install report.txt"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        if panel.runModal() == .OK, let url = panel.url {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.copyItem(atPath: reportPath, toPath: url.path)
        }
    }

    // ── rendering ────────────────────────────────────────────────────────────
    func fmt(_ s: TimeInterval) -> String {
        let t = max(0, Int(s))
        return "\(t / 60):" + String(format: "%02d", t % 60)
    }

    func renderSteps(states: String, now: Date) {
        let dim = NSColor(calibratedWhite: 0.5, alpha: 1)
        let chars = Array(states)
        for i in 0..<6 {
            let c: Character = i < chars.count ? chars[i] : "."
            let prev: Character = i < Array(prevStates).count ? Array(prevStates)[i] : "."
            if c != prev {
                if c == ">" && stepBegan[i] == nil { stepBegan[i] = now }
                if (c == "+" || c == "!" || c == "-") && stepEnded[i] == nil { stepEnded[i] = now }
            }
            switch c {
            case ">":
                symLabels[i].stringValue = "●"
                symLabels[i].textColor = .white
                nameLabels[i].textColor = .white
                nameLabels[i].font = NSFont.boldSystemFont(ofSize: 13)
                if let b = stepBegan[i] { timeLabels[i].stringValue = fmt(now.timeIntervalSince(b)) }
            case "+":
                symLabels[i].stringValue = "✓"
                symLabels[i].textColor = .systemGreen
                nameLabels[i].textColor = NSColor(calibratedWhite: 0.82, alpha: 1)
                nameLabels[i].font = NSFont.systemFont(ofSize: 13)
                if let b = stepBegan[i], let e = stepEnded[i] { timeLabels[i].stringValue = fmt(e.timeIntervalSince(b)) }
            case "!":
                symLabels[i].stringValue = "✗"
                symLabels[i].textColor = .systemRed
                nameLabels[i].textColor = .white
                nameLabels[i].font = NSFont.boldSystemFont(ofSize: 13)
            case "-":
                symLabels[i].stringValue = "–"
                symLabels[i].textColor = dim
                nameLabels[i].textColor = dim
            default:
                symLabels[i].stringValue = "○"
                symLabels[i].textColor = dim
                nameLabels[i].textColor = dim
            }
        }
        prevStates = states
    }

    func finishUI() {
        finished = true
        cancelBtn.isHidden = true
        hintLabel.isHidden = true
        closeBtn.isHidden = false
        saveBtn.isHidden = false
        bar.isIndeterminate = false
        bar.stopAnimation(nil)

        var kind = "CANCELLED"
        var reason = ""
        var failStep = 0
        if let raw = try? String(contentsOfFile: resultPath, encoding: .utf8) {
            let line = raw.split(separator: "\n").first.map(String.init) ?? ""
            let f = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            if !f.isEmpty { kind = f[0] }
            if f.count >= 3 { failStep = Int(f[1]) ?? 0; reason = f[2] }
        }

        let tile = app.dockTile
        switch kind {
        case "OK":
            bar.doubleValue = 100
            dockView.pct = 100
            tile.badgeLabel = "✓"
            overallLabel.stringValue = "✓ Installed and running"
            detailLabel.stringValue = "He's the small dark pill at the top centre of your screen, under the menu bar."
            finderBtn.isHidden = false
            closeBtn.keyEquivalent = "\r"
        case "FAIL":
            tile.badgeLabel = "!"
            overallLabel.stringValue = "✗ Didn't finish"
            let stepBit = (failStep >= 1 && failStep <= 6) ? "Step \(failStep) (\(STEP_NAMES[failStep - 1]))" : "The build"
            detailLabel.stringValue = reason.isEmpty ? "\(stepBit) stopped. Save the report and send it — a fixed kit comes back."
                                                     : "\(stepBit): \(reason)"
            detailLabel.textColor = .systemOrange
            saveBtn.keyEquivalent = "\r"
        default:
            tile.badgeLabel = nil
            overallLabel.stringValue = "Install cancelled"
            detailLabel.stringValue = "Nothing was changed. Double-click Install LUPY any time to try again."
        }
        tile.display()
        _ = app.requestUserAttention(.criticalRequest)   // bounce the Dock icon: "I'm done"
        win.title = (kind == "OK") ? "LUPY is installed" : "Install LUPY"
    }

    @objc func tick() {
        let fm = FileManager.default
        let now = Date()
        let elapsed = now.timeIntervalSince(started)

        if !finished && fm.fileExists(atPath: donePath) {
            finishUI()
            return
        }
        if finished { return }

        // the v3 status line: 3|<pct>|<states>|<flags>|<detail>
        var pct = -1
        var stuck = false
        if let raw = try? String(contentsOfFile: statusPath, encoding: .utf8) {
            let line = raw.split(separator: "\n").first.map(String.init) ?? ""
            let f = line.split(separator: "|", maxSplits: 4, omittingEmptySubsequences: false).map(String.init)
            if f.count >= 4 && f[0] == "3" {
                pct = Int(f[1].trimmingCharacters(in: .whitespaces)) ?? -1
                renderSteps(states: f[2], now: now)
                stuck = f[3].contains("STUCK")
                detailLabel.stringValue = f.count >= 5 ? f[4] : ""
            }
        }

        if pct >= 0 {
            if bar.isIndeterminate { bar.isIndeterminate = false; bar.stopAnimation(nil) }
            bar.doubleValue = Double(min(100, pct))
        }

        // heartbeat: WORKING vs BROKEN at a glance
        var heartAge: TimeInterval = -1
        if let attrs = try? fm.attributesOfItem(atPath: heartPath),
           let mtime = attrs[.modificationDate] as? Date {
            heartAge = now.timeIntervalSince(mtime)
        }
        if !cancelPressed {
            if heartAge > 25 && elapsed > 30 {
                overallLabel.textColor = .systemOrange
                overallLabel.stringValue = "Working for \(fmt(elapsed)) — but no news from the installer for \(Int(heartAge))s. If this stays, screenshot me."
            } else {
                overallLabel.textColor = NSColor(calibratedWhite: 0.78, alpha: 1)
                var eta = "estimating the time…"
                if pct >= 5 && elapsed >= 20 {
                    let guess = elapsed * Double(100 - pct) / Double(pct)
                    etaSmooth = etaSmooth < 0 ? guess : etaSmooth * 0.7 + guess * 0.3
                    let left = min(etaSmooth, 20 * 60)
                    eta = left < 50 ? "under a minute to go" : "about \(Int((left / 60).rounded(.up))) min to go"
                }
                overallLabel.stringValue = "Working · \(fmt(elapsed)) elapsed · \(eta)"
            }
            detailLabel.textColor = stuck ? .systemOrange : NSColor(calibratedWhite: 0.78, alpha: 1)
        }

        // the Dock tells the truth even while minimized
        if pct >= 0 && pct != lastPct {
            lastPct = pct
            dockView.pct = Double(pct)
            app.dockTile.badgeLabel = "\(pct)%"
            app.dockTile.display()
        }

        // the live build text (tail), so progress can be SEEN, not believed
        if let data = try? Data(contentsOf: URL(fileURLWithPath: logPath)), !data.isEmpty {
            let tail = data.count > 8192 ? data.suffix(8192) : data
            let text = String(decoding: tail, as: UTF8.self)
            let lines = text.split(separator: "\n").suffix(10).joined(separator: "\n")
            if lines != lastLogText {
                lastLogText = lines
                logView.string = lines
                logView.scrollToEndOfDocument(nil)
            }
        }
    }
}

let face = Face()
app.delegate = face
app.run()
