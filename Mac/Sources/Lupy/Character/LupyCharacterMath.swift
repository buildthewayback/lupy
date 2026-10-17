//  LupyCharacterMath.swift
//  Pure geometry + motion math for Lupy. NO SwiftUI, NO Foundation, NO CoreGraphics.
//
//  Why self-contained: this exact file compiles for the app (Xcode/macOS) *and* for
//  the sandbox Swift-on-WebAssembly test harness, so the numbers the tests verify are
//  the numbers the app runs. `node tools/swiftwasm/swiftc-wasm.mjs --run` executes it.
//
//  Everything is Double (CGFloat is Double on every 64-bit Apple platform).

// MARK: - Math kernel

/// Minimal trig/sqrt so this file needs no platform maths library.
/// Argument-reduced Taylor series; accurate to ~1e-14 over the ranges used here.
enum LM {
    static let pi = 3.14159265358979323846
    static let twoPi = 6.28318530717958647693
    static let deg = 57.29577951308232
    static let halfPi = 1.57079632679489661923

    /// Reduce to [-pi, pi].
    @inline(__always)
    static func wrap(_ x0: Double) -> Double {
        var x = x0
        if x > pi || x < -pi {
            x = x.truncatingRemainder(dividingBy: twoPi)
        }
        if x > pi { x -= twoPi }
        if x < -pi { x += twoPi }
        return x
    }

    static func sin(_ x0: Double) -> Double {
        let x = wrap(x0)
        let x2 = x * x
        var term = x
        var sum = x
        var n = 1
        while n < 12 {
            term *= -x2 / Double((2 * n) * (2 * n + 1))
            sum += term
            n += 1
        }
        return sum
    }

    @inline(__always)
    static func cos(_ x: Double) -> Double { sin(x + halfPi) }

    static func sqrt(_ v: Double) -> Double {
        if v <= 0 { return 0 }
        var g = v > 1 ? v : 1.0
        var i = 0
        while i < 48 {
            g = 0.5 * (g + v / g)
            i += 1
        }
        return g
    }

    static func exp(_ x0: Double) -> Double {
        let x = max(-60, min(60, x0))
        // x = k*ln2 + r, r in [-0.35, 0.35]
        let k = (x / 0.6931471805599453).rounded()
        let r = x - k * 0.6931471805599453
        var term = 1.0
        var sum = 1.0
        var n = 1
        while n < 18 {
            term *= r / Double(n)
            sum += term
            n += 1
        }
        // 2^k by repeated squaring
        var scale = 1.0
        var base = 2.0
        var e = Int(k)
        if e >= 0 {
            while e > 0 {
                if e % 2 == 1 { scale *= base }
                base *= base
                e /= 2
            }
        } else {
            e = -e
            base = 0.5
            while e > 0 {
                if e % 2 == 1 { scale *= base }
                base *= base
                e /= 2
            }
        }
        return sum * scale
    }

    static func tanh(_ x: Double) -> Double {
        if x > 20 { return 1 }
        if x < -20 { return -1 }
        let e2 = exp(2 * x)
        return (e2 - 1) / (e2 + 1)
    }

    @inline(__always)
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    @inline(__always)
    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        v < lo ? lo : (v > hi ? hi : v)
    }

    /// floor() without Foundation.
    @inline(__always)
    static func floor(_ v: Double) -> Double {
        let r = v.truncatingRemainder(dividingBy: 1)
        return v < 0 && r != 0 ? v - r - 1 : v - r
    }

    @inline(__always)
    static func rounded(_ v: Double) -> Double {
        v < 0 ? -floor(-v + 0.5) : floor(v + 0.5)
    }

    /// Fixed-point formatting without Foundation (`String(format:)` is unavailable).
    static func fixed(_ value: Double, _ decimals: Int = 4) -> String {
        var scale = 1.0
        var i = 0
        while i < decimals { scale *= 10; i += 1 }
        let scaled = rounded(value * scale)
        let negative = scaled < 0
        let magnitude = negative ? -scaled : scaled
        let whole = floor(magnitude / scale)
        let frac = rounded(magnitude - whole * scale)
        var wholeInt = Int(whole)
        if wholeInt < 0 { wholeInt = -wholeInt }
        var fracText = ""
        var f = Int(frac)
        var digits = decimals
        while digits > 0 {
            fracText = String(f % 10) + fracText
            f /= 10
            digits -= 1
        }
        _ = frac
        return (negative ? "-" : "") + String(wholeInt) + (decimals > 0 ? "." + fracText : "")
    }
}

// MARK: - Gaze

/// Where Lupy looks, from the pointer position.
///
/// `tanh` gives a soft saturation: the eyes track precisely near the centre and stop
/// at the body edge instead of clipping. Falloff constants are in points and match
/// the feel of a 260/200 pt reference radius (the same softness Coucou's bot uses).
enum LupyGaze {
    /// Falloff is a multiple of the drawn body width, NOT a fixed number of points.
    /// A fixed falloff looks right at one size and breaks at every other: at 24 px in
    /// the notch menu bar the eyes would saturate on any mouse position and stick to
    /// the rim. Proportional falloff keeps the same feel from 24 px to 400 px.
    static let falloffX: Double = 0.95
    static let falloffY: Double = 0.73

