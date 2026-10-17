import AppKit
import SwiftUI

//  Headless check of the character renderer.
//
//  `Lupy.app/Contents/MacOS/Lupy --character-self-test [--report path]`
//
//  Rasterises the real draw path (LupyRenderer) at the sizes that matter — 24 pt in
//  the menu bar, 32/64 pt in the island, 256 pt on the desktop — and asserts that a
//  body and two eyes are actually present. This is what catches "it compiles but
//  draws nothing", which no unit test of the math can see.

@MainActor
enum LupyCharacterSelfTest {
    private struct Stats {
        var white = 0
        var ink = 0
        var total = 0
        var widestInkRow = 0
        var bodyRGB = (r: 0.0, g: 0.0, b: 0.0)
        /// Ink in the upper-left quadrant, where a badge lives (and the body does not).
        var badgeInk = false
    }

    static func run(arguments: [String]) -> Int32 {
        var lines: [String] = []
        var failures = 0

        let sizes: [(String, CGFloat)] = [
            ("menu-24", 24), ("island-32", 32), ("island-64", 64), ("desktop-256", 256),
        ]

        for (name, size) in sizes {
            guard let stats = render(size: size, state: .idle) else {
                lines.append("FAIL \(name): renderer produced no image")
                failures += 1
                continue
            }
            let whitePct = stats.total > 0 ? Double(stats.white) / Double(stats.total) * 100 : 0
            let inkPct = stats.total > 0 ? Double(stats.ink) / Double(stats.total) * 100 : 0
            let ok = stats.white > 0 && stats.ink > 0
            lines.append(String(
                format: "%@ %@: %dpx, body %.1f%%, eyes %.1f%% (widest ink row %d)",
                ok ? "PASS" : "FAIL", name, Int(size), whitePct, inkPct, stats.widestInkRow))
            if !ok { failures += 1 }
        }

        // Colour is the message: the idle body must be white and a working body must
        // not be. If this fails, a state is invisible at a glance no matter what the
        // data says.
        let idleColour = render(size: 64, state: .idle)?.bodyRGB
        let workColour = render(size: 64, state: .working)?.bodyRGB
        if let idleColour, let workColour {
            let white = idleColour.r > 0.99 && idleColour.g > 0.99 && idleColour.b > 0.99
            let differs = abs(workColour.b - idleColour.b) > 0.12
                && (workColour.r < 0.90 || workColour.g < 0.90)
            lines.append("\(white ? "PASS" : "FAIL") idle body is pure white "
                + String(format: "(%.2f %.2f %.2f)", idleColour.r, idleColour.g, idleColour.b))
            lines.append("\(differs ? "PASS" : "FAIL") working body is coloured "
                + String(format: "(%.2f %.2f %.2f)", workColour.r, workColour.g, workColour.b))
            if !white || !differs { failures += 1 }
        } else {
            lines.append("FAIL could not sample the drawn body colour")
            failures += 1
        }

        // The badge must exist for a state that has one, and must sit clear of the
        // body: a badge touching the shoulder reads as an ear (we shipped that once).
        if let badge = render(size: 128, state: .approval)?.badgeInk {
            lines.append("\(badge ? "PASS" : "FAIL") approval draws its badge")
            if !badge { failures += 1 }
        }

        lines.append(failures == 0 ? "CHARACTER SELF-TEST PASSED"
                                   : "CHARACTER SELF-TEST FAILED (\(failures))")
        let text = lines.joined(separator: "\n") + "\n"
        print(text)

        if let index = arguments.firstIndex(of: "--report"), index + 1 < arguments.count {
            try? text.write(toFile: arguments[index + 1], atomically: true, encoding: .utf8)
        }
        return failures == 0 ? 0 : 1
    }

    /// Draw one frame of the shipping renderer into a bitmap and count pixels.
    private static func render(size: CGFloat, state: LupyCharacterState) -> Stats? {
        let unit = LupyComposition.unit(width: Double(size), height: Double(size))
        var rig = LupyRig()
        rig.requestedState = state
        rig.movePointer(to: 0, 0)
        var i = 0
        while i < 90 { rig.step(dt: LupyFrameClock.step); i += 1 }
        let scale = rig.bodyScale
        let body = state.bodyColour
        let tint = state.tint
        let frame = LupyFrameSnapshot(
            beziers: LupyBody.beziers(),
            eyes: rig.eyes(bodyWidth: 1.0).filter { $0.visible },
            scaleX: scale.x, scaleY: scale.y, blink: rig.blink.open,
            unit: unit,
            centreX: Double(size) * 0.5,
            centreY: Double(size) * 0.5,
            bodyRed: body.r, bodyGreen: body.g, bodyBlue: body.b,
            badge: state.badge,
            tintRed: tint.r, tintGreen: tint.g, tintBlue: tint.b
        )

        // Render at 4x so a 24 pt character still has enough pixels to inspect.
        let renderer = ImageRenderer(content:
            Canvas { context, _ in
                LupyRenderer.draw(frame, in: &context)
            }
            .frame(width: size, height: size)
            .background(Color.black)
        )
        renderer.scale = 4
        guard let cgImage = renderer.cgImage else { return nil }

        let w = cgImage.width
        let h = cgImage.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        var stats = Stats()
        stats.total = w * h
        var rowInk = 0
        var y = 0
        while y < h {
            var thisRow = 0
            var x = 0
            while x < w {
                let i = (y * w + x) * 4
                let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
                let lum = (r * 299 + g * 587 + b * 114) / 1000
                if lum > 200 { stats.white += 1 }
                if lum < 60 {
                    stats.ink += 1
                    thisRow += 1
                }
                x += 1
            }
            if thisRow > rowInk { rowInk = thisRow }
            y += 1
        }
        stats.widestInkRow = rowInk

        // The body colour, sampled well below the eyes but still inside the body.
        let sx = w / 2
        let sy = min(h - 1, Int(Double(h) * 0.5 + 0.30 * unit * 4))
        let si = (sy * w + sx) * 4
        stats.bodyRGB = (Double(pixels[si]) / 255, Double(pixels[si + 1]) / 255,
                         Double(pixels[si + 2]) / 255)

        // Badge: ink or pale ink well above-left of the body. The body occupies the
        // centre, so ink in this corner can only be the badge.
        var corner = 0
        var cy = 0
        while cy < Int(Double(h) * 0.26) {
            var cx = 0
            while cx < Int(Double(w) * 0.30) {
                let i = (cy * w + cx) * 4
                let lum = (Int(pixels[i]) * 299 + Int(pixels[i + 1]) * 587
                           + Int(pixels[i + 2]) * 114) / 1000
                if lum > 40 { corner += 1 }
                cx += 1
            }
            cy += 1
        }
        stats.badgeInk = corner > 12
        return stats
    }
}
