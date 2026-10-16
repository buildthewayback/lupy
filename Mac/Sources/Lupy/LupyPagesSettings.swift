// Ported from the previous Lupy window (App/Sources/SettingsViews.swift, git 09c8c75) by scripts/port-lupy-views.py.
// Coucou's hub colours and components via LupyStyle.swift; logic and engine calls unchanged.

import LupyCore
import SwiftUI

struct LupyAssistantSettings: View {
    private var model: LupyModel { LupyModel.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // LUPY 2 — simple front: what the founder actually adjusts, in his order.
                // AI APIs first (the one setup place), then how he talks to Lupy, then behaviour.
                LupyAPIsSettings()
                LupyVoiceActivationSettings()
                LupyPersonalisationSettings()
                LupyControlSettings()
                LupyIslandWindowSettings()
                LupyAutonomySettings()
                LupyHousekeepingSettings()
                LupyAboutSettings()
                // Hidden for the founder (LUPY 2, D-032): GitHub evidence, connectors, workers —
                // coding-agent coordination he doesn't use. The engine still runs underneath;
                // re-add LupyGitHubSettings()/LupyConnectorsSettings()/LupyWorkersSettings() to bring them back.
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }
}

/// How you talk to Lupy: dictation language, the wake word, and the keyboard shortcut.
/// Every control here has a real effect (the mic menus, Coucou's voice engine, the shortcuts page).
struct LupyVoiceActivationSettings: View {
    @Bindable private var dictation = MacDictation()

    var body: some View {
        LupySettingsCard(title: "Voice input & activation",
                         subtitle: "Speech and typing are the same assistant: dictated words always appear as editable text first — nothing is sent until you review it.") {
            HStack {
                Picker("Dictation language", selection: $dictation.language) {
                    Text("Automatic (my languages)").tag(MacDictation.automatic)
                    ForEach(MacDictation.allLanguages, id: \.self) { id in
                        Text(MacDictation.name(of: id)).tag(id)
                    }
                }
                .frame(maxWidth: 320)
                Spacer()
            }
            .font(.system(size: 12))
            HStack(spacing: 16) {
                Button("Wake word settings…") { LupyModel.shared.open(.voice) }.buttonStyle(LupySecondaryButtonStyle())
                Button("Keyboard shortcuts…") { LupyModel.shared.open(.shortcuts) }.buttonStyle(LupySecondaryButtonStyle())
                Spacer()
            }
            Text("“OK Lupy” wakes the voice commands (music, mail, notes). The mic button in the conversation dictates into the field for anything longer. ⌃⌥Space (changeable) opens the conversation from anywhere.")
                .font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
        }
    }
}

/// Your name, and what Lupy remembers. Real settings only: the memory page owns the rest.
struct LupyPersonalisationSettings: View {
    private var model: LupyModel { LupyModel.shared }
    @State private var name = ""

    var body: some View {
        LupySettingsCard(title: "Personalisation & memory",
                         subtitle: "What Lupy calls you and what it remembers. Memory is per project; sensitive notes are never sent to cloud models.") {
            HStack {
                HubField(placeholder: "Your name", text: $name) { save() }
                    .frame(maxWidth: 260)
                Button("Save", action: save).buttonStyle(LupySecondaryButtonStyle()).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                Button("Open memory…") { model.open(.lupyMemory) }.buttonStyle(LupySecondaryButtonStyle())
            }
            .font(.system(size: 12))
        }
        .onAppear { name = model.state.settings.founderName }
    }

    private func save() {
        var s = model.state.settings
        s.founderName = name.trimmingCharacters(in: .whitespaces)
        model.act { try $0.updateSettings(s); return [] }
        model.say("Got it — hello, \(s.founderName).")
    }
}