    static func from(pointerX: Double, pointerY: Double,
                     centreX: Double, centreY: Double,
                     bodyWidth: Double) -> (yaw: Double, pitch: Double) {
        let fx = max(1.0, bodyWidth * falloffX)
        let fy = max(1.0, bodyWidth * falloffY)
        let yaw = LM.tanh((pointerX - centreX) / fx)
        let pitch = -LM.tanh((pointerY - centreY) / fy)
        return (yaw, pitch)
    }
}

// MARK: - Eye projection

/// One eye's position on the body "sphere", after yaw/pitch.
/// Offsets are from the **body centre**, in body-width units, +y up — the same space
/// as `LupyBody.polygon()`.
struct LupyEyeFrame: Equatable {
    var side: Double      // -1 left, +1 right
    var x: Double         // centre offset, body-width units
    var y: Double         // centre offset, body-width units, +y up
    var fx: Double        // horizontal scale (foreshortening)
    var fy: Double        // vertical scale
    var visible: Bool
    var w: Double
    var h: Double
    var style: LupyEyeStyle = .capsule
}

enum LupyEyes {
    // The eyes live on the body's surface, i.e. on an ellipse of half-width rx and
    // half-height ry. Their rest position is a measured latitude/longitude on it,
    // solved so the rest pose reproduces the reference art EXACTLY (not approximately):
    //
    //   spec: centre_x = 0.1644 body-widths, centre_y_from_bottom = 0.3409
    //   body centre      = 0.8021 / 2 = 0.40105
    //   rest latitude    = asin(-(0.40105 - 0.3409) / 0.40105)   = -0.15055 rad
    //   rest longitude   = asin( 0.1644 / (0.5 * cos(latitude)))  =  0.33898 rad
    /// Solved at first use from the measured eye metrics and the real silhouette,
    /// so the rest pose reproduces the reference exactly and stays correct even if
    /// the outline is re-measured.
    static let neutralYaw: Double = solveAngle(sinTarget:
        LupyGeometry.eyeCentreX /
        LupyBody.halfWidth(atY: LupyGeometry.eyeCentreYFromBase - LupyGeometry.bodyAspect * 0.5))
    static let neutralPitch: Double = solveAngle(sinTarget:
        (LupyGeometry.bodyAspect * 0.5 - LupyGeometry.eyeCentreYFromBase) /
        (LupyGeometry.bodyAspect * 0.5))

    /// Inverse sine by bisection — no Foundation, no libm, exact to well under 1e-12.
    private static func solveAngle(sinTarget: Double) -> Double {
        let target = LM.clamp(sinTarget, 0, 1)
        var lo = 0.0
        var hi = LM.halfPi
        var i = 0
        while i < 60 {
            let mid = (lo + hi) * 0.5
            if LM.sin(mid) < target { lo = mid } else { hi = mid }
            i += 1
        }
        return (lo + hi) * 0.5
    }

    /// Apparent eye size at rest, so `fx`/`fy` == 1 exactly in the neutral pose.
    private static let restFX = LM.cos(neutralYaw)
    private static let restFY = LM.cos(neutralPitch)

    /// Eye frames for a look direction.
    /// - Parameters:
    ///   - yaw: -1...+1 horizontal look (positive = to the viewer's right)
    ///   - pitch: -1...+1 vertical look (positive = UP)
    ///   - rx: body half-width in points
    ///   - ry: body half-height in points
    ///   - bodyWidth: full body width in points (eye size basis)
    static func frames(yaw: Double, pitch: Double,
                       rx: Double, ry: Double, bodyWidth: Double,
                       style: LupyEyeStyle = .capsule) -> [LupyEyeFrame] {
        var out: [LupyEyeFrame] = []
        for side in [-1.0, 1.0] {
            // Look direction rotates both eyes on the sphere. The eyes are below the
            // equator at rest, so latitude is negative; looking up raises it.
            //
            // Travel is deliberately smaller than a small-eyed character would use:
            // Lupy's eyes are 36% of body height, so a full 1 rad swing would jam them
            // against the rim and squash the far eye into a sliver. A third of a radian
            // still reads unmistakably as "looking there", with the far eye only lightly
            // foreshortened — composed, not googly.
            let longitude = side * neutralYaw + yaw * 0.30
            let latitude = -neutralPitch + pitch * 0.32
            let cl = LM.cos(latitude)
            let visible = LM.cos(longitude) * cl > 0.04

            // Vertical position comes from the sphere; the horizontal one is placed
            // on the *actual* silhouette. The eye is a tall capsule, so the room is the
            // narrowest point of the dome across the eye's full height — that is what
            // stops a corner of the eye poking through the rim.
            let ey = LM.sin(latitude) * (ry / bodyWidth)
            let fy = LM.clamp(cl / restFY, 0.18, 1.15)
            let halfH = LupyGeometry.eyeH * fy * 0.5
            let hwCentre = LupyBody.halfWidth(atY: ey)
            var room = hwCentre
            for k in [-0.85, 0.85] {
                let edge = LupyBody.halfWidth(atY: ey + halfH * k)
                if edge < room { room = edge }
            }
            let fx = LM.clamp(LM.cos(longitude) / restFX, 0.18, 1.15)
            var ex = LM.sin(longitude) * hwCentre
            let limit = room - LupyGeometry.eyeW * fx * 0.5 - 0.008
            if ex > limit { ex = limit }
            if ex < -limit { ex = -limit }

            out.append(LupyEyeFrame(
                side: side,
                x: ex,
                y: ey,
                // Both axes foreshorten: longitude squashes horizontally as the eye
                // swings away from the viewer, latitude squashes it vertically as it
                // rolls over the top of the head. Floored so it never hits a line.
                fx: fx,
                fy: fy,
                visible: visible,
                w: LupyGeometry.eyeW,
                h: LupyGeometry.eyeH,
                style: style
            ))
        }
        return out
    }
}

