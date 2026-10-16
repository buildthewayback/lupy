// Lupy — Lupy's pages inside Coucou's window (FlowHub): their titles, symbols, the colour and
// Mochis of their top band (in the style of HubHeroTheme), and the page containers.
// Coucou's FlowHub.swift / FlowHubMochis.swift route the new HubPage cases here.

import LupyCore
import SwiftUI

extension HubPage {
    /// The "Lupy" group at the top of the window's sidebar.
    static let lupyPages: [HubPage] = [.lupyToday, .lupyNeedsYou, .lupyTasks, .lupyProjects, .lupyHandoffs,
                                       .lupyMemory, .lupyActivity, .lupyUsage, .lupyControl, .lupyAssistant]

    var isLupy: Bool { Self.lupyPages.contains(self) }

    var lupyTitle: String {
        switch self {
        case .lupyToday: return "Today"
        case .lupyNeedsYou: return "Needs you"
        case .lupyTasks: return "Tasks"
        case .lupyProjects: return "Projects"
        case .lupyHandoffs: return "Handoffs"
        case .lupyMemory: return "Memory"
        case .lupyActivity: return "Activity"
        case .lupyUsage: return "Usage & budget"
        case .lupyControl: return "Computer control"
        case .lupyAssistant: return "Assistant"
        default: return ""
        }
    }

    var lupySymbol: String {
        switch self {
        case .lupyToday: return "sun.max"
        case .lupyNeedsYou: return "hand.raised"
        case .lupyTasks: return "checklist"
        case .lupyProjects: return "square.grid.2x2"
        case .lupyHandoffs: return "arrow.left.arrow.right"
        case .lupyMemory: return "brain"
        case .lupyActivity: return "clock.arrow.circlepath"
        case .lupyUsage: return "gauge.with.dots.needle.33percent"
        case .lupyControl: return "cursorarrow.motionlines"
        case .lupyAssistant: return "slider.horizontal.3"
        default: return "circle"
        }
    }

    var lupySubtitle: String? {
        switch self {
        case .lupyNeedsYou: return "Decisions only you can make. Nothing consequential happens without your OK."
        case .lupyTasks: return "Most important first. “Done” needs evidence, not just a claim."
        case .lupyProjects: return "Your projects, their rules and their tasks."
        case .lupyHandoffs: return "Work you handed to Arena, Muse or Orin, followed up until it is verified."
        case .lupyMemory: return "What Lupy knows and why — correct it any time."
        case .lupyActivity: return "Everything Lupy did and why, newest first."
        case .lupyUsage: return "What cloud models cost, against the budget you set."
        case .lupyControl: return "Watch Lupy use your Mac with its own cursor — and stop it any time."
        case .lupyAssistant: return "Autonomy, cloud models, budget, GitHub, privacy and backups."
        default: return nil
        }
    }
}

/// The colour and the Mochis of each Lupy page's band.
enum LupyHubThemes {
    static func theme(for page: HubPage) -> HubHeroTheme {
        func m(_ color: String, _ size: CGFloat, _ start: CGFloat, outfit: Outfit = .none,
               state: BotState = .idle, roams: Bool = true) -> HubMochiSpec {
            HubMochiSpec(color: color, size: size, outfit: outfit, state: state, roams: roams, start: start)
        }
        switch page {
        case .lupyToday:
            return .init(color: Color(hex: "#FB923C"), cast: [m("#F5F6F8", 64, 0.25, outfit: .scarf), m("#FB923C", 50, 0.62, state: .working), m("#34D399", 42, 0.92)])
        case .lupyNeedsYou:
            return .init(color: Color(hex: "#F5A524"), cast: [m("#F5A524", 60, 0.3, state: .approval, roams: false), m("#F5F6F8", 46, 0.8)])
        case .lupyTasks:
            return .init(color: Color(hex: "#3B9EFF"), cast: [m("#3B9EFF", 58, 0.15, state: .working, roams: false), m("#F5F6F8", 48, 0.55), m("#F7B32B", 42, 0.9)])
        case .lupyProjects:
            return .init(color: Color(hex: "#7C5CFF"), cast: [m("#7C5CFF", 58, 0.2, outfit: .beanie), m("#22D3EE", 46, 0.6), m("#F5F6F8", 40, 0.95)])
        case .lupyHandoffs:
            return .init(color: Color(hex: "#22D3EE"), cast: [m("#22D3EE", 56, 0.2), m("#A78BFA", 48, 0.55, outfit: .roundGlasses), m("#E07950", 44, 0.9, state: .thinking, roams: false)])
        case .lupyMemory:
            return .init(color: Color(hex: "#A78BFA"), cast: [m("#A78BFA", 60, 0.3, outfit: .roundGlasses), m("#F5F6F8", 46, 0.8, state: .sleeping, roams: false)])
        case .lupyActivity:
            return .init(color: Color(hex: "#34D399"), cast: [m("#34D399", 56, 0.2), m("#F5F6F8", 46, 0.7, state: .searching)])
        case .lupyUsage:
            return .init(color: Color(hex: "#F7B32B"), cast: [m("#F7B32B", 60, 0.3, outfit: .crown), m("#34D399", 44, 0.85)])
        case .lupyControl:
            return .init(color: Color(hex: "#F472B6"), cast: [m("#F472B6", 58, 0.25, outfit: .sunglasses, state: .working), m("#F5F6F8", 46, 0.75)])
        default:
            return .init(color: Color(hex: "#8E939C"), cast: [m("#F5F6F8", 58, 0.35, outfit: .roundGlasses), m("#8E939C", 46, 0.9, state: .sleeping, roams: false)])
        }
    }
}

