// Lupy — the conversation in the workspace's Today page: the same LupyChat the island shows,
// with the project and planning options the window has room for. Starting a task here and
// opening the island (or the reverse) continues one conversation with one state.

import LupyCore
import SwiftUI

struct LupyChatPanel: View {
    private var model: LupyModel { LupyModel.shared }
    private var chat: LupyChat { LupyChat.shared }
    @State private var draft = ""
    @State private var projectID: LupyID?
    @State private var useModel = true
    @State private var dictation = MacDictation()
    @FocusState private var focused: Bool

    var body: some View {
        let projects = model.state.activeProjects
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: chat.statusColor)).frame(width: 8, height: 8)
                Text(chat.statusLine)
                    .font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
                Spacer()
                if LupyControlCenter.shared.isActive {
                    Button("Watch the cursor") { model.open(.lupyControl) }.buttonStyle(LupySecondaryButtonStyle())
                }
                if !model.state.pendingApprovals.isEmpty {
                    Button("Needs you (\(model.state.pendingApprovals.count))") { model.open(.lupyNeedsYou) }
                        .buttonStyle(LupySecondaryButtonStyle())
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chat.messages) { m in
                            LupyChatBubble(message: m, windowStyle: true).id(m.id)
                        }
                        if chat.isWaiting {
                            HStack { LupyTypingDots(); Spacer(minLength: 32) }.id("waiting")
                        }
                        if let approval = model.state.pendingApprovals.sorted(by: { $0.requestedAt < $1.requestedAt }).first {
                            LupyChatApprovalRow(approval: approval).id("approval")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 300)
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

            HStack(alignment: .top, spacing: 10) {
                TextField("Tell Lupy anything — a goal, a question, or “what's next”…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...5)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(HubTheme.field))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
                    .focused($focused)
                    .onSubmit(submit)
                    .onChange(of: dictation.transcript) { _, _ in
                        if dictation.isRecording { draft = dictation.text }
                    }
                Button {
                    Task { @MainActor in
                        if dictation.isRecording { draft = await dictation.finish() }
                        else { await dictation.start(from: draft) }
                    }
                } label: {
                    Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(dictation.isRecording ? Color(hex: "#F4505E") : Color(hex: "#A4A9B1"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(dictation.isRecording ? 0.12 : 0.06)))
                }
                .buttonStyle(.plain)
                .help("Dictate. Your words appear in the field and stay editable before anything is used.")
                .contextMenu { LupyDictationLanguageMenu(dictation: dictation) }
            }
            if dictation.isRecording {
                Text("Listening… your words appear above; nothing is sent until you press Send.")
                    .font(.system(size: 12)).foregroundColor(LupyTheme.secondary)
            }

            HStack(spacing: 12) {
                Picker("Project", selection: Binding(get: { projectID ?? model.defaultCaptureProject }, set: { projectID = $0 })) {
                    ForEach(projects) { p in Text(p.name).tag(p.id) }
                }
                .frame(maxWidth: 260)
                if model.hasUsableModel {
                    Toggle("Plan goals with the cloud model", isOn: $useModel).toggleStyle(.switch).controlSize(.small)
                        .help("Off = Lupy plans with offline rules. Questions you ask always need the model and its approval.")
                } else {
                    Text("Offline planning — open-ended questions need a cloud model (Assistant page).")
                        .font(.system(size: 11.5)).foregroundColor(LupyTheme.muted).lineLimit(1)
                }
                Spacer()
                Button("Send", action: submit)
                    .buttonStyle(LupyPrimaryButtonStyle())
                    .disabled(TextUtil.trimmed(draft).isEmpty && !dictation.isRecording)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .background(LupyCardBackground(wash: .soft))
    }

    private func submit() {
        if dictation.isRecording {
            Task { @MainActor in
                draft = await dictation.finish()
                submit()
            }
            return
        }
        let text = draft
        draft = ""
        chat.send(text, projectID: projectID, useModel: useModel && model.hasUsableModel)
    }
}

/// The window's slightly larger typing dots (the island uses Coucou's TypingDotsView).
struct LupyTypingDots: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#6B7079"))
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase ? 1.2 : 0.6)
                    .animation(.easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.14), value: phase)
            }
        }
        .padding(.horizontal, 2).padding(.vertical, 4)
        .onAppear { phase = true }
    }
}