// MARK: - Composition

/// How the character is placed in a square-ish frame.
///
/// The body is not the whole picture: its light bleeds past the silhouette, and the
/// light is the message. Drawing the body at 94 % of the frame clipped the glow at the
/// edge. 82 % leaves room for a strong light on every side, and gives the status bubble
/// above the head somewhere to live.
enum LupyComposition {
    static let unitFraction: Double = 0.72

    /// The state badge rides the character's right rim, the way the founder's sketch
    /// pins it to the shoulder: the dark ring just kisses the silhouette, so the badge
    /// is attached to him rather than stuck on his face.
    ///
    /// Measured from that sketch, in body widths: the disc is 0.121 across, the ring
    /// 0.165, the ring is 0.023 thick, and the badge's centre sits 0.129 below the top
    /// of the body, 0.087 beyond the rim at that height.
    static let badgeRadius: Double = 0.0605        // the coloured disc
    static let badgeRing: Double = 0.0225          // the dark ring around it
    /// How far below the top of the body the badge's centre sits, as a fraction of
    /// body height. 0.129 measured off the sketch.
    static let badgeDrop: Double = 0.129
    /// How much the ring overlaps the silhouette, in body widths.
    static let badgeOverlap: Double = 0.004

    /// The badge's centre, on the right rim of whatever silhouette we ship. Computed
    /// from the real body path, so it stays on the shoulder at every body shape.
    static func badgeCentre() -> (x: Double, y: Double) {
        let bounds = LupyBody.bounds()
        let top = bounds.minY + bounds.h          // the apex, in body coordinates
        let y = top - badgeDrop * bounds.h
        let rim = LupyBody.halfWidth(atY: y)
        let x = rim + badgeRing + badgeRadius - badgeOverlap
        return (x, y)
    }

    /// How far right the badge reaches, in body widths.
    static var badgeReach: Double {
        badgeCentre().x + badgeRadius + badgeRing
    }
    /// Blur radius of the light, in body widths.
    static let glowBlur: Double = 0.09
    /// How far the light reaches, in body widths: half a body plus two blur radii.
    static var glowReach: Double { 0.5 + 2 * glowBlur }
    /// Half the frame, in body widths. The light must fit inside this.
    static var frameHalf: Double { 0.5 / unitFraction }

    static func unit(width: Double, height: Double) -> Double {
        min(width, height) * unitFraction
    }
}

// MARK: - Body path

/// One cubic Bézier segment of the silhouette, in local units (y up).
struct LupyBezier {
    var x0: Double, y0: Double
    var x1: Double, y1: Double
    var x2: Double, y2: Double
    var x3: Double, y3: Double

    func point(at t: Double) -> (Double, Double) {
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return (a * x0 + b * x1 + c * x2 + d * x3,
                a * y0 + b * y1 + c * y2 + d * y3)
    }

    /// SVG path fragment (`C` command, SVG y-down) for the vector export.
    func svg(bx: Double, by: Double, scale: Double) -> String {
        func f(_ v: Double) -> String { LM.fixed(v) }
        return "C \(f(x1 * scale + bx)) \(f(-y1 * scale + by)) "
             + "\(f(x2 * scale + bx)) \(f(-y2 * scale + by)) "
             + "\(f(x3 * scale + bx)) \(f(-y3 * scale + by))"
    }
}

enum LupyBody {
    /// How many control points the smooth path is fitted through. The measured
    /// outline has 152 points; resampling to a uniform 64 by arc length gives even
    /// segment lengths, which keeps the Catmull-Rom fit free of overshoot.
    static let controlCount = 64

    /// The measured outline, shifted so the body centre is the origin.
    static func centredOutline() -> [(Double, Double)] {
        let half = LupyGeometry.bodyAspect * 0.5
        return LupyGeometry.outline.map { ($0.0, $0.1 - half) }
    }

    /// Resample a closed polyline at equal arc-length intervals.
    static func resample(_ pts: [(Double, Double)], count: Int) -> [(Double, Double)] {
        let n = pts.count
        var cumulative: [Double] = [0]
        var total = 0.0
        var i = 0
        while i < n {
            let a = pts[i]
            let b = pts[(i + 1) % n]
            total += LM.sqrt((b.0 - a.0) * (b.0 - a.0) + (b.1 - a.1) * (b.1 - a.1))
            cumulative.append(total)
            i += 1
        }
        if total <= 0 { return pts }

        var out: [(Double, Double)] = []
        out.reserveCapacity(count)
        var seg = 0
        var k = 0
        while k < count {
            let target = total * Double(k) / Double(count)
            while seg < n - 1, cumulative[seg + 1] < target { seg += 1 }
            let span = cumulative[seg + 1] - cumulative[seg]
            let t = span > 1e-12 ? (target - cumulative[seg]) / span : 0
            let a = pts[seg]
            let b = pts[(seg + 1) % n]
            out.append((a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t))
            k += 1
        }
        return out
    }

