//  LupyIslandCanvas.swift
//  The SwiftUI face of the island's design law (LupyIslandDesign.swift).
//
//  The law is pure math and is tested headlessly; this file is the thin membrane between
//  those tested numbers and the views. It owns no geometry of its own: every rectangle,
//  radius, opacity and font size is read from `LupyIslandLayout.canvas(need:)`, so a view
//  that adopts `LupyCanvasChrome` is, by construction, the canvas the tests approved.
//
//  Adoption is deliberately incremental — one surface at a time, with the founder's
//  approval per use case. Until a view moves over, it keeps drawing itself exactly as it
//  did; nothing here is wired to a live view it has not been approved for.
//
//  What the chrome gives a view:
//    · the glass panel (blur + saturation + derived tint + hairline + shadow)
//    · LUPY at the size the law chose, speaking the one status sentence
//    · the card's glass, its row grid, and its chip row
//    · the composer — mic + field — the island's only permanent control

import SwiftUI

// MARK: - Colours and glass, as SwiftUI values

extension LupyColour {
    /// The same colour, as a SwiftUI value. No second palette lives on this side.
    var colour: Color { Color(red: r, green: g, blue: b, opacity: a) }
}

extension LupyGlass {
    /// The panel's recipe as a view modifier: blurred, saturated backdrop; tint at the
    /// derived alpha; hairline; soft shadow. One place, so no surface can drift.
    func surface(corner: CGFloat) -> some ViewModifier {
        LupyGlassSurface(glass: self, corner: corner)
    }
}

struct LupyGlassSurface: ViewModifier {
    let glass: LupyGlass
    let corner: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .saturation(glass.saturation)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(glass.base.colour.opacity(glass.fillAlpha))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(glass.hairline.colour, lineWidth: 1)
            )
            .shadow(color: glass.shadow.colour,
                    radius: glass.shadowRadius, x: 0, y: glass.shadowY)
    }
}

// MARK: - Type

extension LupyType {
    /// The island's type ramp, as fonts. Sizes come from the kernel, so the 11 pt floor
    /// is enforced where the numbers are tested, not here.
    static func font(_ size: Double, weight: Font.Weight = .regular, mono: Bool = false) -> Font {
        .system(size: size, weight: weight, design: mono ? .monospaced : .default)
    }
    static var headlineFont: Font { font(headline, weight: .bold) }   // HIG Headline
    static var bodyFont: Font { font(body) }
    static var chipFont: Font { font(chip, weight: .medium) }
    static var provenanceFont: Font { font(provenance) }
    static var whisperFont: Font { font(peek, weight: .semibold) }
}

// MARK: - The composer

/// Mic + text field. The only control the island always shows.
struct LupyComposer: View {
    var onSubmit: (String) -> Void = { _ in }
    @State private var text: String = ""

