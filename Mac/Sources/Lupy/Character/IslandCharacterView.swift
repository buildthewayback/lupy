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
@MainActor
final class IslandSampler: ObservableObject {
    let sampler = LupyVitalsSampler()
    private var cancellable: Any?
    private var ticker: Timer?

    init() {
        // Mirror the sampler's own cadence rather than polling faster than it samples.
        ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }
        ticker?.tolerance = 0.5
        if let ticker { RunLoop.main.add(ticker, forMode: .common) }
    }

    deinit { ticker?.invalidate() }
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

    @StateObject private var driver = IslandSampler()

    /// The frame is larger than the body: 1/unitFraction, so the glow is never clipped
    /// and the badge's reach is inside the view.
    private var frame: CGFloat {
        bodyWidth / CGFloat(LupyComposition.unitFraction)
    }

    var body: some View {
        LupyCanvasView(state: LupyStateMapping.state(from: state.effectiveState),
                       vitals: paused ? nil : driver.sampler.vitals,
                       busySamples: paused ? 0 : driver.sampler.busyStreak)
            .frame(width: frame, height: frame)
            .opacity(paused ? 0 : 1)
            .onAppear { if !paused { driver.sampler.start() } }
            .onDisappear { driver.sampler.stop() }
            .onChange(of: paused) { _, isPaused in
                if isPaused { driver.sampler.stop() } else { driver.sampler.start() }
            }
            .accessibilityLabel("Lupy")
            .accessibilityAddTraits(.isImage)
    }
}
