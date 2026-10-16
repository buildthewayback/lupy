// Ported from the previous Lupy window (App/Sources/WorkViews.swift, git 09c8c75) by scripts/port-lupy-views.py.
// Coucou's hub colours and components via LupyStyle.swift; logic and engine calls unchanged.

import LupyCore
import SwiftUI

// MARK: - Projects

struct LupyProjectsContent: View {
    private var model: LupyModel { LupyModel.shared }
    @State private var newName = ""

    var body: some View {
        let s = model.state
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("New project", text: $newName).textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let n = newName
                        model.act { _ = try $0.createProject(name: n); return [] }
                        newName = ""
                    }
                    .disabled(newName.isEmpty)
                }
                .padding(.bottom, 4)
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(s.activeProjects) { p in
                            let open = s.tasks(in: p.id).filter { !$0.status.isTerminal }.count
                            Button {
                                model.selectedProjectID = p.id
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: p.symbol).foregroundColor(Color(hex: p.colorHex)).frame(width: 18)
                                    Text(p.name).font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text).lineLimit(1)
                                    Spacer()
                                    Text("\(open)").font(.system(size: 11)).monospacedDigit().foregroundColor(LupyTheme.secondary)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(model.selectedProjectID == p.id ? Color.white.opacity(0.08) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button("Import project…") { model.importProject() }.buttonStyle(LupySecondaryButtonStyle())
            }
            .padding(14)
            .frame(width: 260)
            .background(LupyTheme.window.opacity(0.4))
            Divider()
            if let pid = model.selectedProjectID ?? s.activeProjects.first?.id, let p = s.projects[pid] {
                LupyProjectDetail(project: p)
            } else {
                LupyEmptyHint(symbol: "square.grid.2x2", title: "No project selected", detail: "Choose a project on the left.")
            }
        }
    }
}

struct LupyProjectDetail: View {
    private var model: LupyModel { LupyModel.shared }
    let project: Project
    @State private var rule = ""
    @State private var repo = ""
    @State private var taskTitle = ""

    var body: some View {
        let s = model.state
        let tasks = s.tasks(in: project.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: project.symbol).font(.system(size: 22)).foregroundColor(Color(hex: project.colorHex))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name).font(.system(size: 20, weight: .semibold)).foregroundColor(LupyTheme.text)
                        Text(project.summary).font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
                    }
                    Spacer()
                    Menu("Export") {
                        Button("Readable summary (Markdown)…") { model.exportProject(project.id, markdown: true) }
                        Button("Project file (to move or share)…") { model.exportProject(project.id, markdown: false) }
                    }
                    .frame(width: 100)
                }
                HStack {
                    TextField("Add a task to \(project.name)", text: $taskTitle).textFieldStyle(.roundedBorder)
                        .onSubmit(addTask)
                    Button("Add task", action: addTask).buttonStyle(LupySecondaryButtonStyle()).disabled(taskTitle.isEmpty)
                }
                LupySectionTitle(text: "Project rules (Lupy and every handoff must respect them)")
                ForEach(project.rules) { r in
                    Label(r.text, systemImage: "checkmark.shield").font(.system(size: 12)).foregroundColor(LupyTheme.body)
                }
                HStack {
                    TextField("Add a rule, e.g. “No client emails without my OK”", text: $rule).textFieldStyle(.roundedBorder)
                    Button("Add rule") {
                        let text = rule
                        model.act { try $0.addProjectRule(project.id, text: text); return [] }
                        rule = ""
                    }
                    .disabled(rule.isEmpty)
                }
                if !project.neverAutomate.isEmpty {
                    Text("Always needs your approval here: " + project.neverAutomate.map(\.label).joined(separator: ", "))
                        .font(.system(size: 11.5)).foregroundColor(LupyTheme.amber)
                }
                HStack {
                    Text("GitHub repository for evidence:").font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
                    TextField(project.repository ?? "owner/name", text: $repo).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                    Button("Save") {
                        var p = project
                        p.repository = repo.isEmpty ? nil : repo
                        model.act { try $0.updateProject(p); return [] }
                    }
                }
                ForEach(groups(tasks)) { group in
                    LupySectionTitle(text: "\(group.id) (\(group.tasks.count))")
                    ForEach(group.tasks) { t in LupyTaskRow(task: t) }
                }
            }
            .padding(24)
        }
        .onAppear { repo = project.repository ?? "" }
    }

    private func addTask() {
        let t = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        model.act { _ = try $0.addTask(projectID: project.id, title: t); return [] }
        taskTitle = ""
    }

    struct TaskGroup: Identifiable {
        let id: String
        let tasks: [LupyTask]
    }

    private func groups(_ tasks: [LupyTask]) -> [TaskGroup] {
        let defs: [(String, (LupyTask) -> Bool)] = [
            ("Needs you", { $0.status.needsFounder }),
            ("In motion", { $0.status.isActionable || $0.status.isDelegationState || $0.status == .submitted || $0.status == .verifying }),
            ("Waiting", { [.planned, .waitingDependency, .blocked, .paused].contains($0.status) }),
            ("Verified & done", { [.verified, .accepted, .completed].contains($0.status) }),
            ("Stopped", { [.failed, .cancelled].contains($0.status) }),
        ]
        return defs.map { TaskGroup(id: $0.0, tasks: tasks.filter($0.1)) }.filter { !$0.tasks.isEmpty }
    }
}

