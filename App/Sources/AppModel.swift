// Lupy macOS shell — the app model: owns the engine, executes effects, drives the scheduler.

import AppKit
import Observation
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case today, projects, tasks, approvals, handoffs, memory, activity, usage, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: return "Today"
        case .projects: return "Projects"
        case .tasks: return "All tasks"
        case .approvals: return "Needs you"
        case .handoffs: return "Handoffs"
        case .memory: return "Memory"
        case .activity: return "Activity"
        case .usage: return "Usage & budget"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .today: return "sun.max"
        case .projects: return "square.grid.2x2"
        case .tasks: return "checklist"
        case .approvals: return "hand.raised"
        case .handoffs: return "arrow.left.arrow.right"
        case .memory: return "brain.head.profile"
        case .activity: return "clock.arrow.circlepath"
        case .usage: return "gauge.with.dots.needle.50percent"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let engine: LupyEngine?
    let disk: DiskFileSystem?
    let dataURL: URL
    var startupError: String?
    var recovery: RecoveryReport?
    var revision = 0
    var toast: String?
    var busyJobs: Set<String> = []
    var section: SidebarItem = .today
    var selectedProjectID: LupyID?
    var selectedTaskID: LupyID?
    var selectedPlanID: LupyID?
    var islandExpanded = false
    var islandPinned = false
    var islandGeometry: IslandGeometry?
    var showIsland: Bool = UserDefaults.standard.object(forKey: "showIsland") as? Bool ?? true
    /// Animations run only while Lupy is the active app (saves CPU/battery); the island keeps a slow pulse when something needs you.
    var appActive = true
    @ObservationIgnored private var attentionCache: (Int, AttentionSummary)?

    func setShowIsland(_ on: Bool) {
        showIsland = on
        UserDefaults.standard.set(on, forKey: "showIsland")
        IslandController.shared?.setVisible(on)
    }
    let dictation = DictationController()
    @ObservationIgnored var openWindowAction: OpenWindowAction?
    @ObservationIgnored private var timer: Timer?

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lupy", isDirectory: true)
        let args = CommandLine.arguments
        var storeURL = support.appendingPathComponent("store", isDirectory: true)
        // --data-dir <path>: use a separate data folder (CI smoke tests, trying the demo safely).
        if let i = args.firstIndex(of: "--data-dir"), i + 1 < args.count {
            storeURL = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        }
        dataURL = storeURL
        var engine: LupyEngine?
        var disk: DiskFileSystem?
        var report: RecoveryReport?
        var failure: String?
        do {
            let fs = try DiskFileSystem(root: storeURL)
            let clock = SystemClock()
            let ids = RandomIDGenerator(clock: clock)
            let store = EventStore(fileSystem: fs, clock: clock, ids: ids)
            report = try store.load()
            let e = LupyEngine(store: store, clock: clock, ids: ids)
            e.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
            let offset = TimeZone.current.secondsFromGMT() / 60
            let first = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
            try e.bootstrap(founderName: first, utcOffsetMinutes: offset)
            if args.contains("--demo") { try e.seedDemo() }
            if e.state.settings.utcOffsetMinutes != offset {
                var s = e.state.settings
                s.utcOffsetMinutes = offset
                try? e.updateSettings(s)
            }
            engine = e
            disk = fs
        } catch {
            failure = "Lupy could not open its data folder: \(error)"
        }
        self.engine = engine
        self.disk = disk
        self.recovery = report
        self.startupError = failure
        syncSecretsPresence()
    }

    // MARK: Derived state (reading `revision` makes views refresh after every change)

    var state: LupyState { _ = revision; return engine?.state ?? LupyState() }

    /// Computed once per revision (views read it many times per render).
    var attention: AttentionSummary {
        let r = revision
        if let cached = attentionCache, cached.0 == r { return cached.1 }
        let a = engine?.attention() ?? AttentionSummary(items: [], activeCount: 0, waitingOnOthers: 0, unverifiedCount: 0,
                                                        budget: BudgetGuard.status(LupyState(), now: SystemClock().now()), paused: false, nextUp: [])
        attentionCache = (r, a)
        return a
    }

    /// Whether Lupy's character animates in a given place (saves CPU when Lupy is in the background).
    func animates(_ place: AnimationPlace) -> Bool {
        switch place {
        case .island: return appActive || mood == .needsYou || mood == .worried
        case .window: return appActive
        }
    }

    enum AnimationPlace { case island, window }

    var isBusy: Bool { !busyJobs.isEmpty }

    var hasUsableModel: Bool { _ = revision; return !(engine.map { ModelRouter.usable($0.state) }?.isEmpty ?? true) }

    var mood: LupyMood {
        let a = attention
        if a.paused { return .sleeping }
        if a.items.contains(where: { $0.kind == .contradiction || $0.kind == .escalation }) { return .worried }
        if isBusy { return .thinking }
        if !a.items.isEmpty { return .needsYou }
        if a.activeCount > 0 || a.waitingOnOthers > 0 { return .working }
        return .idle
    }

    var greeting: String {
        let name = state.settings.founderName
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        return name.isEmpty ? part : "\(part), \(name)"
    }

    var islandHeadline: String {
        let a = attention
        if a.paused { return "Paused" }
        if !a.items.isEmpty { return "\(a.items.count) need\(a.items.count == 1 ? "s" : "") you" }
        if isBusy { return "Working…" }
        if a.waitingOnOthers > 0 { return "\(a.waitingOnOthers) delegated · \(a.activeCount) active" }
        return a.activeCount > 0 ? "\(a.activeCount) active" : "All clear"
    }

    var defaultCaptureProject: LupyID {
        if let p = selectedProjectID, state.projects[p] != nil { return p }
        return state.activeProjects.first { $0.name == "Personal admin" }?.id ?? state.activeProjects.first?.id ?? "prj_none"
    }

    // MARK: Plumbing

    func changed() { revision &+= 1 }

    func say(_ message: String) {
        toast = message
        let current = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            Task { @MainActor in if self?.toast == current { self?.toast = nil } }
        }
    }

    /// Runs an engine command, executes its effects and reports errors in plain language.
    func act(_ block: (LupyEngine) throws -> [Effect]) {
        guard let engine else { say(startupError ?? "Lupy is not ready."); return }
        do { run(try block(engine)) } catch { say("\(error)") }
        changed()
    }

    func run(_ effects: [Effect]) {
        for effect in effects {
            switch effect {
            case .notify(let n): Notifier.post(n)
            case .copyToClipboard(let text): copy(text, announce: "Copied to the clipboard — paste it into the agent.")
            case .callModel(let job): Task { await self.perform(job) }
            case .checkGitHub(let job): Task { await self.performGitHub(job) }
            }
        }
        changed()
    }

    func copy(_ text: String, announce: String? = nil) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        if let a = announce { say(a) }
    }

    func perform(_ job: ModelJob) async {
        if let nb = job.notBefore {
            let delay = Double(nb.millis - SystemClock().now().millis) / 1000
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(min(delay, 900) * 1_000_000_000)) }
        }
        busyJobs.insert(job.id.raw)
        let result = await HTTPExecutor.perform(job.http)
        busyJobs.remove(job.id.raw)
        guard let engine else { return }
        do {
            let r = try engine.completeModelJob(job.id, status: result.status, headers: result.headers, body: result.body, latencyMillis: result.latencyMillis)
            if !r.message.isEmpty { say(TextUtil.truncate(r.message, 220)) }
            if let pid = r.planID { selectedPlanID = pid }
            run(r.effects)
        } catch {
            say("\(error)")
        }
        changed()
    }

    func performGitHub(_ job: GitHubJob) async {
        busyJobs.insert(job.id.raw)
        let result = await HTTPExecutor.perform(job.http)
        busyJobs.remove(job.id.raw)
        guard let engine else { return }
        do { run(try engine.completeGitHubJob(job.id, status: result.status, body: result.body)) } catch { say("\(error)") }
        changed()
    }

    // MARK: Lifecycle

    func start() {
        Notifier.requestPermission()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in try? self?.engine?.store.snapshot() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.appActive = true }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.appActive = false }
        }
        if let r = recovery, !r.isClean {
            say("Lupy recovered from an interrupted session. Details in Settings → Diagnostics.")
        }
    }

    func tick() {
        guard let engine else { return }
        do { run(try engine.tick()) } catch { say("\(error)") }
    }

    // MARK: Navigation and island

    func setIsland(expanded: Bool) {
        islandExpanded = expanded
        if !expanded { islandPinned = false }
        IslandController.shared?.apply(expanded: expanded)
    }

    func openMainWindow() {
        NSApp.activate()
        if let w = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("main") == true && $0.isVisible }) {
            w.makeKeyAndOrderFront(nil)
        } else if let open = openWindowAction {
            open(id: "main")
        } else {
            NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
        }
    }

    func focus(_ item: AttentionItem) {
        switch item.kind {
        case .approval: section = .approvals
        case .planReview: section = .today; selectedPlanID = item.relatedID
        case .relay: section = .handoffs
        case .memoryConflict: section = .memory
        case .budget: section = .usage
        case .recovery: section = .settings
        default:
            section = .tasks
            selectedTaskID = item.relatedID
        }
    }

    // MARK: Capture

    func capture(_ text: String, projectID: LupyID, useModel: Bool) {
        guard let engine else { return }
        do {
            let goal = try engine.captureGoal(text, projectID: projectID)
            if useModel {
                switch try engine.prepareModelPlan(goalID: goal.id) {
                case .job(let job):
                    say("Planning with \(job.modelID)… (\(job.manifest.plainSummary))")
                    run([.callModel(job)])
                case .needsApproval:
                    say("Lupy needs your OK to send this goal to the model — see Needs you. Declining makes an offline plan.")
                case .unavailable(let why):
                    let plan = try engine.planHeuristically(goalID: goal.id, extraWarning: why)
                    selectedPlanID = plan.id
                    say("Planned offline. \(why)")
                }
            } else {
                let plan = try engine.planHeuristically(goalID: goal.id)
                selectedPlanID = plan.id
                say("Offline plan ready for review.")
            }
            section = .today
        } catch {
            say("\(error)")
        }
        changed()
    }

    /// Ask a question (needs an approved cloud model). The answer is saved under Today → Latest from Lupy.
    func ask(_ question: String, projectID: LupyID?) {
        prepared("Asking") { try $0.prepareQuestion(question, projectID: projectID) }
    }

    func writeBriefWithModel() {
        prepared("Writing today's brief with") { try $0.prepareBrief() }
    }

    func analyzeReply(handoffID: LupyID, text: String) {
        prepared("Reading the reply with") { try $0.prepareReplyAnalysis(handoffID: handoffID, text: text) }
    }

    private func prepared(_ verb: String, _ make: (LupyEngine) throws -> PreparedCall) {
        guard let engine else { return }
        do {
            switch try make(engine) {
            case .job(let job): say("\(verb) \(job.modelID)…"); run([.callModel(job)])
            case .needsApproval: say("Lupy needs your OK to send this to the model — see Needs you.")
            case .unavailable(let why): say(why)
            }
        } catch { say("\(error)") }
        changed()
    }

    // MARK: Secrets (Keychain) — keys never reach the engine

    func syncSecretsPresence() {
        guard let engine else { return }
        for p in engine.state.providers.values {
            let present = Keychain.exists(p.keychainAccount)
            if present != p.hasKey { try? engine.setProviderKeyPresent(p.id, present: present) }
        }
        let gh = Keychain.exists(GitHubAPI.keychainAccount)
        if !gh, engine.githubConnected { try? engine.setGitHubConnected(false) }
        changed()
    }

    func saveKey(providerID: String, key: String) {
        guard let engine, let p = engine.state.providers[providerID] else { return }
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        if Keychain.save(p.keychainAccount, k) {
            try? engine.setProviderKeyPresent(providerID, present: true)
            say("Key stored in your Mac's Keychain (not in Lupy's files).")
        } else {
            say("Could not store the key in the Keychain.")
        }
        changed()
    }

    func removeKey(providerID: String) {
        guard let engine, let p = engine.state.providers[providerID] else { return }
        Keychain.delete(p.keychainAccount)
        try? engine.setProviderKeyPresent(providerID, present: false)
        say("Key removed from the Keychain.")
        changed()
    }

    func testProvider(_ providerID: String) {
        guard let engine else { return }
        do {
            switch try engine.prepareConnectionTest(providerID: providerID) {
            case .job(let job): say("Testing \(providerID)…"); run([.callModel(job)])
            case .needsApproval: say("Approval needed first.")
            case .unavailable(let why): say(why)
            }
        } catch { say("\(error)") }
    }

    func refreshModels(_ providerID: String) {
        guard let engine, let p = engine.state.providers[providerID] else { return }
        Task {
            self.busyJobs.insert("models-\(providerID)")
            let r = await HTTPExecutor.perform(ProviderAPI.buildListModels(p))
            self.busyJobs.remove("models-\(providerID)")
            switch ProviderAPI.parseListModels(p.kind, status: r.status, body: r.body, now: SystemClock().now()) {
            case .success(let ids):
                try? engine.addDiscoveredModels(providerID, modelIDs: ids)
                self.say("\(p.displayName) offers \(ids.count) model(s). New ones were added (off, priced conservatively — edit prices).")
            case .failure(let e):
                self.say("\(p.displayName): \(e.category.label). \(e.message)")
            }
            self.changed()
        }
    }

    func saveGitHubToken(_ token: String) {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        guard Keychain.save(GitHubAPI.keychainAccount, t) else { say("Could not store the token."); return }
        testGitHub()
    }

    func testGitHub() {
        guard let engine else { return }
        let spec = HTTPRequestSpec(method: "GET", url: "https://api.github.com/user", headers: ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"],
                                   body: [], auth: AuthPlacement(header: "Authorization", prefix: "Bearer "), keychainAccount: GitHubAPI.keychainAccount, timeoutSeconds: 20)
        Task {
            let r = await HTTPExecutor.perform(spec)
            if r.status == 200 {
                try? engine.setGitHubConnected(true)
                self.say("GitHub connected (read-only checks).")
            } else {
                try? engine.setGitHubConnected(false, error: "GitHub answered HTTP \(r.status).")
                self.say("GitHub check failed (HTTP \(r.status)). Check the token's permissions.")
            }
            self.changed()
        }
    }

    func removeGitHubToken() {
        Keychain.delete(GitHubAPI.keychainAccount)
        try? engine?.setGitHubConnected(false)
        changed()
    }

    // MARK: Backup / export

    func exportBackup() {
        guard let engine else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Lupy-Backup-\(SystemClock().now().dateOnly).lupybackup"
        panel.title = "Save a full backup of Lupy"
        panel.message = "The backup contains your projects, tasks, memory and history — but never API keys."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try engine.store.snapshot()
            let bytes = try Backup.makeFullBackup(store: engine.store, includeHistory: true, appVersion: engine.appVersion, now: SystemClock().now())
            try Data(bytes).write(to: url, options: .atomic)
            say("Backup saved (\(bytes.count / 1024) KB).")
        } catch { say("Backup failed: \(error)") }
        changed()
    }

    func restoreBackup() {
        guard let engine else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose a Lupy backup to restore"
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let bytes = [UInt8](try Data(contentsOf: url))
            let parsed = try Backup.readBackup(bytes)
            let alert = NSAlert()
            alert.messageText = "Restore this backup?"
            alert.informativeText = "Backup from \(parsed.manifest.createdAt.dateOnly) with \(parsed.manifest.projectCount) projects and \(parsed.manifest.taskCount) tasks. Lupy's current data is moved aside (not deleted) first. API keys are not in backups."
            alert.addButton(withTitle: "Restore")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            _ = try Backup.restore(bytes, into: engine.store)
            syncSecretsPresence()
            say("Restored. Re-enter API keys in Settings → Providers if needed.")
        } catch { say("\(error)") }
        changed()
    }

    func exportProject(_ id: LupyID, markdown: Bool) {
        guard let engine, let p = engine.state.projects[id] else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = TextUtil.slug(p.name) + (markdown ? ".md" : ".lupyproject")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data: Data = markdown ? Data(Backup.markdown(project: id, state: engine.state).utf8)
                                      : Data(try Backup.exportProject(id, state: engine.state, now: SystemClock().now()))
            try data.write(to: url, options: .atomic)
            say("Exported \(p.name).")
        } catch { say("Export failed: \(error)") }
    }

    func importProject() {
        guard let engine else { return }
        let panel = NSOpenPanel()
        panel.title = "Import a Lupy project"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let bytes = [UInt8](try Data(contentsOf: url))
            let (drafts, report) = try Backup.importProject(bytes, into: engine.state, ids: engine.ids, now: SystemClock().now())
            try engine.store.append(drafts)
            say("Imported \(report.counts["tasks"] ?? 0) task(s)\(report.remapped ? " as a copy" : "")\(report.skipped.isEmpty ? "" : "; skipped \(report.skipped.count)").")
        } catch { say("\(error)") }
        changed()
    }

    var dataSizeBytes: Int { disk?.totalSize() ?? 0 }

    // MARK: Verified local actions

    /// The only folder Lupy writes deliverables into (approved root for FilePolicy).
    var deliverablesFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Lupy", isDirectory: true)
    }

    /// Saves a draft as a Markdown file, then reads it back and compares SHA-256 before claiming success.
    func saveDraftToFile(_ draft: DraftDocument) {
        guard let engine else { return }
        let folder = deliverablesFolder
        let name = TextUtil.slug(draft.title) + "-" + draft.createdAt.dateOnly + ".md"
        let url = folder.appendingPathComponent(name)
        guard FilePolicy.isAllowed(url.path, approvedRoots: [folder.path]) else { say("That location is not allowed."); return }
        let action = engine.makeAction(kind: .localFileWrite, title: "Save “\(TextUtil.truncate(draft.title, 60))” to Documents/Lupy", target: url.path,
                                       detail: "\(draft.body.count) characters", projectID: draft.projectID, taskID: draft.taskID,
                                       reversible: true, originator: .founder, idempotencyKey: "save:\(draft.id.raw):\(draft.contentHash.prefix(16))")
        do {
            guard let rec = try engine.beginAction(action) else { say("Already saved earlier."); changed(); return }
            let bytes = Array(draft.body.utf8)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data(bytes).write(to: url, options: .atomic)
                let back = [UInt8](try Data(contentsOf: url))
                let hash = SHA256Digest.hex(back)
                let ok = hash == SHA256Digest.hex(bytes)
                let summary = ok ? "Saved \(name) and read it back (SHA-256 \(hash.prefix(12))… matches)." : "Saved \(name) but the read-back did not match."
                try engine.finishAction(rec.id, verified: ok, summary: summary, reference: url.path, contentHash: hash, evidenceKind: .fileObservation)
                say(summary)
                if ok { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            } catch {
                try engine.finishAction(rec.id, verified: false, summary: "Could not save: \(error.localizedDescription)")
                say("Saving failed: \(error.localizedDescription)")
            }
        } catch { say("\(error)") }
        changed()
    }

    /// Actions that were running when Lupy last stopped (outcome unknown until you settle them).
    var interruptedActions: [ActionRecord] {
        let ids = Set(recovery?.interruptedActions ?? [])
        return state.actions.values.filter { ids.contains($0.id) && ($0.state == .executing || $0.state == .outcomeUnknown) }.sorted { $0.createdAt < $1.createdAt }
    }

    func revealDataFolder() { NSWorkspace.shared.activateFileViewerSelecting([dataURL]) }
}
