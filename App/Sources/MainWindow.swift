// Lupy macOS shell — main window, Today screen, capture bar and plan review.

import SwiftUI

func relativeTime(_ t: Timestamp) -> String { t.date.formatted(.relative(presentation: .named)) }
func shortDate(_ t: Timestamp) -> String { t.date.formatted(date: .abbreviated, time: .shortened) }

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let selection = Binding<SidebarItem?>(get: { model.section }, set: { if let v = $0 { model.section = v } })
        ZStack(alignment: .bottom) {
            NavigationSplitView {
                List(selection: selection) {
                    Section {
                        ForEach(SidebarItem.allCases) { item in
                            HStack {
                                Label(item.title, systemImage: item.symbol)
                                Spacer()
                                if item == .approvals, model.attention.items.count > 0 {
                                    Text("\(model.attention.items.count)").font(.system(size: 10.5, weight: .bold)).monospacedDigit()
                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                        .background(LupyTheme.accent).foregroundColor(LupyTheme.onAccent).clipShape(Capsule())
                                }
                            }
                            .tag(item)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            LupyCharacterView(mood: model.mood, size: 26, animated: false)
                            Text("Lupy").font(.system(size: 13, weight: .semibold)).foregroundColor(LupyTheme.text)
                        }
                        .padding(.bottom, 4)
                    }
                }
                .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            } detail: {
                Group {
                    if let err = model.startupError {
                        EmptyHint(symbol: "exclamationmark.triangle", title: "Lupy could not start", detail: err)
                    } else {
                        switch model.section {
                        case .today: TodayView()
                        case .projects: ProjectsView()
                        case .tasks: TasksView()
                        case .approvals: ApprovalsView()
                        case .handoffs: HandoffsView()
                        case .memory: MemoryView()
                        case .activity: ActivityView()
                        case .usage: UsageView()
                        case .settings: SettingsView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LupyTheme.panel)
            }
            if let toast = model.toast {
                Text(toast)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(LupyTheme.text)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(CardBackground(wash: .soft, radius: 14))
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { model.toast = nil }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.toast)
        .onAppear { model.openWindowAction = openWindow }
        .sheet(isPresented: Binding(get: { !model.state.settings.onboardingComplete && model.startupError == nil },
                                    set: { _ in })) {
            OnboardingView().environment(model)
        }
    }
}

// MARK: - Today

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let s = model.state
        let a = model.attention
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    LupyCharacterView(mood: model.mood, size: 64, animated: model.animates(.window), fps: 12)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.greeting).font(.system(size: 22, weight: .semibold)).foregroundColor(LupyTheme.text)
                        Text(statusLine(a)).font(.system(size: 13)).foregroundColor(LupyTheme.secondary)
                    }
                    Spacer()
                    if a.paused {
                        Button("Resume Lupy") { model.act { try $0.setGlobalPause(false); return [] } }.buttonStyle(LupyPrimaryButtonStyle())
                    }
                }
                CaptureBar()
                let proposed = s.plans.values.filter { $0.status == .proposed }.sorted { $0.createdAt > $1.createdAt }
                if !proposed.isEmpty {
                    SectionTitle(text: "Plans waiting for your review")
                    ForEach(proposed) { plan in PlanReviewCard(plan: plan) }
                }
                let needs = a.items.filter { $0.kind != .planReview }
                if !needs.isEmpty {
                    SectionTitle(text: "Needs you")
                    ForEach(needs) { item in AttentionRow(item: item) }
                }
                SectionTitle(text: "Next up")
                if a.nextUp.isEmpty {
                    EmptyHint(symbol: "sparkles", title: "Nothing planned yet", detail: "Tell Lupy a goal above. Lupy will propose steps for you to approve.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(a.nextUp, id: \.self) { id in
                            if let t = s.tasks[id] { RankedTaskRow(task: t) }
                        }
                    }
                }
                let notes = s.drafts.values.filter { $0.taskID == nil }.sorted { $0.createdAt > $1.createdAt }.prefix(3)
                if !notes.isEmpty {
                    SectionTitle(text: "Latest from Lupy")
                    ForEach(Array(notes)) { d in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(d.title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(LupyTheme.text).lineLimit(1)
                                Spacer()
                                Text(relativeTime(d.createdAt)).font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
                                Button("Copy") { model.copy(d.body, announce: "Copied.") }.buttonStyle(LupySecondaryButtonStyle())
                                Button("Save") { model.saveDraftToFile(d) }.buttonStyle(LupySecondaryButtonStyle())
                            }
                            Text(d.body).font(.system(size: 12)).foregroundColor(LupyTheme.body).lineLimit(12).textSelection(.enabled)
                        }
                        .padding(14).background(CardBackground(wash: .soft))
                    }
                }
                HStack {
                    SectionTitle(text: "Brief")
                    Spacer()
                    if model.hasUsableModel {
                        Button("Write with model") { model.writeBriefWithModel() }.buttonStyle(LupySecondaryButtonStyle())
                    }
                }
                Text(model.engine?.templateBrief() ?? "")
                    .font(.system(size: 12.5)).foregroundColor(LupyTheme.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14).background(CardBackground(wash: .indigo))
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func statusLine(_ a: AttentionSummary) -> String {
        var parts: [String] = []
        parts.append(a.items.isEmpty ? "Nothing needs you right now" : "\(a.items.count) thing\(a.items.count == 1 ? "" : "s") need you")
        if a.activeCount > 0 { parts.append("\(a.activeCount) active") }
        if a.waitingOnOthers > 0 { parts.append("\(a.waitingOnOthers) delegated") }
        if a.unverifiedCount > 0 { parts.append("\(a.unverifiedCount) awaiting verification") }
        return parts.joined(separator: " · ")
    }
}