struct LupyTaskRow: View {
    private var model: LupyModel { LupyModel.shared }
    let task: LupyTask
    var body: some View {
        Button {
            model.selectedTaskID = task.id
            model.open(.lupyTasks)
        } label: {
            HStack(spacing: 10) {
                Circle().fill(LupyTheme.statusColor(task.status)).frame(width: 7, height: 7)
                Text(task.title).font(.system(size: 12.5)).foregroundColor(LupyTheme.text).lineLimit(1)
                Spacer()
                if let d = task.deadline { Text(lupyShortDate(d)).font(.system(size: 10.5)).foregroundColor(LupyTheme.muted) }
                LupyStatusChip(text: task.status.label, color: LupyTheme.statusColor(task.status))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(LupyCardBackground(radius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tasks

struct LupyRankedItem: Identifiable {
    let task: LupyTask
    let assessment: PriorityAssessment
    var id: LupyID { task.id }
}

struct LupyTasksContent: View {
    private var model: LupyModel { LupyModel.shared }
    @State private var showDone = false

    var body: some View {
        let s = model.state
        let ranked = (model.engine?.rankedTasks() ?? []).map { LupyRankedItem(task: $0.0, assessment: $0.1) }
        let done = s.tasks.values.filter { $0.status.isTerminal }.sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    LupySectionTitle(text: "Open tasks, most important first")
                    if ranked.isEmpty { LupyEmptyHint(symbol: "checklist", title: "No open tasks", detail: "Approve a plan or add tasks in a project.") }
                    ForEach(ranked) { pair in
                        let t = pair.task
                        Button {
                            model.selectedTaskID = t.id
                        } label: {
                            HStack(spacing: 8) {
                                Text("\(Int(pair.assessment.score))").font(.system(size: 11, weight: .bold)).monospacedDigit().foregroundColor(LupyTheme.accent).frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(t.title).font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text).lineLimit(1)
                                    Text(s.projects[t.projectID]?.name ?? "").font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
                                }
                                Spacer()
                                Circle().fill(LupyTheme.statusColor(t.status)).frame(width: 7, height: 7)
                            }
                            .padding(8)
                            .background(model.selectedTaskID == t.id ? Color.white.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    Toggle("Show finished (\(done.count))", isOn: $showDone).toggleStyle(.checkbox).padding(.top, 8)
                    if showDone {
                        ForEach(done.prefix(100)) { t in
                            Button { model.selectedTaskID = t.id } label: {
                                Text(t.title).font(.system(size: 12)).foregroundColor(LupyTheme.secondary).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
            }
            .frame(width: 330)
            Divider()
            if let id = model.selectedTaskID, let t = s.tasks[id] {
                LupyTaskDetailView(task: t)
            } else {
                LupyEmptyHint(symbol: "hand.point.left", title: "Choose a task", detail: "You'll see why it matters, its evidence and what Lupy can do next.")
            }
        }
    }
}

struct LupyTaskDetailView: View {
    private var model: LupyModel { LupyModel.shared }
    let task: LupyTask
    @State private var note = ""
    @State private var link = ""

    var body: some View {
        let s = model.state
        let now = LupySystemClock().now()
        let pa = PriorityEngine.assess(task, state: s, now: now)
        let evidence = s.evidence(for: task.id).reversed()
        let verification = s.verifications[task.id]
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title).font(.system(size: 19, weight: .semibold)).foregroundColor(LupyTheme.text)
                        Text("\(s.projects[task.projectID]?.name ?? "") · \(task.kind.label) · owner: \(ownerName(task.owner, s))").font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
                    }
                    Spacer()
                    LupyStatusChip(text: task.status.label, color: LupyTheme.statusColor(task.status))
                }
                if !task.statusNote.isEmpty { Text(task.statusNote).font(.system(size: 12)).foregroundColor(LupyTheme.amber) }
                if !task.details.isEmpty { Text(task.details).font(.system(size: 12.5)).foregroundColor(LupyTheme.body) }
                actions
                LupySectionTitle(text: "Done means")
                ForEach(VerificationEngine.criteria(for: task)) { c in
                    let r = verification?.criteria.first { $0.criterionID == c.id }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: icon(r?.outcome)).foregroundColor(color(r?.outcome))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.text).font(.system(size: 12.5)).foregroundColor(LupyTheme.text)
                            Text(r?.explanation ?? c.requirement.label).font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
                        }
                    }
                }
                if let v = verification {
                    Text(v.summary).font(.system(size: 11.5)).foregroundColor(color(v.outcome))
                }
                LupySectionTitle(text: "Why this priority (\(Int(pa.score))/100)")
                Text(pa.factors.filter { abs($0.points) >= 0.5 }.map { "\($0.name) \($0.points >= 0 ? "+" : "")\(Int($0.points.rounded())) — \($0.note)" }.joined(separator: "\n"))
                    .font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
                if let hid = task.handoffID, let h = s.handoffs[hid] {
                    LupySectionTitle(text: "Handoff to \(s.workers[h.workerID]?.name ?? "worker")")
                    LupyHandoffPanel(handoff: h)
                }
                LupySectionTitle(text: "Evidence (\(evidence.count))")
                HStack {
                    TextField("Add a note or link as evidence", text: $note).textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let n = note
                        model.act { _ = try $0.recordEvidence(taskID: task.id, kind: .founderConfirmation, summary: n, verdict: .inconclusive, reference: nil, by: .founder); return [] }
                        note = ""
                    }
                    .disabled(note.isEmpty)
                }
                ForEach(Array(evidence)) { e in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: e.verdict == .supports ? "checkmark.circle" : (e.verdict == .contradicts ? "xmark.octagon" : "questionmark.circle"))
                            .foregroundColor(e.verdict == .supports ? LupyTheme.green : (e.verdict == .contradicts ? LupyTheme.red : LupyTheme.secondary))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.summary).font(.system(size: 12)).foregroundColor(LupyTheme.body)
                            HStack(spacing: 6) {
                                LupyStatusChip(text: e.kind.label, color: LupyTheme.secondary)
                                LupyStatusChip(text: e.independence == .selfReported ? "self-reported" : (e.independence == .founder ? "you" : "independent"),
                                           color: e.independence == .selfReported ? LupyTheme.amber : LupyTheme.green)
                                Text(lupyRelativeTime(e.observedAt)).font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
                                if let ref = e.reference, let url = URL(string: ref), ref.hasPrefix("https://") {
                                    Link("open", destination: url).font(.system(size: 10.5))
                                }
                            }
                        }
                    }
                }
                let drafts = s.drafts.values.filter { $0.taskID == task.id }.sorted { $0.createdAt > $1.createdAt }
                if let d = drafts.first {
                    LupySectionTitle(text: "Latest draft")
                    Text(d.body).font(.system(size: 12.5)).foregroundColor(LupyTheme.body).textSelection(.enabled)
                        .padding(12).background(LupyCardBackground(wash: .soft, radius: 12))
                    HStack(spacing: 8) {
                        Button("Copy draft") { model.copy(d.body, announce: "Draft copied.") }.buttonStyle(LupySecondaryButtonStyle())
                        Button("Save to Documents/Lupy") { model.saveDraftToFile(d) }.buttonStyle(LupySecondaryButtonStyle())
                            .help("Lupy writes the file, reads it back and checks its fingerprint before calling it saved.")
                    }
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder private var actions: some View {
        let s = model.state
        let st = task.status
        let workers = s.workers.values.filter(\.enabled).sorted { $0.name < $1.name }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if [.ready, .planned, .waitingDependency].contains(st) {
                    Button("Start") { model.act { try $0.startTask(task.id); return [] } }.buttonStyle(LupyPrimaryButtonStyle())
                }
                if !st.isTerminal && st != .verified && st != .accepted {
                    Button(Lifecycle.founderSelfCompletable(task) ? "Mark done" : "I confirm it's done") {
                        model.act { try $0.markDone(task.id); return [] }
                    }
                    .buttonStyle(LupySecondaryButtonStyle())
                }
                if st == .verified {
                    Button("Accept") { model.act { try $0.accept(task.id); return [] } }.buttonStyle(LupyPrimaryButtonStyle())
                }
                if [.submitted, .verifying, .waitingFounder, .escalated].contains(st) {
                    Button("Check evidence now") { model.act { _ = try $0.verify(task.id); return [] } }.buttonStyle(LupySecondaryButtonStyle())
                    Button("Request rework") { model.act { try $0.requestRework(task.id, note: "Please address the failed or missing acceptance criteria.") } }
                        .buttonStyle(LupySecondaryButtonStyle())
                    Button("Accept without verification") { model.act { try $0.accept(task.id, withoutVerification: true); return [] } }
                        .buttonStyle(LupyDangerButtonStyle())
                }
            }
            HStack(spacing: 8) {
                if !st.isTerminal && task.handoffID.map({ s.handoffs[$0]?.state.isOpen != true }) ?? true {
                    Menu("Delegate to…") {
                        ForEach(workers) { w in
                            Button("\(w.name) — \(w.channel.label)") {
                                model.act { _ = try $0.delegate(task.id, to: w.id); return [] }
                                model.open(.lupyHandoffs)
                            }
                        }
                    }
                    .frame(width: 130)
                }
                if !st.isTerminal {
                    if st == .paused {
                        Button("Resume") { model.act { try $0.resume(task.id); return [] } }.buttonStyle(LupySecondaryButtonStyle())
                    } else {
                        Button("Pause") { model.act { try $0.pause(task.id); return [] } }.buttonStyle(LupySecondaryButtonStyle())
                    }
                    Button(task.pin > 0 ? "Unpin" : "Pin to top") { let v = task.pin > 0 ? 0 : 1; model.act { try $0.pin(task.id, v); return [] } }
                        .buttonStyle(LupySecondaryButtonStyle())
                    Button("Cancel task") { model.act { try $0.cancel(task.id, note: "Cancelled by you"); return [] } }.buttonStyle(LupyDangerButtonStyle())
                } else {
                    Button("Reopen") { model.act { try $0.reopen(task.id, note: "Reopened by you"); return [] } }.buttonStyle(LupySecondaryButtonStyle())
                }
                if model.hasUsableModel && [.writing, .research, .communication, .publishing, .general].contains(task.kind) && !st.isTerminal {
                    Button("Ask Lupy to draft") {
                        model.act { e in
                            switch try e.prepareDraft(taskID: task.id) {
                            case .job(let j): return [.callModel(j)]
                            case .needsApproval: model.say("Approval needed — see Needs you."); return []
                            case .unavailable(let why): model.say(why); return []
                            }
                        }
                    }
                    .buttonStyle(LupySecondaryButtonStyle())
                }
            }
        }
    }

    private func ownerName(_ o: TaskOwner, _ s: LupyState) -> String {
        if case .worker(let id) = o { return s.workers[id]?.name ?? "worker" }
        return o.label
    }

    private func icon(_ o: VerificationOutcome?) -> String {
        switch o {
        case .verified: return "checkmark.seal.fill"
        case .contradicted: return "xmark.octagon.fill"
        case .ambiguous: return "questionmark.diamond"
        case .claimOnly: return "quote.bubble"
        default: return "circle.dotted"
        }
    }

    private func color(_ o: VerificationOutcome?) -> Color {
        switch o {
        case .verified: return LupyTheme.green
        case .contradicted: return LupyTheme.red
        case .ambiguous, .claimOnly: return LupyTheme.amber
        default: return LupyTheme.secondary
        }
    }
}

