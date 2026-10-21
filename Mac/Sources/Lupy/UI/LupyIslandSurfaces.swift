// THE OTHER SURFACES — same chrome, same law, same discipline as the approval view.
//
// The approval surface is the locked reference; these are its siblings. Each owns
// only the card's inside and takes every size, corner, glass and glyph from the
// kernel through LupyCanvasChrome. A surface that writes its own number is a bug.

import SwiftUI

// MARK: - One card shape for every list-and-choices surface

struct LupyCardPayload {
    var meta: String
    var lines: [LupyApprovalLine]
    var provenance: String? = nil
    var chips: [LupyApprovalChip] = []
}

/// answer / question / error / transcript all reduce to this: meta, rows, quiet
/// source line, optional chips. One implementation, four meanings, zero drift.
struct LupyIslandCardView: View {
    let need: LupyCanvasNeed
    let state: LupyCharacterState
    let payload: LupyCardPayload
    var onChip: (Int) -> Void = { _ in }

    var body: some View {
        LupyCanvasChrome(need: need, state: state) {
            VStack(alignment: .leading, spacing: LupyIslandLayout.padInner) {
                Text(payload.meta)
                    .font(LupyType.provenanceFont)
                    .lineLimit(1)
                    .foregroundStyle(LupyPalette.textBody.colour)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: LupyIslandLayout.headlineRow)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(LupyPalette.decoration.colour.opacity(0.5))
                            .frame(height: 1)
                    }
                VStack(alignment: .leading, spacing: LupyIslandLayout.padInner) {
                    ForEach(payload.lines) { line in
                        Text(line.text)
                            .font(LupyType.font(LupyType.body, mono: line.mono))
                            .foregroundStyle(LupyPalette.textBody.colour)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel(line.text)
                    }
                    if let provenance = payload.provenance {
                        Text(provenance)
                            .font(LupyType.provenanceFont)
                            .foregroundStyle(LupyPalette.iconography.colour)
                            .lineLimit(1)
                    }
                }
                if !payload.chips.isEmpty {
                    HStack(spacing: LupyIslandLayout.grid) {
                        ForEach(Array(payload.chips.enumerated()), id: \.element.id) { i, chip in
                            Button { onChip(i) } label: { LupyChipFace(chip: chip) }
                                .buttonStyle(.plain)
                                .accessibilityLabel(chip.label)
                        }
                    }
                }
            }
            .padding(.horizontal, LupyIslandLayout.padInner)
            .padding(.bottom, LupyIslandLayout.padInner)
        }
    }
}

// MARK: - The task list: his plan, live

struct LupyTaskPayload {
    var title: String
    var meta: String
    var steps: [String]
    var stepIndex: Int
    var provenance: String? = nil
}

struct LupyIslandTaskView: View {
    let payload: LupyTaskPayload
    let state: LupyCharacterState

    private var need: LupyCanvasNeed {
        .task(steps: payload.steps.count, hasPlan: true, hasPreview: false)
    }

    var body: some View {
        LupyCanvasChrome(need: need, state: state) {
            VStack(alignment: .leading, spacing: LupyIslandLayout.padInner) {
                Text(payload.meta)
                    .font(LupyType.provenanceFont)
                    .lineLimit(1)
                    .foregroundStyle(LupyPalette.textBody.colour)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: LupyIslandLayout.headlineRow)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(LupyPalette.decoration.colour.opacity(0.5))
                            .frame(height: 1)
                    }
                VStack(alignment: .leading, spacing: LupyIslandLayout.padInner) {
                    ForEach(Array(payload.steps.enumerated()), id: \.offset) { i, step in
                        HStack(spacing: LupyIslandLayout.chipIconGap) {
                            Text("\(i + 1)")
                                .font(LupyType.font(LupyType.body, weight: .medium))
                                .fixedSize()
                                .foregroundStyle(i < payload.stepIndex
                                                 ? LupyPalette.accent.colour
                                                 : LupyPalette.iconography.colour)
                            Text(step)
                                .font(LupyType.bodyFont)
                                .foregroundStyle(i == payload.stepIndex
                                                 ? LupyPalette.textPrimary.colour
                                                 : LupyPalette.textBody.colour)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let provenance = payload.provenance {
                        Text(provenance)
                            .font(LupyType.provenanceFont)
                            .foregroundStyle(LupyPalette.iconography.colour)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, LupyIslandLayout.padInner)
            .padding(.bottom, LupyIslandLayout.padInner)
        }
    }
}

// MARK: - The conversation

struct LupyChatTurn: Identifiable {
    let id = UUID()
    let who: String      // "You:" / "Lupy:"
    let text: String
}

/// The director's read-only conversation renderer. NOT LupyIslandChatView —
/// that name belongs to the interactive chat surface in Sources/Lupy (draft
/// field, dictation, quick jumps); the two once collided and the first field
/// compile (kit 3.3) was the first compiler ever to see either.
struct LupyIslandTranscriptView: View {
    let turns: [LupyChatTurn]
    let meta: String
    let state: LupyCharacterState

    private var need: LupyCanvasNeed { .chat(turns: turns.count, streaming: true) }

    var body: some View {
        LupyCanvasChrome(need: need, state: state) {
            VStack(alignment: .leading, spacing: LupyIslandLayout.padInner) {
                Text(meta)
                    .font(LupyType.provenanceFont)
                    .lineLimit(1)
                    .foregroundStyle(LupyPalette.textBody.colour)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: LupyIslandLayout.headlineRow)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(LupyPalette.decoration.colour.opacity(0.5))
                            .frame(height: 1)
                    }
                VStack(alignment: .leading, spacing: LupyIslandLayout.padInner) {
                    ForEach(turns) { turn in
                        Text("\(turn.who) \(turn.text)")
                            .font(LupyType.bodyFont)
                            .foregroundStyle(turn.who.hasPrefix("You")
                                             ? LupyPalette.textPrimary.colour
                                             : LupyPalette.textBody.colour)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, LupyIslandLayout.padInner)
            .padding(.bottom, LupyIslandLayout.padInner)
        }
    }
}
