// Lupy — the island's interaction surface: the founder's quick conversation with Lupy, built
// on Coucou's own island chrome (the Mochi placement, card, sounds, buttons). Clicking the
// island (or the ⌃⌥Space shortcut) opens it; type or dictate — dictated words land in the
// editable field first, so mistakes can be fixed before anything is sent. The same
// conversation continues in the window's Today page; nothing here is a mockup.

import LupyCore
import SwiftUI

struct LupyIslandChatView: View {
    @State private var draft = ""
    @FocusState private var focused: Bool
    @State private var dictation = MacDictation()

    private var chat: LupyChat { LupyChat.shared }
    private var model: LupyModel { LupyModel.shared }

    var body: some View {
        ZStack(alignment: .leading) {
            CardBackground(wash: .indigo)
            VStack(alignment: .leading, spacing: 6) {
                header
                messageList
                if dictation.isRecording {
                    Text("Listening — your words appear in the field; edit them, then press the arrow to send.")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color(hex: "#F4505E"))
                }
                inputRow
            }
            .padding(.leading, 84)
            .padding(.trailing, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .onAppear { focused = true }
        .onChange(of: dictation.isRecording) { _, recording in
            // Mochi tells the truth about what Lupy is doing: attentive while listening.
            NotificationCenter.default.post(name: .triggerEmote, object: recording ? BotEmote.listening : BotEmote.happy)
        }
        .onChange(of: dictation.transcript) { _, _ in
            if dictation.isRecording { draft = dictation.text }
        }
    }

    // MARK: Header — live status, never decoration

    private var header: some View {
        HStack(spacing: 8) {
            if chat.isWaiting {
                TypingDotsView()
                Text("Thinking with your cloud model…")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#8E939C"))
            } else {
                Circle().fill(Color(hex: chat.statusColor)).frame(width: 6, height: 6)
                Text(chat.statusLine)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#8E939C"))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 6)
            if !model.hasUsableModel {
                Text("offline")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5A524"))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Capsule())
                    .help("No cloud model is set up. Goals, status and screen routines still work; open-ended questions need a model (Lupy → Assistant).")
            }
            Button {
                AppState.shared.view = .overview
            } label: {
                Image(systemName: "circle.grid.2x2")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "#5F646D"))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Show the island's pills")
            Button {
                model.open(.lupyToday)
                NotificationCenter.default.post(name: .islandCollapse, object: nil)
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "#5F646D"))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open the Lupy workspace — the same conversation continues there")
        }
    }

    // MARK: Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    if chat.isEmpty, draft.isEmpty, !dictation.isRecording {
                        chips
                    }
                    ForEach(chat.messages) { m in
                        LupyChatBubble(message: m)
                            .id(m.id)
                    }
                    if chat.isWaiting {
                        HStack { TypingDotsView(); Spacer(minLength: 32) }.id("waiting")
                    }
                    if let approval = model.state.pendingApprovals.sorted(by: { $0.requestedAt < $1.requestedAt }).first {
                        LupyChatApprovalRow(approval: approval).id("approval")
                    }
                }
                .padding(.vertical, 2)
            }
            .onChange(of: chat.messages.count) { _, _ in
                if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .onChange(of: chat.isWaiting) { _, waiting in
                if waiting { proxy.scrollTo("waiting", anchor: .bottom) }
            }
            .onAppear {
                if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// First-run suggestions — real actions, not decoration; they fill the field for editing.
    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(["What's next?", "Invoice ACME by Friday", "Open Safari and search Displate payouts"], id: \.self) { s in
                Button(s) {
                    draft = s
                    focused = true
                }
                .font(.system(size: 10.5))
                .foregroundColor(Color(hex: "#C5C8CD"))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.white.opacity(0.07))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Input — type or dictate, correct, then send

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Tell Lupy anything…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .lineLimit(1...3)
                .focused($focused)
                .onSubmit(submit)

            Button {
                Task { @MainActor in
                    if dictation.isRecording { draft = await dictation.finish() }
                    else { await dictation.start(from: draft) }
                }
            } label: {
                Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(dictation.isRecording ? Color(hex: "#F4505E") : Color(hex: "#8E939C"))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(dictation.isRecording ? "Stop dictation — the text stays editable" : "Dictate (right-click to choose the language)")
            .contextMenu { LupyDictationLanguageMenu(dictation: dictation) }

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#0B0C0E"))
            }
            .buttonStyle(SendButtonStyle())
            .disabled(TextUtil.trimmed(draft).isEmpty && !dictation.isRecording)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .simultaneousGesture(TapGesture().onEnded { focused = true })
    }

    private func submit() {
        // Still dictating: take the final words first (they land in the field, still editable).
        if dictation.isRecording {
            Task { @MainActor in
                draft = await dictation.finish()
                submit()
            }
            return
        }
        let text = draft
        draft = ""
        chat.send(text)
    }
}

