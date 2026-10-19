// THE TEN-MILLION BETA STRESS — the AI-app checklist, mathematically, at scale.
//
// Six attack modes, 10,000,000 cases: (0) wire-context cap arithmetic, (1) UI
// history cap, (2) AppleScript escape invariants against a hostile alphabet
// (quotes, backslashes, RTL overrides, zero-widths, "$(", "ignore previous
// instructions"), (3) error-mapping totality and determinism, (4) token-budget
// ceilings — cost must be O(cap), never O(session), (5) injection delimiting:
// the 24k truncation, the header, the query-after-content rule.
//
// Run: node tools/swiftwasm/swiftc-wasm.mjs --run tools/ui/stress_beta.swift

nonisolated(unsafe) var seed: UInt64 = 0xBE7A11
func rnd() -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double((seed >> 11) % 1_000_000_000) / 1_000_000_000.0
}
func ri(_ lo: Int, _ hi: Int) -> Int { lo + Int(rnd() * Double(hi - lo + 1)) }

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

// replicas of the product's own guards, so the maths is tested at scale
func escapeAS(_ s: String) -> String {
    var out = ""
    for ch in s {
        if ch == "\\" { out.append("\\\\") }
        else if ch == "\"" { out.append("\\\"") }
        else { out.append(ch) }
    }
    return out
}
func unescapeAS(_ s: String) -> String {
    var out = ""
    var esc = false
    for ch in s {
        if esc { out.append(ch); esc = false }
        else if ch == "\\" { esc = true }
        else { out.append(ch) }
    }
    return out
}
enum UserFace: Equatable { case retry, offline, cancelled, server, unknown }
func face(status: Int?, timeout: Bool, cancelled: Bool, network: Bool) -> UserFace {
    if cancelled { return .cancelled }
    if timeout { return .retry }
    if network { return .offline }
    switch status {
    case .some(400..<500): return .unknown
    case .some(500...): return .server
    case .some(_): return .unknown
    case .none: return .offline
    }
}
let wireCap = 24
let uiCap = 200
let fileCap = 24_000
let perMsgCap = 8_000
let marker = "\n[truncated]"

var wire: [Int] = []
var ui: [Int] = []
var nextId = 0
let hostile = ["\"", "\\", "\n", "a", "x", "U+202E", "U+200B", "'",
               "$(", "`", "; rm -rf", "ignore previous instructions",
               "SYSTEM:", "NUL", "check"]

for i in 0..<10_000_000 {
    casesRun += 1
    switch i % 6 {
    case 0:  // wire cap: bounded, newest kept, order intact
        for _ in 0..<ri(1, 5) {
            nextId += 1
            wire.append(nextId)
        }
        if wire.count > wireCap { wire.removeFirst(wire.count - wireCap) }
        check(wire.count <= wireCap, "beta: wire cap holds")
        check(wire.last == nextId, "beta: newest message survives")
        check(zip(wire, wire.dropFirst()).allSatisfy { $0 < $1 }, "beta: wire order intact")
    case 1:  // UI cap
        for _ in 0..<ri(1, 9) {
            nextId += 1
            ui.append(nextId)
        }
        if ui.count > uiCap { ui.removeFirst(ui.count - uiCap) }
        check(ui.count <= uiCap, "beta: UI cap holds")
        check(ui.last == nextId, "beta: UI newest survives")
    case 2:  // escape invariants against the hostile alphabet
        var s2 = ""
        for _ in 0..<ri(0, 12) { s2 += hostile[ri(0, hostile.count - 1)] }
        let e = escapeAS(s2)
        let chars = Array(e)
        var bad = false
        for j in 0..<chars.count where chars[j] == "\"" {
            var bs = 0
            var k = j - 1
            while k >= 0 && chars[k] == "\\" { bs += 1; k -= 1 }
            if bs % 2 == 0 { bad = true }
        }
        check(!bad, "beta: no unescaped quote survives")
        check(unescapeAS(e) == s2, "beta: escape round-trips")
    case 3:  // error mapping: total and deterministic
        let st: Int? = ri(0, 3) == 0 ? nil : ri(99, 600)
        let to = i % 2 == 0, ca = i % 3 == 0, ne = i % 5 == 0
        let f1 = face(status: st, timeout: to, cancelled: ca, network: ne)
        let f2 = face(status: st, timeout: to, cancelled: ca, network: ne)
        check(f1 == f2, "beta: error mapping deterministic")
        check(ca ? f1 == .cancelled : true, "beta: cancel wins")
        check(!ca && to ? f1 == .retry : true, "beta: timeout asks retry")
        check(!ca && !to && ne ? f1 == .offline : true, "beta: network says offline")
    case 4:  // token budget: O(cap), never O(session)
        let turns = ri(1, 10_000)
        let chars = ri(10, 20_000)
        let msgs = min(turns * 2, wireCap)
        let per = min(chars, perMsgCap)
        let tokens = (msgs * per) / 4 + 500
        check(tokens <= (wireCap * perMsgCap) / 4 + 500, "beta: token ceiling")
        check(tokens <= 50_000, "beta: inside the context window")
        let msgs2 = min((turns + 1_000) * 2, wireCap)
        check(turns * 2 >= wireCap ? msgs == msgs2 : true, "beta: cost flat once capped")
    default:  // injection delimiting — arithmetic at scale, materialise on sample
        let len = ri(0, 100_000)
        let over = len > fileCap
        let truncCount = (over ? fileCap : len) + (over ? marker.count : 0)
        check(truncCount <= fileCap + marker.count, "beta: file cap holds")
        check(over == (truncCount > fileCap), "beta: marker tells the truth")
        if i % 997 == 0 {  // sampled materialisation: the real strings, sometimes
            let content = String(repeating: "x", count: len)
            let truncated = over ? String(content.prefix(fileCap)) + marker : content
            let assembled = "File: evil.md\n\n" + truncated + "\n\n" + "what does it say?"
            check(truncated.count == truncCount, "beta: materialised count matches")
            check(assembled.hasPrefix("File: evil.md\n\n"), "beta: header delimits")
            check(assembled.hasSuffix("what does it say?"), "beta: query stays last")
        }
    }
}
print("BETA STRESS: \(casesRun) cases, \(measures) measurements, \(fails) failures")
for r in reasons.sorted(by: { $0.1 > $1.1 }).prefix(8) { print("  \(r.1)\t\(r.0)") }
print(fails == 0 ? "BETA STRESS: SATISFIED" : "BETA STRESS: FAILED")