/// Island and window behaviour live in Coucou's own settings (they are its engine);
/// this card is the map to them, not a duplicate.
struct LupyIslandWindowSettings: View {
    var body: some View {
        LupySettingsCard(title: "Island, window & sounds",
                         subtitle: "The island and the window: size, auto-close, sounds, wardrobe and screen — all in one place.") {
            HStack(spacing: 16) {
                Button("Island settings…") { LupyModel.shared.open(.general) }.buttonStyle(LupySecondaryButtonStyle())
                Button("Shortcuts…") { LupyModel.shared.open(.shortcuts) }.buttonStyle(LupySecondaryButtonStyle())
                Button("Start at login…") { LupyModel.shared.open(.general) }.buttonStyle(LupySecondaryButtonStyle())
                Spacer()
            }
            .font(.system(size: 12))
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
            LupyBudgetDisclosure()
        }
    }
}

/// Spending limits, folded into the autonomy card (LUPY 2): one line until asked.
struct LupyBudgetDisclosure: View {
    private var model: LupyModel { LupyModel.shared }
    @State private var open = false
    @State private var daily = ""
    @State private var monthly = ""
    @State private var perTask = ""
    @State private var perCall = ""

    var body: some View {
        let b = model.state.budget
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { open.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle").font(.system(size: 12))
                    Text("Spending limits: \(TextUtil.fixed(b.dailyCapCents / 100, 2)) per day, \(TextUtil.fixed(b.monthlyCapCents / 100, 2)) per month")
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.system(size: 9))
                }
                .font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
            }
            .buttonStyle(.plain)
            if open {
                Text("Hard limits stop model calls. Above the per-call amount Lupy asks you first. Amounts in US dollars.")
                    .font(.system(size: 11)).foregroundColor(LupyTheme.muted)
                HStack(spacing: 12) {
                    LupyBudgetDisclosure.field("Per day", $daily, b.dailyCapCents)
                    LupyBudgetDisclosure.field("Per month", $monthly, b.monthlyCapCents)
                    LupyBudgetDisclosure.field("Per task", $perTask, b.perTaskCapCents)
                    LupyBudgetDisclosure.field("Ask above (per call)", $perCall, b.approvalAboveCentsPerCall)
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
    }

    private static func field(_ label: String, _ text: Binding<String>, _ cents: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
            TextField(TextUtil.fixed(cents / 100, 2), text: text).textFieldStyle(.roundedBorder).frame(width: 110)
        }
    }
}

// MARK: - AI APIs — the ONE place for every AI key (D-032)

/// Any key the founder pastes just works: pick a service (or "Another…" with the link they
/// gave you), paste the key, press Add. Lupy enables it, discovers its models, picks the right
/// one for each job, and switches automatically when one API stops or hits its limit.
struct LupyAPIsSettings: View {
    private var model: LupyModel { LupyModel.shared }
    @State private var adding = false
    @State private var picked: String? = nil
    @State private var key = ""
    @State private var customName = ""
    @State private var customURL = ""

    private var providers: [ProviderConfig] {
        model.state.providers.values.sorted { ($0.hasKey && $0.founderApproved ? 0 : 1, $0.displayName) < ($1.hasKey && $1.founderApproved ? 0 : 1, $1.displayName) }
    }

    /// Preset chips — the services people actually get keys from. "Another…" covers the rest
    /// (free-token services are almost always OpenAI-compatible: link + key is all Lupy needs).
    private let presets: [(id: String, label: String)] = [
        ("openai", "OpenAI"), ("anthropic", "Anthropic"), ("gemini", "Google Gemini"),
        ("deepseek", "DeepSeek"), ("openrouter", "OpenRouter"), ("groq", "Groq"),
        ("mistral", "Mistral"), ("custom", "Another…"),
    ]

