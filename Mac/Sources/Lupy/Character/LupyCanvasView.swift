import SwiftUI

//  LupyCanvasView.swift
//  The character, on screen — and the thing that decides what he is showing.
//
//  Rendering: a TimelineView at display refresh rate drives a Canvas that draws the
//  cubic-Bézier silhouette from LupyBody, the projected eye capsules and the one
//  status bubble. No image assets anywhere, so it is crisp at 24 px in the menu bar
//  and at 400 px on the desktop — the same path data.
//
//  Motion: LupyCharacterDriver steps the rig on a fixed 60 Hz clock regardless of the
//  display refresh rate. On a 120 Hz ProMotion panel the character must not animate
//  twice as fast.
//
//  Meaning: colour, eyes and light all come from `rig.state`, and the state is derived
//  from what the task asked for *and* what the machine is doing. A memory-critical Mac
//  makes Lupy dizzy; it cannot make him quiet.

/// One frame of drawable state. A value type, so the Canvas renderer captures only
/// immutable data and nothing can mutate underneath it mid-draw.
struct LupyFrameSnapshot: Sendable {
    var beziers: [LupyBezier]
    var eyes: [LupyEyeFrame]
    var scaleX: Double
    var scaleY: Double
    var blink: Double
    var unit: Double        // points per body-width unit
    var centreX: Double
    var centreY: Double
    var bodyRed: Double
    var bodyGreen: Double
    var bodyBlue: Double
    var tintRed: Double
    var tintGreen: Double
    var tintBlue: Double
    var glowStrength: Double
    /// Radians the dizzy spiral has turned. Coucou spins it; a still spiral reads dead.
    var spiralPhase: Double
}

@MainActor
final class LupyCharacterDriver: ObservableObject {
    private var rig = LupyRig()
    private var clock = LupyFrameClock()
    private var lastTick: Date?
    /// Points per body-width unit for the current view size.
    private(set) var unit: Double = 200

    var state: LupyCharacterState { rig.state }
    var label: String { rig.state.bubbleText }
    var mood: LupyMood { rig.mood }

    /// What the task wants shown. The machine can override this with memory pressure.
    func set(state: LupyCharacterState) {
        rig.requestedState = state
    }

    /// A real system reading, at most every three seconds.
    func apply(vitals: LupyVitals, busySamples: Int) {
        rig.apply(vitals: vitals, busySamples: busySamples)
    }

    /// Step the rig and produce the frame to draw.
    ///
    /// Called from the TimelineView body once per display frame. The rig is not
    /// observable on purpose: the timeline already invalidates every frame, and
    /// publishing from inside a draw closure causes SwiftUI update loops.
    func snapshot(at date: Date, size: CGSize) -> LupyFrameSnapshot {
        let dt = lastTick.map { min(date.timeIntervalSince($0), 0.25) } ?? (1.0 / 60.0)
        lastTick = date
        clock.advance(dt: dt) { rig.step(dt: LupyFrameClock.step) }

        // Room for the light, not just the body: see LupyComposition.
        unit = max(1, LupyComposition.unit(width: Double(size.width),
                                           height: Double(size.height)))
        rig.bodyWidth = unit

        let scale = rig.bodyScale
        let state = rig.state
        let body = state.bodyColour
        let tint = state.tint

        return LupyFrameSnapshot(
            beziers: LupyBody.beziers(),
            eyes: rig.eyes(bodyWidth: 1.0).filter {
                $0.visible && $0.h * $0.fy * rig.drawnBlinkOpen > 0.0008
            },
            scaleX: scale.x,
            scaleY: scale.y,
            blink: rig.drawnBlinkOpen,
            unit: unit,
            centreX: Double(size.width) * 0.5,
            centreY: Double(size.height) * 0.5,
            bodyRed: body.r, bodyGreen: body.g, bodyBlue: body.b,
            tintRed: tint.r, tintGreen: tint.g, tintBlue: tint.b,
            glowStrength: state.glowStrength,
            spiralPhase: rig.time * LupyEyeStyle.spiral.spiralSpin
        )
    }

    /// Pointer in the view's coordinate space (y down).
    func look(at point: CGPoint, size: CGSize) {
        rig.movePointer(to: Double(point.x - size.width * 0.5),
                        Double(point.y - size.height * 0.5))
    }

    func pointerLeft() {
        rig.pointerLeft()
    }

    /// Reset the clock when the view appears, so the first frame cannot see a huge dt.
    func resume() {
        lastTick = nil
    }
}