    /// The silhouette as cubic Béziers. This is what the app strokes: a handful of
    /// smooth curve segments, never a polygon, so it stays crisp at any scale.
    static func beziers() -> [LupyBezier] {
        let p = resample(centredOutline(), count: controlCount)
        let n = p.count
        var out: [LupyBezier] = []
        out.reserveCapacity(n)
        var i = 0
        while i < n {
            let p0 = p[(i - 1 + n) % n]
            let p1 = p[i]
            let p2 = p[(i + 1) % n]
            let p3 = p[(i + 2) % n]
            // Catmull-Rom -> Bézier: control points a third of the way along the
            // neighbouring chords, which is exactly C1 continuous at every joint.
            out.append(LupyBezier(
                x0: p1.0, y0: p1.1,
                x1: p1.0 + (p2.0 - p0.0) / 6, y1: p1.1 + (p2.1 - p0.1) / 6,
                x2: p2.0 - (p3.0 - p1.0) / 6, y2: p2.1 - (p3.1 - p1.1) / 6,
                x3: p2.0, y3: p2.1
            ))
            i += 1
        }
        return out
    }

    /// Flattened silhouette (used by the rasterising test harness and for hit tests).
    static func polygon(samplesPerSegment: Int = 8) -> [(Double, Double)] {
        var out: [(Double, Double)] = []
        for b in beziers() {
            var s = 0
            while s < samplesPerSegment {
                out.append(b.point(at: Double(s) / Double(samplesPerSegment)))
                s += 1
            }
        }
        return out
    }

    /// The silhouette flattened once, for fast containment queries.
    static let silhouette: [(Double, Double)] = polygon(samplesPerSegment: 8)

    /// Half-width of the body at a given height. This is what keeps the eyes on the
    /// character: the body is a dome, so there is less room for the eyes up high than
    /// at the equator, and a sphere-only projection would let them overhang the rim.
    static func halfWidth(atY y: Double) -> Double {
        var best = 0.0
        let n = silhouette.count
        var i = 0
        while i < n {
            let a = silhouette[i]
            let b = silhouette[(i + 1) % n]
            if (a.1 - y) * (b.1 - y) <= 0 && abs(a.1 - b.1) > 1e-12 {
                let t = (y - a.1) / (b.1 - a.1)
                let x = a.0 + (b.0 - a.0) * t
                let ax = x < 0 ? -x : x
                if ax > best { best = ax }
            }
            i += 1
        }
        return best
    }

    /// Exact bounds of the smooth silhouette in local units.
    /// Callers scale by `targetWidth / bounds.w` to land on an exact target width.
    static func bounds() -> (w: Double, h: Double, minX: Double, minY: Double) {
        var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9
        for p in polygon(samplesPerSegment: 12) {
            if p.0 < minX { minX = p.0 }
            if p.0 > maxX { maxX = p.0 }
            if p.1 < minY { minY = p.1 }
            if p.1 > maxY { maxY = p.1 }
        }
        return (maxX - minX, maxY - minY, minX, minY)
    }

    /// Largest deviation of the smooth path from the measured outline, in body-width
    /// units. The rig test asserts this stays tiny, i.e. smoothing never redraws Lupy.
    static func fitError() -> Double {
        let raw = centredOutline()
        let poly = polygon(samplesPerSegment: 12)
        var worst = 0.0
        for r in raw {
            var best = 1e9
            for p in poly {
                let dx = p.0 - r.0
                let dy = p.1 - r.1
                let d = dx * dx + dy * dy
                if d < best { best = d }
            }
            let d = LM.sqrt(best)
            if d > worst { worst = d }
        }
        return worst
    }
}

// MARK: - Motion

/// Damped spring, integrated semi-implicitly.
/// `omega` is the natural frequency (rad/s) — larger is snappier.
/// `zeta` is damping: 1.0 is critically damped, <1 overshoots (that is the charm).
struct LupySpring {
    var value: Double
    var target: Double
    var velocity: Double = 0
    var omega: Double = 18
    var zeta: Double = 0.62

    mutating func step(dt: Double) {
        let accel = omega * omega * (target - value) - 2 * zeta * omega * velocity
        velocity += accel * dt
        value += velocity * dt
    }
}

/// Fixed-timestep driver.
///
/// One animation step per `step` seconds NO MATTER the display refresh rate. This is
/// the fix for a real bug in the reference implementation: stepping once per frame
/// makes the character run at double speed on a 120 Hz ProMotion panel.
struct LupyFrameClock {
    static let step: Double = 1.0 / 60.0
    private var accumulator: Double = 0
    private(set) var ticks: Int = 0

    mutating func advance(dt: Double, body: () -> Void) {
        accumulator += min(dt, 0.25)      // never spiral after a stall
        while accumulator >= LupyFrameClock.step {
            body()
            accumulator -= LupyFrameClock.step
            ticks += 1
        }
    }
}

