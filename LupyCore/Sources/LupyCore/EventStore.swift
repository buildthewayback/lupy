// LupyCore — durable event store.
//
// Layout (relative to the store root, e.g. ~/Library/Application Support/Lupy/store):
//   snapshot.json          full state at `lastSeq` (+ recent idempotency keys), checksummed
//   journal.jsonl          one line per *batch*: {"c":"<fnv64>","k":"<idempotency key>","b":[events…]}
//   archive/journal-<first>-<last>.jsonl   rotated journal segments (audit trail)
//
// Write-ahead: a batch is appended and flushed BEFORE it is applied in memory. If the append fails,
// memory is unchanged and the caller gets the error (nothing is silently lost or half-applied).
// A torn final line (power loss) is detected by checksum and truncated on the next load.

public struct EventDraft: Sendable {
    public var by: Principal
    public var summary: String
    public var payload: EventPayload
    public init(by: Principal, summary: String, payload: EventPayload) { self.by = by; self.summary = summary; self.payload = payload }
}

public enum StoreError: Error, Equatable, CustomStringConvertible, Sendable {
    case writeFailed(String)
    case duplicate(String)
    case corruptSnapshot(String)
    case unsupportedVersion(Int)
    public var description: String {
        switch self {
        case .writeFailed(let m): return "Could not save: \(m). Nothing was changed."
        case .duplicate(let k): return "Already processed (\(k))."
        case .corruptSnapshot(let m): return "Snapshot unreadable: \(m)"
        case .unsupportedVersion(let v): return "Data format version \(v) is newer than this version of Lupy."
        }
    }
}

/// Upgrades events written by older versions before they are decoded.
public enum EventMigrator {
    /// v0 (pre-release) events had no `schema` and used `"kind"` instead of `"payload"`.
    public static func upgrade(_ raw: JSONValue) -> (JSONValue, migrated: Bool) {
        guard case .object(var o) = raw else { return (raw, false) }
        let schema = o["schema"]?.intValue ?? 0
        if schema >= LupyEvent.currentSchema { return (raw, false) }
        if o["payload"] == nil, let k = o["kind"] { o["payload"] = k; o["kind"] = nil }
        if o["summary"] == nil { o["summary"] = .string("") }
        if o["by"] == nil { o["by"] = ["system": [:]] }
        o["schema"] = .number(Double(LupyEvent.currentSchema))
        return (.object(o), true)
    }
}

public final class EventStore {
    public static let snapshotFile = "snapshot.json"
    public static let journalFile = "journal.jsonl"
    public static let archiveDir = "archive"
    public static let snapshotVersion = 1
    public static let maxRememberedKeys = 10_000

    public private(set) var state = LupyState()
    public private(set) var lastRecovery: RecoveryReport?
    public private(set) var eventsSinceSnapshot = 0
    /// Recent events kept in memory for the activity feed (journal is the full record).
    public private(set) var recentEvents: [LupyEvent] = []
    public var snapshotEvery = 500
    public var recentEventsLimit = 1500

    let fs: LupyFileSystem
    let clock: LupyClock
    let ids: IDGenerator
    private var processedKeys: [String] = []
    private var processedKeySet: Set<String> = []

    public init(fileSystem: LupyFileSystem, clock: LupyClock, ids: IDGenerator) {
        self.fs = fileSystem
        self.clock = clock
        self.ids = ids
    }

    // MARK: Loading and recovery

