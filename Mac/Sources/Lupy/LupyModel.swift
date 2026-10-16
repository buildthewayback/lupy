// Lupy — the assistant's app-side model: owns the LupyCore engine (durable journal on the real
// disk), executes its effects (island/notification notices, clipboard, cloud model calls, GitHub
// checks), and exposes state to the Lupy pages of the window and to the island bridge.
// Ported from the previous Lupy shell's AppModel; navigation now goes through Coucou's window.

import AppKit
import Foundation
import LupyCore
import Observation

@MainActor
@Observable
final class LupyModel {
    static let shared = LupyModel()

    let engine: LupyEngine?
    let disk: LupyDiskFileSystem?
    let dataURL: URL
    var startupError: String?
    var recovery: RecoveryReport?
    var revision = 0
    var toast: String?
    var busyJobs: Set<String> = []
    var selectedProjectID: LupyID?
    var selectedTaskID: LupyID?
    var selectedPlanID: LupyID?
    @ObservationIgnored private var attentionCache: (Int, AttentionSummary)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var started = false

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lupy", isDirectory: true)
        let args = CommandLine.arguments
        var storeURL = support.appendingPathComponent("store", isDirectory: true)
        // --data-dir <path>: a separate data folder (CI smoke tests, trying the demo safely).
        if let i = args.firstIndex(of: "--data-dir"), i + 1 < args.count {
            storeURL = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        }
        dataURL = storeURL
        var engine: LupyEngine?
        var disk: LupyDiskFileSystem?
        var report: RecoveryReport?
        var failure: String?
        do {
            let fs = try LupyDiskFileSystem(root: storeURL)
            let clock = LupySystemClock()
            let ids = RandomIDGenerator(clock: clock)
            let store = EventStore(fileSystem: fs, clock: clock, ids: ids)
            report = try store.load()
            let e = LupyEngine(store: store, clock: clock, ids: ids)
            e.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
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
                                                        budget: BudgetGuard.status(LupyState(), now: LupySystemClock().now()),
                                                        paused: false, nextUp: [])
        attentionCache = (r, a)
        return a
    }

    var isBusy: Bool { !busyJobs.isEmpty }

    var hasUsableModel: Bool { _ = revision; return !(engine.map { ModelRouter.usable($0.state) }?.isEmpty ?? true) }

    var greeting: String {
        let name = state.settings.founderName
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        return name.isEmpty ? part : "\(part), \(name)"
    }

    var statusLine: String {
        let a = attention
        var parts: [String] = []
        parts.append(a.items.isEmpty ? "Nothing needs you right now" : "\(a.items.count) thing\(a.items.count == 1 ? "" : "s") need you")
        if a.activeCount > 0 { parts.append("\(a.activeCount) active") }
        if a.waitingOnOthers > 0 { parts.append("\(a.waitingOnOthers) delegated") }
        if a.unverifiedCount > 0 { parts.append("\(a.unverifiedCount) awaiting verification") }
        if a.paused { parts.insert("Paused", at: 0) }
        return parts.joined(separator: " · ")
    }

    var defaultCaptureProject: LupyID {
        if let p = selectedProjectID, state.projects[p] != nil { return p }
        return state.activeProjects.first { $0.name == "Personal admin" }?.id ?? state.activeProjects.first?.id ?? "prj_none"
    }

    // MARK: Plumbing

    func changed() {
        revision &+= 1
        LupyIslandBridge.shared.scheduleSync()
    }

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
            case .notify(let n):
                LupyIslandBridge.shared.present(n)
                if n.severity == .urgent { LupyNotifier.post(n) }
            case .copyToClipboard(let text): copy(text, announce: "Copied to the clipboard — paste it into the agent, or let Lupy deliver it.")
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
            let delay = Double(nb.millis - LupySystemClock().now().millis) / 1000
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(min(delay, 900) * 1_000_000_000)) }
        }
        busyJobs.insert(job.id.raw)
        changed()
        let result = await LupyHTTP.perform(job.http)
        busyJobs.remove(job.id.raw)
        guard let engine else { return }
        do {
            let r = try engine.completeModelJob(job.id, status: result.status, headers: result.headers, body: result.body, latencyMillis: result.latencyMillis)
            if let pid = r.planID {
                selectedPlanID = pid
                LupyChat.shared.planReady(pid)   // Lupy: the conversation shows the finished plan
            }
            // Lupy: a turn the conversation is waiting on lands there (answers, retries); other
            // jobs keep reporting through the toast.
            let retryJobs: [ModelJob] = r.effects.compactMap { if case .callModel(let j) = $0 { return j } else { return nil } }
            let handled = LupyChat.shared.jobCompleted(jobID: job.id, result: r, retryJobs: retryJobs)
            if !handled, !r.message.isEmpty { say(TextUtil.truncate(r.message, 220)) }
            run(r.effects)
        } catch {
            say("\(error)")
        }
        changed()
    }

    func performGitHub(_ job: GitHubJob) async {
        busyJobs.insert(job.id.raw)
        changed()
        let result = await LupyHTTP.perform(job.http)
        busyJobs.remove(job.id.raw)
        guard let engine else { return }
        do { run(try engine.completeGitHubJob(job.id, status: result.status, body: result.body)) } catch { say("\(error)") }
        changed()
    }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        LupyNotifier.requestPermission()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let r = recovery, !r.isClean {
            say("Lupy recovered from an interrupted session. Details in Lupy → Assistant → Diagnostics.")
        }
        changed()
    }

    /// Called when the app quits: a snapshot makes the next launch fast (the journal is already durable).
    func shutdown() {
        timer?.invalidate()
        try? engine?.store.snapshot()
    }

    func tick() {
        guard let engine else { return }
        do { run(try engine.tick()) } catch { say("\(error)") }
    }

    // MARK: Navigation (Lupy's pages live in the Lupy window inherited from Coucou)

    func open(_ page: HubPage) {
        FlowHubController.shared.show(page)
    }

    func focus(_ item: AttentionItem) {
        switch item.kind {
        case .approval: open(.lupyNeedsYou)
        case .planReview: selectedPlanID = item.relatedID; open(.lupyToday)
        case .relay: open(.lupyHandoffs)
        case .memoryConflict: open(.lupyMemory)
        case .budget: open(.lupyUsage)
        case .recovery: open(.lupyAssistant)
        default:
            selectedTaskID = item.relatedID
            open(.lupyTasks)
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
            let present = LupySecrets.exists(p.keychainAccount)
            if present != p.hasKey { try? engine.setProviderKeyPresent(p.id, present: present) }
        }
        let gh = LupySecrets.exists(GitHubAPI.keychainAccount)
        if !gh, engine.githubConnected { try? engine.setGitHubConnected(false) }
        changed()
    }

    func saveKey(providerID: String, key: String) {
        guard let engine, let p = engine.state.providers[providerID] else { return }
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        if LupySecrets.save(p.keychainAccount, k) {
            try? engine.setProviderKeyPresent(providerID, present: true)
            say("Key stored in your Mac's Keychain (not in Lupy's files).")
        } else {
            say("Could not store the key in the Keychain.")
        }
        changed()
    }

    func removeKey(providerID: String) {
        guard let engine, let p = engine.state.providers[providerID] else { return }
        LupySecrets.delete(p.keychainAccount)
        try? engine.setProviderKeyPresent(providerID, present: LupySecrets.exists(p.keychainAccount))
        say(LupySecrets.exists(p.keychainAccount) ? "Removed Lupy's copy; a key from the chat settings is still used." : "Key removed from the Keychain.")
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
        guard let p = engine?.state.providers[providerID] else { return }
        let spec = ProviderAPI.buildListModels(p)
        let kind = p.kind
        let name = p.displayName
        Task { @MainActor in
            self.busyJobs.insert("models-\(providerID)")
            let r = await LupyHTTP.perform(spec)
            self.busyJobs.remove("models-\(providerID)")
            switch ProviderAPI.parseListModels(kind, status: r.status, body: r.body, now: LupySystemClock().now()) {
            case .success(let ids):
                try? self.engine?.addDiscoveredModels(providerID, modelIDs: ids)
                self.say("\(name) offers \(ids.count) model(s). New ones were added (off, priced conservatively — edit prices).")
            case .failure(let e):
                self.say("\(name): \(e.category.label). \(e.message)")
            }
            self.changed()
        }
    }

    func saveGitHubToken(_ token: String) {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        guard LupySecrets.save(GitHubAPI.keychainAccount, t) else { say("Could not store the token."); return }
        testGitHub()
    }

    func testGitHub() {
        guard engine != nil else { return }
        let spec = HTTPRequestSpec(method: "GET", url: "https://api.github.com/user",
                                   headers: ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"],
                                   body: [], auth: AuthPlacement(header: "Authorization", prefix: "Bearer "),
                                   keychainAccount: GitHubAPI.keychainAccount, timeoutSeconds: 20)
        Task { @MainActor in
            let r = await LupyHTTP.perform(spec)
            if r.status == 200 {
                try? self.engine?.setGitHubConnected(true)
                self.say("GitHub connected (read-only checks).")
            } else {
                try? self.engine?.setGitHubConnected(false, error: "GitHub answered HTTP \(r.status).")
                self.say("GitHub check failed (HTTP \(r.status)). Check the token's permissions.")
            }
            self.changed()
        }
    }

    func removeGitHubToken() {
        LupySecrets.delete(GitHubAPI.keychainAccount)
        try? engine?.setGitHubConnected(false)
        changed()
    }

    // MARK: Backup / export

    func exportBackup() {
        guard let engine else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Lupy-Backup-\(LupySystemClock().now().dateOnly).lupybackup"
        panel.title = "Save a full backup of Lupy"
        panel.message = "The backup contains your projects, tasks, memory and history — but never API keys."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try engine.store.snapshot()
            let bytes = try Backup.makeFullBackup(store: engine.store, includeHistory: true, appVersion: engine.appVersion, now: LupySystemClock().now())
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
            say("Restored. Re-enter API keys in Lupy → Assistant if needed.")
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
                                      : Data(try Backup.exportProject(id, state: engine.state, now: LupySystemClock().now()))
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
            let (drafts, report) = try Backup.importProject(bytes, into: engine.state, ids: engine.ids, now: LupySystemClock().now())
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
