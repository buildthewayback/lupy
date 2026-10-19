// THE TEN-MILLION STRESS — the kernel under fire, in every way at once.
//
// 10,000,000 randomised cases cycle through seven attack modes (layout bounds,
// containment, grid, trig identities, geometry, state resolution, spring ticks),
// then an ADVERSARIAL phase feeds NaN, ±infinity, negatives and absurd magnitudes
// into every entry point: a product that survives a founder must also survive a
// hostile universe. Finally a spring storm: a million pointer jumps through the
// gaze springs — bounded, converging, never NaN.
//
// Run: node tools/swiftwasm/swiftc-wasm.mjs --run <kernel files> tools/ui/stress_kernel.swift

nonisolated(unsafe) var seed: UInt64 = 0x57DE55
func rnd() -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double((seed >> 11) % 1_000_000_000) / 1_000_000_000.0
}
func ri(_ lo: Int, _ hi: Int) -> Int { lo + Int(rnd() * Double(hi - lo + 1)) }
func rd(_ lo: Double, _ hi: Double) -> Double { lo + rnd() * (hi - lo) }

nonisolated(unsafe) var casesRun = 0
nonisolated(unsafe) var measures = 0
nonisolated(unsafe) var fails = 0
nonisolated(unsafe) var reasons: [(String, Int)] = []
func check(_ cond: Bool, _ what: String) {
    measures += 1
    if !cond {
        fails += 1
        if let i = reasons.firstIndex(where: { $0.0 == what }) { reasons[i].1 += 1 }
        else { reasons.append((what, 1)) }
    }
}
func finite(_ v: Double) -> Bool { v == v && v < 1e12 && v > -1e12 }