    @discardableResult
    public func load() throws -> RecoveryReport {
        var report = RecoveryReport(at: clock.now(), truncatedBytes: 0, droppedLines: 0, duplicateEventsSkipped: 0,
                                    snapshotUsed: false, snapshotRejected: nil, interruptedActions: [], notes: [])
        state = LupyState()
        processedKeys = []; processedKeySet = []; recentEvents = []
        var needFullReplay = true

        if let bytes = try fs.read(Self.snapshotFile) {
            do {
                try loadSnapshot(bytes)
                report.snapshotUsed = true
                needFullReplay = false
            } catch let StoreError.unsupportedVersion(v) {
                throw StoreError.unsupportedVersion(v)
            } catch {
                report.snapshotRejected = "\(error)"
                report.notes.append("Snapshot could not be read; rebuilding from the journal archive.")
                state = LupyState(); processedKeys = []; processedKeySet = []
            }
        }
        if fs.exists(Self.snapshotFile + ".tmp") {
            try? fs.remove(Self.snapshotFile + ".tmp")
            report.notes.append("Removed an unfinished snapshot left by an interrupted save.")
        }

        if needFullReplay {
            for name in (try fs.list(Self.archiveDir)).filter({ $0.hasSuffix(".jsonl") }).sorted() {
                if let bytes = try fs.read("\(Self.archiveDir)/\(name)") {
                    _ = replay(bytes, path: "\(Self.archiveDir)/\(name)", report: &report, allowTruncate: false)
                }
            }
        }
        if let bytes = try fs.read(Self.journalFile) {
            let keepLength = replay(bytes, path: Self.journalFile, report: &report, allowTruncate: true)
            if keepLength < bytes.count {
                // Preserve the damaged tail for diagnosis, then truncate so new writes start clean.
                let tail = Array(bytes[keepLength...])
                try? fs.writeAtomically("recovery/torn-tail-\(clock.now().millis).bin", tail)
                try fs.truncate(Self.journalFile, toLength: keepLength)
                report.truncatedBytes = bytes.count - keepLength
                report.notes.append("Discarded an incomplete final write (\(bytes.count - keepLength) bytes) left by an interruption.")
            } else if let last = bytes.last, last != 0x0A {
                // Valid final batch whose newline was lost: terminate it so the next batch starts on a new line.
                try fs.append(Self.journalFile, [0x0A])
            }
        }

        // Actions that were executing when Lupy stopped have an unknown outcome: never assume success or failure.
        report.interruptedActions = state.actions.values.filter { $0.state == .executing }.map(\.id).sorted()
        lastRecovery = report
        return report
    }

    private func loadSnapshot(_ bytes: [UInt8]) throws {
        let root = try JSONParser.parse(bytes: bytes)
        guard root["format"]?.stringValue == "lupy-snapshot" else { throw StoreError.corruptSnapshot("wrong format marker") }
        let version = root["version"]?.intValue ?? 0
        if version > Self.snapshotVersion { throw StoreError.unsupportedVersion(version) }
        guard let stateJSON = root["state"], let checksum = root["checksum"]?.stringValue else {
            throw StoreError.corruptSnapshot("missing fields")
        }
        guard FNV1a.hex64(JSONWriter.string(stateJSON)) == checksum else { throw StoreError.corruptSnapshot("checksum mismatch") }
        state = try JSONCoding.decode(LupyState.self, from: stateJSON)
        let keys = root["keys"]?.arrayValue?.compactMap(\.stringValue) ?? []
        processedKeys = keys
        processedKeySet = Set(keys)
    }

    /// Replays journal bytes. Returns the length of the valid prefix (for torn-tail truncation).
    private func replay(_ bytes: [UInt8], path: String, report: inout RecoveryReport, allowTruncate: Bool) -> Int {
        var lineStart = 0
        var validPrefix = 0
        var idx = 0
        let count = bytes.count
        while idx <= count {
            if idx == count || bytes[idx] == 0x0A {
                let isLast = idx == count
                if idx > lineStart {
                    let line = Array(bytes[lineStart..<idx])
                    let terminated = !isLast
                    switch decodeBatchLine(line) {
                    case .success(let (key, events)):
                        applyReplayed(events, key: key, report: &report)
                        validPrefix = terminated ? idx + 1 : idx
                    case .failure(let why):
                        if isLast || (allowTruncate && isOnlyTrailingGarbage(bytes, from: idx)) {
                            // Torn final write: stop here; caller truncates.
                            return validPrefix
                        }
                        report.droppedLines += 1
                        report.notes.append("Skipped an unreadable journal entry in \(path): \(why)")
                        validPrefix = idx + 1
                    }
                } else if !isLast {
                    validPrefix = idx + 1
                }
                lineStart = idx + 1
            }
            idx += 1
        }
        return validPrefix
    }