    var body: some View {
        LupySettingsCard(title: "AI APIs",
                         subtitle: "One place for every AI key. Paste any key — Lupy figures out the rest, picks the right model for each job, and switches to another API automatically if one stops or hits its limit. Your chat memory stays the same whichever model answers. Keys live only in your Mac's Keychain; Lupy never runs models on your Mac.") {
            ForEach(providers) { p in LupyAPIRow(provider: p) }
            if !adding {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { adding = true }
                } label: {
                    Label("Add an API", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(LupyPrimaryButtonStyle())
            } else {
                addFlow
            }
        }
    }

    private var addFlow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Which service is the key from?")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(LupyTheme.text)
            HStack(spacing: 6) {
                ForEach(presets, id: \.id) { preset in
                    Button(preset.label) {
                        picked = preset.id
                        if preset.id != "custom" { customName = ""; customURL = "" }
                    }
                    .font(.system(size: 11.5))
                    .buttonStyle(.plain)
                    .foregroundColor(picked == preset.id ? Color(hex: "#0B0C0E") : LupyTheme.text)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(picked == preset.id ? LupyTheme.accent : Color.white.opacity(0.07))
                    .clipShape(Capsule())
                }
            }
            if picked == "custom" {
                HStack(spacing: 8) {
                    TextField("Name (e.g. CodeCraft)", text: $customName).textFieldStyle(.roundedBorder).frame(width: 160)
                    TextField("The link they gave you (https://…)", text: $customURL).textFieldStyle(.roundedBorder)
                }
            }
            if picked != nil {
                HStack(spacing: 8) {
                    SecureField("Paste the API key", text: $key).textFieldStyle(.roundedBorder)
                    Button("Add") {
                        if picked == "custom" {
                            model.addCustomProvider(name: customName, baseURL: customURL, key: key)
                        } else if let id = picked {
                            model.enableProvider(id, key: key)
                        }
                        key = ""; picked = nil
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { adding = false }
                    }
                    .buttonStyle(LupyPrimaryButtonStyle())
                    .disabled(key.isEmpty || (picked == "custom" && (customName.isEmpty || customURL.isEmpty)))
                    Button("Cancel") {
                        key = ""; picked = nil; customName = ""; customURL = ""
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { adding = false }
                    }.buttonStyle(LupySecondaryButtonStyle())
                }
                Text("Adding a key means Lupy may send your task text to that service to get answers — that is what the key is for. Nothing else is ever sent.")
                    .font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// One API in the list: a dot, the name, what Lupy uses it for — details hidden unless asked.
struct LupyAPIRow: View {
    private var model: LupyModel { LupyModel.shared }
    let provider: ProviderConfig
    @State private var details = false

    private var ready: Bool { provider.hasKey && provider.founderApproved && provider.enabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(ready ? LupyTheme.green : LupyTheme.muted).frame(width: 8, height: 8)
                Text(provider.displayName).font(.system(size: 13, weight: .semibold)).foregroundColor(LupyTheme.text)
                Text(ready ? "ready" : (provider.hasKey ? "not allowed yet" : "no key"))
                    .font(.system(size: 10.5)).foregroundColor(LupyTheme.secondary)
                if ready {
                    Text("\(provider.models.filter(\.enabled).count) model\(provider.models.filter(\.enabled).count == 1 ? "" : "s") in use")
                        .font(.system(size: 10.5)).foregroundColor(LupyTheme.muted)
                }
                Spacer()
                Button("Test") { model.testProvider(provider.id) }.buttonStyle(LupySecondaryButtonStyle())
                Button(details ? "Done" : "Details") { details.toggle() }.buttonStyle(LupySecondaryButtonStyle())
            }
            if details {
                Text(provider.dataNotice).font(.system(size: 11)).foregroundColor(LupyTheme.secondary)
                HStack {
                    SecureField(provider.hasKey ? "Replace API key" : "Paste API key", text: $keyField).textFieldStyle(.roundedBorder)
                    Button("Save") { model.saveKey(providerID: provider.id, key: keyField); keyField = "" }.disabled(keyField.isEmpty)
                    if provider.hasKey { Button("Remove key") { model.removeKey(providerID: provider.id) } }
                }
                Toggle("Allow Lupy to send task context to \(provider.displayName)", isOn: Binding(get: { provider.founderApproved }, set: { on in
                    model.act { try $0.approveProvider(provider.id, approved: on); return [] }
                }))
                .font(.system(size: 12))
                HStack {
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
    @State private var keyField = ""
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

// MARK: - Housekeeping (privacy, backups, diagnostics in one card — LUPY 2)

struct LupyHousekeepingSettings: View {
    private var model: LupyModel { LupyModel.shared }
    var body: some View {
        LupySettingsCard(title: "Privacy, backup & diagnostics", subtitle: "What leaves your Mac, how to keep a copy of everything, and a plain status report.") {
            privacy
            Divider().overlay(LupyTheme.line)
            backup
            Divider().overlay(LupyTheme.line)
            diagnostics
        }
        .font(.system(size: 12))
    }

    private var privacy: some View {
        let s = model.state.settings
        VStack(alignment: .leading, spacing: 8) {
            Text("What leaves your Mac").font(.system(size: 12.5, weight: .semibold)).foregroundColor(LupyTheme.text)
            Text("• Your data lives in ~/Library/Application Support/Lupy on this Mac.\n• API keys live only in the macOS Keychain — never in Lupy's files, backups or logs.\n• When a cloud model is allowed and used, Lupy sends only the context listed with each request (secrets are redacted, sensitive memory is withheld, other projects are never included).\n• Dictation uses Apple's speech recognition (on this Mac when supported).")
                .font(.system(size: 11.5)).foregroundColor(LupyTheme.body)
            Toggle("Include relevant memory in model requests", isOn: Binding(get: { s.dataSharing.includeMemoryInModelContext }, set: { on in
                var x = s; x.dataSharing.includeMemoryInModelContext = on; model.act { try $0.updateSettings(x); return [] }
            }))
            Toggle("Allow memory marked sensitive to be sent (not recommended)", isOn: Binding(get: { s.dataSharing.includeSensitiveMemory }, set: { on in
                var x = s; x.dataSharing.includeSensitiveMemory = on; model.act { try $0.updateSettings(x); return [] }
            }))
        }
    }

    private var backup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backup, restore and export").font(.system(size: 12.5, weight: .semibold)).foregroundColor(LupyTheme.text)
            Text("Backups are single files you can keep anywhere. They never include API keys. Restoring moves current data aside instead of deleting it.")
                .font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
            HStack(spacing: 8) {
                Button("Save a backup…") { model.exportBackup() }.buttonStyle(LupyPrimaryButtonStyle())
                Button("Restore from backup…") { model.restoreBackup() }.buttonStyle(LupySecondaryButtonStyle())
                Button("Import a project…") { model.importProject() }.buttonStyle(LupySecondaryButtonStyle())
                Button("Show data folder") { model.revealDataFolder() }.buttonStyle(LupySecondaryButtonStyle())
            }
        }
    }

    private var diagnostics: some View {
        let report = model.engine?.diagnostics(dataSizeBytes: model.dataSizeBytes)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics").font(.system(size: 12.5, weight: .semibold)).foregroundColor(LupyTheme.text)
            Text((report?.lines ?? [model.startupError ?? "Not started"]).joined(separator: "\n") + "\nMemory in use: \(String(format: "%.0f", lupyResidentMemoryMB())) MB")
                .font(.system(size: 11.5, design: .monospaced)).foregroundColor(report?.healthy == false ? LupyTheme.amber : LupyTheme.body)
                .textSelection(.enabled)
            Button("Copy diagnostics") { model.copy((report?.lines ?? []).joined(separator: "\n"), announce: "Diagnostics copied.") }.buttonStyle(LupySecondaryButtonStyle())
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
            // Lupy: the character is Lupy now; the credit stays because the code and artwork are Louis Raillé's.
            Text("Lupy \(version) — your assistant. Built on the open-source Coucou app by Louis Raillé (github.com/Louis-CFM/coucou); its code is MIT-licensed (notice inside the app). Lupy's character, icon and sounds are © Louis Raillé and are included only in this private build for your own Mac — not for sharing or publishing.")
                .font(.system(size: 11.5)).foregroundColor(LupyTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
