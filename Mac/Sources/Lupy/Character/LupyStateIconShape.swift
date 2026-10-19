import SwiftUI

//  Every state's glyph, as vector paths.
//
//  Drawn on a unit square and stroke-only, so the gear, bulb, magnifier, bell, ?, !,
//  check, clock, Z, spiral and standby ring all land on the same optical weight — and
//  so the badge on the character and the one in the offline sheet are the same drawing.
//
//  `canvasBadge` in LupyCanvasView renders this into the character's edge badge; the
//  status bubble no longer repeats it (the badge on the body is the state's icon).

struct LupyStateIconShape: Shape {
    var icon: LupyStateIcon

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let cx = rect.midX, cy = rect.midY
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: cx + x * s, y: cy + y * s)
        }
        var path = Path()

        switch icon {
        case .standby:
            path.addEllipse(in: CGRect(x: cx - s * 0.26, y: cy - s * 0.26,
                                       width: s * 0.52, height: s * 0.52))

        case .gear:
            for i in 0..<8 {
                let a = Double(i) * .pi / 4
                path.move(to: p(cos(a) * 0.30, sin(a) * 0.30))
                path.addLine(to: p(cos(a) * 0.44, sin(a) * 0.44))
            }
            path.addEllipse(in: CGRect(x: cx - s * 0.24, y: cy - s * 0.24,
                                       width: s * 0.48, height: s * 0.48))

        case .bulb:
            path.addArc(center: p(0, -0.06), radius: s * 0.34,
                        startAngle: .degrees(155), endAngle: .degrees(385),
                        clockwise: false)
            path.move(to: p(-0.11, 0.20))
            path.addLine(to: p(-0.11, 0.30))
            path.move(to: p(0.11, 0.20))
            path.addLine(to: p(0.11, 0.30))
            path.move(to: p(-0.19, 0.44))
            path.addLine(to: p(0.19, 0.44))

        case .magnifier:
            path.addEllipse(in: CGRect(x: cx - s * 0.40, y: cy - s * 0.40,
                                       width: s * 0.60, height: s * 0.60))
            path.move(to: p(0.08, 0.08))
            path.addLine(to: p(0.40, 0.40))

        case .bell:
            path.move(to: p(-0.38, 0.16))
            path.addLine(to: p(-0.27, -0.20))
            path.addLine(to: p(0, -0.40))
            path.addLine(to: p(0.27, -0.20))
            path.addLine(to: p(0.38, 0.16))
            path.addLine(to: p(-0.38, 0.16))
            path.move(to: p(0, 0.16))
            path.addLine(to: p(0, 0.30))
            path.move(to: p(-0.13, 0.38))
            path.addLine(to: p(0.13, 0.38))

        case .question:
            path.move(to: p(-0.19, -0.14))
            path.addLine(to: p(-0.10, -0.34))
            path.addLine(to: p(0.12, -0.38))
            path.addLine(to: p(0.23, -0.22))
            path.addLine(to: p(0.16, -0.04))
            path.addLine(to: p(0, 0.08))
            path.move(to: p(0, 0.30))
            path.addLine(to: p(0, 0.31))

        case .exclamation:
            path.move(to: p(0, -0.38))
            path.addLine(to: p(0, 0.14))
            path.move(to: p(0, 0.32))
            path.addLine(to: p(0, 0.33))

        case .check:
            path.move(to: p(-0.36, 0.02))
            path.addLine(to: p(-0.10, 0.28))
            path.addLine(to: p(0.38, -0.28))

        case .clock:
            path.addEllipse(in: CGRect(x: cx - s * 0.38, y: cy - s * 0.38,
                                       width: s * 0.76, height: s * 0.76))
            path.move(to: p(0, -0.21))
            path.addLine(to: p(0, 0))
            path.addLine(to: p(0.17, 0.11))

        case .zzz:
            path.move(to: p(-0.40, 0.36))
            path.addLine(to: p(0.04, 0.36))
            path.addLine(to: p(-0.40, 0.04))
            path.addLine(to: p(0.04, 0.04))
            path.move(to: p(0.08, -0.40))
            path.addLine(to: p(0.36, -0.40))
            path.addLine(to: p(0.08, -0.16))
            path.addLine(to: p(0.36, -0.16))

        case .spiral:
            var a = 0.0
            var first = true
            while a < LupyEyeStyle.spiralTurns {
                let r = 0.055 + 0.085 * a
                let point = p(cos(a) * r, sin(a) * r)
                if first { path.move(to: point); first = false }
                else { path.addLine(to: point) }
                a += 0.25
            }
        }
        return path
    }
}
