// THE HUNDRED-THOUSAND AUDIT — property fuzzing of the LUPY 3 kernel.
//
// The councils judge pictures; the design tests judge the law at chosen points;
// this harness judges the law EVERYWHERE: 100,000 randomised cases through the
// trigonometry, the character geometry, the state resolution and the canvas growth
// law, asserting the invariants that must never bend — bounds, grid, containment,
// silhouette stability, monotonic growth, finite maths. ~8 measurements per case.
//
// Run: node tools/swiftwasm/swiftc-wasm.mjs --run \
//        Mac/Sources/Lupy/Character/LupyGeometry.swift \
//        Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
//        Mac/Sources/Lupy/UI/LupyIslandDesign.swift tools/ui/fuzz_kernel.swift

nonisolated(unsafe) var seed: UInt64 = 0x4C555059C0DE
func rnd() -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double((seed >> 11) % 1_000_000_000) / 1_000_000_000.0
}
func ri(_ lo: Int, _ hi: Int) -> Int { lo + Int(rnd() * Double(hi - lo + 1)) }
func rd(_ lo: Double, _ hi: Double) -> Double { lo + rnd() * (hi - lo) }

nonisolated(unsafe) var cases = 0
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
func finite(_ v: Double) -> Bool { v == v && v < 1e9 && v > -1e9 }