    private func isOnlyTrailingGarbage(_ bytes: [UInt8], from: Int) -> Bool {
        // True when nothing but whitespace follows the current line.
        var i = from + 1
        while i < bytes.count { if bytes[i] != 0x0A && bytes[i] != 0x20 && bytes[i] != 0x0D { return false }; i += 1 }
        return true
    }

    private enum LineResult { case success((String?, [LupyEvent])); case failure(String) }

    private func decodeBatchLine(_ line: [UInt8]) -> LineResult {
        let root: JSONValue
        do { root = try JSONParser.parse(bytes: line) } catch { return .failure("not JSON") }
        guard let c = root["c"]?.stringValue, let batch = root["b"] else { return .failure("missing fields") }
        guard FNV1a.hex64(JSONWriter.string(batch)) == c else { return .failure("checksum mismatch") }
        guard let arr = batch.arrayValue else { return .failure("batch is not an array") }
        var events: [LupyEvent] = []
        for raw in arr {
            let (upgraded, _) = EventMigrator.upgrade(raw)
            do { events.append(try JSONCoding.decode(LupyEvent.self, from: upgraded)) } catch {
                return .failure("undecodable event: \(error)")
            }
        }
        return .success((root["k"]?.stringValue, events))
    }

    private func applyReplayed(_ events: [LupyEvent], key: String?, report: inout RecoveryReport) {
        if let k = key, processedKeySet.contains(k), events.allSatisfy({ $0.seq <= state.lastSeq }) {
            report.duplicateEventsSkipped += events.count
            return
        }
        for e in events {
            if e.seq <= state.lastSeq { report.duplicateEventsSkipped += 1; continue }
            if e.seq != state.lastSeq + 1 && state.lastSeq != 0 {
                report.notes.append("Gap in event sequence: expected \(state.lastSeq + 1), found \(e.seq).")
            }
            state.apply(e)
            remember(e)
            eventsSinceSnapshot += 1
        }
        if let k = key { rememberKey(k) }
    }

    private func remember(_ e: LupyEvent) {
        recentEvents.append(e)
        if recentEvents.count > recentEventsLimit { recentEvents.removeFirst(recentEvents.count - recentEventsLimit) }
    }

    private func rememberKey(_ k: String) {
        guard !processedKeySet.contains(k) else { return }
        processedKeys.append(k)
        processedKeySet.insert(k)
        if processedKeys.count > Self.maxRememberedKeys {
            let drop = processedKeys.count - Self.maxRememberedKeys
            for old in processedKeys.prefix(drop) { processedKeySet.remove(old) }
            processedKeys.removeFirst(drop)
        }
    }

    // MARK: Appending

    public func hasProcessed(_ key: String) -> Bool { processedKeySet.contains(key) }