// MARK: - Handoffs

struct LupyHandoffsContent: View {
    private var model: LupyModel { LupyModel.shared }
    var body: some View {
        let s = model.state
        let list = s.handoffs.values.sorted { a, b in a.state.isOpen != b.state.isOpen ? a.state.isOpen : a.createdAt > b.createdAt }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Handoffs").font(.system(size: 20, weight: .semibold)).foregroundColor(LupyTheme.text)
                Text("Arena, Muse and Orin have no connection Lupy can use, so you paste briefs and replies. Lupy never claims a message was delivered unless it can see evidence.")
                    .font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
                if list.isEmpty { LupyEmptyHint(symbol: "arrow.left.arrow.right", title: "No handoffs yet", detail: "Open a task and choose “Delegate to…”.") }
                ForEach(list) { h in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(s.tasks[h.taskID]?.title ?? "Task").font(.system(size: 13.5, weight: .semibold)).foregroundColor(LupyTheme.text)
                            Spacer()
                            LupyStatusChip(text: h.state.label, color: h.state.isOpen ? LupyTheme.indigo : LupyTheme.muted)
                        }
                        Text("To \(s.workers[h.workerID]?.name ?? "worker") · \(h.channel.label) · ref \(h.brief.reference)").font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
                        if h.state.isOpen { LupyHandoffPanel(handoff: h) }
                    }
                    .padding(14)
                    .background(LupyCardBackground(wash: h.state == .awaitingRelay ? .amber : .soft))
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

struct LupyHandoffPanel: View {
    private var model: LupyModel { LupyModel.shared }
    let handoff: Handoff
    @State private var reply = ""