/// Routes a Lupy page (called by FlowHubView).
struct LupyHubPage: View {
    let page: HubPage

    var body: some View {
        Group {
            switch page {
            case .lupyToday: LupyTodayPage()
            case .lupyNeedsYou: LupyFixedPage(page: page) { LupyApprovalsContent() }
            case .lupyTasks: LupyFixedPage(page: page) { LupyTasksContent() }
            case .lupyProjects: LupyFixedPage(page: page) { LupyProjectsContent() }
            case .lupyHandoffs: LupyFixedPage(page: page) { LupyHandoffsContent() }
            case .lupyMemory: LupyFixedPage(page: page) { LupyMemoryContent() }
            case .lupyActivity: LupyFixedPage(page: page) { LupyActivityContent() }
            case .lupyUsage: LupyFixedPage(page: page) { LupyUsageContent() }
            case .lupyControl: LupyControlPage()
            default: LupyFixedPage(page: page) { LupyAssistantSettings() }
            }
        }
        .overlay(alignment: .bottom) { LupyToast().animation(.easeInOut(duration: 0.2), value: LupyModel.shared.toast) }
        .overlay {
            if let err = LupyModel.shared.startupError {
                LupyEmptyHint(symbol: "exclamationmark.triangle", title: "Lupy could not start its assistant", detail: err)
                    .background(HubTheme.panel)
            }
        }
    }
}

/// A Lupy page whose content scrolls by itself (lists with a detail column): the band stays on top.
struct LupyFixedPage<Content: View>: View {
    let page: HubPage
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HubHero(page: page, title: page.lupyTitle, subtitle: page.lupySubtitle, compact: true)
                .padding(.horizontal, 28)
                .padding(.top, 24)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// Today: greeting and status in the band, then the day.
struct LupyTodayPage: View {
    var body: some View {
        let model = LupyModel.shared
        let paused = model.attention.paused
        HubPageScaffold(title: model.greeting, subtitle: model.statusLine) {
            Button(paused ? "Resume Lupy" : "Pause Lupy") {
                model.act { try $0.setGlobalPause(!paused, reason: paused ? "" : "Paused from Today"); return [] }
            }
            .buttonStyle(HubButtonStyle(primary: paused))
            .help(paused ? "Lupy resumes follow-ups, checks and computer control." : "Stops follow-ups, model calls and computer control until you resume.")
        } content: {
            if !model.state.settings.onboardingComplete {
                LupyWelcomeCard()
            }
            LupyTodayContent()
        }
    }
}

/// First launch: who Lupy is, what it never does without you, and the name it should use.
/// An inline card, never a sheet: nothing can block quitting the app (DECISIONS D-019).
struct LupyWelcomeCard: View {
    @State private var name = ""

    var body: some View {
        HubGlowCard(color: HubTheme.accent, padding: 22) {
            HStack(alignment: .top, spacing: 16) {
                HubLiveMochi(size: 54, state: .idle, outfit: .scarf)
                    .frame(width: 60, height: 54)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hi, I'm Lupy.").font(.system(size: 20, weight: .bold))
                    Text("I keep your projects moving and I never call something done without evidence.")
                        .font(.system(size: 13)).foregroundColor(Color(hex: "#B7BBC2"))
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                Label("Tell me a goal — I'll propose steps. Nothing starts until you approve.", systemImage: "list.bullet.clipboard")
                Label("I follow up on what you hand to Arena, Muse or ChatGPT, and check GitHub for proof.", systemImage: "checkmark.seal")
                Label("I ask before spending, publishing, messaging people, deleting or touching security.", systemImage: "hand.raised")
                Label("When you turn on computer control, you watch my own cursor work — and can stop it any time.", systemImage: "cursorarrow.motionlines")
                Label("Your data stays on this Mac. Cloud models are optional; keys go in the Keychain.", systemImage: "lock")
            }
            .font(.system(size: 13))
            .foregroundColor(HubTheme.body)
            HStack(spacing: 10) {
                HubField(placeholder: "What should I call you?", text: $name, onSubmit: finish)
                    .frame(maxWidth: 320)
                Button("Get started", action: finish)
                    .buttonStyle(HubButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear { name = LupyModel.shared.state.settings.founderName }
    }

    private func finish() {
        let model = LupyModel.shared
        // Return can reach both the field's submit and the default button; act once.
        guard !model.state.settings.onboardingComplete else { return }
        var s = model.state.settings
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { s.founderName = trimmed }
        s.onboardingComplete = true
        let settings = s
        model.act { try $0.updateSettings(settings); return [] }
    }
}