@main
enum FuzzMain {
    static func main() {
// ── 1 · the trigonometry the body breathes with (20,000 cases) ────────────────
for _ in 0..<20_000 {
    cases += 1
    let x = rd(-40, 40)
    let s = LM.sin(x), c = LM.cos(x)
    check(abs(s) <= 1.0000001, "sin range")
    check(abs(c) <= 1.0000001, "cos range")
    check(abs(s * s + c * c - 1) < 1e-6, "pythagoras")
    check(finite(s) && finite(c), "trig finite")
    let w = LM.wrap(x)
    check(w >= -.pi - 1e-9 && w <= .pi + 1e-9, "wrap range")
    check(abs(LM.wrap(w) - w) < 1e-9, "wrap idempotent")
    let t = LM.tanh(x)
    check(t > -1.0000001 && t < 1.0000001, "tanh range")
    check(LM.exp(x) > 0, "exp positive")
    let v = rd(0, 100)
    check(abs(LM.sqrt(v) * LM.sqrt(v) - v) < 1e-6, "sqrt round trip")
    check(LM.clamp(v, 10, 20) >= 10 && LM.clamp(v, 10, 20) <= 20, "clamp holds")
    check(LM.lerp(3, 7, 0) == 3 && LM.lerp(3, 7, 1) == 7, "lerp endpoints")
    check(LM.rounded(LM.rounded(v)) == LM.rounded(v), "round idempotent")
}

// ── 2 · the character's geometry (20,000 cases) ───────────────────────────────
for _ in 0..<20_000 {
    cases += 1
    let w = rd(8, 1200), h = rd(8, 1200)
    let u = LupyComposition.unit(width: w, height: h)
    check(u > 0 && finite(u), "unit positive")
    let u2 = LupyComposition.unit(width: w * 2, height: h * 2)
    check(abs(u2 - u * 2) < 1e-6, "unit scales linearly")
    let b = LupyComposition.badgeCentre()
    check(finite(b.x) && finite(b.y), "badge finite")
    check(LupyComposition.badgeReach > 0 && LupyComposition.glowReach > 0, "reaches positive")
    check(LupyComposition.showsBubble(bodyWidth: 46) == (46 >= LupyComposition.detailFloor), "bubble threshold")
    check(LupyGeometry.showsBlush == false, "no blush, ever")
    for p in LupyGeometry.outline {
        check(abs(p.0) <= 0.5001 && p.1 >= -0.0001 && p.1 <= 1.0001, "outline inside unit space")
    }
    check(LupyGeometry.eyeW > 0 && LupyGeometry.eyeH > 0 && LupyGeometry.eyeCentreX > 0, "eye metrics sane")
    check(LupyGeometry.bodyAspect > 0.5 && LupyGeometry.bodyAspect < 1.0, "body aspect plausible")
}

// ── 3 · state resolution: an overloaded Mac always tells the truth (10,000) ──
let allStates = LupyCharacterState.allCases
for _ in 0..<10_000 {
    cases += 1
    let s = allStates[ri(0, allStates.count - 1)]
    check(LupyCharacterState.resolved(requested: s, overloaded: false) == s,
          "calm Mac draws what the task says")
    let keeps = s == .approval || s == .question || s == .error
    check(LupyCharacterState.resolved(requested: s, overloaded: true) == (keeps ? s : .dizzy),
          "overloaded Mac is dizzy, except it never hides a question")
}

// ── 4 · the growth law, everywhere (50,000 cases) ─────────────────────────────
func randomNeed() -> LupyCanvasNeed {
    switch ri(0, 6) {
    case 0: return .rest
    case 1: return .whisper(textWidth: rd(0, 700))
    case 2: return .answer(lines: ri(1, 9), chips: ri(0, 4), provenance: rnd() < 0.5)
    case 3: return .task(steps: ri(1, 12), hasPlan: rnd() < 0.5, hasPreview: rnd() < 0.5)
    case 4: return .chat(turns: ri(1, 8), streaming: rnd() < 0.5)
    case 5: return .decision(options: ri(1, 4), hasEvidence: rnd() < 0.5, queue: ri(1, 9))
    default: return .transcript(lines: ri(1, 10))
    }
}
for _ in 0..<50_000 {
    cases += 1
    var notch = Double(ri(0, 50) * 8)          // 0 = no-notch Macs, up to wide notches
    let need = randomNeed()
    // rest *is* the notch band: a 0-notch Mac gets the shell's software capsule instead,
    // so feeding .rest a zero notch is not a case, it is a category error.
    if case .rest = need { notch = max(notch, 184) }
    let cv = LupyIslandLayout.canvas(need, notchWidth: notch)
    if case .rest = need {} else { check(cv.width >= LupyIslandLayout.minWidth - 0.51, "width floor") }
    if case .rest = need { check(cv.width <= notch + 0.51 || cv.width >= LupyIslandLayout.minWidth - 0.51, "rest is the notch band") }
    check(cv.width <= LupyIslandLayout.maxWidth + 0.51, "width ceiling")
    check(cv.height >= LupyIslandLayout.minHeight - 0.51, "height floor")
    check(cv.height <= LupyIslandLayout.maxHeight + 0.51, "height ceiling")
    check(cv.width.truncatingRemainder(dividingBy: 8) < 0.51
          || cv.width.truncatingRemainder(dividingBy: 8) > 7.49, "width on the 8-grid")
    check(cv.corner >= min(8, cv.width / 2) - 0.51 && cv.corner <= cv.height / 2 + 0.51, "corner sane")
    check(cv.corner <= cv.width / 2 + 0.51, "corner within width")
    // LUPY himself: inside the frame, kissing the left edge at exactly padEdge
    if cv.status != .motion {
        check(cv.avatar.x >= cv.frame.x + LupyIslandLayout.padEdge - 0.51, "avatar left padding")
    } else {
        check(abs(cv.avatar.x - (cv.frame.width - cv.avatar.width) / 2) < 0.51, "resting avatar centred under the camera")
    }
    check(cv.avatar.x + cv.avatar.width <= cv.frame.x + cv.frame.width + 0.51, "avatar inside")
    check(cv.avatar.y >= cv.frame.y - 0.51, "avatar below top")
    check(cv.avatar.y + cv.avatar.height <= cv.frame.y + cv.frame.height + 0.51, "avatar above bottom")
    // every carried box lives inside the island
    for box in [cv.content, cv.composer, cv.statusBox] where box.width > 0 {
        check(box.x >= cv.frame.x - 0.51, "box inside left")
        check(box.x + box.width <= cv.frame.x + cv.frame.width + 0.51, "box inside right")
        check(box.y >= cv.frame.y - 0.51, "box inside top")
        check(box.y + box.height <= cv.frame.y + cv.frame.height + 0.51, "box inside bottom")
    }
    // the whisper never changes the silhouette: same band as rest
    if case .whisper = need {
        let rest = LupyIslandLayout.canvas(.rest, notchWidth: notch)
        check(abs(cv.height - rest.height) < 0.51, "whisper keeps the silhouette")
    }
    // monotonic growth: one more line never shrinks the card
    if case .answer(let l, let ch, let pv) = need, l < 9 {
        let bigger = LupyIslandLayout.canvas(.answer(lines: l + 1, chips: ch, provenance: pv),
                                             notchWidth: notch)
        check(bigger.height >= cv.height - 0.51, "growth is monotonic")
    }
    if case .task(let st, let hp, let hv) = need, st < 12 {
        let bigger = LupyIslandLayout.canvas(.task(steps: st + 1, hasPlan: hp, hasPreview: hv),
                                             notchWidth: notch)
        check(bigger.height >= cv.height - 0.51, "task growth monotonic")
    }
    // glass alpha: the derived law, never pastel, never opaque
    check(cv.glass.fillAlpha > 0.5 && cv.glass.fillAlpha < 1.0, "glass alpha in range")
}

print("FUZZ KERNEL: \(cases) cases, \(measures) measurements, \(fails) failures")
for r in reasons.sorted(by: { $0.1 > $1.1 }) { print("  \(r.1)\t\(r.0)") }
if fails > 0 { print("FUZZ KERNEL: FAILED") } else { print("FUZZ KERNEL: SATISFIED") }
    }
}
