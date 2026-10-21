import SwiftUI

//  IslandCharacterView.swift
//  The locked LUPY character, on the island.
//
//  Before this file the island drew Coucou's character (BotCanvasView) while LUPY's
//  rig existed only in the preview window. Two characters shipped in one app: the
//  founder approved one and used the other. This is the bridge, and it is deliberately
//  thin — one mapping, one sampler, no second opinion about how LUPY looks.
//
//  Everything that decides appearance lives in the character kernel:
//    * `LupyCharacterState`  the eleven states
//    * `LupyCanvasView`      the renderer (Bézier body, eyes, badge, glow)
//  This file only translates "what the island knows" into "what the rig asks for".

// MARK: - State mapping

enum LupyStateMapping {
    /// The island speaks Coucou's vocabulary; the rig speaks LUPY's. The two enums
    /// have the same eleven cases on purpose, so this is a total mapping — no state
    /// can fall through to a default and quietly show the wrong face.
    static func state(from bot: BotState) -> LupyCharacterState {
        switch bot {
        case .idle:      return .idle
        case .working:   return .working
        case .thinking:  return .thinking
        case .searching: return .searching
        case .approval:  return .approval
        case .question:  return .question
        case .error:     return .error
        case .finished:  return .finished
        case .ratelimit: return .rateLimit
        case .sleeping:  return .sleeping
        case .dizzy:     return .dizzy
        }
    }
}

/// Owns one sampler per island character and republishes its readings.
///
/// `LupyVitalsSampler` publishes `vitals`, but `busyStreak` is plain state, so a view
/// observing the sampler would not redraw when only the streak changes. This object
/// forwards both through one `objectWillChange`, so the rig always sees a matched pair.
///
/// Lifecycle is explicit start/stop, not `deinit`: Swift 6 will not let a nonisolated
/// `deinit` touch a `Timer`, and the island already tells us exactly when he is on
/// screen.
@MainActor
final class IslandSampler: ObservableObject {
    let sampler = LupyVitalsSampler()
    private var ticker: Timer?

    func start() {
        sampler.start()
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        sampler.stop()
    }
}

// MARK: - The view

/// LUPY, sized as one piece. `bodyWidth` is the width of the white body; the frame
/// adds room for the glow and the badge, exactly as `LupyComposition` describes, so a
/// 24 pt island avatar and a 400 pt desktop one are the same drawing at two scales.
struct IslandCharacterView: View {
    @ObservedObject var state: AppState
    /// The width the body should occupy, in points.
    var bodyWidth: CGFloat
    /// Pause the render loop when the island is hidden or he is drawn on the desktop.
    var paused: Bool = false
    /// Draw the status label. Off in a pill, where there is no room for its text.
    var showsStatusBubble: Bool = true
    /// Keep the label's left edge inside this distance from the frame's left edge.
    /// The island passes its corner radius, so the rounded corner cannot cut a word.
    var labelInset: CGFloat = 0

    /// Where the label's centre goes.
    ///
    /// Default: hung by its trailing edge off his shoulder, per the sketch. With a
    /// `labelInset` (the island), the label is pushed right just far enough that its
    /// left edge clears the island's rounded corner — but never so far that it covers
    /// his face, which is the worse failure of the two.
    private var bubbleCentreX: CGFloat {
        let free = frame * 0.5
            - bodyWidth * CGFloat(LupyComposition.bubbleTrailingInset)
            - bubbleWidth / 2
        guard labelInset > 0, bubbleWidth > 0 else { return free }
        let clearOfCorner = labelInset + bubbleWidth / 2
        guard clearOfCorner > free else { return free }
        // The furthest right it may sit without crossing the body's centre line.
        let onHim = frame * 0.5 - bubbleWidth / 2
        return min(clearOfCorner, onHim)
    }

    @StateObject private var driver = IslandSampler()
    @State private var bubbleWidth: CGFloat = 0
    @State private var needsYouSince: Date?

    /// The rig state, translated once.
    private var rigState: LupyCharacterState { LupyStateMapping.state(from: state.effectiveState) }

    /// States that are waiting on the founder. Only these may ever grow words.
    private var needsYou: Bool { rigState == .approval || rigState == .question || rigState == .error }

    /// FOUNDER'S ICON-FIRST LAW (2026-10-22): no word label at rest — the face
    /// and its light talk (red = needs you). Only if a needs-you state goes
    /// unanswered this long does the word escalate in. The sampler's 1 Hz
    /// tick re-evaluates the body, so no extra timer exists for this.
    private static let bubbleEscalationDelay: TimeInterval = 15
    private var bubbleDue: Bool {
        guard needsYou, state.mode == .expanded, let since = needsYouSince else { return false }
        return Date().timeIntervalSince(since) >= Self.bubbleEscalationDelay
    }

    /// The frame is larger than the body: 1/unitFraction, so the glow is never clipped
    /// and the badge's reach is inside the view.
    private var frame: CGFloat {
        bodyWidth / CGFloat(LupyComposition.unitFraction)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LupyCanvasView(state: LupyStateMapping.state(from: state.effectiveState),
                           vitals: paused ? nil : driver.sampler.vitals,
                           busySamples: paused ? 0 : driver.sampler.busyStreak)
            // The status bubble is not drawn by the canvas — it is a SwiftUI view, so
            // it has to be placed here, and only when there is room for its text.
            //
            // Placement is passed in, not implied. The island clips the window band to
            // the island's rounded corner, so a label that sits at the frame's left
            // edge gets sliced ("…your OK"). Inside the island band the label has to
            // sit inboard of the character; in a window of his own it can float free.
            if showsStatusBubble && bubbleDue {
                LupyStatusBubble(state: rigState,
                                 bodyWidth: bodyWidth)
                    .fixedSize()
                    .background(GeometryReader { b in
                        Color.clear
                            .onAppear { bubbleWidth = b.size.width }
                            .onChange(of: b.size.width) { _, w in bubbleWidth = w }
                    })
                    .position(
                        x: bubbleCentreX,
                        y: frame * 0.5 - bodyWidth * CGFloat(LupyComposition.bubbleRise)
                    )
            }
        }
            .frame(width: frame, height: frame)
            .opacity(paused ? 0 : 1)
            .onAppear {
                if !paused { driver.start() }
                if needsYou, needsYouSince == nil { needsYouSince = Date() }
            }
            .onChange(of: needsYou) { _, waiting in
                needsYouSince = waiting ? Date() : nil
            }
            .onDisappear { driver.stop() }
            .onChange(of: paused) { _, isPaused in
                if isPaused { driver.stop() } else { driver.start() }
            }
            .accessibilityLabel("Lupy")
            .accessibilityAddTraits(.isImage)
    }
}
