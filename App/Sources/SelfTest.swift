// Lupy macOS shell — native self-test, run with:  Lupy.app/Contents/MacOS/Lupy --self-test [--report path]
// Exercises LupyCore with the REAL disk adapter (fsync, atomic rename, recovery), backup,
// Keychain round trip and a performance/memory sample. Used by CI and for support.

import Foundation

enum SelfTest {
    static func run(arguments: [String]) -> Int32 {
        Notifier.enabled = false
        var lines: [String] = []
        var failures = 0
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            lines.append("\(ok ? "PASS" : "FAIL") \(name)\(detail.isEmpty ? "" : " — \(detail)")")
            if !ok { failures += 1 }
        }
        let started = Date()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lupy-selftest-\(UUID().uuidString)", isDirectory: true)
        lines.append("INFO Lupy self-test · macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · \(ProcessInfo.processInfo.processorCount) CPUs")
        do {
            let clock = SystemClock()
            let ids = RandomIDGenerator(clock: clock)
            let fs = try DiskFileSystem(root: dir)
            let store = EventStore(fileSystem: fs, clock: clock, ids: ids)
            check("fresh store loads clean", try store.load().isClean)
            let engine = LupyEngine(store: store, clock: clock, ids: ids)
            try engine.bootstrap(founderName: "Self Test", utcOffsetMinutes: TimeZone.current.secondsFromGMT() / 60)
            check("bootstrap creates the 10 founder projects", engine.state.projects.count == 10, "\(engine.state.projects.count)")
            guard let admin = engine.state.projects.values.first(where: { $0.name == "Personal admin" }) else { throw DiskError.io("no admin project") }
            let goal = try engine.captureGoal("Renew passport then pay the fee by Friday", projectID: admin.id)
            let plan = try engine.planHeuristically(goalID: goal.id)
            let tasks = try engine.approvePlan(plan.id)
            check("offline plan approved into dependent tasks", tasks.count == 2 && tasks[1].status == .waitingDependency)
            try engine.markDone(tasks[0].id)
            _ = try engine.tick()
            check("dependency released after completion", engine.state.tasks[tasks[1].id]?.status == .ready)

            // Agent-claim scenario on real disk: claim alone must not verify.
            guard let arena = engine.state.workers.values.first(where: { $0.name == "Arena" }),
                  let muse = engine.state.projects.values.first(where: { $0.name == "Muse / Arena" }) else { throw DiskError.io("defaults missing") }
            let coding = try engine.addTask(projectID: muse.id, title: "Self-test coding task", kind: .coding, acceptance: ["PR with passing CI"])
            let handoff = try engine.delegate(coding.id, to: arena.id)
            _ = try engine.dispatch(handoff.id)
            try engine.confirmRelayed(handoff.id)
            check("manual relay stays 'delivery unconfirmed'", engine.state.tasks[coding.id]?.status == .deliveryUnconfirmed)
            _ = try engine.recordWorkerReply(handoff.id, text: "Done, everything works!")
            let v = engine.state.verifications[coding.id]?.outcome
            check("a bare 'done' claim is not verified", v != .verified, "\(v.map { "\($0)" } ?? "no verification yet")")

            // Crash simulation: torn write on the real journal, then restart.
            try store.snapshot()
            _ = try engine.addTask(projectID: admin.id, title: "Persisted before crash")
            let journal = dir.appendingPathComponent(EventStore.journalFile)
            let h = try FileHandle(forWritingTo: journal)
            _ = try h.seekToEnd()
            try h.write(contentsOf: Data("{\"c\":\"0000\",\"b\":[{\"torn".utf8))
            try h.close()
            let store2 = EventStore(fileSystem: try DiskFileSystem(root: dir), clock: clock, ids: ids)
            let report = try store2.load()
            check("restart after torn write recovers all committed work",
                  report.truncatedBytes > 0 && store2.state.tasks.count == store.state.tasks.count && store2.state.tasks.values.contains { $0.title == "Persisted before crash" },
                  "truncated \(report.truncatedBytes) bytes")

            // Backup round trip.
            let backup = try Backup.makeFullBackup(store: store2, includeHistory: true, appVersion: "self-test", now: clock.now())
            let parsed = try Backup.readBackup(backup)
            check("backup round-trip preserves state", parsed.state == store2.state, "\(backup.count / 1024) KB")

            // Performance: 400 tasks, ranking and attention.
            let engine2 = LupyEngine(store: store2, clock: clock, ids: ids)
            let t0 = Date()
            for i in 0..<400 { _ = try engine2.addTask(projectID: admin.id, title: "Load test task \(i)", priority: PriorityInputs(urgency: i % 5)) }
            let addMs = Date().timeIntervalSince(t0) * 1000
            let t1 = Date()
            let ranked = engine2.rankedTasks()
            _ = engine2.attention()
            let rankMs = Date().timeIntervalSince(t1) * 1000
            check("400 durable task writes", ranked.count >= 400, "\(Int(addMs)) ms total (\(String(format: "%.1f", addMs / 400)) ms/write incl. fsync)")
            check("ranking + attention over 400+ tasks under 1.5 s", rankMs < 1500, "\(Int(rankMs)) ms")
            let t2 = Date()
            let store3 = EventStore(fileSystem: try DiskFileSystem(root: dir), clock: clock, ids: ids)
            _ = try store3.load()
            check("cold reload of all data under 3 s", Date().timeIntervalSince(t2) < 3, "\(Int(Date().timeIntervalSince(t2) * 1000)) ms")
        } catch {
            check("self-test ran without errors", false, "\(error)")
        }

        // Keychain (may be unavailable on headless CI machines — reported, not fatal).
        let account = "selftest.\(UUID().uuidString)"
        let saved = Keychain.save(account, "FAKE-self-test-value")
        let loaded = Keychain.load(account)
        Keychain.delete(account)
        lines.append(saved && loaded == "FAKE-self-test-value" ? "PASS Keychain save/load/delete round trip" : "WARN Keychain not usable in this environment (saved=\(saved))")

        lines.append("INFO resident memory after self-test: \(String(format: "%.1f", residentMemoryMB())) MB")
        lines.append("INFO duration \(Int(Date().timeIntervalSince(started) * 1000)) ms")
        try? FileManager.default.removeItem(at: dir)
        lines.append("SELFTEST \(failures == 0 ? "PASSED" : "FAILED") (\(failures) failure(s))")
        let text = lines.joined(separator: "\n")
        print(text)
        if let i = arguments.firstIndex(of: "--report"), i + 1 < arguments.count {
            try? text.write(toFile: arguments[i + 1], atomically: true, encoding: .utf8)
        }
        return failures == 0 ? 0 : 1
    }
}
