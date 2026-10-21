// THE APPROVAL SURFACE — the first wired island screen.
//
// "Needs your OK": a program wants to run something, LUPY shows exactly what, where,
// and under which session, and offers the choices. This view owns only the card's
// inside — headline meta, the evidence rows, the chips — and takes everything else
// (glass, LUPY, the status sentence, the composer, every size) from the island law
// through `LupyCanvasChrome`. That is the point: a surface cannot drift from the
// numbers the headless tests prove, because it never writes a number of its own.
//
// Founder's build order: character → approval → locked as the reference. This is it.

import SwiftUI

// MARK: - What the surface shows

/// One quick-reply chip. `key` is the keyboard shortcut shown as its glyph (⌘Y).
struct LupyApprovalChip: Identifiable {
    let id = UUID()
    let label: String
    var key: String? = nil
    var primary: Bool = false
}

/// One evidence row. `mono` sets the monospaced design for commands and paths.
struct LupyApprovalLine: Identifiable {
    let id = UUID()
    let text: String
    var mono: Bool = false
}

/// The payload a host (Claude hook, script, agent) hands the island.
struct LupyApprovalPayload {
    var meta: String                      // right of the headline: "1 of 1 waiting"
    var lines: [LupyApprovalLine]         // what wants to run, where, in which session
    var chips: [LupyApprovalChip]         // the choices, first = primary
    var provenance: String? = nil         // the quiet source line under the rows
}

// MARK: - The surface

struct LupyIslandApprovalView: View {
    let payload: LupyApprovalPayload
    var onChip: (Int) -> Void = { _ in }

    private var need: LupyCanvasNeed {
        .decision(options: payload.chips.count,
                  hasEvidence: !payload.lines.isEmpty,
                  queue: 1)
    }

    var body: some View {
        LupyCanvasChrome(need: need, state: .approval) {
            VStack(alignment: .leading, spacing: LupyIslandLayout.padInner) {
                // The headline row's right half: the card's meta. The status sentence
                // owns the left half; the row is never dead space.
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

                // The evidence, one row per line, on the law's row pitch.
                VStack(alignment: .leading, spacing: LupyIslandLayout.padInner) {
                    ForEach(payload.lines) { line in
                        Text(line.text)
                            .font(LupyType.font(LupyType.body,
                                                mono: line.mono))
                            .foregroundStyle(LupyPalette.textBody.colour)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let provenance = payload.provenance {
                        Text(provenance)
                            .font(LupyType.provenanceFont)
                            .foregroundStyle(LupyPalette.iconography.colour)
                            .lineLimit(1)
                    }
                }

                // The choices. First chip is the primary action: accent fill, ink text,
                // because white on the accent fails our own 4.5:1 law.
                HStack(spacing: LupyIslandLayout.grid) {
                    ForEach(Array(payload.chips.enumerated()), id: \.element.id) { i, chip in
                        Button { onChip(i) } label: { LupyChipFace(chip: chip) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, LupyIslandLayout.padInner)
            .padding(.bottom, LupyIslandLayout.padInner)
        }
    }
}

// MARK: - One chip, on the control kit

struct LupyChipFace: View {
    let chip: LupyApprovalChip

    var body: some View {
        HStack(spacing: LupyIslandLayout.chipIconGap) {
            if let key = chip.key {
                Text(key)                       // "⌘Y" — the glyph, at icon size
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            Text(chip.label)
                .font(LupyType.chipFont)
                .lineLimit(1)
        }
        .padding(.horizontal, LupyIslandLayout.chipPadH)
        .frame(height: LupyIslandLayout.chipHeight)
        .background(
            chip.primary ? LupyPalette.accent.colour
                         : LupyPalette.paper.colour.opacity(0.09),
            in: RoundedRectangle(cornerRadius: LupyIslandLayout.chipCorner,
                                 style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LupyIslandLayout.chipCorner, style: .continuous)
                .strokeBorder(chip.primary
                              ? Color.clear
                              : LupyPalette.paper.colour.opacity(0.14),
                              lineWidth: 1)
        )
        .foregroundStyle(chip.primary ? LupyPalette.ink.colour
                                      : LupyPalette.textBody.colour)
    }
}

// MARK: - Proof that it builds and reads

// #Preview needs Xcode's PreviewsMacros plugin, which the founder's CLT-only
// build does not carry (kit 3.3 field error) — DEBUG keeps it for Xcode users.
#if DEBUG
#Preview("Needs your OK") {
    LupyIslandApprovalView(
        payload: .init(
            meta: "1 of 1 waiting",
            lines: [
                .init(text: "Claude Code wants to run:"),
                .init(text: "rm -rf build/ && xcodegen generate", mono: true),
                .init(text: "in ~/lupy · session a91f", mono: true),
            ],
            chips: [
                .init(label: "Allow once", key: "⌘Y", primary: true),
                .init(label: "Deny", key: "⌘N"),
            ],
            provenance: nil
        )
    )
    .padding(40)
    .background(Color.black)
}
#endif