enum LupyRenderer {
    static func draw(_ frame: LupyFrameSnapshot,
                     state drawnState: LupyCharacterState? = nil,
                     in context: inout GraphicsContext) {
        let unit = frame.unit

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: frame.centreX + x * unit * frame.scaleX,
                    y: frame.centreY - y * unit * frame.scaleY)
        }

        // MARK: body
        var body = Path()
        if let first = frame.beziers.first {
            body.move(to: point(first.x0, first.y0))
            for seg in frame.beziers {
                body.addCurve(to: point(seg.x3, seg.y3),
                              control1: point(seg.x1, seg.y1),
                              control2: point(seg.x2, seg.y2))
            }
            body.closeSubpath()
        }
        let bodyColour = Color(red: frame.bodyRed, green: frame.bodyGreen, blue: frame.bodyBlue)

        // MARK: light
        // The light is the state's colour, drawn behind the body and blurred into the
        // background. It hugs the silhouette — never an offset shadow, never a halo blob.
        var light = context
        light.addFilter(.blur(radius: max(2, unit * LupyComposition.glowBlur)))
        light.opacity = frame.glowStrength
        light.fill(body, with: .color(Color(red: frame.tintRed,
                                            green: frame.tintGreen,
                                            blue: frame.tintBlue)))
        context.fill(body, with: .color(bodyColour))

        // MARK: blush
        // Warm shading, clipped to the body so it can never bleed past the silhouette.
        // Only while the body is close to white; on a coloured body it would muddy the
        // state's colour, and the colour is the message.
        let whiteness = (frame.bodyRed + frame.bodyGreen + frame.bodyBlue) / 3
        if whiteness > 0.86 {
            let blushY = LupyGeometry.blushYFromBase - LupyGeometry.bodyAspect * 0.5
            let rx = LupyGeometry.blushRX * unit * frame.scaleX
            let ry = LupyGeometry.blushRY * unit * frame.scaleY
            var glow = context
            glow.clip(to: body)
            glow.addFilter(.blur(radius: max(0.5, unit * 0.022)))
            for side in [-1.0, 1.0] {
                let cx = side * LupyGeometry.blushX
                let cy = blushY
                let rect = CGRect(x: frame.centreX + cx * unit * frame.scaleX - rx,
                                  y: frame.centreY - cy * unit * frame.scaleY - ry,
                                  width: rx * 2, height: ry * 2)
                glow.fill(Path(ellipseIn: rect),
                          with: .color(Color(red: LupyGeometry.blushColour.r,
                                             green: LupyGeometry.blushColour.g,
                                             blue: LupyGeometry.blushColour.b)
                            .opacity(LupyGeometry.blushOpacity)))
            }
        }

        // MARK: eyes
        // Signature law: solid black, no pupil, no highlight, no gloss. A state may
        // reshape the capsule (lid, dash, arc, spiral) but never adds specular detail.
        for eye in frame.eyes {
            let baseW = eye.w * eye.fx * unit * frame.scaleX
            let baseH = eye.h * eye.fy * frame.blink * unit * frame.scaleY
            let cx = frame.centreX + eye.x * unit * frame.scaleX
            let cy = frame.centreY - eye.y * unit * frame.scaleY

            switch eye.style {
            case .spiral:
                // A thick, turning spiral: same ink mass as the capsule eyes, so the
                // dizzy character is still visibly the same character.
                var spiral = Path()
                var a = 0.0
                var first = true
                let centres = (x: frame.centreX + eye.x * unit * frame.scaleX,
                               y: frame.centreY - eye.y * unit * frame.scaleY)
                while a < LupyEyeStyle.spiralTurns {
                    let pt = LupyEyeStyle.spiralPoint(a + frame.spiralPhase,
                                                      centreX: centres.x,
                                                      centreY: centres.y,
                                                      unit: unit)
                    let p = CGPoint(x: pt.x, y: pt.y)
                    if first { spiral.move(to: p); first = false } else { spiral.addLine(to: p) }
                    a += 0.10
                }
                context.stroke(spiral, with: .color(.black),
                               style: StrokeStyle(
                                   lineWidth: max(1, baseW * LupyEyeStyle.spiral.spiralStroke),
                                   lineCap: .round, lineJoin: .round))
            case .arch, .cup:
                // A wide arc stroked with round caps: the same ink, bent. The span and
                // the bow come from the kernel, so the app and the sheet cannot drift.
                let w = baseW * LupyEyeStyle.arch.arcSpan
                let bow = unit * LupyEyeStyle.arch.arcBow * (eye.style == .arch ? -1 : 1)
                var arc = Path()
                arc.move(to: CGPoint(x: cx - w * 0.5, y: cy))
                arc.addQuadCurve(to: CGPoint(x: cx + w * 0.5, y: cy),
                                 control: CGPoint(x: cx, y: cy + bow))
                context.stroke(arc, with: .color(.black),
                               style: StrokeStyle(lineWidth: max(1, baseW * LupyEyeStyle.arch.arcStroke),
                                                  lineCap: .round, lineJoin: .round))
            case .capsule, .wide, .dash, .halfLid:
                let k = eye.style.capsuleScale
                let w = baseW * k.x
                let h = baseH * k.y
                let rect = CGRect(x: cx - w * 0.5, y: cy - h * 0.5, width: w, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: min(w, h) * 0.5),
                             with: .color(.black))
            }
        }

        // MARK: state badge
        // Pinned to the character's right edge, half on him and half off: a dark ring
        // separates the bright disc from the white body, and this state's own glyph
        // sits inside it.
        if let drawnState, let icon = drawnState.icon {
            drawBadge(icon, state: drawnState, in: &context, frame: frame)
        }
    }

    /// The badge: dark ring, coloured disc, glyph.
    private static func drawBadge(_ icon: LupyStateIcon,
                                  state: LupyCharacterState,
                                  in context: inout GraphicsContext,
                                  frame: LupyFrameSnapshot) {
        let unit = frame.unit
        let centre = CGPoint(
            x: frame.centreX + LupyComposition.badgeCentreX * unit * frame.scaleX,
            y: frame.centreY - LupyComposition.badgeCentreY * unit * frame.scaleY
        )
        let r = LupyComposition.badgeRadius * unit
        let ring = LupyBadgeStyle.ringWidth * unit
        let tint = state.tint
        let colour = Color(red: tint.r, green: tint.g, blue: tint.b)

        let outer = Path(ellipseIn: CGRect(x: centre.x - r - ring, y: centre.y - r - ring,
                                           width: (r + ring) * 2, height: (r + ring) * 2))
        context.fill(outer, with: .color(Color(red: LupyBadgeStyle.ringColour.r,
                                              green: LupyBadgeStyle.ringColour.g,
                                              blue: LupyBadgeStyle.ringColour.b)))
        let inner = Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r,
                                           width: r * 2, height: r * 2))
        context.fill(inner, with: .color(colour))

        // The glyph, at 62 % of the disc, stroked in the ink that can be read on this
        // colour. Built at its final rect rather than translated, so its stroke weight
        // never depends on the transform.
        let glyphSize = r * 2 * 0.62
        let glyphRect = CGRect(x: centre.x - glyphSize / 2,
                               y: centre.y - glyphSize / 2,
                               width: glyphSize, height: glyphSize)
        let glyph = LupyStateIconShape(icon: icon).path(in: glyphRect)
        let ink: Color = state.iconInkIsDark ? .black : .white
        context.stroke(glyph, with: .color(ink),
                       style: StrokeStyle(lineWidth: glyphSize * 0.115,
                                          lineCap: .round, lineJoin: .round))
    }
}

