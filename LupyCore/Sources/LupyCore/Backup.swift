// LupyCore — backups, restore, per-project export/import and human-readable summaries.
// Backups never contain API keys (they live only in the macOS Keychain).

public struct BackupManifest: Codable, Equatable, Sendable {
    public var format: String
    public var version: Int
    public var createdAt: Timestamp
    public var appVersion: String
    public var lastSeq: Int64
    public var eventCount: Int
    public var includesHistory: Bool
    public var secretsIncluded: Bool
    public var projectCount: Int
    public var taskCount: Int
}

public enum BackupError: Error, Equatable, CustomStringConvertible, Sendable {
    case notABackup, unsupportedVersion(Int), checksumMismatch, malformed(String)
    public var description: String {
        switch self {
        case .notABackup: return "This file is not a Lupy backup."
        case .unsupportedVersion(let v): return "This backup was made by a newer Lupy (format \(v))."
        case .checksumMismatch: return "The backup is damaged or was modified (checksum mismatch). Nothing was restored."
        case .malformed(let m): return "The backup could not be read: \(m)"
        }
    }
}

public struct ImportReport: Equatable, Sendable {
    public var projectID: LupyID
    public var remapped: Bool
    public var counts: [String: Int]
    public var skipped: [String]
}

public enum Backup {
    public static let format = "lupy-backup"
    public static let projectFormat = "lupy-project-export"
    public static let version = 1

    // MARK: Full backup

    public static func makeFullBackup(store: EventStore, includeHistory: Bool, appVersion: String, now: Timestamp) throws -> [UInt8] {
        let stateJSON = try JSONCoding.encode(store.state)
        let events: [LupyEvent] = includeHistory ? try store.allEvents() : []
        let eventsJSON: JSONValue = .array(try events.map { try JSONCoding.encode($0) })
        let manifest = BackupManifest(format: format, version: version, createdAt: now, appVersion: appVersion,
                                      lastSeq: store.state.lastSeq, eventCount: events.count, includesHistory: includeHistory,
                                      secretsIncluded: false, projectCount: store.state.projects.count,
                                      taskCount: store.state.tasks.count)
        let body: JSONValue = ["state": stateJSON, "events": eventsJSON]
        let root: JSONValue = [
            "format": .string(format),
            "version": .number(Double(version)),
            "manifest": try JSONCoding.encode(manifest),
            "checksum": .string(SHA256Digest.hex(JSONWriter.string(body))),
            "state": stateJSON,
            "events": eventsJSON,
        ]
        return JSONWriter.bytes(root, pretty: true)
    }

    public static func readBackup(_ bytes: [UInt8]) throws -> (manifest: BackupManifest, state: LupyState, events: [LupyEvent]) {
        let root: JSONValue
        do { root = try JSONParser.parse(bytes: bytes) } catch { throw BackupError.notABackup }
        guard root["format"]?.stringValue == format else { throw BackupError.notABackup }
        let v = root["version"]?.intValue ?? 0
        guard v <= version else { throw BackupError.unsupportedVersion(v) }
        guard let stateJSON = root["state"], let eventsJSON = root["events"], let checksum = root["checksum"]?.stringValue,
              let manifestJSON = root["manifest"] else { throw BackupError.malformed("missing sections") }
        let body: JSONValue = ["state": stateJSON, "events": eventsJSON]
        guard SHA256Digest.hex(JSONWriter.string(body)) == checksum else { throw BackupError.checksumMismatch }
        do {
            let manifest = try JSONCoding.decode(BackupManifest.self, from: manifestJSON)
            let state = try JSONCoding.decode(LupyState.self, from: stateJSON)
            let events = try (eventsJSON.arrayValue ?? []).map { try JSONCoding.decode(LupyEvent.self, from: EventMigrator.upgrade($0).0) }
            return (manifest, state, events)
        } catch {
            throw BackupError.malformed("\(error)")
        }
    }

    /// Validates the whole file first; only then archives current data and installs the backup.
    public static func restore(_ bytes: [UInt8], into store: EventStore) throws -> BackupManifest {
        let (manifest, state, _) = try readBackup(bytes)
        var restored = state
        // Keys are not in backups: providers must be re-confirmed on this Mac.
        for (id, var p) in restored.providers { p.hasKey = false; restored.providers[id] = p }
        // Anything that was mid-execution in the backup has an unknown outcome now.
        for (id, var a) in restored.actions where a.state == .executing { a.state = .outcomeUnknown; restored.actions[id] = a }
        try store.replaceAll(with: restored)
        return manifest
    }

    // MARK: Project export / import