    var body: some View {
        let s = model.state
        let worker = s.workers[handoff.workerID]
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                switch handoff.state {
                case .drafted, .reworkRequested:
                    Button(handoff.state == .drafted ? "Send (copy brief)" : "Copy rework message again") {
                        model.act { e in
                            let r = try e.dispatch(handoff.id)
                            if let why = r.blockedReason { model.say(why) }
                            return r.effects
                        }
                    }
                    .buttonStyle(LupyPrimaryButtonStyle())
                    if handoff.state == .reworkRequested {
                        Button("I pasted it") { model.act { try $0.confirmRelayed(handoff.id); return [] } }.buttonStyle(LupySecondaryButtonStyle())
                    }
                case .awaitingRelay:
                    Button("Copy brief again") {
                        model.copy(HandoffBriefWriter.render(handoff.brief, workerName: worker?.name ?? "", utcOffsetMinutes: s.settings.utcOffsetMinutes),
                                   announce: "Brief copied.")
                    }
                    .buttonStyle(LupySecondaryButtonStyle())
                    Button("I pasted it into \(worker?.name ?? "the agent")") { model.act { try $0.confirmRelayed(handoff.id); return [] } }
                        .buttonStyle(LupyPrimaryButtonStyle())
                default:
                    EmptyView()
                }
                // Lupy (port): computer control can deliver the brief itself while you watch its cursor.
                if [.drafted, .awaitingRelay, .reworkRequested].contains(handoff.state), let w = worker {
                    Button {
                        LupyDelivery.deliver(handoff.id)
                    } label: {
                        Label("Deliver with Lupy", systemImage: "cursorarrow.motionlines")
                    }
                    .buttonStyle(LupySecondaryButtonStyle())
                    .disabled(LupyControlCenter.shared.isActive)
                    .help(LupyDelivery.target(for: w) == nil
                          ? "Tell Lupy where you talk to \(w.name) first (Lupy → Computer control)."
                          : "Lupy opens \(LupyDelivery.describe(LupyDelivery.target(for: w))), types the brief and asks you before clicking Send.")
                }
            }
            if [.deliveryUnconfirmed, .sent, .acknowledged, .progressEvidenced, .submitted, .verifying, .stalled].contains(handoff.state) {
                Text("Paste \(worker?.name ?? "the worker")'s reply (Lupy records it as a claim and checks evidence):").font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
                TextEditor(text: $reply).font(.system(size: 12)).frame(minHeight: 70, maxHeight: 140)
                    .scrollContentBackground(.hidden).padding(6).background(LupyTheme.field).clipShape(RoundedRectangle(cornerRadius: 8))
                HStack {
                    Button("Record reply") {
                        let text = reply
                        model.act { e in
                            let r = try e.recordWorkerReply(handoff.id, text: text)
                            if !r.injectionWarnings.isEmpty { model.say("Note: the reply contained instruction-like text; Lupy treated it only as data.") }
                            return r.effects
                        }
                        reply = ""
                    }
                    .buttonStyle(LupyPrimaryButtonStyle()).disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let nf = handoff.nextFollowUpAt { Text("Next check-in \(lupyRelativeTime(nf))").font(.system(size: 11)).foregroundColor(LupyTheme.muted) }
                    Spacer()
                    if model.hasUsableModel, let last = handoff.notes.last(where: { if case .worker = $0.by { return true } else { return false } }) {
                        Button("Have the model read the last reply") { model.analyzeReply(handoffID: handoff.id, text: last.text) }
                            .buttonStyle(LupySecondaryButtonStyle())
                            .help("Advisory summary only — it is never treated as evidence.")
                    }
                }
            }
            ForEach(Array(handoff.notes.suffix(6).enumerated()), id: \.offset) { _, n in
                Text("\(lupyRelativeTime(n.at)) · \(n.by.label): \(n.text)").font(.system(size: 11)).foregroundColor(LupyTheme.secondary).lineLimit(3)
            }
        }
    }
}

