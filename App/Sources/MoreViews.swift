// Lupy macOS shell — memory, decisions, activity (audit trail), usage & budget.

import SwiftUI

struct MemoryView: View {
    @Environment(AppModel.self) private var model
    @State private var title = ""
    @State private var detail = ""
    @State private var key = ""
    @State private var kind: MemoryKind = .preference
    @State private var scopeProject: LupyID? = nil
    @State private var sensitive = false
    @State private var decisionTitle = ""
    @State private var decisionText = ""

    var body: some View {
        let s = model.state
        let contested = s.memory.values.filter { $0.status == .contested }.sorted { ($0.key ?? "") < ($1.key ?? "") }
        let active = s.memory.values.filter { $0.status == .active }.sorted { $0.updatedAt > $1.updatedAt }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Memory").font(.system(size: 20, weight: .semibold)).foregroundColor(LupyTheme.text)
                Text("Preferences, rules, facts and lessons Lupy uses. Project memory never leaves its project. Sensitive items are never sent to cloud models.")
                    .font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
                if !contested.isEmpty {
                    SectionTitle(text: "Conflicts to resolve")
                    ForEach(contested) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title).font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text)
                                Text("\(m.body) · from \(m.source.label) · \(relativeTime(m.createdAt))").font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
                            }
                            Spacer()
                            Button("This one is right") {
                                let others = contested.filter { $0.key == m.key }.map(\.id)
                                model.act { try $0.resolveMemoryConflict(keep: m.id, supersede: others); return [] }
                            }
                            .buttonStyle(LupyPrimaryButtonStyle())
                        }
                        .padding(10).background(CardBackground(wash: .amber, radius: 12))
                    }
                }
                SectionTitle(text: "Teach Lupy something")
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Picker("Kind", selection: $kind) { ForEach(MemoryKind.allCases, id: \.self) { k in Text(k.label).tag(k) } }.frame(maxWidth: 220)
                        Picker("Scope", selection: $scopeProject) {
                            Text("All projects").tag(LupyID?.none)
                            ForEach(s.activeProjects) { p in Text(p.name).tag(LupyID?.some(p.id)) }
                        }
                        .frame(maxWidth: 260)
                        Toggle("Sensitive", isOn: $sensitive).toggleStyle(.checkbox)
                    }
                    TextField("Title, e.g. “I do deep work before noon”", text: $title).textFieldStyle(.roundedBorder)
                    TextField("Details (optional)", text: $detail).textFieldStyle(.roundedBorder)
                    HStack {
                        TextField("Topic key for conflict detection (optional), e.g. work-hours", text: $key).textFieldStyle(.roundedBorder)
                        Button("Remember") {
                            let scope: MemoryScope = scopeProject.map { .project($0) } ?? .global
                            let t = title, d = detail, k = key.isEmpty ? nil : key, sen = sensitive, kd = kind
                            model.act { _ = try $0.remember(scope: scope, kind: kd, title: t, body: d, key: k, sensitive: sen); return [] }
                            title = ""; detail = ""; key = ""
                        }
                        .buttonStyle(LupyPrimaryButtonStyle()).disabled(title.isEmpty)
                    }
                }
                .padding(14).background(CardBackground(wash: .soft))
                SectionTitle(text: "What Lupy knows (\(active.count))")
                ForEach(active) { m in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title).font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text)
                            if !m.body.isEmpty { Text(m.body).font(.system(size: 11.5)).foregroundColor(LupyTheme.body) }
                            Text("\(m.kind.label) · \(m.scope.projectID.flatMap { s.projects[$0]?.name } ?? "All projects") · \(m.source.label)\(m.confidence < 1 ? " · unconfirmed" : "")")
                                .font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
                        }
                        Spacer()
                        if m.sensitive { StatusChip(text: "sensitive", color: LupyTheme.pink) }
                    }
                    .padding(10).background(CardBackground(radius: 12))
                }
                SectionTitle(text: "Decisions")
                HStack {
                    TextField("Decision title", text: $decisionTitle).textFieldStyle(.roundedBorder)
                    TextField("What was decided", text: $decisionText).textFieldStyle(.roundedBorder)
                    Button("Record") {
                        let t = decisionTitle, d = decisionText, p = scopeProject
                        model.act { _ = try $0.recordDecision(projectID: p, title: t, decision: d); return [] }
                        decisionTitle = ""; decisionText = ""
                    }
                    .disabled(decisionTitle.isEmpty || decisionText.isEmpty)
                }
                ForEach(s.decisions.values.sorted { $0.createdAt > $1.createdAt }) { d in
                    Text("\(d.createdAt.dateOnly) · \(d.title): \(d.decision)").font(.system(size: 11.5)).foregroundColor(LupyTheme.body)
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

struct ActivityView: View {
    @Environment(AppModel.self) private var model
    @State private var projectID: LupyID? = nil

    var body: some View {
        let s = model.state
        let events = model.engine?.activity(limit: 300, projectID: projectID) ?? []
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity").font(.system(size: 20, weight: .semibold)).foregroundColor(LupyTheme.text)
                Spacer()
                Picker("Project", selection: $projectID) {
                    Text("Everything").tag(LupyID?.none)
                    ForEach(s.activeProjects) { p in Text(p.name).tag(LupyID?.some(p.id)) }
                }
                .frame(maxWidth: 260)
            }
            Text("Every change is recorded in an append-only journal on this Mac. This is the most recent part.")
                .font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
            List(events) { e in
                HStack(alignment: .top, spacing: 10) {
                    Text(e.at.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 11)).monospacedDigit().foregroundColor(LupyTheme.muted).frame(width: 64, alignment: .leading)
                    Text(e.by.label).font(.system(size: 11, weight: .semibold)).foregroundColor(color(e.by)).frame(width: 110, alignment: .leading).lineLimit(1)
                    Text(e.summary).font(.system(size: 12)).foregroundColor(LupyTheme.body).lineLimit(2)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .padding(24)
    }

    private func color(_ p: Principal) -> Color {
        switch p {
        case .founder: return LupyTheme.accent
        case .lupy: return LupyTheme.cyan
        case .model: return LupyTheme.indigo
        case .worker: return LupyTheme.pink
        case .connector: return LupyTheme.green
        case .system: return LupyTheme.secondary
        }
    }
}

struct UsageView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let s = model.state
        let b = model.attention.budget
        let recent = s.usage.suffix(60).reversed()
        let byProvider = Dictionary(grouping: s.usage, by: { $0.providerID }).mapValues { list in list.reduce(0) { $0 + $1.costCents } }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Usage & budget").font(.system(size: 20, weight: .semibold)).foregroundColor(LupyTheme.text)
                Text("Costs are estimates from token counts and the prices in Settings → Providers. Your provider's bill is the final word.")
                    .font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
                HStack(spacing: 14) {
                    meter("Today", b.spentTodayCents, b.dailyCapCents)
                    meter("This month", b.spentMonthCents, b.monthlyCapCents)
                }
                if b.hardStopped { Text("Limit reached: cloud model calls are stopped until it resets or you raise it.").font(.system(size: 12)).foregroundColor(LupyTheme.red) }
                SectionTitle(text: "By provider (all time)")
                ForEach(byProvider.keys.sorted(), id: \.self) { pid in
                    Text("\(s.providers[pid]?.displayName ?? pid): \(TextUtil.formatCents(byProvider[pid] ?? 0))").font(.system(size: 12)).foregroundColor(LupyTheme.body)
                }
                ForEach(FailurePatterns.detect(s.usage, now: SystemClock().now()), id: \.signature) { p in
                    Label(p.advice, systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundColor(LupyTheme.amber)
                }
                SectionTitle(text: "Recent model calls")
                if recent.isEmpty { Text("No model calls yet.").font(.system(size: 12)).foregroundColor(LupyTheme.secondary) }
                ForEach(Array(recent)) { u in
                    HStack {
                        Text(shortDate(u.at)).font(.system(size: 11)).foregroundColor(LupyTheme.muted).frame(width: 150, alignment: .leading)
                        Text("\(u.providerID)/\(u.modelID)").font(.system(size: 11.5)).foregroundColor(LupyTheme.body).frame(width: 220, alignment: .leading).lineLimit(1)
                        Text(u.purpose.label).font(.system(size: 11)).foregroundColor(LupyTheme.secondary).frame(width: 130, alignment: .leading)
                        Text(u.ok ? "\(u.inputTokens)+\(u.outputTokens) tok" : (u.errorCategory?.label ?? "failed")).font(.system(size: 11)).foregroundColor(u.ok ? LupyTheme.secondary : LupyTheme.red)
                        Spacer()
                        Text(TextUtil.formatCents(u.costCents) + (u.estimated ? "*" : "")).font(.system(size: 11.5)).monospacedDigit().foregroundColor(LupyTheme.text)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func meter(_ title: String, _ spent: Double, _ cap: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(LupyTheme.secondary)
            Text("\(TextUtil.formatCents(spent)) of \(TextUtil.formatCents(cap))").font(.system(size: 16, weight: .semibold)).foregroundColor(LupyTheme.text)
            ProgressView(value: cap > 0 ? min(1, spent / cap) : 0).tint(spent >= cap ? LupyTheme.red : LupyTheme.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(wash: .soft))
    }
}
