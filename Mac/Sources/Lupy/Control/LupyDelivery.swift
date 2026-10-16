// Lupy — delivering a handoff with computer control: Lupy opens the agent (Arena, Muse, ChatGPT…),
// types the brief into its message box while the founder watches the Lupy cursor, and asks before
// clicking Send. Afterwards it looks for the message on screen: seen → handoff "sent" (UI evidence
// of delivery, never of the work); not seen → "delivery unconfirmed", exactly as a manual paste.

import AppKit
import LupyCore

@MainActor
enum LupyDelivery {
    private static func key(_ worker: Worker) -> String { "lupyDeliveryTarget." + worker.id.raw }

    /// Where Lupy delivers to this agent: an https page or an app ("app:<bundle id>").
    static func savedTarget(for worker: Worker) -> String {
        UserDefaults.standard.string(forKey: key(worker)) ?? ""
    }

    static func setTarget(_ value: String, for worker: Worker) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(v, forKey: key(worker))
        LupyModel.shared.changed()
    }

    static func isChatGPT(_ worker: Worker) -> Bool {
        let n = worker.name.lowercased()
        return n.contains("chatgpt") || n.contains("orin")
    }

    static func target(for worker: Worker) -> DeliveryTarget? {
        let saved = savedTarget(for: worker)
        if saved.hasPrefix("app:") {
            let bundle = String(saved.dropFirst(4))
            let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
                .flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleName") as? String } ?? worker.name
            return DeliveryTarget(bundleID: bundle, appName: name)
        }
        if saved.lowercased().hasPrefix("https://") { return DeliveryTarget(appName: worker.name, url: saved) }
        if isChatGPT(worker) {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.chat") != nil {
                return DeliveryTarget(bundleID: "com.openai.chat", appName: "ChatGPT")
            }
            return DeliveryTarget(appName: "ChatGPT", url: "https://chatgpt.com")
        }
        return nil
    }

    /// Plain description of the target for the UI.
    static func describe(_ t: DeliveryTarget?) -> String {
        guard let t else { return "not set" }
        if let u = t.url { return u }
        return "the \(t.appName) app"
    }

    /// Dispatches the handoff if needed (policy gate for sending a handoff), then delivers it.
    static func deliver(_ handoffID: LupyID) {
        let model = LupyModel.shared
        guard let h0 = model.state.handoffs[handoffID], let w = model.state.workers[h0.workerID] else { return }
        guard let target = target(for: w) else {
            model.say("Tell Lupy where you talk to \(w.name) first (Lupy → Computer control → Where Lupy delivers).")
            model.open(.lupyControl)
            return
        }
        if let why = LupyControlCenter.shared.blocker() { model.say(why); return }
        if h0.state == .drafted || h0.state == .reworkRequested {
            var blocked: String?
            model.act { e in
                let r = try e.dispatch(handoffID)
                blocked = r.blockedReason
                // The brief goes straight into the agent: no clipboard copy needed.
                return r.effects.filter { if case .copyToClipboard = $0 { return false }; return true }
            }
            if let blocked { model.say(blocked); return }
        }
        guard let h = model.state.handoffs[handoffID], h.state == .awaitingRelay || h.state == .deliveryUnconfirmed else {
            model.say("This handoff is not waiting to be delivered.")
            return
        }
        let brief = HandoffBriefWriter.render(h.brief, workerName: w.name, utcOffsetMinutes: model.state.settings.utcOffsetMinutes)
        let steps = DeliveryPlan.steps(brief: brief, to: target, send: true)
        let projectID = model.state.tasks[h.taskID]?.projectID
        LupyControlCenter.shared.start(title: "Deliver the brief to \(w.name)", steps: steps, byFounder: true, projectID: projectID) { run in
            // Only when the Send click really happened, look at the screen for the message.
            guard let last = run.steps.last, case .press = last.step, last.state == .succeeded else { return }
            let observed = observeDelivery(brief: brief)
            let app = LupyControlCenter.shared.appName
            LupyModel.shared.act { try $0.recordControlDelivery(handoffID, observed: observed, app: app.isEmpty ? w.name : app); return [] }
            LupyModel.shared.say(observed ? "Delivered to \(w.name): the message is on screen. Lupy follows up as usual."
                                          : "Sent to \(w.name), but Lupy could not see it on screen — delivery unconfirmed.")
        }
    }

    static func observeDelivery(brief: String) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let (snap, _) = LupyAX.snapshot(of: app, maxElements: 900, timeBudget: 2.5)
        // The message box's own frame is excluded: its text (however the browser exposes it) is
        // not delivery evidence — only the message appearing elsewhere on screen is.
        let box = ElementMatcher.best(ElementQuery(DeliveryPlan.messageBox, role: .textInput), in: snap.elements)?.element.frame
        return DeliveryPlan.deliveryObserved(brief: brief, after: snap, excluding: box)
    }
}

/// Starts and stops Lupy's assistant inside Coucou's app (called from AppDelegate).
@MainActor
enum LupyRuntime {
    static func start() {
        LupyModel.shared.start()
        LupyIslandBridge.shared.start()
        // Launch flags used by CI screenshots (and handy for support); inert unless passed.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--open-window") {
            let page = i + 1 < args.count ? HubPage(rawValue: args[i + 1]) ?? .lupyToday : .lupyToday
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                Task { @MainActor in FlowHubController.shared.show(page) }
            }
        }
        if args.contains("--show-island") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                Task { @MainActor in NotificationCenter.default.post(name: .hookExpand, object: IslandView.overview) }
            }
        }
    }

    static func shutdown() {
        LupyControlCenter.shared.stop(reason: "Lupy is quitting")
        LupyModel.shared.shutdown()
    }
}