    public static func exportProject(_ projectID: LupyID, state: LupyState, now: Timestamp) throws -> [UInt8] {
        guard let project = state.projects[projectID] else { throw BackupError.malformed("unknown project") }
        let tasks = state.tasks.values.filter { $0.projectID == projectID }.sorted { $0.createdAt < $1.createdAt }
        let taskIDs = Set(tasks.map(\.id))
        let goals = state.goals.values.filter { $0.projectID == projectID }.sorted { $0.createdAt < $1.createdAt }
        let plans = state.plans.values.filter { $0.projectID == projectID }.sorted { $0.createdAt < $1.createdAt }
        let evidence = state.evidence.values.filter { taskIDs.contains($0.taskID) }.sorted { $0.recordedAt < $1.recordedAt }
        let handoffs = state.handoffs.values.filter { taskIDs.contains($0.taskID) }.sorted { $0.createdAt < $1.createdAt }
        let memory = state.memory.values.filter { $0.scope == .project(projectID) }.sorted { $0.createdAt < $1.createdAt }
        let decisions = state.decisions.values.filter { $0.projectID == projectID }.sorted { $0.createdAt < $1.createdAt }
        let content: JSONValue = [
            "project": try JSONCoding.encode(project),
            "goals": try JSONCoding.encode(goals),
            "plans": try JSONCoding.encode(plans),
            "tasks": try JSONCoding.encode(tasks),
            "evidence": try JSONCoding.encode(evidence),
            "handoffs": try JSONCoding.encode(handoffs),
            "memory": try JSONCoding.encode(memory),
            "decisions": try JSONCoding.encode(decisions),
        ]
        let root: JSONValue = [
            "format": .string(projectFormat),
            "version": .number(Double(version)),
            "exportedAt": .string(now.iso8601),
            "checksum": .string(SHA256Digest.hex(JSONWriter.string(content))),
            "content": content,
        ]
        return JSONWriter.bytes(root, pretty: true)
    }

    /// Produces events that import a project. If the project ID already exists, every ID is
    /// remapped so the import can never overwrite or merge into existing data.
    public static func importProject(_ bytes: [UInt8], into state: LupyState, ids: IDGenerator, now: Timestamp) throws -> ([EventDraft], ImportReport) {
        let root: JSONValue
        do { root = try JSONParser.parse(bytes: bytes) } catch { throw BackupError.notABackup }
        guard root["format"]?.stringValue == projectFormat else { throw BackupError.notABackup }
        let v = root["version"]?.intValue ?? 0
        guard v <= version else { throw BackupError.unsupportedVersion(v) }
        guard let content = root["content"], let checksum = root["checksum"]?.stringValue else { throw BackupError.malformed("missing content") }
        guard SHA256Digest.hex(JSONWriter.string(content)) == checksum else { throw BackupError.checksumMismatch }

        var project: Project
        var goals: [Goal], plans: [Plan], tasks: [LupyTask], evidence: [Evidence], handoffs: [Handoff]
        var memory: [MemoryItem], decisions: [DecisionRecord]
        do {
            project = try JSONCoding.decode(Project.self, from: content["project"] ?? .null)
            goals = try JSONCoding.decode([Goal].self, from: content["goals"] ?? [])
            plans = try JSONCoding.decode([Plan].self, from: content["plans"] ?? [])
            tasks = try JSONCoding.decode([LupyTask].self, from: content["tasks"] ?? [])
            evidence = try JSONCoding.decode([Evidence].self, from: content["evidence"] ?? [])
            handoffs = try JSONCoding.decode([Handoff].self, from: content["handoffs"] ?? [])
            memory = try JSONCoding.decode([MemoryItem].self, from: content["memory"] ?? [])
            decisions = try JSONCoding.decode([DecisionRecord].self, from: content["decisions"] ?? [])
        } catch { throw BackupError.malformed("\(error)") }

        let remap = state.projects[project.id] != nil
        var map: [LupyID: LupyID] = [:]
        func m(_ id: LupyID, _ prefix: String) -> LupyID {
            guard remap else { return id }
            if let x = map[id] { return x }
            let n = ids.next(prefix); map[id] = n; return n
        }
        func mo(_ id: LupyID?, _ prefix: String) -> LupyID? { id.map { m($0, prefix) } }

        project.id = m(project.id, "prj")
        if remap { project.name += " (imported)" }
        project.updatedAt = now
        var skipped: [String] = []
        var drafts: [EventDraft] = [EventDraft(by: .founder, summary: "Imported project \(project.name)", payload: .projectUpserted(project))]
        for var g in goals { g.id = m(g.id, "gol"); g.projectID = project.id; g.planID = mo(g.planID, "pln")
            drafts.append(EventDraft(by: .founder, summary: "Imported goal", payload: .goalUpserted(g))) }
        for var t in tasks {
            t.id = m(t.id, "tsk"); t.projectID = project.id; t.goalID = mo(t.goalID, "gol")
            t.dependsOn = t.dependsOn.map { m($0, "tsk") }; t.handoffID = mo(t.handoffID, "hnd")
            drafts.append(EventDraft(by: .founder, summary: "Imported task \(t.title)", payload: .taskUpserted(t)))
        }
        for var p in plans { p.id = m(p.id, "pln"); p.goalID = m(p.goalID, "gol"); p.projectID = project.id
            p.draftTasks = p.draftTasks.map { var d = $0; d.id = m(d.id, "tsk"); d.projectID = project.id; return d }
            drafts.append(EventDraft(by: .founder, summary: "Imported plan", payload: .planUpserted(p))) }
        for var e in evidence { e.id = m(e.id, "evd"); e.taskID = m(e.taskID, "tsk"); e.handoffID = mo(e.handoffID, "hnd")
            drafts.append(EventDraft(by: .founder, summary: "Imported evidence", payload: .evidenceRecorded(e))) }
        for var h in handoffs {
            guard state.workers[h.workerID] != nil else { skipped.append("handoff \(h.id.raw): worker not present on this Mac"); continue }
            h.id = m(h.id, "hnd"); h.taskID = m(h.taskID, "tsk")
            drafts.append(EventDraft(by: .founder, summary: "Imported handoff", payload: .handoffUpserted(h)))
        }
        for var mi in memory { mi.id = m(mi.id, "mem"); mi.scope = .project(project.id); mi.supersededBy = mo(mi.supersededBy, "mem")
            drafts.append(EventDraft(by: .founder, summary: "Imported memory", payload: .memoryUpserted(mi))) }
        for var d in decisions { d.id = m(d.id, "dec"); d.projectID = project.id; d.relatedTaskIDs = d.relatedTaskIDs.map { m($0, "tsk") }
            drafts.append(EventDraft(by: .founder, summary: "Imported decision", payload: .decisionUpserted(d))) }
        let report = ImportReport(projectID: project.id, remapped: remap,
                                  counts: ["goals": goals.count, "plans": plans.count, "tasks": tasks.count, "evidence": evidence.count,
                                           "handoffs": handoffs.count - skipped.count, "memory": memory.count, "decisions": decisions.count],
                                  skipped: skipped)
        return (drafts, report)
    }