// MARK: - Approvals

struct LupyApprovalsContent: View {
    private var model: LupyModel { LupyModel.shared }

    var body: some View {
        let s = model.state
        let pending = s.pendingApprovals
        let standing = s.standingApprovals.values.filter { $0.revokedAt == nil }.sorted { $0.createdAt > $1.createdAt }
        let decided = s.approvals.values.filter { $0.status != .pending }.sorted { ($0.decidedAt ?? $0.requestedAt) > ($1.decidedAt ?? $1.requestedAt) }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Needs you").font(.system(size: 20, weight: .semibold)).foregroundColor(LupyTheme.text)
                ForEach(model.attention.items.filter { $0.kind != .approval }) { item in LupyAttentionRow(item: item) }
                let interrupted = model.interruptedActions
                if !interrupted.isEmpty {
                    LupySectionTitle(text: "Interrupted actions — did they happen?")
                    ForEach(interrupted) { rec in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.action.title).font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text)
                                Text("Lupy stopped while doing this, so it can't know the outcome. Target: \(rec.action.target)").font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
                            }
                            Spacer()
                            Button("It did not happen") { model.act { try $0.resolveUnknownAction(rec.id, happened: false, note: "checked by you"); return [] } }
                                .buttonStyle(LupySecondaryButtonStyle())
                            Button("It happened") { model.act { try $0.resolveUnknownAction(rec.id, happened: true, note: "checked by you"); return [] } }
                                .buttonStyle(LupySecondaryButtonStyle())
                        }
                        .padding(10).background(LupyCardBackground(wash: .amber, radius: 12))
                    }
                }
                LupySectionTitle(text: "Approvals (\(pending.count))")
                if pending.isEmpty { Text("Nothing is waiting for approval.").font(.system(size: 12)).foregroundColor(LupyTheme.secondary) }
                ForEach(pending) { a in LupyApprovalCard(request: a) }
                LupySectionTitle(text: "Standing approvals (\(standing.count))")
                Text("Narrow, expiring permissions you granted. Some actions (deleting data, security, access) can never be pre-approved.")
                    .font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
                ForEach(standing) { sa in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(sa.kind.label) → \(sa.targetPattern)").font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text)
                            Text("\(sa.projectID.flatMap { s.projects[$0]?.name } ?? "any project") · used \(sa.uses)\(sa.maxUses.map { "/\($0)" } ?? "") · expires \(lupyShortDate(sa.expiresAt))")
                                .font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
                        }
                        Spacer()
                        Button("Revoke") { model.act { try $0.revokeStandingApproval(sa.id); return [] } }.buttonStyle(LupyDangerButtonStyle())
                    }
                    .padding(10).background(LupyCardBackground(radius: 12))
                }
                LupySectionTitle(text: "History")
                ForEach(decided.prefix(30)) { a in
                    Text("\(a.status.rawValue.capitalized): \(a.action.title) — \(lupyShortDate(a.decidedAt ?? a.requestedAt))").font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

struct LupyApprovalCard: View {
    private var model: LupyModel { LupyModel.shared }
    let request: ApprovalRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.action.title).font(.system(size: 13.5, weight: .semibold)).foregroundColor(LupyTheme.text)
                Spacer()
                LupyStatusChip(text: "\(request.risk.label) risk", color: request.risk >= .high ? LupyTheme.red : LupyTheme.amber)
            }
            Text(request.reasons.joined(separator: " ")).font(.system(size: 12)).foregroundColor(LupyTheme.body)
            if !request.action.detail.isEmpty { Text(request.action.detail).font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary).lineLimit(4) }
            Text(request.consequence).font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
            Text("Requested by \(request.action.originator.label) · \(lupyRelativeTime(request.requestedAt))").font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
            HStack(spacing: 8) {
                Button("Deny") { model.act { try $0.decideApproval(request.id, approve: false) } }.buttonStyle(LupySecondaryButtonStyle())
                Button("Allow once") { model.act { try $0.decideApproval(request.id, approve: true) } }.buttonStyle(LupyPrimaryButtonStyle())
                if !request.action.kind.neverStanding && request.action.kind != .modelCall {
                    Button("Allow this for 7 days") { model.act { try $0.decideApproval(request.id, approve: true, standingDays: 7, standingMaxUses: 20) } }
                        .buttonStyle(LupySecondaryButtonStyle())
                }
            }
        }
        .padding(14)
        .background(LupyCardBackground(wash: .amber))
    }
}