struct CaptureBar: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var projectID: LupyID?
    @State private var useModel = true
    @State private var askMode = false

    var body: some View {
        let projects = model.state.activeProjects
        let dictation = model.dictation
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                TextField(askMode ? "Ask Lupy anything about your work…" : "What do you want to get done? e.g. “Invoice ACME by Friday, then follow up next week”", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...5)
                    .padding(12)
                    .background(LupyTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit(submit)
                Button {
                    if dictation.isRecording {
                        dictation.stop()
                        if !dictation.transcript.isEmpty { text = (text.isEmpty ? "" : text + " ") + dictation.transcript }
                    } else {
                        dictation.start()
                    }
                } label: {
                    Image(systemName: dictation.isRecording ? "stop.circle.fill" : "mic.fill").font(.system(size: 16))
                        .frame(width: 40, height: 40)
                        .background(dictation.isRecording ? LupyTheme.red.opacity(0.3) : Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Dictate. You review the text before anything is sent.")
            }
            if dictation.isRecording {
                Text(dictation.transcript.isEmpty ? "Listening… (\(dictation.privacyNote))" : dictation.transcript)
                    .font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
            }
            if let err = dictation.error { Text(err).font(.system(size: 11.5)).foregroundColor(LupyTheme.red) }
            HStack(spacing: 12) {
                Picker("", selection: $askMode) {
                    Text("Plan a goal").tag(false)
                    Text("Ask Lupy").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
                .disabled(!model.hasUsableModel && !askMode)
                Picker("Project", selection: Binding(get: { projectID ?? model.defaultCaptureProject }, set: { projectID = $0 })) {
                    ForEach(projects) { p in Text(p.name).tag(p.id) }
                }
                .frame(maxWidth: 260)
                if askMode {
                    EmptyView()
                } else if model.hasUsableModel {
                    Toggle("Plan with cloud model", isOn: $useModel).toggleStyle(.switch).controlSize(.small)
                } else {
                    Text("Offline planning").font(.system(size: 11.5)).foregroundColor(LupyTheme.muted).lineLimit(1)
                        .help("No cloud model is set up, so Lupy plans with offline rules. Add one in Settings → Cloud model providers.")
                }
                Spacer()
                Button(askMode ? "Ask" : "Plan it", action: submit).buttonStyle(LupyPrimaryButtonStyle()).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .background(CardBackground(wash: .soft))
    }

    private func submit() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if askMode {
            model.ask(t, projectID: projectID ?? model.defaultCaptureProject)
        } else {
            model.capture(t, projectID: projectID ?? model.defaultCaptureProject, useModel: useModel && model.hasUsableModel)
        }
        text = ""
    }
}

struct PlanReviewCard: View {
    @Environment(AppModel.self) private var model
    let plan: Plan
    @State private var note = ""

    var body: some View {
        let project = model.state.projects[plan.projectID]
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.summary).font(.system(size: 14, weight: .semibold)).foregroundColor(LupyTheme.text)
                    Text("\(project?.name ?? "") · \(plan.method.label) · \(plan.draftTasks.count) step(s)").font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
                }
                Spacer()
            }
            ForEach(plan.warnings, id: \.self) { w in
                Label(w, systemImage: "exclamationmark.triangle").font(.system(size: 11.5)).foregroundColor(LupyTheme.amber)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(plan.draftTasks.enumerated()), id: \.element.id) { idx, t in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(LupyTheme.muted).frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.title).font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text)
                            HStack(spacing: 8) {
                                StatusChip(text: t.kind.label, color: LupyTheme.secondary)
                                if !t.dependsOn.isEmpty { Text("after \(t.dependsOn.count) step(s)").font(.system(size: 10.5)).foregroundColor(LupyTheme.muted) }
                                if let d = t.deadline { Text("due \(shortDate(d))").font(.system(size: 10.5)).foregroundColor(LupyTheme.amber) }
                            }
                            ForEach(t.acceptance) { c in
                                Text("✓ \(c.text) — \(c.requirement.label)").font(.system(size: 10.5)).foregroundColor(LupyTheme.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            model.act { try $0.removeDraftTask(planID: plan.id, taskID: t.id); return [] }
                        } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                        .buttonStyle(.plain).foregroundColor(LupyTheme.muted).help("Remove this step")
                    }
                }
            }
            if !plan.risks.isEmpty {
                Text("Risks: " + plan.risks.joined(separator: "; ")).font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
            }
            if !plan.openQuestions.isEmpty {
                Text("Questions: " + plan.openQuestions.joined(separator: "; ")).font(.system(size: 11.5)).foregroundColor(LupyTheme.cyan)
            }
            HStack {
                TextField("Why reject? (optional)", text: $note).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                Spacer()
                Button("Reject") { model.act { try $0.rejectPlan(plan.id, note: note); return [] } }.buttonStyle(LupySecondaryButtonStyle())
                Button("Approve plan") { model.act { _ = try $0.approvePlan(plan.id); return [] }; model.say("Plan approved. Tasks are ready.") }
                    .buttonStyle(LupyPrimaryButtonStyle())
            }
        }
        .padding(16)
        .background(CardBackground(wash: model.selectedPlanID == plan.id ? .amber : .cyan))
    }
}