    /// Durably appends a batch atomically, then applies it. With an idempotency key, a repeated
    /// call (e.g. after a crash and retry) is rejected with `.duplicate` and changes nothing.
    @discardableResult
    public func append(_ drafts: [EventDraft], idempotencyKey: String? = nil) throws -> [LupyEvent] {
        guard !drafts.isEmpty else { return [] }
        if let k = idempotencyKey, processedKeySet.contains(k) { throw StoreError.duplicate(k) }
        let now = clock.now()
        var seq = state.lastSeq
        let events: [LupyEvent] = drafts.map { d in
            seq += 1
            return LupyEvent(id: ids.next("evt"), seq: seq, at: now, by: d.by, summary: d.summary, payload: d.payload)
        }
        let batchJSON: JSONValue
        do { batchJSON = .array(try events.map { try JSONCoding.encode($0) }) } catch {
            throw StoreError.writeFailed("could not encode events: \(error)")
        }
        var line: [String: JSONValue] = ["c": .string(FNV1a.hex64(JSONWriter.string(batchJSON))), "b": batchJSON]
        if let k = idempotencyKey { line["k"] = .string(k) }
        var bytes = JSONWriter.bytes(.object(line))
        bytes.append(0x0A)
        do { try fs.append(Self.journalFile, bytes) } catch {
            throw StoreError.writeFailed("\(error)")
        }
        for e in events { state.apply(e); remember(e) }
        if let k = idempotencyKey { rememberKey(k) }
        eventsSinceSnapshot += events.count
        if eventsSinceSnapshot >= snapshotEvery { try? snapshot() }
        return events
    }

    // MARK: Snapshots

    /// Writes a checksummed snapshot atomically and rotates the journal into the archive.
    public func snapshot() throws {
        let stateJSON = try JSONCoding.encode(state)
        let root: JSONValue = .object([
            "format": "lupy-snapshot",
            "version": .number(Double(Self.snapshotVersion)),
            "lastSeq": .number(Double(state.lastSeq)),
            "savedAt": .string(clock.now().iso8601),
            "checksum": .string(FNV1a.hex64(JSONWriter.string(stateJSON))),
            "keys": .array(processedKeys.map { .string($0) }),
            "state": stateJSON,
        ])
        try fs.writeAtomically(Self.snapshotFile, JSONWriter.bytes(root, pretty: true))
        // Rotate only after the snapshot is safely on disk. A crash here is harmless: on load,
        // journal events with seq <= snapshot.lastSeq are skipped as duplicates.
        if let j = try fs.read(Self.journalFile), !j.isEmpty {
            try fs.makeDirectory(Self.archiveDir)
            let name = "\(Self.archiveDir)/journal-\(pad(Int(state.lastSeq), 9))-\(clock.now().millis).jsonl"
            try fs.move(Self.journalFile, to: name)
        }
        eventsSinceSnapshot = 0
    }

    /// Reads every event ever recorded (archive + current journal), in order. Used by backup/export.
    public func allEvents() throws -> [LupyEvent] {
        var out: [LupyEvent] = []
        var seen = Set<Int64>()
        var paths = (try fs.list(Self.archiveDir)).filter { $0.hasSuffix(".jsonl") }.sorted().map { "\(Self.archiveDir)/\($0)" }
        paths.append(Self.journalFile)
        for p in paths {
            guard let bytes = try fs.read(p) else { continue }
            for lineSub in bytes.split(separator: 0x0A) {
                if case .success(let (_, events)) = decodeBatchLine(Array(lineSub)) {
                    for e in events where !seen.contains(e.seq) { seen.insert(e.seq); out.append(e) }
                }
            }
        }
        return out.sorted { $0.seq < $1.seq }
    }

    /// Replace the entire store with a restored state. Existing files are archived first, never deleted.
    public func replaceAll(with newState: LupyState, keys: [String] = []) throws {
        let stamp = clock.now().millis
        for f in [Self.snapshotFile, Self.journalFile] where fs.exists(f) {
            try fs.makeDirectory("pre-restore-\(stamp)")
            try fs.move(f, to: "pre-restore-\(stamp)/\(f)")
        }
        for name in try fs.list(Self.archiveDir) {
            try fs.makeDirectory("pre-restore-\(stamp)")
            try fs.move("\(Self.archiveDir)/\(name)", to: "pre-restore-\(stamp)/archive-\(name)")
        }
        state = newState
        processedKeys = keys; processedKeySet = Set(keys)
        recentEvents = []
        try snapshot()
    }
}