// MARK: - Blink

/// Randomised, non-metronomic blinking. A perfectly regular blink reads as robotic.
struct LupyBlink {
    var open: Double = 1
    private var nextAt: Double
    private var since: Double = 0
    private var closing: Double = -1
    var seed: UInt64 = 0x9E3779B97F4A7C15

    init(firstBlinkIn seconds: Double = 2.6) {
        nextAt = seconds
    }

    private mutating func rand() -> Double {
        // xorshift64* — deterministic, no Foundation
        seed ^= seed >> 12
        seed ^= seed << 25
        seed ^= seed >> 27
        let v = (seed &* 0x2545F4914F6CDD1D) >> 11
        return Double(v % 10_000) / 10_000.0
    }

    mutating func step(dt: Double) {
        since += dt
        if closing < 0, since >= nextAt {
            closing = 0
        }
        if closing >= 0 {
            closing += dt
            let d = closing / 0.12          // 120 ms close, 120 ms open
            open = d < 1 ? 1 - d : (d < 2 ? d - 1 : 1)
            if closing >= 0.24 {
                closing = -1
                since = 0
                nextAt = 2.2 + rand() * 4.0  // 2.2 s ... 6.2 s
            }
        }
    }
}

// MARK: - Rig

/// The live character state. One instance owns everything that moves.
///
/// Held by the SwiftUI view and stepped at a fixed rate; it deliberately has no
/// dependency on SwiftUI, AppKit or Foundation so it can be exercised headlessly.
struct LupyRig {
    // Where the pointer is, in points, in the same space as the body centre.
    var pointerX: Double = 0
    var pointerY: Double = 0
    var pointerSeen = false

    /// Seconds since the pointer last moved. Used to stop the eyes "staring".
    var pointerIdleTime: Double = 0
    private var lastPointerX: Double = 0
    private var lastPointerY: Double = 0

    /// Smoothed gaze, so the eyes glide instead of snapping to the pointer.
    /// Slightly under-damped: a hint of settle, never a wobble.
    var gazeX = LupySpring(value: 0, target: 0, omega: 16, zeta: 0.88)
    var gazeY = LupySpring(value: 0, target: 0, omega: 16, zeta: 0.88)

    /// Width the character is currently drawn at, in points. Gaze falloff and eye
    /// placement are both derived from it, so nothing is size-dependent.
    var bodyWidth: Double = 200

    /// What the task wants the character to show.
    var requestedState: LupyCharacterState = .idle
    /// Set from real memory pressure: an overloaded Mac overrides the task's state.
    var machineOverloaded = false
    /// What is actually drawn. Drives the eyes, the light and the status bubble.
    /// Never the silhouette.
    var state: LupyCharacterState {
        LupyCharacterState.resolved(requested: requestedState, overloaded: machineOverloaded)
    }

    /// How the machine feels. Eased towards `moodTarget` so nothing snaps.
    var mood = LupyMood()
    var moodTarget = LupyMood()

    var blink = LupyBlink()
    var time: Double = 0
    var pointerActive = true

    /// Random-looking idle wander, so a still character still feels alive.
    private var wanderSeed: UInt64 = 0x243F6A8885A308D3
    private var wanderX: Double = 0
    private var wanderY: Double = 0

    init() {}

    private mutating func nextRandom() -> Double {
        wanderSeed ^= wanderSeed >> 12
        wanderSeed ^= wanderSeed << 25
        wanderSeed ^= wanderSeed >> 27
        let v = (wanderSeed &* 0x2545F4914F6CDD1D) >> 11
        return Double(v % 10_000) / 10_000.0
    }

    mutating func movePointer(to x: Double, _ y: Double) {
        if !pointerSeen {
            pointerSeen = true
            lastPointerX = x
            lastPointerY = y
        }
        if (x - lastPointerX) * (x - lastPointerX) + (y - lastPointerY) * (y - lastPointerY) > 0.25 {
            pointerIdleTime = 0
        }
        lastPointerX = x
        lastPointerY = y
        pointerX = x
        pointerY = y
        pointerActive = true
    }

    mutating func pointerLeft() {
        pointerActive = false
    }

    /// The eyes actually drawn: mood can override the state's shape (heavy lids when
    /// tired, closed when asleep), but a state that is *already* explicit wins.
    var effectiveEyeStyle: LupyEyeStyle {
        if mood.asleep { return .arch }
        if mood.tired > 0.5 && (state == .idle || state == .working) { return .halfLid }
        if state == .dizzy { return .spiral }
        return state.eyeStyle
    }

    /// Feed a fresh system reading in. Called at most every three seconds; the rig
    /// eases towards it, so the character never snaps between two moods.
    mutating func apply(vitals: LupyVitals, busySamples: Int) {
        moodTarget = vitals.mood(busySamples: busySamples)
        machineOverloaded = vitals.overloaded()
    }

