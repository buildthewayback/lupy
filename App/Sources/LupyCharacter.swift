// Lupy macOS shell — Lupy, an ORIGINAL character (a small wolf pup) drawn in code.
// Technique (TimelineView-driven Canvas, paused when not animating) follows Coucou's MIT code
// pattern in App/BotCanvasView.swift; the character design is new and is not Coucou's Mochi.

import SwiftUI

enum LupyMood: String, CaseIterable {
    case idle, thinking, working, needsYou, happy, worried, sleeping

    var label: String {
        switch self {
        case .idle: return "relaxed"
        case .thinking: return "thinking"
        case .working: return "working"
        case .needsYou: return "waiting for you"
        case .happy: return "happy"
        case .worried: return "worried"
        case .sleeping: return "paused"
        }
    }
}

struct LupyCharacterView: View {
    var mood: LupyMood
    var size: CGFloat
    var animated: Bool = true
    var fps: Double = 24

    var body: some View {
        // Calm moods only need a slow tick (blinks, gentle bob); active moods get the requested rate.
        let rate = (mood == .idle || mood == .sleeping || mood == .happy) ? min(fps, 4) : fps
        TimelineView(.animation(minimumInterval: 1.0 / rate, paused: !animated)) { timeline in
            let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 1.0
            Canvas { context, canvasSize in
                LupyRenderer.draw(context, size: canvasSize, mood: mood, t: t)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text("Lupy is \(mood.label)"))
    }
}

enum LupyRenderer {
    static let fur = Color(hex: "#AEBBCC")
    static let furDark = Color(hex: "#76859B")
    static let muzzleColor = Color(hex: "#EEF1F5")
    static let innerEar = Color(hex: "#F3B27A")
    static let eyeColor = Color(hex: "#1B1E24")
    static let noseColor = Color(hex: "#2A2E36")
    static let moon = Color(hex: "#FFB547")

    static func blinkAmount(_ t: Double) -> CGFloat {
        let period = 4.3
        let phase = t.truncatingRemainder(dividingBy: period)
        return phase < 0.15 ? CGFloat(sin(phase / 0.15 * Double.pi)) : 0
    }

    static func draw(_ context: GraphicsContext, size: CGSize, mood: LupyMood, t: Double) {
        let s = min(size.width, size.height)
        let speed: Double = mood == .working ? 5 : (mood == .sleeping ? 0.7 : 1.7)
        let bob = CGFloat(sin(t * speed)) * s * (mood == .sleeping ? 0.008 : 0.016)
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + s * 0.09 + bob)
        let r = s * 0.29
        var g = context
        var tilt: Double = 0
        if mood == .thinking { tilt = -7 }
        if mood == .worried { tilt = sin(t * 11) * 2.5 }
        if mood == .happy { tilt = sin(t * 3) * 4 }
        if tilt != 0 {
            g.translateBy(x: c.x, y: c.y)
            g.rotate(by: .degrees(tilt))
            g.translateBy(x: -c.x, y: -c.y)
        }

        // Ears (pointed, perk up when Lupy needs you, droop when paused)
        let earLift: CGFloat = mood == .needsYou ? -s * 0.035 : (mood == .sleeping ? s * 0.035 : 0)
        for side in [CGFloat(-1), CGFloat(1)] {
            let base = CGPoint(x: c.x + side * r * 0.62, y: c.y - r * 0.6)
            var ear = Path()
            ear.move(to: CGPoint(x: base.x - side * r * 0.44, y: base.y + r * 0.14))
            ear.addQuadCurve(to: CGPoint(x: base.x + side * r * 0.2, y: base.y - r * 0.82 + earLift),
                             control: CGPoint(x: base.x - side * r * 0.26, y: base.y - r * 0.56 + earLift))
            ear.addQuadCurve(to: CGPoint(x: base.x + side * r * 0.44, y: base.y + r * 0.22),
                             control: CGPoint(x: base.x + side * r * 0.46, y: base.y - r * 0.36))
            ear.closeSubpath()
            g.fill(ear, with: .color(furDark))
            var inner = Path()
            inner.move(to: CGPoint(x: base.x - side * r * 0.22, y: base.y + r * 0.04))
            inner.addQuadCurve(to: CGPoint(x: base.x + side * r * 0.15, y: base.y - r * 0.56 + earLift),
                               control: CGPoint(x: base.x - side * r * 0.12, y: base.y - r * 0.4 + earLift))
            inner.addQuadCurve(to: CGPoint(x: base.x + side * r * 0.27, y: base.y + r * 0.1),
                               control: CGPoint(x: base.x + side * r * 0.29, y: base.y - r * 0.26))
            inner.closeSubpath()
            g.fill(inner, with: .color(innerEar.opacity(0.85)))
        }

