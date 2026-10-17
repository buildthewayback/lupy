// Sandbox test harness for LupyCharacterMath.
// Run:
//   node tools/swiftwasm/swiftc-wasm.mjs --run \
//     Mac/Sources/Lupy/Character/LupyGeometry.swift \
//     Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
//     tools/character/rig_tests.swift

final class RigTests {
    var failures = 0
    var checks = 0

    func ok(_ cond: Bool, _ what: String) {
        checks += 1
        if cond { print("ok    \(what)") }
        else { failures += 1; print("FAIL  \(what)") }
    }

    func near(_ a: Double, _ b: Double, _ tol: Double, _ what: String) {
        checks += 1
        if abs(a - b) > tol {
            failures += 1
            print("FAIL  \(what): got \(a), want \(b) +/- \(tol)")
        } else {
            print("ok    \(what)  (\(a))")
        }
    }

    func main() {
        print("== math kernel vs known values ==")
        near(LM.sin(0), 0, 1e-12, "sin(0)")
        near(LM.sin(LM.pi / 2), 1, 1e-10, "sin(pi/2)")
        near(LM.cos(0), 1, 1e-12, "cos(0)")
        near(LM.cos(LM.pi), -1, 1e-10, "cos(pi)")
        near(LM.sqrt(2), 1.41421356237, 1e-9, "sqrt(2)")
        near(LM.exp(0), 1, 1e-12, "exp(0)")
        near(LM.exp(1), 2.71828182846, 1e-8, "exp(1)")
        near(LM.tanh(0), 0, 1e-12, "tanh(0)")
        near(LM.tanh(1), 0.761594155956, 1e-8, "tanh(1)")

        print("\n== body geometry ==")
        let poly = LupyBody.polygon()
        ok(poly.count == LupyBody.controlCount * 8, "polygon samples the 64 fitted segments")
        ok(LupyBody.beziers().count == LupyBody.controlCount, "one Bézier per control point")
        let bs = LupyBody.beziers()
        near(bs[bs.count - 1].x3, bs[0].x0, 1e-9, "path is closed")
        near(bs[bs.count - 1].y3, bs[0].y0, 1e-9, "path closes on the same point")
        // fidelity: smoothing must never redraw the character
        ok(LupyBody.fitError() < 0.004,
           "smooth path stays within 0.4% of the measured outline (\(LupyBody.fitError()))")
        // smoothness: no corner anywhere on the silhouette
        var maxTurn = 0.0
        var k = 0
        while k < poly.count {
            let a = poly[(k - 1 + poly.count) % poly.count]
            let b = poly[k]
            let c = poly[(k + 1) % poly.count]
            let v1x = b.0 - a.0, v1y = b.1 - a.1
            let v2x = c.0 - b.0, v2y = c.1 - b.1
            let n1 = LM.sqrt(v1x * v1x + v1y * v1y)
            let n2 = LM.sqrt(v2x * v2x + v2y * v2y)
            let cosA = (v1x * v2x + v1y * v2y) / (n1 * n2)
            // small-angle form of acos, accurate well past the range that matters
            let turn = LM.sqrt(2 * (1 - cosA))
            if turn > maxTurn { maxTurn = turn }
            k += 1
        }
        // A real kink in a flattened path shows up as tens of degrees at one vertex.
        // The natural apex of the silhouette turns a few degrees per sample.
        ok(maxTurn < 0.09,
           "silhouette has no kinks (max turn \(LM.fixed(maxTurn * 57.2958, 2)) deg)")
        var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9
        for p in poly {
            if p.0 < minX { minX = p.0 }
            if p.0 > maxX { maxX = p.0 }
            if p.1 < minY { minY = p.1 }
            if p.1 > maxY { maxY = p.1 }
        }
        near(maxX - minX, 1.0, 0.01, "body width == 1.0 body-width unit")
        near(maxY - minY, LupyGeometry.bodyAspect, 0.01, "body height == aspect")
        near(minX + maxX, 0, 0.005, "body is horizontally centred")
        near(minY + maxY, 0, 0.005, "body is vertically centred on y=0")
        near(maxY, LupyGeometry.bodyAspect / 2, 0.005, "body top edge at +aspect/2")

        print("\n== eye geometry at rest ==")
        let frames = LupyEyes.frames(yaw: 0, pitch: 0, rx: 0.5,
                                     ry: 0.5 * LupyGeometry.bodyAspect, bodyWidth: 1.0)
        ok(frames.count == 2, "two eyes")
        let left = frames[0]
        ok(left.visible, "eyes visible at rest")
        near(left.w, LupyGeometry.eyeW, 1e-9, "eye width from spec")
        near(left.h, LupyGeometry.eyeH, 1e-9, "eye height from spec")
        near(abs(left.x), 0.1644, 0.0005, "eye centre offset == measured 0.1644 body-widths")
        near(left.y, 0.3409 - LupyGeometry.bodyAspect * 0.5, 0.0005,
             "eye centre height == measured 0.3409 from the bottom")
        near(LupyGeometry.eyeH / LupyGeometry.eyeW, 2.08, 0.06, "eye h/w ratio == 2.08")
        ok(abs(left.fx - 1) < 0.02, "no foreshortening at rest")

        print("\n== gaze ==")
        let g0 = LupyGaze.from(pointerX: 500, pointerY: 500, centreX: 500, centreY: 500, bodyWidth: 200)
        near(g0.yaw, 0, 1e-12, "gaze neutral when the pointer is on the centre")
        let gR = LupyGaze.from(pointerX: 1000, pointerY: 500, centreX: 500, centreY: 500, bodyWidth: 200)
        ok(gR.yaw > 0.8 && gR.yaw < 1.0, "gaze right saturates below 1 (got \(gR.yaw))")
        let gUp = LupyGaze.from(pointerX: 500, pointerY: 100, centreX: 500, centreY: 500, bodyWidth: 200)
        ok(gUp.pitch > 0, "pointer above the centre makes Lupy look up (got \(gUp.pitch))")
        let gFar = LupyGaze.from(pointerX: 100000, pointerY: 500, centreX: 500, centreY: 500, bodyWidth: 200)
        ok(gFar.yaw <= 1.0001, "tanh clamps the gaze, never overshoots")

        print("\n== foreshortening (the 3D eye trick) ==")
        let turned = LupyEyes.frames(yaw: 0.9, pitch: 0, rx: 0.5,
                                     ry: 0.5 * LupyGeometry.bodyAspect, bodyWidth: 1.0)
        ok(abs(turned[0].fx - turned[1].fx) > 0.05,
           "turning compresses the two eyes differently")
        ok(turned[1].fx < 0.9, "far eye compresses (fx=\(turned[1].fx))")
        let up = LupyEyes.frames(yaw: 0, pitch: 1, rx: 0.5,
                                 ry: 0.5 * LupyGeometry.bodyAspect, bodyWidth: 1)
        let down = LupyEyes.frames(yaw: 0, pitch: -1, rx: 0.5,
                                   ry: 0.5 * LupyGeometry.bodyAspect, bodyWidth: 1)
        ok(up[0].y > 0.04, "looking up raises the eyes (y=\(up[0].y))")
        ok(down[0].y < -0.14, "looking down lowers the eyes (y=\(down[0].y))")
        ok(up[0].fy < 1.0 && down[0].fy < 1.0, "eyes squash at the top and bottom of the arc")
        let b = LupyBody.bounds()
        near(b.w, 1.0, 0.005, "bounds() reports the true drawn width")
        let back = LupyEyes.frames(yaw: 1.0, pitch: 0, rx: 0.5,
                                   ry: 0.5 * LupyGeometry.bodyAspect, bodyWidth: 1.0)
        ok(back[0].fx >= 0.18, "scale floor stops the eye collapsing to a line")

        print("\n== springs ==")
        var s = LupySpring(value: 0, target: 1, omega: 18, zeta: 0.62)
        var t = 0.0
        while t < 0.6 {
            s.step(dt: 1.0 / 60.0)
            t += 1.0 / 60.0
        }
        near(s.value, 1.0, 0.02, "spring settles at its target")
        ok(s.velocity < 2.0 && s.velocity > -2.0, "spring velocity decays")

        var crit = LupySpring(value: 0, target: 1, omega: 18, zeta: 1.0)
        var peak = 0.0
        t = 0
        while t < 0.6 {
            crit.step(dt: 1.0 / 60.0)
            if crit.value > peak { peak = crit.value }
            t += 1.0 / 60.0
        }
        ok(peak <= 1.001, "critically damped spring does not overshoot (peak \(peak))")

        print("\n== fixed timestep ==")
        var clock = LupyFrameClock()
        var steps = 0
        var i = 0
        while i < 120 {
            clock.advance(dt: 1.0 / 120.0) { steps += 1 }
            i += 1
        }
        ok(steps == 60, "120 Hz display yields 60 fixed steps (got \(steps))")

        var clock2 = LupyFrameClock()
        var steps2 = 0
        i = 0
        while i < 30 {
            clock2.advance(dt: 1.0 / 30.0) { steps2 += 1 }
            i += 1
        }
        ok(steps2 == 60, "30 Hz display covers a full second of animation (got \(steps2))")

        print("\n== blink ==")
        var blink = LupyBlink(firstBlinkIn: 0.1)
        var minOpen = 1.0
        i = 0
        while i < 60 {
            blink.step(dt: 1.0 / 60.0)
            if blink.open < minOpen { minOpen = blink.open }
            i += 1
        }
        ok(minOpen < 0.2, "blink actually closes (min open \(minOpen))")
        near(blink.open, 1.0, 0.001, "eye re-opens after the blink")

        print("\n== live rig ==")
        var rig = LupyRig()
        rig.movePointer(to: 600, 300)          // well to the right and below
        var rigSteps = 0
        var t2 = 0.0
        while t2 < 1.0 {
            rig.step(dt: LupyFrameClock.step)
            t2 += LupyFrameClock.step
            rigSteps += 1
        }
        ok(rigSteps == 60, "one second of rig time is 60 fixed steps (\(steps))")
        ok(rig.gazeX.value > 0.7, "gaze settles toward a right-hand pointer (\(rig.gazeX.value))")
        ok(rig.gazeY.value < -0.5, "gaze settles downward for a pointer below (\(rig.gazeY.value))")
        ok(rig.gazeX.value <= 1.0 && rig.gazeY.value >= -1.0, "gaze stays inside its bounds")
        // idle drift: after a few still seconds the eyes stop staring dead ahead
        var still = LupyRig()
        still.movePointer(to: 600, 300)
        t2 = 0
        while t2 < 6.0 { still.step(dt: LupyFrameClock.step); t2 += LupyFrameClock.step }
        ok(abs(still.gazeX.value) < 0.9, "long stillness relaxes the gaze (\(still.gazeX.value))")
        // breathing is subtle but present, and never changes the silhouette materially
        var br = LupyRig()
        t2 = 0
        var lo = 9.0, hi = -9.0
        while t2 < 5.0 {
            br.step(dt: LupyFrameClock.step)
            let s2 = br.bodyScale.y
            if s2 < lo { lo = s2 }
            if s2 > hi { hi = s2 }
            t2 += LupyFrameClock.step
        }
        ok(hi - lo > 0.010, "breathing moves the body (range \(hi - lo))")
        ok(hi - 1 < 0.012, "breathing stays subtle (max +2%)")
        // eyes must stay fully inside the real dome, at every gaze, not just a box
        var worstOverhang = -9.0
        var worstAt = (0.0, 0.0)
        var yy = -1.0
        while yy <= 1.0001 {
            var xx = -1.0
            while xx <= 1.0001 {
                let fs = LupyEyes.frames(yaw: xx, pitch: yy, rx: 0.5,
                                         ry: 0.5 * LupyGeometry.bodyAspect, bodyWidth: 1)
                for f in fs {
                    let halfW = f.w * f.fx * 0.5
                    let halfH = f.h * f.fy * 0.5
                    // check both the eye's centre line and its top/bottom edges
                    var edges = [f.y]
                    edges.append(f.y + halfH * 0.85)
                    edges.append(f.y - halfH * 0.85)
                    for ey in edges {
                        let room = LupyBody.halfWidth(atY: ey)
                        let over = (abs(f.x) + halfW) - room
                        if over > worstOverhang {
                            worstOverhang = over
                            worstAt = (xx, yy)
                        }
                    }
                }
                xx += 0.05
            }
            yy += 0.05
        }
        ok(worstOverhang < 0.0,
           "eyes stay inside the silhouette at every gaze (worst overhang \(worstOverhang) at \(worstAt))")

        print("\n== machine mood ==")
        var v = LupyVitals()
        v.cpu = 0.92
        ok(v.mood(busySamples: 1).busy == 0, "one hot CPU sample is not enough (no panic)")
        ok(v.mood(busySamples: 2).busy > 0.9, "two hot samples pin the processor mood")
        var cool = LupyVitals(); cool.cpu = 0.3
        ok(cool.mood(busySamples: 4).busy == 0, "a normal CPU stays calm")
        var warm = LupyVitals(); warm.thermal = 2
        near(warm.mood(busySamples: 0).hot, 0.8, 1e-9, "thermal serious = warm 0.8")
        var fullm = LupyVitals(); fullm.memoryPressure = 2
        near(fullm.mood(busySamples: 0).full, 1.0, 1e-9, "memory critical = full 1.0")
        ok(fullm.overloaded(), "memory critical marks the machine overloaded")
        var lowbat = LupyVitals(); lowbat.batteryPercent = 15; lowbat.onPower = false
        near(lowbat.mood(busySamples: 0).tired, 1.0, 1e-9, "battery under 20 = tired")
        var dead = LupyVitals(); dead.batteryPercent = 8; dead.onPower = false
        ok(dead.mood(busySamples: 0).asleep, "battery under 10 = asleep")
        var plugged = LupyVitals(); plugged.batteryPercent = 8; plugged.onPower = true
        ok(!plugged.mood(busySamples: 0).asleep, "plugged in never sleeps")

        print("\n== states tell the truth ==")
        let white = LupyCharacterState.working.bodyColour
        ok(white.r == 1 && white.g == 1 && white.b == 1,
           "the body is pure white while working — colour lives in the light")
        var tight = LupyCharacterState.idle
        for st in LupyCharacterState.allCases where st.glowStrength > tight.glowStrength { tight = st }
        ok(LupyCharacterState.idle.glowStrength < LupyCharacterState.working.glowStrength,
           "working glows harder than idle")
        ok(LupyCharacterState.error.glowStrength > LupyCharacterState.working.glowStrength,
           "errors burn brighter than normal work")
        ok(LupyCharacterState.sleeping.glowStrength < LupyCharacterState.working.glowStrength,
           "a sleeping character is quiet")
        // vivid, not pastel: every state that carries a message is strongly saturated
        for st in LupyCharacterState.allCases where st != .idle && st != .sleeping {
            let t = st.tint
            let hi = max(t.r, t.g, t.b), lo = min(t.r, t.g, t.b)
            ok(hi > 0.95 && hi - lo > 0.45, "\(st.name) is a vivid RGB colour, not pastel")
        }
        var hues = Set<Int>()
        for st in LupyCharacterState.allCases where st != .idle {
            let t = st.tint
            let hi = max(t.r, t.g, t.b), lo = min(t.r, t.g, t.b)
            let d = hi - lo
            guard d > 0 else { hues.insert(0); continue }
            var h = 0.0
            if hi == t.r { h = (t.g - t.b) / d }
            else if hi == t.g { h = 2 + (t.b - t.r) / d }
            else { h = 4 + (t.r - t.g) / d }
            hues.insert(Int(((h * 60) + 360).truncatingRemainder(dividingBy: 360) / 12))
        }
        ok(hues.count >= 8, "\(hues.count) distinct hue families — states cannot be confused")
        var icons = Set<String>()
        for st in LupyCharacterState.allCases {
            if let icon = st.icon { icons.insert(icon.name) }
        }
        ok(icons.count == LupyCharacterState.allCases.count,
           "every state has its own icon, idle included")
        ok(LupyCharacterState.resolved(requested: .working, overloaded: true) == .dizzy,
           "an overloaded Mac makes Lupy dizzy while working")
        ok(LupyCharacterState.resolved(requested: .approval, overloaded: true) == .approval,
           "a question is never hidden by the machine's mood")
        var seen = Set<String>()
        for st in LupyCharacterState.allCases { seen.insert(st.label) }
        ok(seen.count == LupyCharacterState.allCases.count, "every state has its own sentence")

        print("\n== mood changes the body ==")
        var rigM = LupyRig()
        rigM.moodTarget = LupyMood(full: 1)
        var mm = 0
        while mm < 90 { rigM.step(dt: LupyFrameClock.step); mm += 1 }
        let puff = rigM.bodyScale
        ok(puff.x > 1.05, "memory pressure puffs the body out (\(puff.x))")
        var tiredRig = LupyRig()
        tiredRig.moodTarget = LupyMood(tired: 1)
        mm = 0
        while mm < 90 { tiredRig.step(dt: LupyFrameClock.step); mm += 1 }
        ok(tiredRig.effectiveEyeStyle == .halfLid, "a tired Mac gives him heavy lids")
        var sleepRig = LupyRig()
        sleepRig.moodTarget = LupyMood(asleep: true)
        mm = 0
        while mm < 90 { sleepRig.step(dt: LupyFrameClock.step); mm += 1 }
        ok(sleepRig.effectiveEyeStyle == .arch, "an empty battery closes his eyes")
        // The app draws what effectiveEyeStyle says. It used to ignore it, so the
        // character stayed wide awake on a sleeping machine.
        ok(sleepRig.eyes(bodyWidth: 1.0).allSatisfy { $0.style == .arch },
           "the drawn eyes are the overridden ones, not the raw state's")

        print("\n== composition ==")
        ok(LupyComposition.glowReach <= LupyComposition.frameHalf,
           "the strongest glow still fits inside the frame")
        // The badge rides the right rim: it must fit in the frame too, with the ring,
        // and it must actually touch the silhouette it is pinned to.
        ok(LupyComposition.badgeReach <= LupyComposition.frameHalf,
           "the state badge fits inside the frame, ring included")
        let bc = LupyComposition.badgeCentre()
        let rimAtBadge = LupyBody.halfWidth(atY: bc.y)
        ok(abs(bc.x - rimAtBadge) < 0.12,
           "the badge sits on the rim, not on his face")
        ok(bc.y > 0.2 && bc.y < 0.4,
           "the badge sits on the upper shoulder")
        // The sketch's proportions, normalised by the body's height (his blob is
        // 0.79 as tall as it is wide, ours 0.56 — width ratios over-scale his parts),
        // then converted back to body widths for our silhouette.
        near(LupyComposition.badgeRadius * 2, 0.197, 0.004,
             "the badge disc is the size measured off the sketch")
        near(LupyComposition.badgeRing, 0.035, 0.002,
             "the badge ring is as thick as the sketch's")
        // "half in character inside and half out": the ring's middle sits on the rim.
        near(bc.x - rimAtBadge,
             LupyComposition.badgeRadius + LupyComposition.badgeRing / 2, 1e-9,
             "the badge ring straddles the rim, half in and half out")
        ok(LupyComposition.badgeRadius < 0.105,
           "the badge is still small enough not to shout")
        // The spiral must have the same ink mass as the capsule it replaces.
        ok(LupyEyeStyle.spiral.spiralStroke >= 0.18,
           "the dizzy spiral is drawn with real ink, not a hairline")
        near(LupyComposition.unit(width: 200, height: 200), 144, 1e-9,
             "a 200 pt frame draws the body at 144 pt")
        ok(abs(LupyComposition.glowBlur - 0.09) < 1e-9,
           "the glow blur is the one number the app and the sheets share")
        ok(LupyComposition.unit(width: 24, height: 24) > 16,
           "the 24 pt menu-bar body is still bigger than half the frame")

        print("\n== the ∪∪ face the founder drew ==")
        // He chose closed lids as LUPY's resting face; open eyes only when he needs you.
        for st in [LupyCharacterState.idle, .working, .thinking, .searching, .finished] {
            ok(st.eyeStyle == .cup, "\(st.name) wears the calm ∪∪ lids")
        }
        for st in [LupyCharacterState.question, .approval, .error] {
            ok(st.eyeStyle != .cup, "\(st.name) opens his eyes: it needs something from you")
        }
        // Geometry, measured off the sketch, in body widths.
        near(LupyEyeStyle.cup.arcStroke * 0.139, 0.084, 0.004,
             "the lid's ink is the sketch's 0.084 of body width")
        near(LupyEyeStyle.cup.arcLift, 0.028, 0.002,
             "the lids ride where the sketch puts them")
        // A round cap adds half a stroke at each end: the path must keep the lids apart.
        let eyeSpan = LupyGeometry.eyeCentreX * 2
        let drawn = LupyEyeStyle.cup.arcSpan * LupyGeometry.eyeW + LupyEyeStyle.cup.arcStroke * LupyGeometry.eyeW
        ok(eyeSpan - drawn > 0.03,
           "the two lids never touch — they read as eyes, not a moustache")
        // Closed lids do not look around: the pointer must not drag them.
        var lookRig = LupyRig()
        lookRig.requestedState = .working
        lookRig.movePointer(to: 400, -200)
        var n = 0
        while n < 90 { lookRig.step(dt: LupyFrameClock.step); n += 1 }
        let closed = lookRig.eyes(bodyWidth: 1.0)
        ok(closed.allSatisfy { abs($0.x) < 0.18 },
           "a closed lid stays put instead of sliding with the mouse")
        // And they must fit inside the silhouette at their widest point.
        for f in closed {
            let halfSpan = LupyGeometry.eyeW * LupyEyeStyle.cup.arcSpan * 0.5
            let rim = LupyBody.halfWidth(atY: f.y)
            ok(abs(f.x) + halfSpan <= rim,
               "the closed lid is drawn inside his own rim")
        }

        print("\n== the words match the face ==")
        // The dots are drawn by the bubble, not typed into the label: one ellipsis only.
        ok(LupyCharacterState.working.bubbleText == "Working", "working reads Working")
        ok(LupyCharacterState.thinking.bubbleText == "Thinking", "thinking reads Thinking")
        ok(LupyCharacterState.searching.bubbleText == "Searching", "searching reads Searching")
        for st in LupyCharacterState.allCases {
            ok(!st.bubbleText.contains("…"),
               "\(st.name) carries no hard-coded ellipsis")
        }
        ok(LupyCharacterState.working.isOngoing && !LupyCharacterState.finished.isOngoing,
           "only a going concern animates its dots")
        var quiet = LupyVitals()
        ok(quiet.describe(quiet.mood(busySamples: 0), top: []) == nil,
           "a calm Mac has nothing to report")
        var pinnedRun = LupyVitals(); pinnedRun.cpu = 0.91
        let line = pinnedRun.describe(pinnedRun.mood(busySamples: 2), top: ["Xcode", "node"])
        ok(line == "CPU 91 % · Xcode, node", "the hover line names the processors (\(line ?? "nil"))")
        var hotRun = LupyVitals(); hotRun.thermal = 3
        ok(hotRun.describe(hotRun.mood(busySamples: 0), top: []) == "hot", "heat is reported")

        print("\n== the rig believes the machine ==")
        var fed = LupyRig()
        fed.requestedState = .working
        var critical = LupyVitals(); critical.memoryPressure = 2
        fed.apply(vitals: critical, busySamples: 0)
        ok(fed.state == .dizzy, "a memory-critical Mac overrides working with dizzy")
        var calmFeed = LupyVitals()
        fed.apply(vitals: calmFeed, busySamples: 0)
        ok(fed.state == .working, "when memory recovers, the task state returns")
        fed.requestedState = .approval
        fed.apply(vitals: critical, busySamples: 0)
        ok(fed.state == .approval, "a waiting question is never overridden")

        print("\n-------------------------------------------")
        if failures == 0 {
            print("RIGTESTS PASSED (\(checks) checks)")
        } else {
            print("RIGTESTS FAILED (\(failures) of \(checks))")
        }
    }
}

@main
struct Entry {
    static func main() {
        RigTests().main()
    }
}
