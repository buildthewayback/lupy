// Durability, recovery, idempotency, migration and backup tests.

func makeStore(_ fs: InMemoryFileSystem = InMemoryFileSystem(), clock: ManualClock? = nil) -> (EventStore, InMemoryFileSystem, ManualClock) {
    let c = clock ?? ManualClock(Timestamp(year: 2026, month: 10, day: 15, hour: 9))
    return (EventStore(fileSystem: fs, clock: c, ids: SequentialIDGenerator()), fs, c)
}

func projectDraft(_ name: String, id: String, at: Timestamp) -> EventDraft {
    EventDraft(by: .founder, summary: "Created \(name)", payload: .projectUpserted(Project(id: LupyID(id), name: name, createdAt: at)))
}

func taskDraft(_ title: String, id: String, project: String, at: Timestamp) -> EventDraft {
    EventDraft(by: .founder, summary: "Task \(title)", payload: .taskUpserted(LupyTask(id: LupyID(id), projectID: LupyID(project), title: title, createdAt: at)))
}

func storeSuite() -> TestSuite {
    TestSuite(name: "Store", cases: [
        TestCase("append then reload reproduces identical state") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("PENGLAI City", id: "prj_1", at: c.now())])
            c.advance(.minutes(1))
            try s.append([taskDraft("Write world bible", id: "tsk_1", project: "prj_1", at: c.now()),
                          taskDraft("Pick art style", id: "tsk_2", project: "prj_1", at: c.now())])
            let (s2, _, _) = makeStore(fs, clock: c)
            let report = try s2.load()
            t.equal(s2.state, s.state)
            t.equal(s2.state.tasks.count, 2)
            t.equal(s2.state.lastSeq, 3)
            t.expect(report.isClean, "clean reload should report no recovery: \(report)")
        },
        TestCase("torn final write is truncated; earlier batches survive; new writes work") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("Income", id: "prj_1", at: c.now())])
            fs.tornAppendAfterBytes = 25
            t.throwsError("torn append must surface as an error") { try s.append([taskDraft("Invoice", id: "tsk_1", project: "prj_1", at: c.now())]) }
            t.equal(s.state.tasks.count, 0, "write-ahead: failed append must not change memory")
            let (s2, fs2, _) = makeStore(fs, clock: c)
            let report = try s2.load()
            t.equal(s2.state.projects.count, 1)
            t.equal(s2.state.tasks.count, 0)
            t.equal(report.truncatedBytes, 25)
            t.expect(!report.isClean)
            t.expect((try fs2.list("recovery")).count == 1, "damaged tail preserved for diagnosis")
            try s2.append([taskDraft("Invoice", id: "tsk_1", project: "prj_1", at: c.now())])
            let (s3, _, _) = makeStore(fs2, clock: c)
            let r3 = try s3.load()
            t.equal(s3.state.tasks.count, 1)
            t.expect(r3.isClean, "after repair the journal is clean")
        },
        TestCase("disk failure leaves state unchanged and reports a clear error") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("Notes", id: "prj_1", at: c.now())])
            fs.failAllWrites = true
            do {
                try s.append([taskDraft("x", id: "tsk_1", project: "prj_1", at: c.now())])
                t.fail("expected failure")
            } catch let e as StoreError {
                t.expect("\(e)".contains("Nothing was changed"))
            }
            t.equal(s.state.tasks.count, 0)
            t.equal(s.state.lastSeq, 1)
        },
        TestCase("corrupt middle line is skipped and reported; later batches still applied") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("A", id: "prj_1", at: c.now())])
            try s.append([projectDraft("B", id: "prj_2", at: c.now())])
            try s.append([projectDraft("C", id: "prj_3", at: c.now())])
            // Flip a byte inside the second line's payload (checksum will no longer match).
            let bytes = try fs.read(EventStore.journalFile)!
            let firstNL = bytes.firstIndex(of: 0x0A)!
            fs.overwrite(EventStore.journalFile, at: firstNL + 60, with: [UInt8(ascii: "#")])
            let (s2, _, _) = makeStore(fs, clock: c)
            let report = try s2.load()
            t.equal(report.droppedLines, 1)
            t.equal(s2.state.projects.keys.sorted(), ["prj_1", "prj_3"])
            t.expect(report.notes.contains { $0.contains("Gap in event sequence") })
        },
        TestCase("snapshot rotates journal; reload uses snapshot + new journal") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("A", id: "prj_1", at: c.now())])
            try s.snapshot()
            t.expect(fs.exists(EventStore.snapshotFile))
            t.equal(try fs.read(EventStore.journalFile), nil)
            t.equal((try fs.list(EventStore.archiveDir)).count, 1)
            try s.append([projectDraft("B", id: "prj_2", at: c.now())])
            let (s2, _, _) = makeStore(fs, clock: c)
            let report = try s2.load()
            t.expect(report.snapshotUsed)
            t.equal(s2.state, s.state)
            t.equal((try s2.allEvents()).map(\.seq), [1, 2], "archive + journal hold the full history")
        },
        TestCase("corrupt snapshot falls back to full replay from archive") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("A", id: "prj_1", at: c.now())])
            try s.snapshot()
            try s.append([projectDraft("B", id: "prj_2", at: c.now())])
            fs.overwrite(EventStore.snapshotFile, at: 40, with: Array("XXXX".utf8))
            let (s2, _, _) = makeStore(fs, clock: c)
            let report = try s2.load()
            t.notNil(report.snapshotRejected)
            t.expect(!report.snapshotUsed)
            t.equal(s2.state.projects.count, 2)
        },
        TestCase("crash during snapshot write keeps the previous snapshot and cleans up") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("A", id: "prj_1", at: c.now())])
            try s.snapshot()
            try s.append([projectDraft("B", id: "prj_2", at: c.now())])
            fs.failNextAtomicWrite = true
            t.throwsError { try s.snapshot() }
            t.expect(fs.exists(EventStore.snapshotFile + ".tmp"))
            let (s2, fs2, _) = makeStore(fs, clock: c)
            let report = try s2.load()
            t.equal(s2.state.projects.count, 2, "journal still holds the post-snapshot batch")
            t.expect(!fs2.exists(EventStore.snapshotFile + ".tmp"))
            t.expect(report.notes.contains { $0.contains("unfinished snapshot") })
        },
        TestCase("crash between snapshot and rotation: duplicates are skipped") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("A", id: "prj_1", at: c.now())])
            let journalBefore = try fs.read(EventStore.journalFile)!
            try s.snapshot()
            fs.setFile(EventStore.journalFile, journalBefore) // as if rotation never happened
            let (s2, _, _) = makeStore(fs, clock: c)
            let report = try s2.load()
            t.equal(report.duplicateEventsSkipped, 1)
            t.equal(s2.state.lastSeq, 1)
            t.equal(s2.state.projects.count, 1)
        },
        TestCase("idempotency keys reject repeats, including after restart and snapshot") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("A", id: "prj_1", at: c.now())], idempotencyKey: "cmd-42")
            do { try s.append([projectDraft("A2", id: "prj_9", at: c.now())], idempotencyKey: "cmd-42"); t.fail("duplicate accepted") }
            catch let e as StoreError { t.equal(e, .duplicate("cmd-42")) }
            let (s2, fs2, _) = makeStore(fs, clock: c)
            try s2.load()
            t.expect(s2.hasProcessed("cmd-42"))
            try s2.snapshot()
            let (s3, _, _) = makeStore(fs2, clock: c)
            try s3.load()
            t.expect(s3.hasProcessed("cmd-42"), "keys survive snapshots")
            t.throwsError { try s3.append([projectDraft("A3", id: "prj_8", at: c.now())], idempotencyKey: "cmd-42") }
            t.equal(s3.state.projects.count, 1)
        },
        TestCase("valid final batch without newline is kept and terminated") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("A", id: "prj_1", at: c.now())])
            var bytes = try fs.read(EventStore.journalFile)!
            bytes.removeLast() // drop trailing newline
            fs.setFile(EventStore.journalFile, bytes)
            let (s2, fs2, _) = makeStore(fs, clock: c)
            try s2.load()
            t.equal(s2.state.projects.count, 1)
            try s2.append([projectDraft("B", id: "prj_2", at: c.now())])
            let (s3, _, _) = makeStore(fs2, clock: c)
            let r = try s3.load()
            t.equal(s3.state.projects.count, 2)
            t.expect(r.isClean)
        },
        TestCase("v0 events are migrated on load") { t in
            let fs = InMemoryFileSystem()
            let project = try JSONCoding.encode(Project(id: "prj_old", name: "Legacy", createdAt: Timestamp(year: 2026, month: 1, day: 1)))
            let v0: JSONValue = ["id": "evt_old", "seq": 1, "at": "2026-01-01T00:00:00.000Z", "kind": ["projectUpserted": ["_0": project]]]
            let batch: JSONValue = [v0]
            let line = JSONWriter.string(["c": .string(FNV1a.hex64(JSONWriter.string(batch))), "b": batch]) + "\n"
            fs.setFile(EventStore.journalFile, Array(line.utf8))
            let (s, _, _) = makeStore(fs)
            try s.load()
            t.equal(s.state.projects["prj_old"]?.name, "Legacy")
            t.equal(s.recentEvents.first?.schema, LupyEvent.currentSchema)
        },
        TestCase("actions executing at crash time are reported as interrupted") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            let action = ProposedAction(id: "act_1", kind: .sendExternalMessage, title: "Email client", target: "client@example.com",
                                        detail: "", projectID: nil, taskID: nil, workerID: nil, idempotencyKey: "k1",
                                        estimatedCostCents: nil, reversible: false, originator: .lupy, createdAt: c.now())
            let rec = ActionRecord(id: "rec_1", action: action, state: .executing, attempts: 1, lastError: nil, createdAt: c.now(),
                                   startedAt: c.now(), finishedAt: nil, nextRetryAt: nil, resultSummary: nil)
            try s.append([EventDraft(by: .lupy, summary: "Executing", payload: .actionUpserted(rec))])
            let (s2, _, _) = makeStore(fs, clock: c)
            let report = try s2.load()
            t.equal(report.interruptedActions, ["rec_1"])
        },
        TestCase("full backup round-trips, detects tampering, restore archives instead of deleting") { t in
            let (s, fs, c) = makeStore()
            try s.load()
            try s.append([projectDraft("PENGLAI City", id: "prj_1", at: c.now()), taskDraft("Lore", id: "tsk_1", project: "prj_1", at: c.now())])
            try s.append([EventDraft(by: .founder, summary: "provider", payload: .providerUpserted(ProviderConfig(
                id: "openai", kind: .openAI, displayName: "OpenAI", baseURL: "https://api.openai.com/v1", keychainAccount: "openai",
                models: [], enabled: true, founderApproved: true, hasKey: true, priceAsOf: "2026-10", dataNotice: "", createdAt: c.now())))])
            let backup = try Backup.makeFullBackup(store: s, includeHistory: true, appVersion: "0.1.0", now: c.now())
            let text = String(decoding: backup, as: UTF8.self)
            t.expect(!text.contains("sk-"), "no secrets in backups")
            let parsed = try Backup.readBackup(backup)
            t.equal(parsed.manifest.eventCount, 3)
            t.equal(parsed.state, s.state)
            var tampered = backup
            if let i = tampered.firstIndex(of: UInt8(ascii: "L")) { tampered[i] = UInt8(ascii: "M") }
            do { _ = try Backup.readBackup(tampered); t.fail("tamper not detected") } catch let e as BackupError { t.equal(e, .checksumMismatch) }
            // Restore into a fresh Mac
            let (fresh, freshFS, _) = makeStore(clock: c)
            try fresh.load()
            try fresh.append([projectDraft("Scratch", id: "prj_x", at: c.now())])
            _ = try Backup.restore(backup, into: fresh)
            t.equal(fresh.state.projects.keys.sorted(), ["prj_1"])
            t.equal(fresh.state.providers["openai"]?.hasKey, false, "keys must be re-entered after restore")
            t.expect((try freshFS.list("")).contains { $0.hasPrefix("pre-restore-") }, "previous data archived")
            let (again, _, _) = makeStore(freshFS, clock: c)
            try again.load()
            t.equal(again.state.projects.keys.sorted(), ["prj_1"])
            _ = fs
        },
        TestCase("project export contains only that project; import remaps IDs on collision") { t in
            let (s, _, c) = makeStore()
            try s.load()
            try s.append([projectDraft("Clients", id: "prj_1", at: c.now()), projectDraft("Private", id: "prj_2", at: c.now()),
                          taskDraft("Invoice ACME", id: "tsk_1", project: "prj_1", at: c.now()),
                          taskDraft("Diary", id: "tsk_2", project: "prj_2", at: c.now())])
            let mem = MemoryItem(id: "mem_1", scope: .project("prj_2"), kind: .fact, title: "secret diary detail", body: "x", key: nil,
                                 status: .active, supersededBy: nil, source: .founder, confidence: 1, sensitive: true,
                                 createdAt: c.now(), updatedAt: c.now(), lastConfirmedAt: nil)
            try s.append([EventDraft(by: .founder, summary: "m", payload: .memoryUpserted(mem))])
            let export = try Backup.exportProject("prj_1", state: s.state, now: c.now())
            let text = String(decoding: export, as: UTF8.self)
            t.expect(text.contains("Invoice ACME"))
            t.expect(!text.contains("Diary") && !text.contains("secret diary"), "no data from other projects")
            let (drafts, report) = try Backup.importProject(export, into: s.state, ids: SequentialIDGenerator(), now: c.now())
            t.expect(report.remapped)
            try s.append(drafts)
            t.equal(s.state.projects.count, 3)
            t.equal(s.state.tasks.values.filter { $0.title == "Invoice ACME" }.count, 2)
            t.equal(s.state.tasks["tsk_1"]?.projectID, "prj_1", "original untouched")
            let md = Backup.markdown(project: "prj_1", state: s.state)
            t.expect(md.contains("# Clients") && md.contains("Invoice ACME"))
        },
    ])
}