        // Head with cheek tufts
        let headRect = CGRect(x: c.x - r * 1.08, y: c.y - r * 0.95, width: r * 2.16, height: r * 1.9)
        for side in [CGFloat(-1), CGFloat(1)] {
            var tuft = Path()
            tuft.move(to: CGPoint(x: c.x + side * r * 0.95, y: c.y - r * 0.02))
            tuft.addLine(to: CGPoint(x: c.x + side * r * 1.24, y: c.y + r * 0.34))
            tuft.addLine(to: CGPoint(x: c.x + side * r * 0.86, y: c.y + r * 0.46))
            tuft.closeSubpath()
            g.fill(tuft, with: .color(furDark))
        }
        g.fill(Path(ellipseIn: headRect), with: .linearGradient(Gradient(colors: [fur, furDark]),
                                                               startPoint: CGPoint(x: c.x, y: headRect.minY),
                                                               endPoint: CGPoint(x: c.x, y: headRect.maxY)))
        // Forehead marking
        var stripe = Path()
        stripe.move(to: CGPoint(x: c.x, y: c.y - r * 0.92))
        stripe.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r * 0.2), control: CGPoint(x: c.x - r * 0.13, y: c.y - r * 0.52))
        stripe.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r * 0.92), control: CGPoint(x: c.x + r * 0.13, y: c.y - r * 0.52))
        g.fill(stripe, with: .color(muzzleColor.opacity(0.5)))
        // Muzzle
        g.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.56, y: c.y + r * 0.02, width: r * 1.12, height: r * 0.78)), with: .color(muzzleColor))

        // Eyes
        let eyeY = c.y - r * 0.17
        let blink = blinkAmount(t)
        let line = max(1, r * 0.075)
        for side in [CGFloat(-1), CGFloat(1)] {
            let ec = CGPoint(x: c.x + side * r * 0.42, y: eyeY)
            switch mood {
            case .happy:
                var p = Path()
                p.addArc(center: CGPoint(x: ec.x, y: ec.y + r * 0.07), radius: r * 0.13, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                g.stroke(p, with: .color(eyeColor), style: StrokeStyle(lineWidth: line, lineCap: .round))
            case .sleeping:
                var p = Path()
                p.move(to: CGPoint(x: ec.x - r * 0.12, y: ec.y + r * 0.02))
                p.addQuadCurve(to: CGPoint(x: ec.x + r * 0.12, y: ec.y + r * 0.02), control: CGPoint(x: ec.x, y: ec.y + r * 0.1))
                g.stroke(p, with: .color(eyeColor), style: StrokeStyle(lineWidth: line, lineCap: .round))
            default:
                let open = max(0.1, 1 - blink)
                let w = r * (mood == .needsYou ? 0.25 : 0.21)
                let h = r * (mood == .needsYou ? 0.31 : 0.27) * open
                let look = mood == .thinking ? CGPoint(x: r * 0.06, y: -r * 0.07) : CGPoint.zero
                let rect = CGRect(x: ec.x - w / 2 + look.x, y: ec.y - h / 2 + look.y, width: w, height: h)
                g.fill(Path(ellipseIn: rect), with: .color(eyeColor))
                if open > 0.6 {
                    let hl = r * 0.07
                    g.fill(Path(ellipseIn: CGRect(x: rect.midX + w * 0.06, y: rect.minY + h * 0.14, width: hl, height: hl)), with: .color(.white.opacity(0.9)))
                }
                if mood == .worried {
                    var brow = Path()
                    brow.move(to: CGPoint(x: ec.x - side * r * 0.16, y: ec.y - r * 0.24))
                    brow.addLine(to: CGPoint(x: ec.x + side * r * 0.12, y: ec.y - r * 0.3))
                    g.stroke(brow, with: .color(eyeColor), style: StrokeStyle(lineWidth: line * 0.8, lineCap: .round))
                }
            }
        }

        // Nose
        let ny = c.y + r * 0.2
        var nose = Path()
        nose.move(to: CGPoint(x: c.x - r * 0.15, y: ny))
        nose.addQuadCurve(to: CGPoint(x: c.x + r * 0.15, y: ny), control: CGPoint(x: c.x, y: ny - r * 0.09))
        nose.addQuadCurve(to: CGPoint(x: c.x - r * 0.15, y: ny), control: CGPoint(x: c.x, y: ny + r * 0.22))
        nose.closeSubpath()
        g.fill(nose, with: .color(noseColor))

        // Mouth
        let my = ny + r * 0.16
        var mouth = Path()
        switch mood {
        case .needsYou:
            g.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.07, y: my - r * 0.01, width: r * 0.14, height: r * 0.16)), with: .color(noseColor))
        case .worried:
            mouth.move(to: CGPoint(x: c.x - r * 0.14, y: my + r * 0.08))
            mouth.addQuadCurve(to: CGPoint(x: c.x + r * 0.14, y: my + r * 0.08), control: CGPoint(x: c.x, y: my - r * 0.02))
            g.stroke(mouth, with: .color(noseColor), style: StrokeStyle(lineWidth: line * 0.8, lineCap: .round))
        default:
            let smile: CGFloat = mood == .happy ? 0.16 : 0.09
            mouth.move(to: CGPoint(x: c.x - r * 0.2, y: my))
            mouth.addQuadCurve(to: CGPoint(x: c.x, y: my), control: CGPoint(x: c.x - r * 0.1, y: my + r * smile))
            mouth.addQuadCurve(to: CGPoint(x: c.x + r * 0.2, y: my), control: CGPoint(x: c.x + r * 0.1, y: my + r * smile))
            g.stroke(mouth, with: .color(noseColor), style: StrokeStyle(lineWidth: line * 0.8, lineCap: .round))
        }

        // Mood extras (drawn without tilt)
        let e = context
        switch mood {
        case .needsYou:
            let pulse = 1 + CGFloat(sin(t * 5)) * 0.08
            let d = s * 0.22 * pulse
            let bc = CGPoint(x: c.x + r * 1.05, y: c.y - r * 1.05)
            e.fill(Path(ellipseIn: CGRect(x: bc.x - d / 2, y: bc.y - d / 2, width: d, height: d)), with: .color(moon))
            e.draw(Text("!").font(.system(size: d * 0.7, weight: .black)).foregroundColor(Color(hex: "#1A1206")), at: bc)
        case .sleeping:
            for i in 0..<2 {
                let phase = (t * 0.6 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let p = CGPoint(x: c.x + r * (0.95 + CGFloat(phase) * 0.35), y: c.y - r * (0.75 + CGFloat(phase) * 0.6))
                e.draw(Text("z").font(.system(size: s * (0.1 + 0.05 * CGFloat(i)), weight: .bold)).foregroundColor(moon.opacity(1 - phase)), at: p)
            }
        case .thinking:
            for i in 0..<3 {
                let on = Int(t * 3) % 3 >= i
                let p = CGPoint(x: c.x + r * (0.85 + CGFloat(i) * 0.22), y: c.y - r * 1.15)
                let d = s * 0.05
                e.fill(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)), with: .color(moon.opacity(on ? 0.95 : 0.25)))
            }
        case .working:
            let a = t * 2.4
            let p = CGPoint(x: c.x + CGFloat(cos(a)) * r * 1.25, y: c.y - r * 0.2 + CGFloat(sin(a)) * r * 0.9)
            let d = s * 0.06
            e.fill(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)), with: .color(moon))
        case .worried:
            let p = CGPoint(x: c.x + r * 1.1, y: c.y - r * 0.55)
            var drop = Path()
            drop.move(to: CGPoint(x: p.x, y: p.y - s * 0.06))
            drop.addQuadCurve(to: CGPoint(x: p.x, y: p.y + s * 0.04), control: CGPoint(x: p.x + s * 0.06, y: p.y + s * 0.02))
            drop.addQuadCurve(to: CGPoint(x: p.x, y: p.y - s * 0.06), control: CGPoint(x: p.x - s * 0.06, y: p.y + s * 0.02))
            e.fill(drop, with: .color(Color(hex: "#22D3EE").opacity(0.85)))
        case .happy:
            for i in 0..<2 {
                let tw = CGFloat(abs(sin(t * 3 + Double(i))))
                let p = CGPoint(x: c.x + (i == 0 ? -1 : 1) * r * 1.2, y: c.y - r * (0.9 - CGFloat(i) * 0.3))
                let d = s * 0.05 * (0.6 + tw)
                e.fill(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)), with: .color(moon.opacity(0.9)))
            }
        case .idle:
            break
        }
    }
}
