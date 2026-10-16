// Ported from the previous Lupy window (App/Sources/MainWindow.swift, git 09c8c75) by scripts/port-lupy-views.py.
// Coucou's hub colours and components via LupyStyle.swift; logic and engine calls unchanged.

import LupyCore
import SwiftUI

struct LupyTodayContent: View {
    private var model: LupyModel { LupyModel.shared }

    var body: some View {
        let s = model.state
        let a = model.attention
        // Lupy (port): the greeting, status and Mochis are in the page's hero band (LupyTodayPage).
        VStack(alignment: .leading, spacing: 18) {
            LupyCaptureBar()
            if LupyControlCenter.shared.isActive || LupyControlCenter.shared.lastRun != nil {
                LupyControlStatusCard()
            }
            let proposed = s.plans.values.filter { $0.status == .proposed }.sorted { $0.createdAt > $1.createdAt }
            if !proposed.isEmpty {
                LupySectionTitle(text: "Plans waiting for your review")
                ForEach(proposed) { plan in LupyPlanReviewCard(plan: plan) }
            }
            let needs = a.items.filter { $0.kind != .planReview }
            if !needs.isEmpty {
                LupySectionTitle(text: "Needs you")
                ForEach(needs) { item in LupyAttentionRow(item: item) }
            }
            LupySectionTitle(text: "Next up")
            if a.nextUp.isEmpty {
                LupyEmptyHint(symbol: "sparkles", title: "Nothing planned yet", detail: "Tell Lupy a goal above. Lupy will propose steps for you to approve.")
            } else {
                VStack(spacing: 8) {
                    ForEach(a.nextUp, id: \.self) { id in
                        if let t = s.tasks[id] { LupyRankedTaskRow(task: t) }
                    }
                }
            }
            let notes = s.drafts.values.filter { $0.taskID == nil }.sorted { $0.createdAt > $1.createdAt }.prefix(3)
            if !notes.isEmpty {
                LupySectionTitle(text: "Latest from Lupy")
                ForEach(Array(notes)) { d in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(d.title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(LupyTheme.text).lineLimit(1)
                            Spacer()
                            Text(lupyRelativeTime(d.createdAt)).font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
                            Button("Copy") { model.copy(d.body, announce: "Copied.") }.buttonStyle(LupySecondaryButtonStyle())
                            Button("Save") { model.saveDraftToFile(d) }.buttonStyle(LupySecondaryButtonStyle())
                        }
                        Text(d.body).font(.system(size: 12)).foregroundColor(LupyTheme.body).lineLimit(12).textSelection(.enabled)
                    }
                    .padding(14).background(LupyCardBackground(wash: .soft))
                }
            }
            HStack {
                LupySectionTitle(text: "Brief")
                Spacer()
                if model.hasUsableModel {
                    Button("Write with model") { model.writeBriefWithModel() }.buttonStyle(LupySecondaryButtonStyle())
                }
            }
            Text(model.engine?.templateBrief() ?? "")
                .font(.system(size: 12.5)).foregroundColor(LupyTheme.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(LupyCardBackground(wash: .indigo))
        }
    }
}

struct LupyCaptureBar: View {
    private var model: LupyModel { LupyModel.shared }
    @State private var text = ""
    @State private var projectID: LupyID?
    @State private var useModel = true
    @State private var askMode = false
    /// Lupy (port): Coucou's own dictation (on-device when the Mac supports it; several languages).
    @State private var dictation = MacDictation()

    var body: some View {
        let projects = model.state.activeProjects
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                TextField(askMode ? "Ask Lupy anything about your work…" : "What do you want to get done? e.g. “Invoice ACME by Friday, then follow up next week”", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...5)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(HubTheme.field))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
                    .onSubmit(submit)
                    .onChange(of: dictation.transcript) { _, _ in
                        if dictation.isRecording { text = dictation.text }
                    }
                Button {
                    Task { @MainActor in
                        if dictation.isRecording { text = await dictation.finish() }
                        else { await dictation.start(from: text) }
                    }
                } label: {
                    Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(dictation.isRecording ? Color(hex: "#F4505E") : Color(hex: "#A4A9B1"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(dictation.isRecording ? 0.12 : 0.06)))
                }
                .buttonStyle(.plain)
                .help("Dictate. You see and can edit the text before anything is used.")
                .accessibilityLabel(dictation.isRecording ? "Stop dictation" : "Dictate")
            }
            if dictation.isRecording {
                Text("Listening… your words appear above; nothing is sent until you press \(askMode ? "Ask" : "Plan it").")
                    .font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
            }
            HStack(spacing: 12) {
                Picker("", selection: $askMode) {
                    Text("Plan a goal").tag(false)
                    Text("Ask Lupy").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
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
                        .help("No cloud model is set up, so Lupy plans with offline rules. Add one in Lupy → Assistant.")
                }
                Spacer()
                Button(askMode ? "Ask" : "Plan it", action: submit).buttonStyle(LupyPrimaryButtonStyle()).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .background(LupyCardBackground(wash: .soft))
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

struct LupyPlanReviewCard: View {
    private var model: LupyModel { LupyModel.shared }
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
                                LupyStatusChip(text: t.kind.label, color: LupyTheme.secondary)
                                if !t.dependsOn.isEmpty { Text("after \(t.dependsOn.count) step(s)").font(.system(size: 10.5)).foregroundColor(LupyTheme.muted) }
                                if let d = t.deadline { Text("due \(lupyShortDate(d))").font(.system(size: 10.5)).foregroundColor(LupyTheme.amber) }
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
        .background(LupyCardBackground(wash: model.selectedPlanID == plan.id ? .amber : .cyan))
    }
}

struct LupyAttentionRow: View {
    private var model: LupyModel { LupyModel.shared }
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
        .background(LupyCardBackground(wash: item.severity == .urgent ? .red : .amber, radius: 14))
    }
}

struct LupyRankedTaskRow: View {
    private var model: LupyModel { LupyModel.shared }
    let task: LupyTask

    var body: some View {
        let s = model.state
        let pa = PriorityEngine.assess(task, state: s, now: LupySystemClock().now())
        Button {
            model.selectedTaskID = task.id
            model.open(.lupyTasks)
        } label: {
            HStack(spacing: 12) {
                Text("\(Int(pa.score))").font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundColor(LupyTheme.accent).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.system(size: 13, weight: .medium)).foregroundColor(LupyTheme.text).lineLimit(1)
                    Text("\(s.projects[task.projectID]?.name ?? "") · \(pa.explanation)").font(.system(size: 11)).foregroundColor(LupyTheme.secondary).lineLimit(1)
                }
                Spacer()
                LupyStatusChip(text: task.status.label, color: LupyTheme.statusColor(task.status))
            }
            .padding(12)
            .background(LupyCardBackground(radius: 12))
        }
        .buttonStyle(.plain)
    }
}
