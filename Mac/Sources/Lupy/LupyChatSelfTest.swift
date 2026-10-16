// Lupy — conversation self-test (CI and support):
//   Lupy.app/Contents/MacOS/Lupy --chat-self-test [--report path] [--data-dir dir]
// The island's interaction loop driven end-to-end against the REAL engine on the real disk —
// every answer must reflect what actually happened:
//  1. a typed instruction becomes a captured goal with an offline plan, shown as a card;
//  2. “approve it” approves the newest plan and creates the tasks;
//  3. a status question is answered from real engine state (offline, honest);
//  4. an open question without a cloud model gets the honest no-model answer;
//  5. a screen-work request without computer control gets the honest blocker, not a fake run;
//  6. pause / resume really pause and resume the engine;
//  7. “stop” rejects a waiting plan and says exactly what it stopped;
//  8. follow-up turns carry the conversation's history into the prepared request
//     (checked through the engine — no network call is made);
//  9. the transcript is persisted to disk and decodes with the same messages.

import Foundation
import LupyCore

@MainActor
enum LupyChatSelfTest {
    static func run(arguments: [String]) -> Int32 {
        LupyNotifier.enabled = false
        var lines: [String] = []
        var failures = 0
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            lines.append("\(ok ? "PASS" : "FAIL") \(name)\(detail.isEmpty ? "" : " — \(detail)")")
            if !ok { failures += 1 }
        }
        lines.append("INFO Lupy conversation self-test · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

        let model = LupyModel.shared
        let chat = LupyChat.shared
        LupyControlCenter.shared.enabled = false   // deterministic: the blocker answer must be the real one
        guard let engine = model.engine else {
            lines.append("CHATTEST FAIL — Lupy's engine did not start: \(model.startupError ?? "?")")
            finish(lines: lines, arguments: arguments)
            return 2
        }

        // 1. A typed instruction → goal + offline plan + a plan card in the conversation.
        let before = chat.messages.count
        chat.send("Self-test: invoice ACME by Friday then follow up next week")
        let afterGoal = chat.messages.count
        check("a typed instruction is answered (goal → plan)", afterGoal >= before + 3,
              chat.messages.suffix(afterGoal - before).map { String($0.text.prefix(40)) }.joined(separator: " | "))
        let proposed = engine.state.plans.values.filter { $0.status == .proposed }
        check("the goal is captured and a plan is proposed", proposed.count == 1, "\(proposed.count) proposed")
        check("the conversation shows a plan card", chat.messages.contains { $0.kind == .plan })
        let goalTasks = proposed.first.map { $0.draftTasks.count } ?? 0
        check("the plan has real steps", goalTasks >= 1, "\(goalTasks) steps")

        // 2. “approve it” decides the plan; the tasks exist.
        let tasksBefore = engine.state.tasks.count
        chat.send("approve it")
        check("“approve it” approves the plan and creates the tasks", engine.state.tasks.count > tasksBefore,
              "\(engine.state.tasks.count - tasksBefore) new tasks")
        check("the approval answer reports the created steps",
              chat.messages.last?.text.contains("approved") == true, chat.messages.last?.text.prefix(80) ?? "")

        // 3. A status question is answered from real state, offline.
        chat.send("what's next")
        let statusAnswer = chat.messages.last?.text ?? ""
        check("a status question is answered locally from real state",
              statusAnswer.contains("Next up") || statusAnswer.contains("need you"), statusAnswer.prefix(80))

        // 4. An open question without a cloud model: the honest answer, never a guess.
        chat.send("Who owns the PENGLAI domain?")
        let askAnswer = chat.messages.last?.text ?? ""
        check("an open question without a model gets the honest no-model answer",
              askAnswer.localizedCaseInsensitiveContains("no cloud model"), askAnswer.prefix(80))

        // 5. Screen work without computer control: the honest blocker.
        chat.send("Open Safari and search for Displate payouts")
        let controlAnswer = chat.messages.last?.text ?? ""
        check("screen work without computer control explains the real blocker",
              controlAnswer.localizedCaseInsensitiveContains("computer control is off")
              || controlAnswer.localizedCaseInsensitiveContains("can't take over the screen"),
              controlAnswer.prefix(90))

        // 6. Pause and resume actually change the engine.
        chat.send("pause")
        check("“pause” pauses the engine", model.state.settings.globalPause)
        chat.send("resume")
        check("“resume” resumes the engine", !model.state.settings.globalPause)

        // 7. “stop” rejects a waiting plan and says so; with nothing running it says that too.
        chat.send("Self-test: organise the studio receipts")
        check("a second goal proposes a second plan", engine.state.plans.values.contains { $0.status == .proposed })
        chat.send("stop")
        check("“stop” rejects the waiting plan", !engine.state.plans.values.contains { $0.status == .proposed })
        let stopAnswer = chat.messages.last?.text ?? ""
        check("the stop answer reports what was actually stopped",
              stopAnswer.localizedCaseInsensitiveContains("rejected"), stopAnswer.prefix(90))
        chat.send("stop")
        check("“stop” with nothing running says so honestly",
              chat.messages.last?.text.localizedCaseInsensitiveContains("nothing is executing") == true,
              chat.messages.last?.text.prefix(60) ?? "")

        // 8. Follow-up turns carry the conversation's history (through the engine, no network).
        do {
            try engine.setProviderKeyPresent("openai", present: true)
            try engine.approveProvider("openai", approved: true)
            let history = chat.conversationHistory()
            check("the conversation history is non-empty for follow-ups", !history.isEmpty, "\(history.count) turns")
            let prepared = try engine.prepareConversationTurn(question: "and what about the fee?", history: history, projectID: nil)
            if case .job(let job) = prepared {
                let contents = job.request.messages.map(\.content)
                let carried = history.contains { h in contents.contains { $0.contains(h.content) } }
                check("a follow-up turn includes the conversation's history", carried,
                      "\(job.request.messages.count) messages in the request")
                check("the turn stays within the history cap", job.request.messages.count <= 20,
                      "\(job.request.messages.count) messages")
                // The job is never performed here — no network call happens in this self-test.
                _ = engine.pendingJob(job.id) != nil ? () : ()
            } else {
                check("a follow-up turn prepares a real job", false, "unavailable instead")
            }
        } catch {
            check("a follow-up turn prepares a real job", false, "\(error)")
        }

        // 9. The transcript persists and decodes with the same messages.
        chat.flushNow()
        let storeURL = model.dataURL.appendingPathComponent("conversation.json")
        var persisted = 0
        if let data = try? Data(contentsOf: storeURL) {
            struct File: Codable { var messages: [LupyChatMessage] }
            if let file = try? JSONDecoder().decode(File.self, from: data) {
                persisted = file.messages.count
            }
        }
        check("the transcript persists to disk and decodes", persisted == chat.messages.count,
              "file \(persisted) vs memory \(chat.messages.count)")

        lines.append(failures == 0 ? "CHATTEST PASSED (\(lines.count - failures) checks)" : "CHATTEST FAILED (\(failures) failures)")
        finish(lines: lines, arguments: arguments)
        return failures == 0 ? 0 : 1
    }

    private static func finish(lines: [String], arguments: [String]) {
        let text = lines.joined(separator: "\n")
        print(text)
        if let i = arguments.firstIndex(of: "--report"), i + 1 < arguments.count {
            try? text.write(toFile: arguments[i + 1], atomically: true, encoding: .utf8)
        }
    }
}
