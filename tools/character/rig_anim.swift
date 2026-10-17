// Drives the live rig along a pointer path and emits every drawn frame.
// The rasteriser turns these into the animated proof / regression fixture.
//
//   node tools/swiftwasm/swiftc-wasm.mjs --run \
//     Mac/Sources/Lupy/Character/LupyGeometry.swift \
//     Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
//     tools/character/rig_anim.swift > /tmp/anim.txt

struct AnimEmitter {
    func run(seconds: Double = 4.0, fps: Double = 60) {
        var rig = LupyRig()
        rig.movePointer(to: 900, -30)          // starts off to the right
        let total = Int(seconds * fps)
        var i = 0
        while i < total {
            let t = Double(i) / Double(total - 1)
            // A slow, deliberate sweep: enters from the right, crosses the face,
            // dips low, then rises to settle at the left. Eased, never linear.
            let ease = t * t * (3 - 2 * t)
            let px = 150 - 300 * ease      // crosses right over the body
            let py = 58 * LM.sin(t * LM.pi * 1.25) - 18
            rig.movePointer(to: px, py)
            rig.step(dt: 1.0 / fps)

            let sc = rig.bodyScale
            print("FRAME \(i) \(rig.gazeX.value) \(rig.gazeY.value) \(rig.blink.open)")
            print("BODY " + LupyBody.polygon().map {
                "\($0.0 * sc.x),\($0.1 * sc.y)"
            }.joined(separator: " "))
            for f in rig.eyes(bodyWidth: 1.0) where f.visible {
                let halfW = f.w * f.fx * 0.5
                let halfH = f.h * f.fy * rig.blink.open * 0.5
                if halfH > 0.0008 {
                    print("EYE \(f.side) \(f.x * sc.x) \(f.y * sc.y) \(halfW) \(halfH)")
                }
            }
            print("CURSOR \(px / 200.0) \(-py / 200.0)")   // y up, to match the rig
            i += 1
        }
    }
}

@main
struct Entry {
    static func main() {
        AnimEmitter().run()
    }
}