struct AttentionRow: View {
    @Environment(AppModel.self) private var model
    let item: AttentionItem

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(LupyTheme.severityColor(item.severity)).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 13, weight: .medium)).foregroundColor(LupyTheme.text).lineLimit(2)
                if !item.detail.isEmpty { Text(item.detail).font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary).lineLimit(2) }
            }
            Spacer()
            if item.kind == .approval, let id = item.relatedID {
                Button("Deny") { model.act { try $0.decideApproval(id, approve: false) } }.buttonStyle(LupySecondaryButtonStyle())
                Button("Allow") { model.act { try $0.decideApproval(id, approve: true) } }.buttonStyle(LupyPrimaryButtonStyle())
            } else {
                Button("Open") { model.focus(item) }.buttonStyle(LupySecondaryButtonStyle())
            }
        }
        .padding(12)
        .background(CardBackground(wash: item.severity == .urgent ? .red : .amber, radius: 14))
    }
}

struct RankedTaskRow: View {
    @Environment(AppModel.self) private var model
    let task: LupyTask

    var body: some View {
        let s = model.state
        let pa = PriorityEngine.assess(task, state: s, now: SystemClock().now())
        Button {
            model.selectedTaskID = task.id
            model.section = .tasks
        } label: {
            HStack(spacing: 12) {
                Text("\(Int(pa.score))").font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundColor(LupyTheme.accent).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.system(size: 13, weight: .medium)).foregroundColor(LupyTheme.text).lineLimit(1)
                    Text("\(s.projects[task.projectID]?.name ?? "") · \(pa.explanation)").font(.system(size: 11)).foregroundColor(LupyTheme.secondary).lineLimit(1)
                }
                Spacer()
                StatusChip(text: task.status.label, color: LupyTheme.statusColor(task.status))
            }
            .padding(12)
            .background(CardBackground(radius: 12))
        }
        .buttonStyle(.plain)
    }
}
