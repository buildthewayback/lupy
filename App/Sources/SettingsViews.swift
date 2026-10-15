// Lupy macOS shell — settings (autonomy, providers & keys, budget, GitHub, connectors, workers,
// privacy, backup, diagnostics, licences) and first-launch onboarding.

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings").font(.system(size: 20, weight: .semibold)).foregroundColor(LupyTheme.text)
                AutonomySettings()
                ProvidersSettings()
                BudgetSettings()
                GitHubSettings()
                ConnectorsSettings()
                WorkersSettings()
                PrivacySettings()
                BackupSettings()
                DiagnosticsSettings()
                AboutSettings()
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }
}

struct SettingsCard<Content: View>: View {
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
        .background(CardBackground(wash: .soft))
    }
}

struct AutonomySettings: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let s = model.state.settings
        SettingsCard(title: "How much Lupy may do on its own", subtitle: "Spending, publishing, messaging people, deleting data and security changes always need you, in every mode.") {
            Picker("Mode", selection: Binding(get: { s.autonomy }, set: { m in model.act { try $0.setAutonomy(m); return [] } })) {
                ForEach(AutonomyMode.allCases, id: \.self) { m in Text(m.label).tag(m) }
            }
            .pickerStyle(.segmented)
            HStack {
                Toggle("Pause everything", isOn: Binding(get: { s.globalPause }, set: { on in model.act { try $0.setGlobalPause(on, reason: on ? "Paused in Settings" : ""); return [] } }))
                Spacer()
                Toggle("Show notch island", isOn: Binding(get: { model.showIsland }, set: { model.setShowIsland($0) }))
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

struct ProvidersSettings: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let providers = model.state.providers.values.sorted { $0.displayName < $1.displayName }
        SettingsCard(title: "Cloud model providers", subtitle: "Optional. Keys are stored only in your Mac's Keychain. Nothing is sent to a provider until you allow it. Lupy never runs models on your Mac.") {
            ForEach(providers) { p in ProviderRow(provider: p) }
        }
    }
}

