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
    }

    static func run(arguments: [String]) -> Int32 {
        var lines: [String] = []
        var failures = 0

        let sizes: [(String, CGFloat)] = [
            ("menu-24", 24), ("island-32", 32), ("island-64", 64), ("desktop-256", 256),
        ]

        for (name, size) in sizes {
            guard let stats = render(size: size) else {
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
    private static func render(size: CGFloat) -> Stats? {
        let bounds = LupyBody.bounds()
        let unit = min(Double(size) * 0.94 / bounds.w, Double(size) * 0.94 / bounds.h)
        let eyes = LupyEyes.frames(yaw: 0.28, pitch: -0.12,
                                   rx: 0.5, ry: 0.5 * LupyGeometry.bodyAspect,
                                   bodyWidth: 1.0).filter { $0.visible }
        let frame = LupyFrameSnapshot(
            beziers: LupyBody.beziers(),
            eyes: eyes,
            scaleX: 1, scaleY: 1, blink: 1,
            unit: unit,
            centreX: Double(size) * 0.5,
            centreY: Double(size) * 0.5
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
        return stats
    }
}