@main
enum StressMain {
    static func main() {
        let allStates = LupyCharacterState.allCases

        for i in 0..<10_000_000 {
            casesRun += 1
            switch i % 7 {
            case 0:  // layout under random load
                let notch = Double(ri(23, 50) * 8)
                let need: LupyCanvasNeed
                switch ri(0, 5) {
                case 0: need = .whisper(textWidth: rd(0, 700))
                case 1: need = .answer(lines: ri(1, 9), chips: ri(0, 4), provenance: i % 2 == 0)
                case 2: need = .task(steps: ri(1, 12), hasPlan: i % 3 == 0, hasPreview: i % 5 == 0)
                case 3: need = .chat(turns: ri(1, 8), streaming: i % 2 == 0)
                case 4: need = .decision(options: ri(1, 4), hasEvidence: i % 2 == 0, queue: ri(1, 9))
                default: need = .transcript(lines: ri(1, 10))
                }
                let cv = LupyIslandLayout.canvas(need, notchWidth: notch)
                check(cv.width >= LupyIslandLayout.minWidth - 0.51
                      && cv.width <= LupyIslandLayout.maxWidth + 0.51, "stress: width bounds")
                check(cv.height >= LupyIslandLayout.minHeight - 0.51
                      && cv.height <= LupyIslandLayout.maxHeight + 0.51, "stress: height bounds")
                check(finite(cv.width) && finite(cv.height) && finite(cv.corner),
                      "stress: canvas finite")
                check(cv.avatar.x + cv.avatar.width <= cv.frame.width + 0.51,
                      "stress: avatar contained")
            case 1:  // trig identities at speed
                let x = rd(-1e3, 1e3)
                let s = LM.sin(x), c = LM.cos(x)
                check(abs(s * s + c * c - 1) < 1e-6, "stress: pythagoras")
                check(abs(LM.sin(x + LM.twoPi) - s) < 1e-6, "stress: period")
                check(finite(LM.tanh(x)) && LM.exp(-x) > 0, "stress: exp/tanh sane")
            case 2:  // clamps, lerps, rounding under random fire
                let a = rd(-1e4, 1e4), b = rd(-1e4, 1e4), t = rd(-2, 3)
                let cl = LM.clamp(a, min(a, b), max(a, b))
                check(cl >= min(a, b) - 1e-9 && cl <= max(a, b) + 1e-9, "stress: clamp holds")
                check(finite(LM.lerp(a, b, t)), "stress: lerp finite beyond [0,1]")
                check(LM.rounded(a) == LM.rounded(LM.rounded(a)), "stress: round idempotent")
            case 3:  // geometry scalings
                let w = rd(1, 5000), h = rd(1, 5000)
                let u = LupyComposition.unit(width: w, height: h)
                check(u > 0 && finite(u), "stress: unit positive")
                check(abs(LupyComposition.unit(width: w * 3, height: h * 3) - u * 3) < 1e-6,
                      "stress: unit linear")
                check(LupyComposition.badgeReach > 0, "stress: badge reach")
            case 4:  // state resolution, both truths
                let s = allStates[ri(0, allStates.count - 1)]
                let keeps = s == .approval || s == .question || s == .error
                check(LupyCharacterState.resolved(requested: s, overloaded: true)
                      == (keeps ? s : .dizzy), "stress: overload truth")
                check(LupyCharacterState.resolved(requested: s, overloaded: false) == s,
                      "stress: calm truth")
            case 5:  // grid discipline
                let notch = Double(ri(23, 50) * 8)
                let cv = LupyIslandLayout.canvas(
                    .answer(lines: ri(1, 6), chips: ri(0, 3), provenance: false),
                    notchWidth: notch)
                let r = cv.width.truncatingRemainder(dividingBy: 8)
                check(r < 0.51 || r > 7.49, "stress: 8-pt grid")
                check(cv.corner <= cv.height / 2 + 0.51, "stress: corner within band")
            default:  // spring storm: pointer jumps, gaze follows, never explodes
                var spring = LupySpring(value: 0, target: 0, omega: 16, zeta: 0.88)
                for _ in 0..<10 {
                    spring.target = rd(-40, 40)
                    for _ in 0..<10 { spring.step(dt: 1.0 / 60.0) }
                    check(finite(spring.value), "stress: spring finite")
                }
                check(abs(spring.value) < 1e3, "stress: spring bounded")
            }
        }

        // ── adversarial phase: the hostile universe ─────────────────────────
        let hostiles: [Double] = [.nan, .infinity, -.infinity, -0.0, -1e308, 1e308,
                                  -42, 0, 1e-300, 123456789.123456789]
        for h in hostiles {
            casesRun += 1
            check(finite(LM.clamp(h, 0, 100)) || h.isNaN, "adversarial: clamp survives")
            check(LM.sqrt(abs(h)) >= 0 || h.isNaN, "adversarial: sqrt of magnitude")
            check(finite(LM.wrap(h)) || h.isNaN, "adversarial: wrap survives")
            check(finite(LM.tanh(h)), "adversarial: tanh survives infinities")
            check(LM.exp(h) >= 0, "adversarial: exp never negative")
            let cv = LupyIslandLayout.canvas(.whisper(textWidth: h), notchWidth: 200)
            check(finite(cv.width) && finite(cv.height),
                  "adversarial: whisper width sanitised")
            let cv2 = LupyIslandLayout.canvas(.answer(lines: Int(exactly: h) ?? 1, chips: 0,
                                                      provenance: false), notchWidth: h)
            check(finite(cv2.width) && finite(cv2.height),
                  "adversarial: answer canvas sanitised")
            check(finite(LupyComposition.unit(width: h, height: h)) || h.isNaN,
                  "adversarial: unit survives")
        }
        // absurd but finite loads: a thousand lines, a thousand chips
        let monster = LupyIslandLayout.canvas(.answer(lines: 1000, chips: 1000,
                                                      provenance: true), notchWidth: 400)
        check(monster.height <= LupyIslandLayout.maxHeight + 0.51,
              "adversarial: monster card still capped")
        check(monster.width <= LupyIslandLayout.maxWidth + 0.51,
              "adversarial: monster card still narrow")

        print("STRESS KERNEL: \(casesRun) cases, \(measures) measurements, \(fails) failures")
        for r in reasons.sorted(by: { $0.1 > $1.1 }).prefix(10) {
            print("  \(r.1)\t\(r.0)")
        }
        print(fails == 0 ? "STRESS KERNEL: SATISFIED" : "STRESS KERNEL: FAILED")
    }
}