    // MARK: Human-readable export

    public static func markdown(project id: LupyID, state: LupyState) -> String {
        guard let p = state.projects[id] else { return "" }
        var out = "# \(p.name)\n\n"
        if !p.summary.isEmpty { out += p.summary + "\n\n" }
        if !p.rules.isEmpty {
            out += "## Project rules\n\n"
            for r in p.rules { out += "- \(r.text)\n" }
            out += "\n"
        }
        let tasks = state.tasks(in: id)
        let groups: [(String, [TaskStatus])] = [
            ("Needs you", [.waitingApproval, .waitingFounder, .escalated]),
            ("In motion", [.ready, .inProgress, .dispatched, .deliveryUnconfirmed, .acknowledged, .progressEvidenced, .submitted, .verifying, .recovering]),
            ("Waiting", [.planned, .waitingDependency, .blocked, .paused]),
            ("Done", [.verified, .accepted, .completed]),
            ("Stopped", [.failed, .cancelled]),
        ]
        for (title, statuses) in groups {
            let list = tasks.filter { statuses.contains($0.status) }
            guard !list.isEmpty else { continue }
            out += "## \(title)\n\n"
            for t in list {
                var line = "- **\(t.title)** — \(t.status.label)"
                if let d = t.deadline { line += " · due \(d.dateOnly)" }
                out += line + "\n"
            }
            out += "\n"
        }
        let decisions = state.decisions.values.filter { $0.projectID == id }.sorted { $0.createdAt < $1.createdAt }
        if !decisions.isEmpty {
            out += "## Decisions\n\n"
            for d in decisions { out += "- \(d.createdAt.dateOnly): **\(d.title)** — \(d.decision)\n" }
            out += "\n"
        }
        let memory = state.memory.values.filter { $0.scope == .project(id) && $0.status == .active }.sorted { $0.createdAt < $1.createdAt }
        if !memory.isEmpty {
            out += "## Memory\n\n"
            for m in memory { out += "- \(m.kind.label): \(m.title)\(m.sensitive ? " (sensitive)" : "")\n" }
        }
        return out
    }
}
