// LupyProgress.swift — the installer's face.
//
// A tiny native window that stays on screen for the WHOLE install: Lupy's face,
// the current stage, a progress bar fed by the real build, elapsed time and an
// estimated time left that tick every second (proof of life), the live build
// text, and a Cancel button. If the installer ever stops reporting, this window
// says so itself — the founder can always tell WORKING from BROKEN at a glance,
// which is what he asked for after the 3.0/3.1 installer "disappeared" on him
// (the AppleScript progress panel never visibly appeared on his Mac).
//
// Compiled ON THE FOUNDER'S MAC by Install-LUPY at install time, with the same
// free Command Line Tools that then build LUPY himself — so it only ever exists
// where it can run, nothing extra is downloaded, and Gatekeeper never meets a
// stranger (locally compiled code carries no quarantine). If this compile or
// launch ever fails, the installer falls back to self-refreshing dialogues:
// there is no silent path left.
//
// Deliberately conservative AppKit (decades-stable APIs, absolute frames, one
// timer on the main run loop): it must compile first-try on a Mac no one here
// can see. Syntax-checked in the sandbox via tools/swiftwasm; its runtime
// behaviour is part of the founder's kit acceptance, like all macOS surfaces.
//
// argv: 1 statusFile  2 doneFile  3 cancelFile  4 heartbeatFile  5 buildLog  6 iconPath
// status format, written by the installer shell: PCT|STAGE|DETAIL
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

let app = NSApplication.shared
app.setActivationPolicy(.regular)

final class Face: NSObject, NSApplicationDelegate {
    var win: NSWindow!
    var stageLabel: NSTextField!
    var detailLabel: NSTextField!
    var timeLabel: NSTextField!
    var bar: NSProgressIndicator!
    var logView: NSTextView!
    var cancelBtn: NSButton!

    let started = Date()
    var lastLogText = ""
    var etaSmooth: Double = -1
    var finishingTicks = -1
    var cancelPressed = false

