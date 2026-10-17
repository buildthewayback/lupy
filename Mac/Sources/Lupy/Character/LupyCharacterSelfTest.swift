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
        /// The strongest tint found just outside the left edge of the body.
        var glowRGB = (r: 0.0, g: 0.0, b: 0.0)
        var glowSpread = 0.0
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

        // The body is #FFFFFF in every state — brand law — and the light is the state's
        // colour. Both halves are checked, because either one failing means the
        // character has stopped communicating.
        for state in [LupyCharacterState.working, .error, .finished, .dizzy] {
            guard let colour = render(size: 96, state: state)?.bodyRGB else {
                lines.append("FAIL \(state.name): renderer produced no image")
                failures += 1
                continue
            }
            let white = colour.r > 0.985 && colour.g > 0.985 && colour.b > 0.985
            lines.append("\(white ? "PASS" : "FAIL") \(state.name) body is pure white "
                + String(format: "(%.2f %.2f %.2f)", colour.r, colour.g, colour.b))
            if !white { failures += 1 }
        }

        let errorGlow = render(size: 96, state: .error)?.glowRGB
        let doneGlow = render(size: 96, state: .finished)?.glowRGB
        if let errorGlow, let doneGlow {
            let redder = errorGlow.r > max(0.02, errorGlow.g * 2) && errorGlow.r > errorGlow.b * 1.5
            let greener = doneGlow.g > max(0.02, doneGlow.r * 2) && doneGlow.g > doneGlow.b * 1.2
            lines.append("\(redder ? "PASS" : "FAIL") an error glows red "
                + String(format: "(%.2f %.2f %.2f)", errorGlow.r, errorGlow.g, errorGlow.b))
            lines.append("\(greener ? "PASS" : "FAIL") done glows green "
                + String(format: "(%.2f %.2f %.2f)", doneGlow.r, doneGlow.g, doneGlow.b))
            if !redder || !greener { failures += 1 }
        } else {
            lines.append("FAIL could not sample the glow colour")
            failures += 1
        }

        lines.append(failures == 0 ? "CHARACTER SELF-TEST PASSED"
                                   : "CHARACTER SELF-TEST FAILED (\(failures))")
        let text = lines.joined(separator: "\n") + "\n"
        print(text)
        // Make a failure readable from CI even when the raw log cannot be fetched:
        // GitHub turns these lines into annotations on the build check.
        for line in lines where line.hasPrefix("FAIL") {
            print("::error title=Character self-test::\(line)")
        }

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
            tintRed: tint.r, tintGreen: tint.g, tintBlue: tint.b,
            glowStrength: state.glowStrength
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
        // `pointsPerUnit` is the 4x-scaled body width in pixels.
        let pointsPerUnit = CGFloat(unit) * 4
        let sx = w / 2
        let sy = min(h - 1, Int(Double(h) * 0.5 + 0.30 * Double(pointsPerUnit)))
        let si = (sy * w + sx) * 4
        stats.bodyRGB = (Double(pixels[si]) / 255, Double(pixels[si + 1]) / 255,
                         Double(pixels[si + 2]) / 255)

        // Glow: scan a short strip just outside the left edge and keep the most
        // strongly tinted pixel. A single sample can land on the dim tail of a blur
        // and report "no colour" for a glow a person can plainly see.
        let gy = h / 2
        var best = (r: 0.0, g: 0.0, b: 0.0)
        var bestSpread = 0.0
        let startX = Int(Double(w) * 0.5 - Double(pointsPerUnit) * 0.66)
        let endX = Int(Double(w) * 0.5 - Double(pointsPerUnit) * 0.52)
        for gx in max(0, startX)...min(w - 1, endX) {
            let gi = (gy * w + gx) * 4
            let r = Double(pixels[gi]) / 255
            let g = Double(pixels[gi + 1]) / 255
            let b = Double(pixels[gi + 2]) / 255
            let spread = max(r, g, b) - min(r, g, b)
            if spread > bestSpread { bestSpread = spread; best = (r, g, b) }
        }
        stats.glowRGB = best
        stats.glowSpread = bestSpread
        return stats
    }
}