// MARK: - One message

struct LupyChatBubble: View {
    let message: LupyChatMessage
    var windowStyle: Bool = false
    private var model: LupyModel { LupyModel.shared }

    var body: some View {
        switch message.kind {
        case .text:
            HStack(alignment: .top, spacing: 6) {
                if message.role == .user { Spacer(minLength: 32) }
                Group {
                    if message.role == .assistant {
                        ChatMarkdownView(markdown: message.text)
                    } else {
                        Text(message.text)
                            .font(.system(size: windowStyle ? 13.5 : 12.5))
                            .foregroundColor(Color(hex: "#F1F2F4"))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(message.role == .user ? Color.white.opacity(0.13) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: message.role == .user ? 12 : 8))
                if message.role == .assistant { Spacer(minLength: 8) }
            }
        case .plan:
            LupyChatPlanCard(planID: LupyID(message.relatedID ?? ""))
        }
    }
}

// MARK: - A plan awaiting the founder's decision (the conversation stays the surface)

struct LupyChatPlanCard: View {
    let planID: LupyID
    private var model: LupyModel { LupyModel.shared }
    private var plan: Plan? { model.state.plans[planID] }

    var body: some View {
        if let plan {
            let decided = plan.status != .proposed
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: decided ? "checkmark.seal" : "list.bullet.clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: decided ? "#34D399" : "#22D3EE"))
                    Text(plan.summary)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F6F8"))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                }
                if !decided {
                    ForEach(Array(plan.draftTasks.prefix(3).enumerated()), id: \.element.id) { idx, t in
                        Text("\(idx + 1). \(t.title)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#C5C8CD"))
                            .lineLimit(1)
                    }
                    if plan.draftTasks.count > 3 {
                        Text("+ \(plan.draftTasks.count - 3) more step\(plan.draftTasks.count - 3 == 1 ? "" : "s")")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color(hex: "#6B7079"))
                    }
                    HStack(spacing: 8) {
                        SecondaryButton("Reject") {
                            model.act { try $0.rejectPlan(plan.id, note: "Rejected in the conversation"); return [] }
                            LupyChat.shared.replyAfterDecision(rejected: true)
                        }
                        PrimaryButton("Approve plan") {
                            var created = 0
                            model.act { engine in
                                let tasks = try engine.approvePlan(plan.id)
                                created = tasks.count
                                return []
                            }
                            LupyChat.shared.replyAfterDecision(rejected: false, created: created)
                        }
                        Button("Open in Today") {
                            model.selectedPlanID = plan.id
                            model.open(.lupyToday)
                            NotificationCenter.default.post(name: .islandCollapse, object: nil)
                        }
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#8E939C"))
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("This plan was \(plan.status == .approved ? "approved" : "rejected") — see Today for the steps.")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color(hex: "#6B7079"))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#22D3EE").opacity(decided ? 0 : 0.35), lineWidth: 1))
        }
    }
}

// MARK: - An approval mirrored into the conversation (answer it without hunting for it)

struct LupyChatApprovalRow: View {
    let approval: ApprovalRequest
    private var model: LupyModel { LupyModel.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#F5A524"))
                Text("Lupy needs your OK")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5F6F8"))
            }
            Text(approval.action.title + (approval.consequence.isEmpty ? "" : "\n" + approval.consequence))
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#C5C8CD"))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
            HStack(spacing: 8) {
                SecondaryButton("Deny") {
                    model.act { try $0.decideApproval(approval.id, approve: false); return [] }
                }
                PrimaryButton("Allow") {
                    model.act { try $0.decideApproval(approval.id, approve: true); return [] }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color(hex: "#F5A524").opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#F5A524").opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Dictation language menu (same choices as Coucou's prompt mic)

struct LupyDictationLanguageMenu: View {
    @Bindable var dictation: MacDictation

    var body: some View {
        let automatic = MacDictation.automaticLocales().map(\.identifier)
        Picker("Dictation language", selection: $dictation.language) {
            Text("Automatic (" + automatic.map(MacDictation.name(of:)).joined(separator: ", ") + ")")
                .tag(MacDictation.automatic)
            ForEach(MacDictation.allLanguages, id: \.self) { id in
                Text(MacDictation.name(of: id)).tag(id)
            }
        }
    }
}
