// Emits every state from the shipping rig, so the sheet is drawn from real geometry.
//
//   node tools/swiftwasm/swiftc-wasm.mjs --run \
//     Mac/Sources/Lupy/Character/LupyGeometry.swift \
//     Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
//     tools/character/rig_states.swift > /tmp/states.txt
//
//   FRAME <name> <yaw> <pitch> <blink>
//   STATE <name> <r> <g> <b> <badge>
//   BODY  x,y ...
//   EYE   <side> <cx> <cy> <rx> <ry> <style>

struct StateEmitter {
    func run() {
        for state in LupyState.allCases {
            var rig = LupyRig()
            rig.state = state
            rig.movePointer(to: 0, 0)
            // let the springs settle so the sheet shows the resting pose of each state
            var i = 0
            while i < 120 { rig.step(dt: LupyFrameClock.step); i += 1 }

            let name = state.name
            print("FRAME \(name) \(rig.gazeX.value) \(rig.gazeY.value) \(rig.blink.open)")
            let t = state.tint
            print("STATE \(name) \(t.r) \(t.g) \(t.b) \(state.badge?.name ?? "none")")

            let sc = rig.bodyScale
            print("BODY " + LupyBody.polygon().map {
                "\($0.0 * sc.x),\($0.1 * sc.y)"
            }.joined(separator: " "))

            for f in rig.eyes(bodyWidth: 1.0) where f.visible {
                let halfW = f.w * f.fx * 0.5
                let halfH = f.h * f.fy * rig.blink.open * 0.5
                if halfH > 0.0008 {
                    let style: String
                    switch f.style {
                    case .capsule: style = "capsule"
                    case .wide: style = "wide"
                    case .dash: style = "dash"
                    case .halfLid: style = "half_lid"
                    case .arch: style = "arch"
                    case .cup: style = "cup"
                    case .spiral: style = "spiral"
                    }
                    print("EYE \(f.side) \(f.x * sc.x) \(f.y * sc.y) \(halfW) \(halfH) \(style)")
                }
            }
        }
    }
}

@main
struct Entry {
    static func main() { StateEmitter().run() }
}