struct ProviderRow: View {
    @Environment(AppModel.self) private var model
    let provider: ProviderConfig
    @State private var key = ""
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider.displayName).font(.system(size: 13, weight: .semibold)).foregroundColor(LupyTheme.text)
                StatusChip(text: provider.hasKey ? "key saved" : "no key", color: provider.hasKey ? LupyTheme.green : LupyTheme.muted)
                StatusChip(text: provider.founderApproved ? "allowed" : "not allowed", color: provider.founderApproved ? LupyTheme.green : LupyTheme.amber)
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
                ForEach(provider.models) { m in ModelRow(provider: provider, model: m) }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ModelRow: View {
    @Environment(AppModel.self) private var appModel
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

struct BudgetSettings: View {
    @Environment(AppModel.self) private var model
    @State private var daily = ""
    @State private var monthly = ""
    @State private var perTask = ""
    @State private var perCall = ""

    var body: some View {
        let b = model.state.budget
        SettingsCard(title: "Spending limits", subtitle: "Hard limits stop model calls. Above the per-call amount Lupy asks you first. Amounts in US dollars.") {
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

struct GitHubSettings: View {
    @Environment(AppModel.self) private var model
    @State private var token = ""
    var body: some View {
        let c = model.state.connectors["github"]
        SettingsCard(title: "GitHub evidence (optional)", subtitle: "Lets Lupy check branches, pull requests and CI results to verify what coding agents claim. Read-only: Lupy never pushes or merges. Use a fine-grained token with read-only access to the repositories you choose.") {
            HStack {
                StatusChip(text: c?.state == .connected ? "connected" : (c?.state == .error ? "error" : "not connected"),
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

struct ConnectorsSettings: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let list = model.state.connectors.values.sorted { $0.name < $1.name }
        SettingsCard(title: "Connections (honest status)", subtitle: "What Lupy can and cannot reach. “Not connected” means Lupy will prepare things for you to do by hand.") {
            ForEach(list) { c in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(c.name).font(.system(size: 12.5, weight: .medium)).foregroundColor(LupyTheme.text)
                        StatusChip(text: label(c.state), color: c.state == .connected ? LupyTheme.green : (c.state == .error ? LupyTheme.red : LupyTheme.muted))
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

struct WorkersSettings: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let s = model.state
        SettingsCard(title: "Workers and oversight", subtitle: "Lupy tracks, per kind of task, whether each worker's claims held up — and checks harder where they didn't. This never changes what they are allowed to do.") {
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

struct PrivacySettings: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let s = model.state.settings
        SettingsCard(title: "What leaves your Mac", subtitle: "") {
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

struct BackupSettings: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        SettingsCard(title: "Backup, restore and export", subtitle: "Backups are single files you can keep anywhere. They never include API keys. Restoring moves current data aside instead of deleting it.") {
            HStack(spacing: 8) {
                Button("Save a backup…") { model.exportBackup() }.buttonStyle(LupyPrimaryButtonStyle())
                Button("Restore from backup…") { model.restoreBackup() }.buttonStyle(LupySecondaryButtonStyle())
                Button("Import a project…") { model.importProject() }.buttonStyle(LupySecondaryButtonStyle())
                Button("Show data folder") { model.revealDataFolder() }.buttonStyle(LupySecondaryButtonStyle())
            }
        }
    }
}

struct DiagnosticsSettings: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let report = model.engine?.diagnostics(dataSizeBytes: model.dataSizeBytes)
        SettingsCard(title: "Diagnostics", subtitle: "Plain status for troubleshooting. Contains no keys or personal content.") {
            Text((report?.lines ?? [model.startupError ?? "Not started"]).joined(separator: "\n") + "\nMemory in use: \(String(format: "%.0f", residentMemoryMB())) MB")
                .font(.system(size: 11.5, design: .monospaced)).foregroundColor(report?.healthy == false ? LupyTheme.amber : LupyTheme.body)
                .textSelection(.enabled)
            Button("Copy diagnostics") { model.copy((report?.lines ?? []).joined(separator: "\n"), announce: "Diagnostics copied.") }.buttonStyle(LupySecondaryButtonStyle())
        }
    }
}

struct AboutSettings: View {
    var body: some View {
        SettingsCard(title: "About Lupy", subtitle: "") {
            Text("Lupy 0.1.0 — your executive assistant. Lupy's notch island and visual style are adapted from Coucou (github.com/Louis-CFM/coucou), MIT License, © 2026 Louis Raillé. Coucou's name, its character Mochi, its icons and sounds are not used. Lupy's character and icon are original.")
                .font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                LupyCharacterView(mood: .happy, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi, I'm Lupy.").font(.system(size: 22, weight: .semibold))
                    Text("I keep your projects moving and I never call something done without evidence.").font(.system(size: 13)).foregroundColor(LupyTheme.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("Tell me a goal — I'll propose steps. Nothing starts until you approve.", systemImage: "list.bullet.clipboard")
                Label("I'll follow up on what you hand to Arena, Muse or ChatGPT, and check GitHub for proof.", systemImage: "checkmark.seal")
                Label("I ask before spending, publishing, messaging people, deleting or touching security.", systemImage: "hand.raised")
                Label("Your data stays on this Mac. Cloud models are optional; keys go in the Keychain.", systemImage: "lock")
            }
            .font(.system(size: 13))
            TextField("What should I call you?", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit(finish)
            HStack {
                Spacer()
                Button("Get started", action: finish)
                    .buttonStyle(LupyPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560)
        .onAppear {
            name = model.state.settings.founderName
            nameFocused = true
        }
    }

    private func finish() {
        // Return can reach both the text field's submit and the default button; act once.
        guard !model.state.settings.onboardingComplete else { return }
        var s = model.state.settings
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { s.founderName = trimmed }
        s.onboardingComplete = true
        let settings = s
        model.act { try $0.updateSettings(settings); return [] }
    }
}
