// Ported from the previous Lupy window (App/Sources/SettingsViews.swift, git 09c8c75) by scripts/port-lupy-views.py.
// Coucou's hub colours and components via LupyStyle.swift; logic and engine calls unchanged.

import LupyCore
import SwiftUI

struct LupyAssistantSettings: View {
    private var model: LupyModel { LupyModel.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LupyAutonomySettings()
                LupyControlSettings()
                LupyProvidersSettings()
                LupyBudgetSettings()
                LupyGitHubSettings()
                LupyConnectorsSettings()
                LupyWorkersSettings()
                LupyPrivacySettings()
                LupyBackupSettings()
                LupyDiagnosticsSettings()
                LupyAboutSettings()
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }
}

struct LupySettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(LupyTheme.text)
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary) }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LupyCardBackground(wash: .soft))
    }
}

struct LupyAutonomySettings: View {
    private var model: LupyModel { LupyModel.shared }
    var body: some View {
        let s = model.state.settings
        LupySettingsCard(title: "How much Lupy may do on its own", subtitle: "Spending, publishing, messaging people, deleting data and security changes always need you, in every mode.") {
            Picker("Mode", selection: Binding(get: { s.autonomy }, set: { m in model.act { try $0.setAutonomy(m); return [] } })) {
                ForEach(AutonomyMode.allCases, id: \.self) { m in Text(m.label).tag(m) }
            }
            .pickerStyle(.segmented)
            HStack {
                Toggle("Pause everything", isOn: Binding(get: { s.globalPause }, set: { on in model.act { try $0.setGlobalPause(on, reason: on ? "Paused in Settings" : ""); return [] } }))
                Spacer()
                // Lupy (port): the island is Coucou's now; its settings live on the General page.
                Button("Island settings…") { model.open(.general) }.buttonStyle(LupySecondaryButtonStyle())
            }
            HStack {
                Toggle("Quiet hours (22:00–07:30)", isOn: Binding(get: { s.quietHours.enabled }, set: { on in
                    var x = s; x.quietHours.enabled = on; model.act { try $0.updateSettings(x); return [] }
                }))
                Stepper("At most \(s.maxNotificationsPerHour) notifications/hour", value: Binding(get: { s.maxNotificationsPerHour }, set: { v in
                    var x = s; x.maxNotificationsPerHour = max(1, min(20, v)); model.act { try $0.updateSettings(x); return [] }
                }), in: 1...20)
            }
            .font(.system(size: 12))
        }
    }
}

struct LupyProvidersSettings: View {
    private var model: LupyModel { LupyModel.shared }
    var body: some View {
        let providers = model.state.providers.values.sorted { $0.displayName < $1.displayName }
        LupySettingsCard(title: "Cloud model providers", subtitle: "Optional. Keys are stored only in your Mac's Keychain. Nothing is sent to a provider until you allow it. Lupy never runs models on your Mac.") {
            ForEach(providers) { p in LupyProviderRow(provider: p) }
        }
    }
}