    func makeLabel(_ s: String, size: CGFloat, bold: Bool, color: NSColor, rect: NSRect) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.frame = rect
        t.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        t.textColor = color
        t.lineBreakMode = .byTruncatingTail
        return t
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let W: CGFloat = 520
        let H: CGFloat = 400
        win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H),
                       styleMask: [.titled], backing: .buffered, defer: false)
        win.title = "Installing LUPY"
        win.level = .floating            // stays visible; no close button to fat-finger
        win.isReleasedWhenClosed = false
        win.center()
        let v = win.contentView!
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(calibratedRed: 16.0/255.0, green: 16.0/255.0,
                                           blue: 19.0/255.0, alpha: 1).cgColor

        if let img = NSImage(contentsOfFile: iconPath) {
            let iv = NSImageView(frame: NSRect(x: 20, y: H - 86, width: 64, height: 64))
            iv.image = img
            iv.imageScaling = .scaleProportionallyUpOrDown
            v.addSubview(iv)
            app.applicationIconImage = img
        }

        let white = NSColor.white
        let gray = NSColor(calibratedWhite: 0.78, alpha: 1)
        let dim = NSColor(calibratedWhite: 0.55, alpha: 1)

        v.addSubview(makeLabel("Installing LUPY", size: 18, bold: true, color: white,
                               rect: NSRect(x: 100, y: H - 58, width: W - 120, height: 24)))
        stageLabel = makeLabel("Preparing…", size: 13.5, bold: false, color: gray,
                               rect: NSRect(x: 100, y: H - 84, width: W - 120, height: 20))
        v.addSubview(stageLabel)

        bar = NSProgressIndicator(frame: NSRect(x: 20, y: H - 122, width: W - 40, height: 14))
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = 100
        bar.isIndeterminate = true
        bar.startAnimation(nil)
        v.addSubview(bar)

        timeLabel = makeLabel("", size: 12, bold: false, color: dim,
                              rect: NSRect(x: 20, y: H - 148, width: W - 40, height: 18))
        v.addSubview(timeLabel)
        detailLabel = makeLabel("", size: 12, bold: false, color: gray,
                                rect: NSRect(x: 20, y: H - 170, width: W - 40, height: 18))
        v.addSubview(detailLabel)

        let logRect = NSRect(x: 20, y: 58, width: W - 40, height: H - 170 - 74)
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

        v.addSubview(makeLabel("You can move this window aside — LUPY keeps installing and tells you when he's done.",
                               size: 11, bold: false, color: dim,
                               rect: NSRect(x: 20, y: 24, width: W - 170, height: 16)))
        cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(pressedCancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.frame = NSRect(x: W - 124, y: 16, width: 104, height: 30)
        v.addSubview(cancelBtn)

        win.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(tick),
                             userInfo: nil, repeats: true)
        tick()
    }

    @objc func pressedCancel() {
        cancelPressed = true
        FileManager.default.createFile(atPath: cancelPath, contents: nil)
        cancelBtn.isEnabled = false
        stageLabel.stringValue = "Cancelling…"
    }

    func fmt(_ s: TimeInterval) -> String {
        let t = max(0, Int(s))
        return "\(t / 60):" + String(format: "%02d", t % 60)
    }

    @objc func tick() {
        let fm = FileManager.default
        let now = Date()
        let elapsed = now.timeIntervalSince(started)

        // finished? close politely; the installer's own dialogue follows
        if fm.fileExists(atPath: donePath) {
            if finishingTicks < 0 {
                finishingTicks = 2
                bar.isIndeterminate = false
                bar.doubleValue = 100
                stageLabel.stringValue = "Finishing…"
            } else if finishingTicks == 0 {
                app.terminate(nil)
                return
            }
            finishingTicks -= 1
            return
        }

        // the stage line from the installer shell: PCT|STAGE|DETAIL
        var pct = -1
        if let raw = try? String(contentsOfFile: statusPath, encoding: .utf8) {
            let line = raw.split(separator: "\n").first.map(String.init) ?? ""
            let f = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            if f.count >= 2 {
                pct = Int(f[0].trimmingCharacters(in: .whitespaces)) ?? -1
                if !cancelPressed { stageLabel.stringValue = f[1] }
                detailLabel.stringValue = f.count >= 3 ? f[2] : ""
            }
        }

        if pct >= 0 {
            if bar.isIndeterminate {
                bar.isIndeterminate = false
                bar.stopAnimation(nil)
            }
            bar.doubleValue = Double(min(100, pct))
        }

        // heartbeat: WORKING vs BROKEN, in the founder's own window
        var heartAge: TimeInterval = -1
        if let attrs = try? fm.attributesOfItem(atPath: heartPath),
           let mtime = attrs[.modificationDate] as? Date {
            heartAge = now.timeIntervalSince(mtime)
        }
        if heartAge > 25 && elapsed > 30 {
            timeLabel.textColor = NSColor.systemOrange
            timeLabel.stringValue = "Working for \(fmt(elapsed)) — but no news from the installer for \(Int(heartAge))s. If this stays, screenshot me."
        } else {
            timeLabel.textColor = NSColor(calibratedWhite: 0.55, alpha: 1)
            var eta = "estimating the time…"
            if pct >= 5 && elapsed >= 20 {
                let guess = elapsed * Double(100 - pct) / Double(pct)
                etaSmooth = etaSmooth < 0 ? guess : etaSmooth * 0.7 + guess * 0.3
                let left = min(etaSmooth, 15 * 60)
                eta = left < 50 ? "under a minute to go" : "about \(Int((left / 60).rounded(.up))) min to go"
            }
            timeLabel.stringValue = "Working · \(fmt(elapsed)) elapsed · \(eta)"
        }

        // the live build text (tail), so progress can be SEEN, not believed
        if let data = try? Data(contentsOf: URL(fileURLWithPath: logPath)), !data.isEmpty {
            let tail = data.count > 8192 ? data.suffix(8192) : data
            let text = String(decoding: tail, as: UTF8.self)
            let lines = text.split(separator: "\n").suffix(9).joined(separator: "\n")
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