    /// One fixed step (LupyFrameClock.step).
    mutating func step(dt: Double) {
        time += dt
        pointerIdleTime += dt

        // mood eases in ~0.4 s, the same feel as Coucou's 1 - 0.25^dt
        let k = 1 - LM.exp(-dt / 0.42)
        mood.busy += (moodTarget.busy - mood.busy) * k
        mood.hot += (moodTarget.hot - mood.hot) * k
        mood.full += (moodTarget.full - mood.full) * k
        mood.tired += (moodTarget.tired - mood.tired) * k
        mood.asleep = moodTarget.asleep

        var targetX = 0.0
        var targetY = 0.0
        if pointerActive && pointerSeen {
            let g = LupyGaze.from(pointerX: pointerX, pointerY: pointerY,
                                  centreX: 0, centreY: 0, bodyWidth: bodyWidth)
            targetX = g.yaw
            targetY = g.pitch
        }

        // After a couple of seconds without movement the gaze settles and drifts,
        // instead of staying pinned to a stale pointer position like a dead thing.
        let idle = LM.clamp((pointerIdleTime - 2.2) / 1.6, 0, 1)
        if idle > 0 {
            wanderX += (nextRandom() - 0.5) * dt * 0.6
            wanderY += (nextRandom() - 0.5) * dt * 0.6
            wanderX = LM.clamp(wanderX, -0.30, 0.30)
            wanderY = LM.clamp(wanderY, -0.18, 0.18)
            targetX = targetX * (1 - idle) + wanderX * idle
            targetY = targetY * (1 - idle) + wanderY * idle
        } else {
            wanderX *= 0.98
            wanderY *= 0.98
        }

        gazeX.target = targetX
        gazeY.target = targetY
        gazeX.step(dt: dt)
        gazeY.step(dt: dt)
        blink.step(dt: dt)
    }

    /// The openness to *draw*. A fully closed blink would erase the eyes and leave a
    /// blank face; a real blink leaves a thin line of ink. Never draw nothing.
    var drawnBlinkOpen: Double { max(0.12, blink.open) }

    /// Breathing: a slow, tiny vertical swell. A pinned processor makes it faster —
    /// the character is panting, which is the whole point of the mood system.
    var breath: Double {
        let period = 4.4 - 2.1 * mood.busy
        return LM.sin(time * (LM.twoPi / period))
    }

    var bodyScale: (x: Double, y: Double) {
        let b = breath
        var sx = 1 - 0.0045 * b
        var sy = 1 + 0.0075 * b
        // memory short: puffed up, like Coucou's full-memory pose
        sx *= 1 + 0.07 * mood.full
        sy *= 1 - 0.035 * mood.full
        // pins him down a touch when the machine is overloaded
        let stress = max(mood.busy, mood.full)
        sx *= 1 - 0.006 * stress
        sy *= 1 - 0.006 * stress
        return (sx, sy)
    }

    /// A small tremble for a pinned processor. Zero when calm, so stills stay clean.
    var tremble: (x: Double, y: Double) {
        guard mood.busy > 0.02 else { return (0, 0) }
        let a = min(1, mood.busy * 1.3)
        return (LM.sin(time * 63) * 0.004 * a, LM.cos(time * 51) * 0.003 * a)
    }

    /// Eye frames for the current state.
    func eyes(bodyWidth: Double) -> [LupyEyeFrame] {
        let rx = bodyWidth * 0.5
        let ry = bodyWidth * 0.5 * LupyGeometry.bodyAspect
        return LupyEyes.frames(yaw: gazeX.value, pitch: gazeY.value,
                               rx: rx, ry: ry, bodyWidth: bodyWidth,
                               style: state.eyeStyle)
    }
}

// MARK: - States

/// How the eye is deformed for a state. The silhouette and the eye *colour law*
/// (solid black, no pupil, no highlight) never change — only the capsule's shape.
enum LupyEyeStyle {
    /// The signature: tall solid-black capsule.
    case capsule
    /// Slightly taller and wider — attention, approval, surprise.
    case wide
    /// Flattened dash — error, annoyance.
    case dash
    /// Lid down to a slit — rate limit, sleepy.
    case halfLid
    /// Wide arc bowing UP (∩∩) — sleeping, closed.
    case arch
    /// Wide arc bowing DOWN (∪∪) — finished, happy.
    case cup
    /// Thin spiral — dizzy. Still solid ink, still no pupil.
    case spiral
}

extension LupyEyeStyle {
    /// The one place the drawn shape of an eye is defined. Both the AppKit/SwiftUI
    /// renderer and the offline sheet read these numbers, so the character can never
    /// drift between the app and the documentation.
    var capsuleScale: (x: Double, y: Double) {
        switch self {
        case .capsule: return (1.00, 1.00)
        case .wide:    return (1.16, 1.06)
        case .dash:    return (1.12, 0.20)
        case .halfLid: return (1.30, 0.28)
        default:       return (1.00, 1.00)
        }
    }

    /// Half the span of a stroked arc eye, as a multiple of the eye's own width.
    var arcSpan: Double { 1.32 }
    /// How far the arc bows, as a fraction of body width. Negative = ∪ (down), positive = ∩ (up).
    var arcBow: Double { 0.052 }
    /// Stroke weight, as a fraction of the eye's drawn width.
    var arcStroke: Double { 0.46 }

    /// Spiral ink, as a fraction of the eye's width. Coucou draws its dizzy spiral at
    /// 0.22 of the eye width; anything thinner reads as a hairline next to the fat
    /// capsule eyes of every other state, and the character stops looking like itself.
    var spiralStroke: Double { 0.20 }
    /// How fast the dizzy spiral turns, in radians per second.
    var spiralSpin: Double { 3.4 }