    var body: some View {
        let fieldH = LupyIslandLayout.composerHeight - 2
        let circle: CGFloat = 24          // one control size across the island
        HStack(spacing: LupyIslandLayout.chipIconGap + 4) {
            Image(systemName: "mic.fill")
                .font(.system(size: 11, weight: .medium))
                // Icons take the iconography tone; words never do.
                .foregroundStyle(LupyPalette.iconography.colour)
                .frame(width: circle, height: circle)
                .overlay(Circle().strokeBorder(LupyPalette.decoration.colour
                    .opacity(0.6), lineWidth: 1))
            TextField("Ask LUPY anything…", text: $text)
                .textFieldStyle(.plain)
                .font(LupyType.bodyFont)
                .foregroundStyle(LupyPalette.textBody.colour)
                .onSubmit {
                    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    text = ""
                    onSubmit(t)
                }
            Button {
                onSubmit(text)
                text = ""
            } label: {
                Image(systemName: "return.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LupyPalette.ink.colour)
                    .frame(width: circle, height: circle)
                    .background(LupyPalette.accent.colour, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: fieldH)
        .background(LupyGlass.card().surface(corner: LupyIslandLayout.fieldCorner))
    }
}

// MARK: - The chrome

/// The island's canvas: glass, LUPY, the one status sentence, the card's room, and the
/// composer. A view drops its own content into the card and takes everything else for
/// free — including every invariant the headless tests hold.
struct LupyCanvasChrome<Content: View>: View {
    let need: LupyCanvasNeed
    let state: LupyCharacterState
    @ViewBuilder var content: () -> Content

    private var canvas: LupyCanvas { LupyIslandLayout.canvas(need) }

    var body: some View {
        let c = canvas
        ZStack(alignment: .topLeading) {
            // The card's glass, behind whatever the view brings.
            if !c.content.isEmpty {
                RoundedRectangle(cornerRadius: LupyIslandLayout.cardCorner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: LupyIslandLayout.cardCorner, style: .continuous)
                            .fill(LupyGlass.card().base.colour
                                .opacity(LupyGlass.card().fillAlpha))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LupyIslandLayout.cardCorner, style: .continuous)
                            .strokeBorder(LupyGlass.card().hairline.colour, lineWidth: 1)
                    )
                    .frame(width: c.content.width, height: c.content.height)
                    .offset(x: c.content.x, y: c.content.y)
            }

            // The status sentence, in the one home the law gave it.
            if !c.statusBox.isEmpty {
                LupyStatusLine(state: state,
                               whisper: c.status == .whisper)
                    .frame(width: c.statusBox.width, height: c.statusBox.height)
                    .offset(x: c.statusBox.x, y: c.statusBox.y)
            }

            // The card's own content, laid into the room the law reserved.
            if !c.content.isEmpty {
                content()
                    .frame(width: c.content.width,
                           height: c.content.height,
                           alignment: .topLeading)
                    .offset(x: c.content.x, y: c.content.y)
            }

            // The composer: at the foot, full width, always.
            if !c.composer.isEmpty {
                LupyComposer()
                    .frame(width: c.composer.width, height: c.composer.height)
                    .offset(x: c.composer.x, y: c.composer.y)
            }

            // LUPY, last so his light sits over the glass he is standing on. He sizes
            // himself from his frame at the character's own unit fraction, so the box the
            // law reserved is the body width the rig draws — one number, one owner.
            LupyCanvasView(state: state, showsStatusLabel: false)
                .frame(width: c.avatar.width, height: c.avatar.height)
                .offset(x: c.avatar.x, y: c.avatar.y)
        }
        .frame(width: c.width, height: c.height)
        .modifier(LupyGlass.panel.surface(corner: c.corner))
        .clipShape(RoundedRectangle(cornerRadius: c.corner, style: .continuous))
    }
}

/// The status sentence, animated. His label already carries a single ellipsis when the
/// work is ongoing; the dots breathe so the sentence is visibly alive, per the founder's
/// rule that the status text is never a baked string.
struct LupyStatusLine: View {
    let state: LupyCharacterState
    var whisper: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { tl in
            let phase = Int(tl.date.timeIntervalSinceReferenceDate / 0.45) % 3
            HStack(spacing: 5) {
                Text(state.label)
                    .font(whisper ? LupyType.whisperFont : LupyType.headlineFont)
                    .foregroundStyle(LupyPalette.textPrimary.colour)
                    .lineLimit(1)
                if state.label.hasSuffix("…") {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(LupyPalette.textPrimary.colour)
                                .frame(width: 3, height: 3)
                                .opacity(i == phase ? 0.9 : 0.25)
                        }
                    }
                    .padding(.leading, 2)
                }
            }
            // The sentence is a string on the card: it keeps the card's padding.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, LupyIslandLayout.padInner)
        }
    }
}

// MARK: - Which need a view is

/// The judged mapping from the island's screens to the canvas law.
///
/// Every case says what that screen *has to show*, because that is the only input the
/// growth law accepts. Numbers the views already know (running tasks, queued approvals,
/// conversation turns) are passed in, so a busy canvas really is a bigger canvas.
enum LupyIslandNeedMapping {
    static func need(for view: IslandView,
                     runningTasks: Int = 1,
                     queue: Int = 1,
                     options: Int = 2,
                     turns: Int = 2,
                     transcriptLines: Int = 2,
                     settingsRows: Int = 4,
                     captureActions: Int = 4) -> LupyCanvasNeed {
        switch view {
        case .overview:
            return .task(steps: max(1, runningTasks), hasPlan: false, hasPreview: false)
        case .empty:
            return .answer(lines: 1, chips: 0, provenance: false)
        case .approval:
            return .decision(options: 2, hasEvidence: true, queue: queue)
        case .question, .confused:
            return .decision(options: options, hasEvidence: false, queue: queue)
        case .error:
            return .answer(lines: 2, chips: 2, provenance: true)
        case .finished:
            return .answer(lines: 1, chips: 1, provenance: true)
        case .upload, .uploading, .choose:
            return .task(steps: 2, hasPlan: false, hasPreview: true)
        case .mail:
            return .chat(turns: 2, streaming: false)
        case .prompt, .lupyChat:
            return .chat(turns: turns, streaming: true)
        case .searching:
            return .task(steps: 2, hasPlan: false, hasPreview: false)
        case .result:
            return .answer(lines: 3, chips: 2, provenance: true)
        case .note:
            return .answer(lines: 3, chips: 0, provenance: false)
        case .settings, .wardrobe:
            return .settings(rows: settingsRows)
        case .recap:
            return .answer(lines: 4, chips: 0, provenance: true)
        case .listening:
            return .transcript(lines: transcriptLines)
        case .voiceResult:
            return .answer(lines: 1, chips: 0, provenance: false)
        case .capture:
            return .capture(actions: captureActions)
        case .greeting:
            return .rest
        }
    }
}