struct LupyProviderRow: View {
    private var model: LupyModel { LupyModel.shared }
    let provider: ProviderConfig
    @State private var key = ""
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider.displayName).font(.system(size: 13, weight: .semibold)).foregroundColor(LupyTheme.text)
                LupyStatusChip(text: provider.hasKey ? "key saved" : "no key", color: provider.hasKey ? LupyTheme.green : LupyTheme.muted)
                LupyStatusChip(text: provider.founderApproved ? "allowed" : "not allowed", color: provider.founderApproved ? LupyTheme.green : LupyTheme.amber)
                Spacer()
                Button(expanded ? "Done" : "Set up") { expanded.toggle() }.buttonStyle(LupySecondaryButtonStyle())
            }
            if expanded {
                Text(provider.dataNotice).font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
                HStack {
                    SecureField(provider.hasKey ? "Replace API key" : "Paste API key", text: $key).textFieldStyle(.roundedBorder)
                    Button("Save key") { model.saveKey(providerID: provider.id, key: key); key = "" }.disabled(key.isEmpty)
                    if provider.hasKey { Button("Remove key") { model.removeKey(providerID: provider.id) } }
                }
                Toggle("Allow Lupy to send task context to \(provider.displayName)", isOn: Binding(get: { provider.founderApproved }, set: { on in
                    model.act { try $0.approveProvider(provider.id, approved: on); return [] }
                }))
                .font(.system(size: 12))
                HStack {
                    Button("Test connection") { model.testProvider(provider.id) }.disabled(!provider.hasKey)
                    Button("Refresh models") { model.refreshModels(provider.id) }.disabled(!provider.hasKey)
                    Spacer()
                    Text("Prices: \(provider.priceAsOf)").font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
                }
                ForEach(provider.models) { m in LupyModelRow(provider: provider, model: m) }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct LupyModelRow: View {
    private var appModel: LupyModel { LupyModel.shared }
    let provider: ProviderConfig
    let model: ModelSpec
    @State private var input = ""
    @State private var output = ""

    var body: some View {
        HStack {
            Toggle(model.displayName, isOn: Binding(get: { model.enabled }, set: { on in update { $0.enabled = on } })).font(.system(size: 12))
            Spacer()
            Text("¢/M tokens in").font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
            TextField("\(TextUtil.fixed(model.inputCentsPerMTok, 0))", text: $input).frame(width: 60).textFieldStyle(.roundedBorder)
            Text("out").font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
            TextField("\(TextUtil.fixed(model.outputCentsPerMTok, 0))", text: $output).frame(width: 60).textFieldStyle(.roundedBorder)
            Button("Set") {
                let i = Double(input), o = Double(output)
                update { m in if let i { m.inputCentsPerMTok = i }; if let o { m.outputCentsPerMTok = o } }
                input = ""; output = ""
            }
            .disabled(Double(input) == nil && Double(output) == nil)
        }
    }

    private func update(_ change: (inout ModelSpec) -> Void) {
        var p = provider
        guard let i = p.models.firstIndex(where: { $0.id == model.id }) else { return }
        change(&p.models[i])
        appModel.act { try $0.upsertProvider(p); return [] }
    }
}

struct LupyBudgetSettings: View {
    private var model: LupyModel { LupyModel.shared }
    @State private var daily = ""
    @State private var monthly = ""
    @State private var perTask = ""
    @State private var perCall = ""

    var body: some View {
        let b = model.state.budget
        LupySettingsCard(title: "Spending limits", subtitle: "Hard limits stop model calls. Above the per-call amount Lupy asks you first. Amounts in US dollars.") {
            HStack(spacing: 12) {
                field("Per day", $daily, b.dailyCapCents)
                field("Per month", $monthly, b.monthlyCapCents)
                field("Per task", $perTask, b.perTaskCapCents)
                field("Ask above (per call)", $perCall, b.approvalAboveCentsPerCall)
            }
            Button("Save limits") {
                var x = b
                if let v = Double(daily) { x.dailyCapCents = v * 100 }
                if let v = Double(monthly) { x.monthlyCapCents = v * 100 }
                if let v = Double(perTask) { x.perTaskCapCents = v * 100 }
                if let v = Double(perCall) { x.approvalAboveCentsPerCall = v * 100 }
                model.act { try $0.setBudget(x); return [] }
                daily = ""; monthly = ""; perTask = ""; perCall = ""
            }
            .buttonStyle(LupyPrimaryButtonStyle())
        }
    }

    private func field(_ label: String, _ text: Binding<String>, _ cents: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
            TextField(TextUtil.fixed(cents / 100, 2), text: text).textFieldStyle(.roundedBorder).frame(width: 110)
        }
    }
}

struct LupyGitHubSettings: View {
    private var model: LupyModel { LupyModel.shared }
    @State private var token = ""
    var body: some View {
        let c = model.state.connectors["github"]
        LupySettingsCard(title: "GitHub evidence (optional)", subtitle: "Lets Lupy check branches, pull requests and CI results to verify what coding agents claim. Read-only: Lupy never pushes or merges. Use a fine-grained token with read-only access to the repositories you choose.") {
            HStack {
                LupyStatusChip(text: c?.state == .connected ? "connected" : (c?.state == .error ? "error" : "not connected"),
                           color: c?.state == .connected ? LupyTheme.green : (c?.state == .error ? LupyTheme.red : LupyTheme.muted))
                if let e = c?.lastError { Text(e).font(.system(size: 11)).foregroundColor(LupyTheme.red) }
            }
            HStack {
                SecureField("Paste a GitHub token", text: $token).textFieldStyle(.roundedBorder)
                Button("Save & test") { model.saveGitHubToken(token); token = "" }.disabled(token.isEmpty)
                Button("Remove") { model.removeGitHubToken() }
            }
        }
    }
}

struct LupyConnectorsSettings: View {
    private var model: LupyModel { LupyModel.shared }
    var body: some View {
        let list = model.state.connectors.values.sorted { $0.name < $1.name }
        LupySettingsCard(title: "Connections (honest status)", subtitle: "What Lupy can and cannot reach. “Not connected” means Lupy will prepare things for you to do by hand.") {
            ForEach(list) { c in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(c.name).font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text)
                        LupyStatusChip(text: label(c.state), color: c.state == .connected ? LupyTheme.green : (c.state == .error ? LupyTheme.red : LupyTheme.muted))
                    }
                    ForEach(c.limitations, id: \.self) { l in Text("• \(l)").font(.system(size: 11)).foregroundColor(LupyTheme.secondary) }
                }
            }
        }
    }

    private func label(_ s: ConnectorState) -> String {
        switch s {
        case .connected: return "connected"
        case .notConnected: return "not connected"
        case .error: return "error"
        case .disabled: return "off"
        case .planned: return "not in this version"
        }
    }
}

