
// Emits the character's drawable geometry as plain lines, for two sheets:
//   * every task state, driven through the real rig
//   * the machine-mood states (calm, CPU pinned, RAM critical, too hot)
//
// Every number comes from LupyBody / LupyRig / LupyState — the same code the app
// draws with. The renderer only fills shapes. If a pixel is wrong, the rig is wrong.
//
//   swiftc LupyGeometry.swift LupyCharacterMath.swift rig_states.swift -o /tmp/states

enum LupyConsole {
    static func line(_ s: String) { print(s) }
}

struct StateEmitter {
    func emit(_ label: String, rig: LupyRig) {
        let state = rig.state
        let t = state.tint
        let bs = rig.bodyScale
        let style = rig.effectiveEyeStyle

        LupyConsole.line("FRAME \(label) \(rig.gazeX.value) \(rig.gazeY.value) \(rig.drawnBlinkOpen)")
        LupyConsole.line("MOOD \(rig.mood.hot) \(rig.mood.busy) \(rig.mood.full) \(rig.mood.tired) \(rig.mood.asleep ? 1 : 0)")
        LupyConsole.line("STATE \(label) \(t.r) \(t.g) \(t.b) \(state.bodyTintAmount) \(state.badge?.name ?? "none") \(state.label)")
        LupyConsole.line("BODY " + LupyBody.polygon().map {
            "\($0.0 * bs.x),\($0.1 * bs.y)"
        }.joined(separator: " "))

        let sc = style.capsuleScale
        let isArc = style == .arch || style == .cup
        for f in rig.eyes(bodyWidth: 1.0) where f.visible {
            let halfW = f.w * f.fx * 0.5 * (isArc ? style.arcSpan : sc.x)
            let halfH = f.h * f.fy * rig.drawnBlinkOpen * 0.5 * (isArc ? 1 : sc.y)
            guard halfH > 0.0008 else { continue }
            let name: String
            switch style {
            case .capsule: name = "capsule"
            case .wide:    name = "wide"
            case .dash:    name = "dash"
            case .halfLid: name = "half_lid"
            case .arch:    name = "arch"
            case .cup:     name = "cup"
            case .spiral:  name = "spiral"
            }
            LupyConsole.line("EYE \(f.side) \(f.x * bs.x) \(f.y * bs.y) \(halfW) \(halfH) \(name)")
        }
    }

    /// A tile driven by the machine rather than by a task.
    func emitMood(_ name: String, requested: LupyState, vitals: LupyVitals, busySamples: Int) {
        var rig = LupyRig()
        rig.requestedState = requested
        rig.apply(vitals: vitals, busySamples: busySamples)
        rig.movePointer(to: 0, 0)
        var i = 0
        while i < 150 { rig.step(dt: LupyFrameClock.step); i += 1 }
        emit(name, rig: rig)
    }

    func run() {
        for state in LupyState.allCases {
            var rig = LupyRig()
            rig.requestedState = state
            rig.movePointer(to: 0, 0)
            var i = 0
            while i < 150 { rig.step(dt: LupyFrameClock.step); i += 1 }
            emit(state.name, rig: rig)
        }

        emitMood("mood_calm", requested: .idle, vitals: LupyVitals(), busySamples: 0)
        var pinned = LupyVitals(); pinned.cpu = 0.97
        emitMood("cpu_pinned", requested: .working, vitals: pinned, busySamples: 3)
        var ram = LupyVitals(); ram.memoryPressure = 2
        emitMood("ram_critical", requested: .working, vitals: ram, busySamples: 0)
        var warm = LupyVitals(); warm.thermal = 3
        emitMood("too_hot", requested: .working, vitals: warm, busySamples: 0)
    }
}

@main
struct Emitter {
    static func main() { StateEmitter().run() }
}
