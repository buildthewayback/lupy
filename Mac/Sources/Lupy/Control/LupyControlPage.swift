// Lupy — the Computer control page (in Coucou's window style), the card on Today while Lupy is
// using the Mac, and the short card in Assistant settings.

import AppKit
import LupyCore
import SwiftUI

struct LupyControlPage: View {
    @State private var goal = ""
    @State private var refresh = 0

    var body: some View {
        let control = LupyControlCenter.shared
        let model = LupyModel.shared
        let trusted = LupyAX.isTrusted()
        let _ = refresh
        HubPageScaffold(title: HubPage.lupyControl.lupyTitle, subtitle: HubPage.lupyControl.lupySubtitle) {
            if control.isActive {
                Button("Stop") { control.stop(reason: "you pressed Stop") }.buttonStyle(LupyDangerButtonStyle())
            }
        } content: {
            HubGlowCard(color: Color(hex: "#F472B6"), padding: 22) {
                HStack(alignment: .top, spacing: 16) {
                    HubLiveMochi(size: 50, state: control.isActive ? .working : .idle, outfit: .sunglasses)
                        .frame(width: 56, height: 50)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(control.enabled ? "Lupy may operate apps when you ask" : "Computer control is off")
                            .font(.system(size: 18, weight: .bold))
                        Text("Lupy never moves your pointer. It presses buttons and fills fields directly through macOS Accessibility, and its own orange cursor with Lupy on it shows you each real action. Esc or Stop ends it at once; if you start typing, it pauses.")
                            .font(.system(size: 13)).foregroundColor(Color(hex: "#B7BBC2"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Toggle("", isOn: Binding(get: { control.enabled }, set: { control.enabled = $0; refresh &+= 1 }))
                        .toggleStyle(.switch).labelsHidden()
                        .accessibilityLabel("Let Lupy operate apps")
                }
                HubDivider()
                HubRow(title: "macOS permission (Accessibility)",
                       detail: trusted ? "Allowed. You can remove it any time in System Settings → Privacy & Security → Accessibility."
                                       : "Needed so Lupy can see and press buttons in other apps. macOS asks you; nothing changes until you allow it.") {
                    if trusted {
                        Label("Allowed", systemImage: "checkmark.seal.fill").foregroundColor(HubTheme.green).font(.system(size: 12.5, weight: .semibold))
                    } else {
                        Button("Allow in System Settings…") {
                            _ = LupyAX.isTrusted(prompt: true)
                            LupyAX.openAccessibilitySettings()
                            refresh &+= 1
                        }
                        .buttonStyle(HubButtonStyle(primary: true))
                    }
                }
            }

            if let r = control.run ?? control.lastRun {
                LupyRunCard(run: r, active: control.isActive)
            }

            HStack(alignment: .top, spacing: 14) {
                HubCard(padding: 18) {
                    Text("Try it safely").font(.system(size: 14, weight: .bold))
                    Text("Lupy creates a note in Documents/Lupy, opens it in TextEdit and types a line while you watch its cursor. Nothing leaves your Mac.")
                        .font(.system(size: 12.5)).foregroundColor(HubTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Show me") { LupyControlDemo.start() }
                        .buttonStyle(HubButtonStyle(primary: true))
                        .disabled(control.isActive)
                }
                .frame(maxWidth: .infinity)
                HubCard(padding: 18) {
                    Text("Do something on screen").font(.system(size: 14, weight: .bold))
                    Text(model.hasUsableModel ? "Your cloud model picks each step from what is on screen; Lupy shows and checks every step, and asks before anything consequential."
                                              : "Needs a cloud model you approved (Lupy → Assistant). Delivering handoffs and the demo work without one.")
                        .font(.system(size: 12.5)).foregroundColor(HubTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        HubField(placeholder: "e.g. Open Safari and search for Displate artist payouts", text: $goal) { run() }
                        Button("Do it", action: run)
                            .buttonStyle(HubButtonStyle(primary: true))
                            .disabled(goal.trimmingCharacters(in: .whitespaces).isEmpty || control.isActive || !model.hasUsableModel)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HubCard(padding: 18) {
                Text("What Lupy always asks you first").font(.system(size: 14, weight: .bold))
                VStack(alignment: .leading, spacing: 6) {
                    Label("Sending, posting or publishing, deleting, paying, granting access, signing in or confirming — on the notch card or in Needs you.", systemImage: "hand.raised")
                    Label("Never types passwords, PINs or verification codes, and stops at CAPTCHA or two-factor screens: you do those.", systemImage: "lock.shield")
                    Label("In Prepare mode it also asks before moving around an app; in Act within limits it moves freely and still asks for the above.", systemImage: "slider.horizontal.3")
                    Label("Pausing Lupy stops computer control. Every step is in Activity with what was actually observed.", systemImage: "pause.circle")
                }
                .font(.system(size: 12.5))
                .foregroundColor(HubTheme.body)
            }

            LupyDeliveryTargetsCard()
        }
    }

    private func run() {
        let g = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !g.isEmpty else { return }
        if LupyControlCenter.shared.startAgent(goal: g) { goal = "" }
    }
}

/// A session: its steps with their real states.
struct LupyRunCard: View {
    let run: ControlRun
    let active: Bool

    var body: some View {
        HubCard(padding: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(run.title).font(.system(size: 14, weight: .bold)).lineLimit(2)
                    Text(run.summary).font(.system(size: 12)).foregroundColor(HubTheme.secondary)
                }
                Spacer()
                if active {
                    if run.state == .paused {
                        Button("Resume") { LupyControlCenter.shared.resume() }.buttonStyle(HubButtonStyle(primary: true))
                    } else {
                        Button("Pause") { LupyControlCenter.shared.pause("Paused by you") }.buttonStyle(HubButtonStyle())
                    }
                    Button("Stop") { LupyControlCenter.shared.stop(reason: "you pressed Stop") }.buttonStyle(LupyDangerButtonStyle())
                }
            }
            ForEach(run.steps) { s in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: Self.icon(s.state)).foregroundColor(Self.color(s.state)).frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).font(.system(size: 12.5, weight: .medium))
                        Text(s.detail.isEmpty ? s.state.label : "\(s.state.label) — \(s.detail)")
                            .font(.system(size: 11.5)).foregroundColor(HubTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if let k = s.kind { LupyStatusChip(text: k.label, color: k.risk >= .high ? LupyTheme.amber : LupyTheme.secondary) }
                }
            }
        }
    }

    static func icon(_ s: ControlStepState) -> String {
        switch s {
        case .pending: return "circle"
        case .locating: return "scope"
        case .awaitingApproval: return "hand.raised.fill"
        case .executing: return "cursorarrow.click"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .skipped: return "minus.circle"
        case .stopped: return "stop.circle"
        }
    }

    static func color(_ s: ControlStepState) -> Color {
        switch s {
        case .succeeded: return HubTheme.green
        case .failed: return HubTheme.red
        case .awaitingApproval: return LupyTheme.amber
        case .executing, .locating: return HubTheme.accent
        default: return HubTheme.secondary
        }
    }
}

/// Where Lupy delivers to each agent you relay to by hand.
struct LupyDeliveryTargetsCard: View {
    @State private var drafts: [String: String] = [:]

    var body: some View {
        let workers = LupyModel.shared.state.workers.values.filter { $0.enabled && $0.channel == .manualRelay }.sorted { $0.name < $1.name }
        HubCard(padding: 18) {
            Text("Where Lupy delivers your handoffs").font(.system(size: 14, weight: .bold))
            Text("The page (https://…) or app where you talk to each agent. “Deliver with Lupy” on a handoff opens it, types the brief and asks you before clicking Send.")
                .font(.system(size: 12.5)).foregroundColor(HubTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(workers) { w in
                HubRow(title: w.name, detail: "Now: \(LupyDelivery.describe(LupyDelivery.target(for: w)))") {
                    HStack(spacing: 8) {
                        HubField(placeholder: LupyDelivery.isChatGPT(w) ? "ChatGPT app, or https://chatgpt.com" : "https://…",
                                 text: Binding(get: { drafts[w.id.raw] ?? LupyDelivery.savedTarget(for: w) },
                                               set: { drafts[w.id.raw] = $0 }))
                            .frame(width: 280)
                        Button("Save") {
                            let v = drafts[w.id.raw] ?? LupyDelivery.savedTarget(for: w)
                            let lower = v.lowercased()
                            if v.isEmpty || lower.hasPrefix("https://") || lower.hasPrefix("app:") {
                                LupyDelivery.setTarget(v, for: w)
                                LupyModel.shared.say(v.isEmpty ? "Cleared." : "Saved: Lupy delivers to \(w.name) at \(v).")
                            } else {
                                LupyModel.shared.say("Use a page starting with https:// (or leave empty).")
                            }
                        }
                        .buttonStyle(HubButtonStyle())
                    }
                }
            }
        }
    }
}

/// Today: what Lupy is doing on screen right now (or did last).
struct LupyControlStatusCard: View {
    var body: some View {
        let control = LupyControlCenter.shared
        if let r = control.run ?? control.lastRun {
            HStack(spacing: 12) {
                HubLiveMochi(size: 30, state: control.isActive ? .working : (r.state == .finished ? .finished : .error))
                    .frame(width: 36, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(control.isActive ? "Lupy is using your Mac" : "Last computer-control session").font(.system(size: 13, weight: .semibold))
                    Text(control.isActive ? control.statusLine : "\(r.title) — \(r.summary)")
                        .font(.system(size: 12)).foregroundColor(HubTheme.secondary).lineLimit(2)
                }
                Spacer()
                if control.isActive {
                    Button("Stop") { control.stop(reason: "you pressed Stop") }.buttonStyle(LupyDangerButtonStyle())
                }
                Button("Details") { LupyModel.shared.open(.lupyControl) }.buttonStyle(HubButtonStyle())
            }
            .padding(14)
            .background(LupyCardBackground(wash: control.isActive ? .pink : .soft))
        }
    }
}

/// Assistant settings: the short version, linking to the full page.
struct LupyControlSettings: View {
    var body: some View {
        let control = LupyControlCenter.shared
        LupySettingsCard(title: "Computer control (the Lupy cursor)",
                         subtitle: "Off until you turn it on. Lupy always asks before sending, deleting, paying or granting access, and never types passwords.") {
            HStack {
                Toggle("Let Lupy operate apps when you ask", isOn: Binding(get: { control.enabled }, set: { control.enabled = $0 }))
                    .toggleStyle(.switch)
                Spacer()
                Text(LupyAX.isTrusted() ? "Accessibility: allowed" : "Accessibility: not allowed yet")
                    .font(.system(size: 12)).foregroundColor(LupyAX.isTrusted() ? HubTheme.green : LupyTheme.amber)
                Button("Open Computer control…") { LupyModel.shared.open(.lupyControl) }.buttonStyle(LupySecondaryButtonStyle())
            }
        }
    }
}

/// The safe demo: a note in Documents/Lupy, opened in TextEdit, one line typed while you watch.
@MainActor
enum LupyControlDemo {
    static func noteURL() -> URL {
        LupyModel.shared.deliverablesFolder.appendingPathComponent("Lupy cursor demo.txt")
    }

    static func start() {
        let url = noteURL()
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) { try Data().write(to: url) }
        } catch {
            LupyModel.shared.say("Could not create the demo note: \(error.localizedDescription)")
            return
        }
        let line = "Hello from Lupy — typed with computer control at \(Date().formatted(date: .omitted, time: .shortened)). You watched every step."
        let steps: [ControlStep] = [
            .openURL(url.absoluteString),
            .waitFor(ElementQuery([], role: .textInput), seconds: 15),
            .setText(ElementQuery([], role: .textInput), text: line),
            .read(ElementQuery([], role: .textInput)),
        ]
        LupyControlCenter.shared.start(title: "Show me: write a line in TextEdit", steps: steps, byFounder: true)
    }
}
