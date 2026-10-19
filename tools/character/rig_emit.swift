// Emits real rig frames from the shipping Swift code, as plain text, so an external
// rasteriser can draw the *exact* geometry the app will draw.
//
//   node tools/swiftwasm/swiftc-wasm.mjs --run \
//     Mac/Sources/Lupy/Character/LupyGeometry.swift \
//     Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
//     tools/character/rig_emit.swift > /tmp/frames.txt
//
// Format (all lengths in body-width units, y UP, origin at body centre):
//   FRAME <name> <yaw> <pitch> <blink>
//   BODY  x,y x,y ...
//   EYE   <side> <cx> <cy> <rx> <ry>    (rx/ry are HALF extents)

struct Emitter {
    func emitFrame(_ name: String, yaw: Double, pitch: Double, blink: Double,
                   bodyWidth: Double = 1.0) {
        let aspect = LupyGeometry.bodyAspect
        let rx = bodyWidth * 0.5
        let ry = bodyWidth * 0.5 * aspect
        print("FRAME \(name) \(yaw) \(pitch) \(blink)")
        print("BODY " + LupyBody.polygon().map { "\($0.0),\($0.1)" }.joined(separator: " "))
        let frames = LupyEyes.frames(yaw: yaw, pitch: pitch, rx: rx, ry: ry, bodyWidth: bodyWidth)
        for f in frames where f.visible {
            // blink squashes the eye about its own centre
            let halfW = f.w * f.fx * 0.5
            let halfH = f.h * f.fy * blink * 0.5
            print("EYE \(f.side) \(f.x) \(f.y) \(halfW) \(halfH)")
        }
    }

    func run() {
        // the shapes we must prove: rest, the four look directions, and a blink
        emitFrame("rest", yaw: 0, pitch: 0, blink: 1)
        emitFrame("look_right", yaw: 0.86, pitch: 0.0, blink: 1)
        emitFrame("look_left", yaw: -0.86, pitch: 0.0, blink: 1)
        emitFrame("look_up", yaw: 0.12, pitch: 0.72, blink: 1)
        emitFrame("look_down", yaw: 0.0, pitch: -0.55, blink: 1)
        emitFrame("blink", yaw: 0.0, pitch: 0.0, blink: 0.05)
        // and the eyebrow-less corners: gaze driven to the floor / ceiling
        emitFrame("look_far_up", yaw: 0, pitch: 1.0, blink: 1)
        emitFrame("look_far_down", yaw: 0, pitch: -1.0, blink: 1)
    }
}

@main
struct Entry {
    static func main() {
        Emitter().run()
    }
}