struct LupyWorkersSettings: View {
    private var model: LupyModel { LupyModel.shared }
    var body: some View {
        let s = model.state
        LupySettingsCard(title: "Workers and oversight", subtitle: "Lupy tracks, per kind of task, whether each worker's claims held up — and checks harder where they didn't. This never changes what they are allowed to do.") {
            ForEach(s.workers.values.sorted { $0.name < $1.name }) { w in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(w.name) — \(w.channel.label)").font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text)
                    Text(w.notes).font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
                    ForEach(s.reliability.values.filter { $0.workerID == w.id }.sorted { $0.taskKind.rawValue < $1.taskKind.rawValue }, id: \.key) { r in
                        HStack {
                            Text("\(r.taskKind.label): \(r.effective.label)").font(.system(size: 11.5)).foregroundColor(r.effective == .standard ? LupyTheme.green : LupyTheme.amber)
                            Text(r.explanation).font(.system(size: 10.5)).foregroundColor(LupyTheme.muted).lineLimit(2)
                            Spacer()
                            Menu("Override") {
                                Button("Automatic") { model.act { try $0.overrideOversight(worker: w.id, kind: r.taskKind, level: nil, note: ""); return [] } }
                                ForEach(OversightLevel.allCases, id: \.self) { lvl in
                                    Button(lvl.label) { model.act { try $0.overrideOversight(worker: w.id, kind: r.taskKind, level: lvl, note: "Set by you"); return [] } }
                                }
                            }
                            .frame(width: 100)
                        }
                    }
                }
            }
        }
    }
}

struct LupyPrivacySettings: View {
    private var model: LupyModel { LupyModel.shared }
    var body: some View {
        let s = model.state.settings
        LupySettingsCard(title: "What leaves your Mac", subtitle: "") {
            Text("• Your data lives in ~/Library/Application Support/Lupy on this Mac.\n• API keys live only in the macOS Keychain — never in Lupy's files, backups or logs.\n• When a cloud model is allowed and used, Lupy sends only the context listed with each request (secrets are redacted, sensitive memory is withheld, other projects are never included).\n• GitHub checks send repository and branch/PR identifiers to api.github.com.\n• Dictation uses Apple's speech recognition (on this Mac when supported).")
                .font(.system(size: 12)).foregroundColor(LupyTheme.body)
            Toggle("Include relevant memory in model requests", isOn: Binding(get: { s.dataSharing.includeMemoryInModelContext }, set: { on in
                var x = s; x.dataSharing.includeMemoryInModelContext = on; model.act { try $0.updateSettings(x); return [] }
            }))
            Toggle("Allow memory marked sensitive to be sent (not recommended)", isOn: Binding(get: { s.dataSharing.includeSensitiveMemory }, set: { on in
                var x = s; x.dataSharing.includeSensitiveMemory = on; model.act { try $0.updateSettings(x); return [] }
            }))
        }
        .font(.system(size: 12))
    }
}

struct LupyBackupSettings: View {
    private var model: LupyModel { LupyModel.shared }
    var body: some View {
        LupySettingsCard(title: "Backup, restore and export", subtitle: "Backups are single files you can keep anywhere. They never include API keys. Restoring moves current data aside instead of deleting it.") {
            HStack(spacing: 8) {
                Button("Save a backup…") { model.exportBackup() }.buttonStyle(LupyPrimaryButtonStyle())
                Button("Restore from backup…") { model.restoreBackup() }.buttonStyle(LupySecondaryButtonStyle())
                Button("Import a project…") { model.importProject() }.buttonStyle(LupySecondaryButtonStyle())
                Button("Show data folder") { model.revealDataFolder() }.buttonStyle(LupySecondaryButtonStyle())
            }
        }
    }
}

struct LupyDiagnosticsSettings: View {
    private var model: LupyModel { LupyModel.shared }
    var body: some View {
        let report = model.engine?.diagnostics(dataSizeBytes: model.dataSizeBytes)
        LupySettingsCard(title: "Diagnostics", subtitle: "Plain status for troubleshooting. Contains no keys or personal content.") {
            Text((report?.lines ?? [model.startupError ?? "Not started"]).joined(separator: "\n") + "\nMemory in use: \(String(format: "%.0f", lupyResidentMemoryMB())) MB")
                .font(.system(size: 11.5, design: .monospaced)).foregroundColor(report?.healthy == false ? LupyTheme.amber : LupyTheme.body)
                .textSelection(.enabled)
            Button("Copy diagnostics") { model.copy((report?.lines ?? []).joined(separator: "\n"), announce: "Diagnostics copied.") }.buttonStyle(LupySecondaryButtonStyle())
        }
    }
}

struct LupyAboutSettings: View {
    var body: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
        LupySettingsCard(title: "About Lupy", subtitle: "") {
            // Lupy (port): updated — Lupy is now built on Coucou's own app.
            Text("Lupy \(version) — your executive assistant, built on Coucou's Mac app by Louis Raillé (github.com/Louis-CFM/coucou). Coucou's code is MIT-licensed (notice inside the app). Coucou's character Mochi, its icon and its sounds are © Louis Raillé and are included only in this private build for your own Mac — not for sharing or publishing.")
                .font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
