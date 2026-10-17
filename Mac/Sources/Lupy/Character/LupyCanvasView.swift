import SwiftUI

//  LupyCanvasView.swift
//  The character, on screen — and the thing that decides what he is showing.
//
//  Rendering: a TimelineView at display refresh rate drives a Canvas that draws the
//  cubic-Bézier silhouette from LupyBody, the projected eye capsules and the one
//  small badge. No image assets anywhere, so it is crisp at 24 px in the menu bar
//  and at 400 px on the desktop — the same path data.
//
//  Motion: LupyCharacterDriver steps the rig on a fixed 60 Hz clock regardless of the
//  display refresh rate. On a 120 Hz ProMotion panel the character must not animate
//  twice as fast.
//
//  Meaning: colour, eyes and badge all come from `rig.state`, and the state is derived
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
    var badge: LupyBadge?
    var tintRed: Double
    var tintGreen: Double
    var tintBlue: Double
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

        // Room for the badge, not just the body: see LupyComposition.
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
            badge: state.badge,
            tintRed: tint.r, tintGreen: tint.g, tintBlue: tint.b
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
    static func draw(_ frame: LupyFrameSnapshot, in context: inout GraphicsContext) {
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
        light.addFilter(.blur(radius: max(2, unit * 0.085)))
        light.opacity = 0.46
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
                var spiral = Path()
                var a = 0.0
                var first = true
                while a < 5.4 {
                    let r = unit * (0.010 + 0.0082 * a)
                    let p = CGPoint(x: cx + r * LM.cos(a), y: cy - r * LM.sin(a) * 0.86)
                    if first { spiral.move(to: p); first = false } else { spiral.addLine(to: p) }
                    a += 0.16
                }
                context.stroke(spiral, with: .color(.black),
                               style: StrokeStyle(lineWidth: max(1, unit * 0.013),
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

        // MARK: badge
        if let badge = frame.badge {
            drawBadge(badge, in: &context, frame: frame)
        }
    }

    /// The one small overlay a state gets. Upper-LEFT and fully detached: if it touches
    /// the shoulder it reads as an ear, which is a brand breach (we shipped that once).
    private static func drawBadge(_ badge: LupyBadge,
                                  in context: inout GraphicsContext,
                                  frame: LupyFrameSnapshot) {
        let unit = frame.unit
        let originX = frame.centreX - 0.545 * unit * frame.scaleX
        let originY = frame.centreY - 0.395 * unit * frame.scaleY
        let s = unit * 0.048

        func point(_ dx: Double, _ dy: Double) -> CGPoint {
            CGPoint(x: originX + dx * s, y: originY + dy * s)
        }
        func circle(_ centre: CGPoint, _ r: Double) -> Path {
            Path(ellipseIn: CGRect(x: centre.x - r * s, y: centre.y - r * s,
                                   width: r * s * 2, height: r * s * 2))
        }
        func roundedBox(_ a: CGPoint, _ b: CGPoint, _ radius: Double) -> Path {
            Path(roundedRect: CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                                     width: abs(b.x - a.x), height: abs(b.y - a.y)),
                 cornerRadius: radius * s)
        }

        let ink = Color(red: 26 / 255, green: 20 / 255, blue: 24 / 255)
        let bubble = Color.white

        switch badge {
        case .dots:
            let pw = 3.4, ph = 1.9
            context.fill(roundedBox(point(-pw, -ph), point(pw, ph), ph), with: .color(bubble.opacity(0.92)))
            for i in [-1.0, 0.0, 1.0] {
                context.fill(circle(point(i * 0.95, 0), 0.30), with: .color(ink))
            }

        case .exclamation:
            context.fill(circle(point(0, 0), 1.75), with: .color(bubble.opacity(0.94)))
            context.fill(roundedBox(point(-0.26, -1.05), point(0.26, 0.28), 0.26), with: .color(ink))
            context.fill(circle(point(0, 0.92), 0.30), with: .color(ink))

        case .questionMark:
            context.fill(circle(point(0, 0), 1.75), with: .color(bubble.opacity(0.94)))
            // A drawn hook, not a font glyph: the badge must look the same everywhere.
            var hook = Path()
            var a = -2.55
            var first = true
            while a < 0.80 {
                let p = point(0.62 * LM.cos(a), -0.30 + 0.62 * LM.sin(a))
                if first { hook.move(to: p); first = false } else { hook.addLine(to: p) }
                a += 3.35 / 18
            }
            context.stroke(hook, with: .color(ink),
                           style: StrokeStyle(lineWidth: max(1, 0.42 * s), lineCap: .round,
                                              lineJoin: .round))
            var stem = Path()
            stem.move(to: point(0, 0.02))
            stem.addLine(to: point(0, 0.42))
            context.stroke(stem, with: .color(ink),
                           style: StrokeStyle(lineWidth: max(1, 0.42 * s), lineCap: .round))
            context.fill(circle(point(0, 1.02), 0.22), with: .color(ink))

        case .ring:
            context.stroke(circle(point(0, 0), 0.75), with: .color(ink),
                           style: StrokeStyle(lineWidth: max(1, 0.42 * s)))

        case .dot:
            context.fill(circle(point(0, 0), 0.62), with: .color(ink))

        case .zzz:
            let pale = Color(red: 236 / 255, green: 240 / 255, blue: 248 / 255)
            for (i, k) in [(1.0, 1.0), (1.55, 1.55)] {
                let dx = i * 1.5
                let dy = -i * 1.15
                let z = 0.85 * k
                var path = Path()
                path.move(to: point(dx - z / 2, dy - z / 2))
                path.addLine(to: point(dx + z / 2, dy - z / 2))
                path.addLine(to: point(dx - z / 2, dy + z / 2))
                path.addLine(to: point(dx + z / 2, dy + z / 2))
                context.stroke(path, with: .color(pale),
                               style: StrokeStyle(lineWidth: max(1, 0.30 * s),
                                                  lineCap: .round, lineJoin: .round))
            }
        }
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
                    LupyRenderer.draw(frame, in: &context)
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