    /// The spiral itself: two full turns growing from the centre, sized to fill the
    /// same visual mass as a capsule eye.
    static let spiralTurns: Double = 12.566   // 4π
    static func spiralPoint(_ a: Double, centreX: Double, centreY: Double, unit: Double)
        -> (x: Double, y: Double) {
        let r = unit * (0.006 + 0.0094 * a)
        return (centreX + r * LM.cos(a), centreY - r * LM.sin(a) * 0.92)
    }
}

/// The 11 states from the reference sheet.
///
/// Named `LupyCharacterState`, not `LupyState`: LupyCore already exports a `LupyState`
/// (the assistant's whole-app state). Two types with one name in one module silently
/// broke the Control pages at build time — the same class of bug as `LupyClock`. A state changes the eyes, the hue of the
/// light around the body, and the icon in the status bubble. It never changes the body.
enum LupyCharacterState: Int, CaseIterable {
    case idle, working, thinking, searching, approval, question
    case error, finished, rateLimit, sleeping, dizzy

    var eyeStyle: LupyEyeStyle {
        switch self {
        case .idle, .working, .thinking, .searching, .question: return .capsule
        case .approval: return .wide
        case .error: return .dash
        case .rateLimit: return .halfLid
        case .sleeping: return .arch
        case .finished: return .cup
        case .dizzy: return .spiral
        }
    }

    var name: String {
        switch self {
        case .idle: return "idle"
        case .working: return "working"
        case .thinking: return "thinking"
        case .searching: return "searching"
        case .approval: return "approval"
        case .question: return "question"
        case .error: return "error"
        case .finished: return "finished"
        case .rateLimit: return "rate_limit"
        case .sleeping: return "sleeping"
        case .dizzy: return "dizzy"
        }
    }

    /// Black ink on a bright circle, white ink on a deep one. A glyph that cannot be
    /// read is worse than no glyph.
    var iconInkIsDark: Bool {
        let t = tint
        let luminance = 0.2126 * t.r + 0.7152 * t.g + 0.0722 * t.b
        return luminance > 0.52
    }

    /// The body is #FFFFFF in every single state. Not a tint, not a shade.
    var bodyColour: (r: Double, g: Double, b: Double) { (1, 1, 1) }

    /// Colour of the light around Lupy — vivid RGB, full saturation, never pastel.
    ///
    /// These are deliberately loud: a glow that has to be recognised in a quarter of
    /// a second from across a desk cannot be a tint. Each one is a distinct hue, so
    /// no two states can be confused even at a glance.
    var tint: (r: Double, g: Double, b: Double) {
        switch self {
        case .idle:     return (1.000, 1.000, 1.000)   // #FFFFFF  white light
        case .working:  return (0.039, 0.518, 1.000)   // #0A84FF  electric blue
        case .thinking: return (0.608, 0.188, 1.000)   // #9B30FF  violet
        case .searching:return (0.231, 0.306, 1.000)   // #3B4EFF  indigo
        case .approval: return (1.000, 0.702, 0.000)   // #FFB300  amber
        case .question: return (0.000, 0.835, 1.000)   // #00D5FF  cyan
        case .error:    return (1.000, 0.122, 0.122)   // #FF1F1F  red
        case .finished: return (0.000, 1.000, 0.353)   // #00FF5A  green
        case .rateLimit:return (1.000, 0.478, 0.000)   // #FF7A00  orange
        case .sleeping: return (0.310, 0.357, 1.000)   // #4F5BFF  deep blue
        case .dizzy:    return (1.000, 0.180, 0.604)   // #FF2E9A  magenta
        }
    }

    /// How hard the state's light burns behind him.
    ///
    /// The body is **pure white in every state** — that is brand law, and it is the
    /// reason the character reads as one thing everywhere. The state speaks through
    /// the light around him, and through how much of it there is: a sleeping character
    /// glows faintly, a character that needs you burns.
    var glowStrength: Double {
        switch self {
        case .idle: return 0.24
        case .sleeping: return 0.34
        case .working, .thinking, .searching: return 0.60
        case .finished: return 0.60
        case .approval, .question, .error, .rateLimit, .dizzy: return 0.80
        }
    }

    /// The sentence that goes with the face. The island shows this; the eyes agree with it.
    var label: String {
        switch self {
        case .idle: return "Ready"
        case .working: return "Working"
        case .thinking: return "Thinking"
        case .searching: return "Searching"
        case .approval: return "Waiting for your OK"
        case .question: return "Has a question"
        case .error: return "Something broke"
        case .finished: return "Done"
        case .rateLimit: return "Rate limited"
        case .sleeping: return "Asleep"
        case .dizzy: return "Overloaded"
        }
    }

    /// True while the state is still going, so the bubble knows to animate its dots.
    var isOngoing: Bool {
        switch self {
        case .working, .thinking, .searching: return true
        default: return false
        }
    }

    /// What the bubble says. **No ellipsis is baked in**: while a state is ongoing the
    /// bubble appends three animated dots, so a literal "…" here would print
    /// "Working… · · ·" — two ellipses fighting each other.
    var bubbleText: String { label }

