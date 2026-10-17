import SwiftUI

//  LupyCanvasView.swift
//  The character, on screen.
//
//  Rendering: a TimelineView at display refresh rate drives a Canvas that draws the
//  cubic-Bézier silhouette from LupyBody plus the projected eye capsules. No image
//  assets anywhere, so it is crisp at 24 px in the menu bar and at 400 px on the
//  desktop — the same path data.
//
//  Motion: LupyRig is stepped on a fixed 60 Hz clock regardless of the display
//  refresh rate. On a 120 Hz ProMotion panel the character must not animate twice
//  as fast (a real bug in the reference implementation, fixed here by design).
//
//  Input: onContinuousHover in the view's own coordinate space. The rig takes the
//  pointer in points relative to the body centre, y down.

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
}

@MainActor
final class LupyAnimator: ObservableObject {
    private var rig = LupyRig()
    private var clock = LupyFrameClock()
    private var lastTick: Date?
    /// Points per body-width unit for the current view size.
    private(set) var unit: Double = 200

    /// Step the rig and produce the frame to draw.
    ///
    /// Called from the TimelineView body once per display frame. The rig is not
    /// observable on purpose: the timeline already invalidates every frame, and
    /// publishing from inside a draw closure causes SwiftUI update loops.
    func snapshot(at date: Date, size: CGSize) -> LupyFrameSnapshot {
        let dt = lastTick.map { min(date.timeIntervalSince($0), 0.25) } ?? (1.0 / 60.0)
        lastTick = date
        clock.advance(dt: dt) { rig.step(dt: LupyFrameClock.step) }

        let bounds = LupyBody.bounds()
        let fit = min(size.width * 0.94 / bounds.w, size.height * 0.94 / bounds.h)
        unit = max(1, fit)
        rig.bodyWidth = unit

        let scale = rig.bodyScale
        return LupyFrameSnapshot(
            beziers: LupyBody.beziers(),
            eyes: rig.eyes(bodyWidth: 1.0).filter { $0.visible && $0.h * $0.fy * rig.blink.open > 0.0008 },
            scaleX: scale.x,
            scaleY: scale.y,
            blink: rig.blink.open,
            unit: unit,
            centreX: Double(size.width) * 0.5,
            centreY: Double(size.height) * 0.5
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
        context.fill(body, with: .color(.white))

        // MARK: blush
        // A warm blur, clipped to the body so it can never bleed past the silhouette.
        // This is shading, not a body colour: the body stays pure white by brand law.
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

        // MARK: eyes
        // Signature law: solid black, no pupil, no highlight, no gloss. A state may
        // reshape the capsule (lid, dash, arc) but never adds specular detail.
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
                // A wide arc stroked with round caps: the same ink, bent.
                let w = baseW * 1.32
                let bow = unit * 0.052 * (eye.style == .arch ? -1 : 1)
                var arc = Path()
                arc.move(to: CGPoint(x: cx - w * 0.5, y: cy))
                arc.addQuadCurve(to: CGPoint(x: cx + w * 0.5, y: cy),
                                 control: CGPoint(x: cx, y: cy + bow))
                context.stroke(arc, with: .color(.black),
                               style: StrokeStyle(lineWidth: max(1, baseW * 0.46),
                                                  lineCap: .round, lineJoin: .round))
            case .capsule, .wide, .dash, .halfLid:
                let kx: Double = eye.style == .wide ? 1.16 : (eye.style == .dash ? 1.12 : 1.0)
                let ky: Double = eye.style == .wide ? 1.06
                    : (eye.style == .dash ? 0.20 : (eye.style == .halfLid ? 0.40 : 1.0))
                let w = baseW * kx
                let h = baseH * ky
                let rect = CGRect(x: cx - w * 0.5, y: cy - h * 0.5, width: w, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: min(w, h) * 0.5),
                             with: .color(.black))
            }
        }
    }
}

struct LupyCanvasView: View {
    @StateObject private var animator = LupyAnimator()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                // Stepping happens here, not inside the Canvas closure: the closure
                // must stay a pure function of the snapshot it receives.
                let frame = animator.snapshot(at: timeline.date, size: geo.size)
                Canvas { context, _ in
                    LupyRenderer.draw(frame, in: &context)
                }
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point):
                    animator.look(at: point, size: geo.size)
                case .ended:
                    animator.pointerLeft()
                }
            }
            .onAppear { animator.resume() }
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
