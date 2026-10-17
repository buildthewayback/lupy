// Drives the live rig along a pointer path and emits every drawn frame, so the
// animated proof is made from the same code the app ships.
//
// The story it tells is the point of the whole thing: a calm Mac, a working one,
// one that runs out of memory, and the return to calm. The pointer is the user's
// mouse; the character is the machine's body language.
//
//   node tools/swiftwasm/swiftc-wasm.mjs --run \
//     Mac/Sources/Lupy/Character/LupyGeometry.swift \
//     Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
//     tools/character/rig_anim.swift > /tmp/anim.txt

struct AnimEmitter {
    struct Beat {
        var start: Double
        var state: LupyCharacterState
        var cpu: Double
        var memory: Int
    }

    func run(seconds: Double = 7.2, fps: Double = 25) {
        var rig = LupyRig()
        rig.movePointer(to: 460, -40)          // starts off to the right

        let beats: [Beat] = [
            Beat(start: 0.0, state: .idle, cpu: 0.12, memory: 0),
            Beat(start: 0.8, state: .working, cpu: 0.35, memory: 0),
            Beat(start: 2.4, state: .working, cpu: 0.96, memory: 0),
            Beat(start: 3.9, state: .working, cpu: 0.55, memory: 2),
            Beat(start: 5.2, state: .working, cpu: 0.40, memory: 0),
            Beat(start: 6.0, state: .finished, cpu: 0.20, memory: 0),
        ]

        let total = Int(seconds * fps)
        var i = 0
        while i < total {
            let t = Double(i) / fps

            // A slow, deliberate sweep: enters from the right, crosses the face,
            // dips low, then rises to settle at the left. Eased, never linear.
            let u = min(1, t / seconds)
            let ease = u * u * (3 - 2 * u)
            let px = 430 - 860 * ease
            let py = 78 * LM.sin(u * LM.pi * 1.35) - 30
            rig.movePointer(to: px, py)

            // What the machine is doing at this moment.
            var beat = beats[0]
            for b in beats where t >= b.start { beat = b }
            rig.requestedState = beat.state
            var vitals = LupyVitals()
            vitals.cpu = beat.cpu
            vitals.memoryPressure = beat.memory
            vitals.thermal = 0
            rig.apply(vitals: vitals, busySamples: beat.cpu >= 0.8 ? 3 : 0)

            rig.step(dt: 1.0 / fps)

            let state = rig.state
            let tint = state.tint
            let bs = rig.bodyScale
            let style = rig.effectiveEyeStyle
            let sc = style.capsuleScale
            let isArc = style == .arch || style == .cup

            print("FRAME \(i) \(rig.gazeX.value) \(rig.gazeY.value) \(rig.drawnBlinkOpen)")
            print("MOOD \(rig.mood.hot) \(rig.mood.busy) \(rig.mood.full) \(rig.mood.tired) \(rig.mood.asleep ? 1 : 0)")
            print("STATE \(state.bodyTintAmount) \(tint.r) \(tint.g) \(tint.b) \(state.badge?.name ?? "none") \(state.bubbleText)")
            print("BODY " + LupyBody.polygon().map {
                "\($0.0 * bs.x),\($0.1 * bs.y)"
            }.joined(separator: " "))

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
                print("EYE \(f.side) \(f.x * bs.x) \(f.y * bs.y) \(halfW) \(halfH) \(name)")
            }
            print("CURSOR \(px / 200.0) \(-py / 200.0)")   // y up, to match the rig
            i += 1
        }
    }
}

@main
struct Anim {
    static func main() { AnimEmitter().run() }
}