    /// The single small overlay allowed per state.
    /// The icon that represents this state, in the circle on the right of the
    /// status bubble. Every state has its own; none of them is decoration.
    var icon: LupyStateIcon? {
        switch self {
        case .idle:      return .standby
        case .working:   return .gear        // machinery doing work
        case .thinking:  return .bulb        // an idea forming
        case .searching: return .magnifier   // looking for something
        case .approval:  return .bell        // someone is waiting for you
        case .question:  return .question    // it needs an answer
        case .error:     return .exclamation // something is wrong
        case .finished:  return .check       // it is done
        case .rateLimit: return .clock       // wait, then try again
        case .sleeping:  return .zzz         // nothing is happening
        case .dizzy:     return .spiral      // the machine is overloaded
        }
    }
}

// MARK: - The machine's body language

/// How the Mac feels, 0...1 each — the same five channels Coucou's Mochi shows.
/// Continuous on purpose: the body language eases between levels, never snaps.
struct LupyMood: Equatable {
    var busy: Double = 0      // processor pinned: tremble, fast breath, darting eyes
    var hot: Double = 0       // warm: flushed tint, heat
    var full: Double = 0      // memory short: puffs up
    var tired: Double = 0     // battery low: heavy lids
    var asleep = false        // battery nearly empty
}

/// Raw system readings. In the app these come from host_statistics / thermalState /
/// DispatchSourceMemoryPressure / IOPS; in tests they are just numbers.
struct LupyVitals: Equatable {
    var cpu: Double = 0              // 0...1, last sample
    var thermal: Int = 0             // 0 nominal, 1 fair, 2 serious, 3 critical
    var memoryPressure: Int = 0      // 0 normal, 1 warning, 2 critical
    var batteryPercent: Int? = nil   // nil on a desktop Mac
    var onPower = true

    /// Apply Coucou's rules, including "two samples in a row or it does not count".
    func mood(busySamples: Int) -> LupyMood {
        var m = LupyMood()
        m.busy = busySamples >= 2 ? LM.clamp((cpu - 0.6) / 0.3, 0, 1) : 0
        switch thermal {
        case 1: m.hot = 0.4
        case 2: m.hot = 0.8
        case 3: m.hot = 1
        default: m.hot = 0
        }
        m.full = memoryPressure >= 2 ? 1 : (memoryPressure == 1 ? 0.6 : 0)
        if let battery = batteryPercent, !onPower {
            m.tired = battery < 20 ? 1 : 0
            m.asleep = battery < 10
        }
        return m
    }

    /// A memory-critical machine makes the character dizzy: that is the founder's
    /// example, and it is also the honest one — nothing else is happening any more.
    func overloaded() -> Bool { memoryPressure >= 2 }
}

extension LupyCharacterState {
    /// What is actually drawn. A machine in memory-critical state is dizzy whatever
    /// the task thinks it is doing — the body language tells the truth about the Mac.
    static func resolved(requested: LupyCharacterState, overloaded: Bool) -> LupyCharacterState {
        guard overloaded else { return requested }
        switch requested {
        case .approval, .question, .error: return requested   // never hide a question
        default: return .dizzy
        }
    }
}

extension LupyVitals {
    /// The line under the bubble: the most telling fact first, at most two facts.
    func describe(_ mood: LupyMood, top: [String]) -> String? {
        var parts: [String] = []
        if mood.busy > 0 {
            let pct = Int((cpu * 100).rounded())
            parts.append(top.isEmpty
                ? "CPU \(pct) %"
                : "CPU \(pct) % · " + top.prefix(2).joined(separator: ", "))
        }
        if mood.hot >= 0.8 { parts.append("hot") }
        else if mood.hot > 0 { parts.append("warm") }
        if mood.full >= 1 { parts.append("memory full") }
        else if mood.full > 0 { parts.append("memory short") }
        if let battery = batteryPercent, mood.tired > 0 || mood.asleep {
            parts.append("battery \(battery) %")
        }
        return parts.isEmpty ? nil : parts.prefix(2).joined(separator: " · ")
    }
}

/// Small overlay, always upper-LEFT of the body (brand rule).
/// How the badge is drawn: a dark ring, the state's colour inside it, the glyph in ink.
/// The ring is what separates a bright disc from a white body — without it the badge
/// dissolves into the character.
enum LupyBadgeStyle {
    static let ringColour: (r: Double, g: Double, b: Double) = (0.043, 0.047, 0.055)
}

/// One glyph per state, drawn as vector paths — never a font, never an emoji, so it
/// looks identical in the app, in the debug sheet and at any size.
enum LupyStateIcon {
    case standby, gear, bulb, magnifier, bell, question, exclamation, check, clock, zzz, spiral

    var name: String {
        switch self {
        case .standby: return "standby"
        case .gear: return "gear"
        case .bulb: return "bulb"
        case .magnifier: return "magnifier"
        case .bell: return "bell"
        case .question: return "question"
        case .exclamation: return "exclamation"
        case .check: return "check"
        case .clock: return "clock"
        case .zzz: return "zzz"
        case .spiral: return "spiral"
        }
    }
}

typealias LupyBadge = LupyStateIcon