struct LupyCanvasView: View {
    /// What the task wants the character to show.
    var state: LupyCharacterState = .idle
    /// Real system readings, or nil when nothing is sampling.
    var vitals: LupyVitals? = nil
    /// Consecutive busy samples, so one spike cannot make him panic.
    var busySamples: Int = 0

    @StateObject private var driver = LupyCharacterDriver()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                // Stepping happens here, not inside the Canvas closure: the closure
                // must stay a pure function of the snapshot it receives.
                let frame = driver.snapshot(at: timeline.date, size: geo.size)
                Canvas { context, _ in
                    LupyRenderer.draw(frame, state: driver.state, in: &context)
                }
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point):
                    driver.look(at: point, size: geo.size)
                case .ended:
                    driver.pointerLeft()
                }
            }
            .onAppear {
                driver.resume()
                driver.set(state: state)
                if let vitals { driver.apply(vitals: vitals, busySamples: busySamples) }
            }
            .onChange(of: state) { _, new in driver.set(state: new) }
            .onChange(of: vitals) { _, new in
                if let new { driver.apply(vitals: new, busySamples: busySamples) }
            }
        }
        .accessibilityLabel("Lupy")
        .accessibilityAddTraits(.isImage)
    }
}

#if DEBUG
#Preview("Lupy — idle") {
    LupyCanvasView()
        .frame(width: 320, height: 300)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
}
#endif
