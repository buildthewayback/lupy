//  LupyIslandDesign.swift
//  The island's design law: how big the canvas is, where LUPY stands in it, where the
//  status sentence goes, what the glass is made of, and which colours may mean what.
//
//  Pure math. NO SwiftUI, NO Foundation, NO CoreGraphics — so this exact file compiles
//  for the app *and* for the sandbox Swift-on-WebAssembly harness
//  (tools/swiftwasm/swiftc-wasm.mjs). The numbers the tests prove are the numbers the app
//  runs. That is the point: this project cannot wait on a CI machine to find out whether
//  the UI is right, so the UI's rules are written where they can be checked anywhere.
//
//  Why a kernel instead of hand-tuned SwiftUI frames:
//  the island used to carry a table of fixed heights per screen (IslandConst.viewLayouts)
//  — one canvas shape reused for everything, tuned by eye, one number at a time. The
//  founder's rule is the opposite: **the canvas grows per need, never fixed.** A growth
//  rule cannot live in a table of constants. It has to be a function — and a function can
//  be tested, argued with, and fixed.
//
//  Everything is Double (CGFloat is Double on every 64-bit Apple platform).

// MARK: - Maths the character kernel does not already have

extension LM {
    /// Natural log, range-reduced then an atanh series. `LM` ships sin/cos/exp/sqrt but
    /// no log, and colour science needs one (sRGB → linear light is a 2.4-power curve).
    /// Accurate to ~1e-15 over the whole positive range.
    static func ln(_ x0: Double) -> Double {
        guard x0 > 0 else { return -1e300 }
        var x = x0
        var k = 0
        let root2 = 1.4142135623730951
        while x > root2 { x /= 2; k += 1 }
        while x < 1 / root2 { x *= 2; k -= 1 }
        // x is now in [1/√2, √2], so y is small and the series converges in a few terms.
        let y = (x - 1) / (x + 1)
        let y2 = y * y
        var term = y
        var sum = y
        var i = 1
        while i <= 24 {
            term *= y2
            sum += term / Double(2 * i + 1)
            i += 1
        }
        return 2 * sum + Double(k) * 0.6931471805599453
    }

    /// x^p for any real p, via exp(p·ln x).
    static func pow(_ x: Double, _ p: Double) -> Double {
        guard x > 0 else { return 0 }
        return exp(p * ln(x))
    }
}

// MARK: - Colour

/// An sRGB colour with alpha, all channels 0…1.
struct LupyColour: Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(_ t: (r: Double, g: Double, b: Double)) { self.init(t.r, t.g, t.b) }

    /// Parse "#RRGGBB" or "#RRGGBBAA". Returns nil rather than guessing: a typo'd hex in a
    /// palette must fail a test, never silently render as black.
    static func hex(_ s: String) -> LupyColour? {
        var t = s
        if t.hasPrefix("#") { t = String(t.dropFirst()) }
        guard t.count == 6 || t.count == 8 else { return nil }
        var v: UInt64 = 0
        for c in t {
            guard let av = c.asciiValue else { return nil }
            let d: UInt64
            switch av {
            case 48...57:  d = UInt64(av - 48)          // 0-9
            case 97...102: d = UInt64(av - 87)          // a-f
            case 65...70:  d = UInt64(av - 55)          // A-F
            default: return nil
            }
            v = v * 16 + d
        }
        if t.count == 6 {
            return LupyColour(Double((v >> 16) & 255) / 255,
                              Double((v >> 8) & 255) / 255,
                              Double(v & 255) / 255)
        }
        return LupyColour(Double((v >> 24) & 255) / 255,
                          Double((v >> 16) & 255) / 255,
                          Double((v >> 8) & 255) / 255,
                          Double(v & 255) / 255)
    }

    var hexString: String {
        let digits = Array("0123456789ABCDEF")
        func byte(_ x: Double) -> String {
            let v = Int(LM.rounded(LM.clamp(x, 0, 1) * 255))
            return String(digits[v / 16]) + String(digits[v % 16])
        }
        return "#" + byte(r) + byte(g) + byte(b)
    }

    /// sRGB → linear light (IEC 61966-2-1). Contrast maths is only meaningful in linear
    /// light: averaging sRGB channel values directly lies about how bright a colour looks.
    func linearised() -> LupyColour {
        func f(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : LM.pow((c + 0.055) / 1.055, 2.4)
        }
        return LupyColour(f(r), f(g), f(b), a)
    }

    /// WCAG 2.x relative luminance.
    var luminance: Double {
        let l = linearised()
        return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
    }

    /// WCAG contrast ratio, 1…21. Body text on a surface must clear 4.5.
    func contrast(with other: LupyColour) -> Double {
        let a = luminance, b = other.luminance
        let hi = a > b ? a : b
        let lo = a > b ? b : a
        return (hi + 0.05) / (lo + 0.05)
    }

    /// This colour painted over `back` (source-over), flattening alpha.
    func over(_ back: LupyColour) -> LupyColour {
        LupyColour(r * a + back.r * (1 - a),
                   g * a + back.g * (1 - a),
                   b * a + back.b * (1 - a),
                   a + back.a * (1 - a))
    }

    /// Mix toward another colour by t.
    func mixed(with other: LupyColour, _ t: Double) -> LupyColour {
        let k = LM.clamp(t, 0, 1)
        return LupyColour(LM.lerp(r, other.r, k), LM.lerp(g, other.g, k),
                          LM.lerp(b, other.b, k), LM.lerp(a, other.a, k))
    }

    func withAlpha(_ a: Double) -> LupyColour { LupyColour(r, g, b, LM.clamp(a, 0, 1)) }

    static let white = LupyColour(1, 1, 1)
    static let black = LupyColour(0, 0, 0)
}

// MARK: - Palette

/// The colours LUPY is allowed to use, and what each one is *for*.
///
/// Two families, kept deliberately apart:
///  * **Milkinside** — the founder's chosen UI palette: desaturated blues and greys. It is
///    the room. It builds surfaces, structure and quiet text.
///  * **Status RGB** — LUPY's own vivid state colours, owned by the character kernel
///    (`LupyCharacterState.tint`). They are the only loud colours in the app and they mean
///    exactly one thing: what the machine is doing right now.
///
/// The law that keeps them apart: a Milkinside colour never means a state, and a status
/// colour is never used as chrome. If a surface is blue because LUPY is *working*, that
/// blue is his #0A84FF and nothing else may borrow it.
enum LupyPalette {
    // Milkinside (founder-supplied; docs/LUPY3_MEMORY_FULL.md §11)
    static let ink   = LupyColour.hex("#253256")!   // deepest — the canvas floor
    static let slate = LupyColour.hex("#374772")!   // panels
    static let dusk  = LupyColour.hex("#576692")!   // elevated cards
    static let stone = LupyColour.hex("#5D5D69")!   // lines, dividers
    static let fog   = LupyColour.hex("#7F8493")!   // disabled, decoration
    static let mist  = LupyColour.hex("#989FAB")!   // quiet text
    static let chalk = LupyColour.hex("#C0C5D4")!   // body text

    /// Pure white — LUPY's body, and the island's primary text.
    static let paper = LupyColour(1, 1, 1)

    /// Text roles — and the two tones that are *not* text roles.
    ///
    /// These assignments are not taste. They are the output of `LupyGlass.worstContrast`,
    /// measured over both extremes of desktop the island can float above (a white document
    /// and a black terminal), at the panel's derived opacity. The founder's Milkinside
    /// palette has seven tones; the arithmetic says only two of them may carry a word:
    ///
    ///   paper #FFFFFF — primary text. Clears AA with room to spare.
    ///   chalk #C0C5D4 — body and secondary text. Clears AA at the shipped panel depth.
    ///   mist  #989FAB — reaches ~3.4:1, which is WCAG's *large-text* floor, and nothing
    ///                   on the island is large text (11–15 pt). So mist draws icons,
    ///                   dividers and disabled affordances. Never a sentence.
    ///   fog   #7F8493 — clears nothing. Structure only.
    ///
    /// A grey that cannot be read is not a quieter design, it is a broken one.
    static let textPrimary = paper
    static let textBody    = chalk
    /// The quietest tone still allowed to *mean* something visually. Not text.
    static let iconography = mist
    /// Hairlines, dividers, tracks. Not text, not meaning.
    static let decoration  = fog

    /// The accent. Not mango, not Coucou's orange: LUPY's electric blue — which is also
    /// his "working" light. The app's accent and the character's busiest state are the
    /// same colour, so the interface can never disagree with him.
    static var accent: LupyColour { LupyCharacterState.working.colour }

    /// Destructive actions take his error red; success takes his finished green. Never an
    /// invented second red or green — one colour, one meaning, everywhere.
    static var destructive: LupyColour { LupyCharacterState.error.colour }
    static var success: LupyColour { LupyCharacterState.finished.colour }
    static var warning: LupyColour { LupyCharacterState.approval.colour }

    /// A state's light, dimmed to the strength the character kernel says it burns.
    /// The island must not invent a second brightness for the same state.
    static func statusGlow(_ s: LupyCharacterState) -> LupyColour {
        s.colour.mixed(with: .black, 1 - s.glowStrength)
    }
}

extension LupyCharacterState {
    /// The state's light as a colour, so the design kernel and the character cannot drift.
    var colour: LupyColour { LupyColour(tint) }
}

// MARK: - Glass

/// The glass recipe — and the one number in it that is *derived* rather than chosen.
///
/// Synvy Neuro is the style target (docs/LUPY3_UI_RESEARCH.md §6): dark glassmorphism,
/// frosted cards, a soft directional glow, rounded corners. The craft rules say glass
/// needs a tint for text contrast, a hairline border, a soft shadow, and a radius in the
/// 8–24 range.
///
/// The trap: the island floats over **the desktop**, which can be anything — a white
/// document, a black terminal, a photograph. A glass panel is only partly opaque, so text
/// contrast changes with what is behind it. Choosing a fill alpha by eye, on one
/// wallpaper, is exactly how a UI ships unreadable.
///
/// There are two levers and they trade against each other: how dark the base is, and how
/// opaque the fill is. Measured over Milkinside ink (#253256), body text needed 84%
/// opacity — at which point there is no glass left, only a dark rectangle. Deepening the
/// base buys the transparency back: at 55% toward black the same text clears AA at 78%
/// opacity, so a fifth of the desktop still comes through, blurred and saturated.
///
/// So both numbers here are derived: `panelDepth` is how far the base is pushed toward
/// black while still reading as Milkinside blue rather than neutral, and `fillAlpha` is
/// the smallest alpha at which the *quietest text the island draws* clears 4.5:1 over
/// both extremes. The rest of the recipe is craft; these two are arithmetic.
struct LupyGlass: Equatable {
    /// How far the panel base is pushed from Milkinside ink toward black.
    ///
    /// 0.55 is not a vibe: it is the depth at which body text clears AA while the fill can
    /// stay translucent enough to be glass. Shallower and the panel has to go nearly
    /// opaque to stay readable; deeper and it stops being Milkinside blue and becomes
    /// neutral black, losing the palette the founder chose. `design_tests` pins both ends.
    static let panelDepth = 0.55

    /// The panel base: Milkinside ink, deepened.
    static let panelBase = LupyPalette.ink.mixed(with: .black, panelDepth)

    /// Base of the panel, before alpha.
    var base: LupyColour
    /// How opaque the panel is. Derived — see `minimumFillAlpha`.
    var fillAlpha: Double
    /// Backdrop blur, points.
    var blur: Double
    /// Saturation boost on the backdrop: what separates real glass from plain frost.
    var saturation: Double
    /// The 1px hairline, top-lit.
    var hairline: LupyColour
    /// Soft shadow beneath the island.
    var shadow: LupyColour
    var shadowRadius: Double
    var shadowY: Double

    /// WCAG AA for body text. A floor, not a target.
    static let contrastFloor = 4.5
    /// WCAG AA for large text (≥18 pt, or ≥14 pt bold).
    static let contrastFloorLarge = 3.0

    /// The two desktops a floating island can sit over. Everything else is between them.
    static let behindBright = LupyColour(0.98, 0.98, 0.98)   // a white document
    static let behindDark   = LupyColour(0.04, 0.04, 0.05)   // a dark terminal

    /// The panel as it will actually appear over `behind`.
    func composited(over behind: LupyColour) -> LupyColour {
        base.withAlpha(fillAlpha).over(behind)
    }

    /// Worst-case contrast for `text` on this glass: the smaller of the two desktops'
    /// results. If this clears the floor, the text is readable over any wallpaper.
    func worstContrast(_ text: LupyColour) -> Double {
        let onBright = text.contrast(with: composited(over: Self.behindBright))
        let onDark   = text.contrast(with: composited(over: Self.behindDark))
        return onBright < onDark ? onBright : onDark
    }

    func worstTextContrast() -> Double { worstContrast(LupyPalette.textPrimary) }

    /// The smallest fill alpha at which `text` clears `floor` over both extremes.
    /// Solved by bisection — valid because contrast is monotone in alpha.
    static func minimumFillAlpha(base: LupyColour,
                                 text: LupyColour = LupyPalette.textPrimary,
                                 floor: Double = contrastFloor) -> Double {
        func passes(_ a: Double) -> Double {
            base.withAlpha(a).over(Self.behindBright).contrast(with: text)
                < base.withAlpha(a).over(Self.behindDark).contrast(with: text)
                ? base.withAlpha(a).over(Self.behindBright).contrast(with: text)
                : base.withAlpha(a).over(Self.behindDark).contrast(with: text)
        }
        guard passes(1) >= floor else { return 1 }   // even solid fails: the base is wrong
        if passes(0) >= floor { return 0 }
        var lo = 0.0, hi = 1.0
        for _ in 0..<48 {
            let mid = (lo + hi) / 2
            if passes(mid) >= floor { hi = mid } else { lo = mid }
        }
        return hi
    }

    /// The quietest colour the island draws as text. The panel's opacity is derived from
    /// this one, so every text role above it is legal by construction.
    static let strictestText = LupyPalette.textBody

    /// The island's glass. `fillAlpha` is not a guess: it is the legal minimum for the
    /// strictest text, nudged up a step so the panel carries margin, then re-checked.
    static let panel: LupyGlass = {
        let base = panelBase
        let legal = minimumFillAlpha(base: base, text: strictestText)
        var g = LupyGlass(base: base,
                          fillAlpha: LM.clamp(legal + 0.10, 0, 1),
                          blur: 28,
                          saturation: 1.55,
                          hairline: LupyColour(1, 1, 1, 0.16),
                          shadow: LupyColour(0, 0, 0, 0.42),
                          shadowRadius: 26,
                          shadowY: 10)
        // Never ship a panel below the floor, whatever the arithmetic said.
        while g.worstTextContrast() < contrastFloor, g.fillAlpha < 1 {
            g.fillAlpha = LM.clamp(g.fillAlpha + 0.02, 0, 1)
        }
        return g
    }()

    /// A card inside the island: lifted, a touch lighter, less blur (it sits over glass,
    /// not over the desktop, so it does not have to work as hard). Its opacity is derived
    /// from the same strictest text — a card that dims the body copy is not a card.
    static func card(lift: Double = 0.12) -> LupyGlass {
        let base = panelBase.mixed(with: LupyPalette.dusk, lift)
        let legal = minimumFillAlpha(base: base, text: strictestText)
        var g = LupyGlass(base: base,
                          fillAlpha: LM.clamp(legal + 0.12, 0, 1),
                          blur: 18,
                          saturation: 1.35,
                          hairline: LupyColour(1, 1, 1, 0.12),
                          shadow: LupyColour(0, 0, 0, 0.28),
                          shadowRadius: 12,
                          shadowY: 4)
        while g.worstTextContrast() < contrastFloor, g.fillAlpha < 1 {
            g.fillAlpha = LM.clamp(g.fillAlpha + 0.02, 0, 1)
        }
        return g
    }
}

// MARK: - Type

/// Every text size the island uses, in points.
///
/// These exist because of a measured failure, not taste: at 4 pt the character's floating
/// label was unreadable mush, and below ~30 pt his ∪∪ lids fuse into one dash. The same
/// reasoning applies to UI type — so there is a floor, and it is enforced by a test.
enum LupyType {
    /// The status sentence in an open canvas. The largest text on the island, because it
    /// is the one thing that must be read at a glance.
    /// macOS HIG text style "Headline": 13 pt, Bold, 16 pt line height. The island is a
    /// compact surface; Apple's own alerts and cards title at 13 Bold, and the founder's
    /// eye caught 16 as "too big" because it was — a Title-3 number on a Headline job.
    static let headline: Double = 13
    /// A whisper beside him in the compact band.
    static let peek: Double     = 13
    /// Card body.
    static let body: Double     = 13
    /// Quick-reply chips (⌘1/⌘2/⌘3).
    static let chip: Double     = 13   // body size, medium weight: one family, two weights
    /// Provenance: "researched 4 sources · 2 agents · $0.11 · 3m".
    static let provenance: Double = 11

    /// Nothing on the island may be smaller than this. Proven, not promised.
    static let floor: Double = 11

    /// Every size the island can draw, so a test can walk them all.
    static let all: [Double] = [headline, peek, body, chip, provenance]
}

// MARK: - The canvas

/// A box in island coordinates: origin top-left, y down, in points.
struct LupyBox: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let zero = LupyBox(x: 0, y: 0, width: 0, height: 0)

    var midX: Double { x + width / 2 }
    var midY: Double { y + height / 2 }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
    var isEmpty: Bool { width <= 0.5 || height <= 0.5 }

    func inset(_ dx: Double, _ dy: Double) -> LupyBox {
        LupyBox(x: x + dx, y: y + dy, width: width - 2 * dx, height: height - 2 * dy)
    }

    func intersects(_ o: LupyBox) -> Bool {
        guard !isEmpty, !o.isEmpty else { return false }
        return x < o.maxX && o.x < maxX && y < o.maxY && o.y < maxY
    }

    /// True when `o` is wholly inside, to within half a point of slop.
    func contains(_ o: LupyBox) -> Bool {
        guard !o.isEmpty else { return true }
        return o.x >= x - 0.5 && o.y >= y - 0.5 && o.maxX <= maxX + 0.5 && o.maxY <= maxY + 0.5
    }

    /// The box's four corners.
    var corners: [(x: Double, y: Double)] {
        [(x, y), (maxX, y), (x, maxY), (maxX, maxY)]
    }

    /// True when the whole box survives a `clipShape` to this rect's rounded corners.
    ///
    /// This is the real test, and it replaced a naive one. The first attempt checked
    /// "text must start at least one corner-radius in from the edge", which is wrong in
    /// both directions: it rejects perfectly visible text near a corner (the arc only
    /// bites *outside* the quarter-circle) and it accepts text that is genuinely outside
    /// the frame. A rounded rectangle is convex, so testing the four corners is exact.
    ///
    /// The defect this guards is one that shipped: the island clipped its own status
    /// label at its rounded corner and it read "…your OK".
    func containsRounded(_ o: LupyBox, corner r: Double) -> Bool {
        guard !o.isEmpty else { return true }
        guard contains(o) else { return false }
        guard r > 0.5 else { return true }
        let slop = 0.5
        for p in o.corners {
            // Which corner region is this point in, if any?
            let nearLeft  = p.x < x + r
            let nearRight = p.x > maxX - r
            let nearTop   = p.y < y + r
            let nearBot   = p.y > maxY - r
            let cx = nearLeft ? x + r : (nearRight ? maxX - r : p.x)
            let cy = nearTop  ? y + r : (nearBot  ? maxY - r : p.y)
            // Only a point in a corner quadrant is tested against the arc.
            guard (nearLeft || nearRight) && (nearTop || nearBot) else { continue }
            let dx = p.x - cx, dy = p.y - cy
            if LM.sqrt(dx * dx + dy * dy) > r + slop { return false }
        }
        return true
    }
}

/// Where the status sentence lives. Exactly one of these is ever true — the app must
/// never say the same thing twice, in two places, at two sizes.
///
///  * `.motion` — rest. He is 20 pt under the camera. A label there is mush, and the
///    founder's rule for the resting island is that state reads through motion and
///    colour, not text.
///  * `.whisper` — one line beside him in the compact band, drawn by the island as real UI
///    type at 13 pt. Not the character's body-relative bubble: that one scales off his
///    width and is only legible above 46 pt, which is why it kept getting clipped and
///    unreadable inside the island. The island owns its own words now.
///  * `.headline` — the canvas's own first line. When a card exists, the card *is* the
///    status text; a floating label would duplicate it and fight the layout for room.
enum LupyStatusSurface: Equatable {
    case motion, whisper, headline
}

/// What the island has to show right now. This is the *need*; the layout is the answer.
///
/// Every case carries only what changes the size. The growth law has to be a function of
/// real content, not of which screen happens to be open — that is the difference between
/// a canvas that grows per need and a table of 22 hard-coded heights.
enum LupyCanvasNeed: Equatable {
    /// Avatar alone under the camera.
    case rest
    /// Avatar plus one whispered line. `textWidth` is the measured width of that line.
    case whisper(textWidth: Double)
    /// An answer blooming: streaming text, quick replies, and — when there is something
    /// worth naming — a provenance row at the card's foot.
    case answer(lines: Int, chips: Int, provenance: Bool)
    /// Work in progress: a plan, a ledger of steps, an optional live preview.
    case task(steps: Int, hasPlan: Bool, hasPreview: Bool)
    /// He needs you: an approval or a question, with options and optional evidence.
    case decision(options: Int, hasEvidence: Bool, queue: Int)
    /// Voice: a live transcript.
    case transcript(lines: Int)
    /// The conversation surface.
    case chat(turns: Int, streaming: Bool)
    /// On-demand management. Minimal — never a dashboard.
    case settings(rows: Int)
    /// A captured screen, and what to do with it.
    case capture(actions: Int)

    /// True when the canvas is open enough to hold a card.
    var isExpanded: Bool {
        switch self {
        case .rest, .whisper: return false
        default: return true
        }
    }

    /// Every need, for tests that must walk the whole surface.
    static let samples: [LupyCanvasNeed] = [
        .rest,
        .whisper(textWidth: 0), .whisper(textWidth: 90), .whisper(textWidth: 260),
        .answer(lines: 1, chips: 0, provenance: false),
        .answer(lines: 3, chips: 2, provenance: true),
        .answer(lines: 9, chips: 3, provenance: true),
        .task(steps: 1, hasPlan: false, hasPreview: false),
        .task(steps: 6, hasPlan: true, hasPreview: true),
        .task(steps: 24, hasPlan: true, hasPreview: true),
        .decision(options: 2, hasEvidence: true, queue: 1),
        .decision(options: 3, hasEvidence: false, queue: 4),
        .decision(options: 0, hasEvidence: true, queue: 1),
        .transcript(lines: 1), .transcript(lines: 3), .transcript(lines: 12),
        .chat(turns: 1, streaming: true), .chat(turns: 4, streaming: false),
        .chat(turns: 40, streaming: true),
        .settings(rows: 1), .settings(rows: 6), .settings(rows: 30),
        .capture(actions: 0), .capture(actions: 4),
    ]
}

/// The computed island: one rect, and where everything inside it goes.
struct LupyCanvas: Equatable {
    /// The island band itself.
    var frame: LupyBox
    /// Corner radius — a function of the frame alone, so width, height and radius morph
    /// as one thing instead of three animations that happen to run together.
    var corner: Double
    /// LUPY. Always present, always the same character, sized by the law below.
    var avatar: LupyBox
    /// The card area. Empty when there is no card.
    var content: LupyBox
    /// Mic + text field. The only permanent control. Empty when collapsed.
    var composer: LupyBox
    /// Where the status sentence goes.
    var status: LupyStatusSurface
    /// The status sentence's box. Empty when `status == .motion`.
    var statusBox: LupyBox
    /// The glass the island is made of.
    var glass: LupyGlass

    var width: Double { frame.width }
    var height: Double { frame.height }

    /// True when the canvas is open and carrying a card.
    var isOpen: Bool { status == .headline }
}

// MARK: - The growth law

enum LupyIslandLayout {

    /// The device's notch band. Rest *is* the notch — the island does not invent a
    /// silhouette of its own while nothing is happening.
    static let notchWidth: Double  = 200
    static let notchHeight: Double = 32

    /// Canvas bounds. Laptop-first: wide, never tall. `maxWidth > maxHeight` is what makes
    /// the horizontal law enforceable rather than aspirational — a canvas can never be
    /// asked to grow taller than it is allowed to be wide, so it can never become the
    /// vertical phone panel the founder rejected.
    static let minWidth: Double  = 200
    static let maxWidth: Double  = 816     // 102 × 8
    static let minHeight: Double = 32
    static let maxHeight: Double = 416     // 52 × 8

    /// Padding, on an 8 pt grid. Growth is stepped, so the island never jitters by a point
    /// and a half between two similar needs and every size is a number a designer can read.
    static let grid: Double     = 8
    /// 16 pt at the edge: the standard floating-panel inset, and proven by
    /// `containsRounded` to clear a 22 pt corner with room to spare.
    static let padEdge: Double  = 16
    /// 12 pt inside a card: the documented 4 pt half-step of the 8 pt grid (8 felt cramped
    /// against a 16 pt edge pad, 16 made the card's own padding equal the panel's and
    /// killed the proximity hierarchy edge > card > row).
    static let padInner: Double = 12

    /// LUPY's column, in points of *frame*.
    ///
    /// The frame is not the body: the character kernel fits him at
    /// `min(width, height) × unitFraction`, so a 46 pt frame gives a 33 pt body. That
    /// matters because his face changes below 30 pt of *body* — the ∪∪ lids fuse into a
    /// single dash. 46 pt is the smallest frame that keeps his face his face with a point
    /// and a half of margin, and it is the size at which he reads as the speaker of the
    /// headline beside him.
    static let avatarExpanded: Double = 46
    /// At rest he is small: motion and colour only.
    static let avatarRest: Double     = 20
    /// In the compact band, a little bigger.
    static let avatarWhisper: Double  = 26
    static let avatarGap: Double      = 12   // half-step: his column to the card

    /// The composer. Permanent whenever the canvas is open — the only control that is.
    /// 40 pt is a standard macOS field height; 44 was a phone number.
    static let composerHeight: Double = 40   // 5 × 8
    static let composerGap: Double    = 12   // half-step between card and composer

    /// Row metrics.
    /// The headline row is exactly as tall as LUPY, so he and the status sentence share a
    /// centre line and he reads as the one saying it. Its right half carries the card's
    /// meta (step count, queue, cost) so the row is never dead space.
    static let headlineRow: Double = avatarExpanded
    /// HIG body line height is 16 pt for 13 pt text; plus an 8 pt related-row gap the
    /// pitch is 24 — a full grid step, and how every well-set Mac list reads.
    static let rowHeight: Double   = 24
    /// A chip is a button you press with a pointer. macOS push buttons run ~22 pt at
    /// .regular and ~28 at .large; 24 is the table-row / sidebar-medium height and the
    /// grid step between them — the size the founder's crops called for after 28 read
    /// chunky next to 13 pt labels.
    static let chipHeight: Double  = 24

    // MARK: the control kit, on the same scale
    /// Button horizontal padding at the 12 half-step: a 24 pt control wants 12, where
    /// the taller 28 pt cut wanted 16.
    static let chipPadH: Double     = 12
    /// Icon to label inside a button: the standard icon-text gap.
    static let chipIconGap: Double  = 8
    /// THE SHAPE LANGUAGE — two roles, never a third:
    ///   * the SURFACE: a capsule while it is a band, `corner()` once it opens;
    ///   * a CONTROL: 8 pt continuous — chips, the composer's recessed field.
    /// Nothing else gets a shape. macOS System Settings groups with spacing and
    /// hairline dividers, never with a box inside a box; the founder's eye caught
    /// our card-in-panel-in-field nesting as exactly the mistake it was.
    static let chipCorner: Double   = 8    // every control: one corner, one family
    static let fieldCorner: Double  = 8    // the composer's recess, same corner

    /// The narrowest card that can still hold a headline and a source line.
    static let headlineMin: Double = 240

    /// Round *up* to the grid.
    ///
    /// Up, not down and not nearest. The height of a canvas is the sum of the rows its
    /// card actually draws; rounding that sum down rounds a row *out of the box*, and the
    /// card's last line gets clipped by its own panel — the same class of bug as the label
    /// the island's corner once ate, one level down. Rounding up buys at most 7 pt of
    /// breathing room above the composer.
    ///
    /// The bounds are themselves grid multiples, so clamping after rounding can never
    /// escape them. When the content genuinely needs more than `maxHeight`, the clamp
    /// wins and the card scrolls — that is a decision, not an accident, and it is visible
    /// in the picture.
    static func stepped(_ v: Double) -> Double { LM.floor((v + grid - 0.001) / grid) * grid }

    /// Snap into the legal range, then onto the grid.
    static func fit(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        stepped(LM.clamp(v, lo, hi))
    }

    /// The corner radius, from the frame alone.
    ///
    /// Apple's Live Activities guidance is that the island should morph like a living
    /// organism. Deriving the radius from the frame is what makes that literally true.
    /// Fully round while it is a band; then the middle of the 8–24 pt glass range, clamped
    /// so the corner can never eat the frame.
    static func corner(width: Double, height: Double) -> Double {
        let small = width < height ? width : height
        if small <= notchHeight + 2 { return small / 2 }     // a band is a capsule
        return LM.clamp(24, 8, small / 2)   // top of the 8/16/24 radius family
    }

    /// The whole answer. One call, no view code involved.
    static func canvas(_ need: LupyCanvasNeed,
                       notchWidth: Double = LupyIslandLayout.notchWidth) -> LupyCanvas {
        switch need {
        case .rest:
            return band(width: notchWidth, avatar: avatarRest, status: .motion,
                        statusBox: .zero, notchWidth: notchWidth)

        case .whisper(let textWidth):
            // Avatar left, one line right. Height stays the notch band: a whisper must not
            // change the island's silhouette, only fill it.
            let d = avatarWhisper
            let labelX = padEdge + d + avatarGap
            let w = fit(padEdge + d + avatarGap + textWidth + padEdge, minWidth, maxWidth)
            let avail = w - padEdge - labelX
            // The whisper only exists if there is real room for it. A sliced word is worse
            // than no word — that is the lesson of the label the island corner once ate.
            let shows = textWidth >= 24 && avail >= 24
            let box = shows
                ? LupyBox(x: labelX,
                          y: (notchHeight - LupyType.peek * 1.4) / 2,
                          width: min(textWidth, avail),
                          height: LupyType.peek * 1.4)
                : LupyBox.zero
            return band(width: w, avatar: d,
                        status: shows ? .whisper : .motion,
                        statusBox: box, notchWidth: notchWidth)

        default:
            return expanded(need)
        }
    }

    /// The compact band: LUPY, optionally one line beside him, nothing else.
    private static func band(width: Double, avatar d: Double,
                             status: LupyStatusSurface, statusBox: LupyBox,
                             notchWidth: Double) -> LupyCanvas {
        let h = notchHeight
        // At rest he is centred under the camera; with a whisper he moves left to make
        // room for the words, which is the whole reason the band grew.
        let ax = status == .motion ? (width - d) / 2 : padEdge
        let avatar = LupyBox(x: ax, y: (h - d) / 2, width: d, height: d)
        return LupyCanvas(frame: LupyBox(x: 0, y: 0, width: width, height: h),
                          corner: corner(width: width, height: h),
                          avatar: avatar, content: .zero, composer: .zero,
                          status: status, statusBox: statusBox,
                          glass: LupyGlass.panel)
    }

    /// Everything with a card: answer, task, decision, transcript, chat, settings, capture.
    private static func expanded(_ need: LupyCanvasNeed) -> LupyCanvas {
        let (rows, contentWidth) = measure(need)

        // Height: LUPY's row, the card's rows, the chips, the composer, the padding.
        let cardHeight = rows <= 1
            ? rowHeight
            : stepped(Double(rows) * rowHeight + Double(rows - 1) * padInner)
        let chips = chipRow(need)
        // The trailing padInner is the card's own bottom padding: without it the last
        // row — or the chip row — sat flush on the card's hairline, which is exactly
        // the "no padding" the founder's crops circled.
        let body = headlineRow + padInner + cardHeight
                 + (chips > 0 ? padInner + chips : 0) + padInner

        var h = padEdge + body + composerGap + composerHeight + padEdge
        h = fit(h, minHeight, maxHeight)

        // Width: LUPY's column plus what the card actually needs.
        let avatarColumn = avatarExpanded + avatarGap
        var w = padEdge + avatarColumn + contentWidth + padEdge
        if h >= maxHeight { w += 96 }        // spill sideways before letting content scroll
        w = fit(w, minWidth, maxWidth)

        // The horizontal law, enforced rather than hoped for: if the content wanted more
        // height than the cap allowed and the canvas came out portrait, buy the room back
        // sideways. maxWidth > maxHeight guarantees this always succeeds.
        if w < h {
            w = fit(h + 4 * grid, minWidth, maxWidth)
            if w < h { h = w }               // content scrolls; the island stays landscape
        }

        let corner = corner(width: w, height: h)

        // LUPY, top-left, centred against the headline row so he reads as its speaker.
        let avatar = LupyBox(x: padEdge,
                             y: padEdge + (headlineRow - avatarExpanded) / 2,
                             width: avatarExpanded, height: avatarExpanded)

        // The card: everything to his right, down to the composer.
        let contentX = avatar.maxX + avatarGap
        let content = LupyBox(x: contentX, y: padEdge,
                              width: w - padEdge - contentX,
                              height: h - padEdge - composerGap - composerHeight - padEdge)

        // The composer: full width at the foot.
        let composer = LupyBox(x: padEdge,
                               y: h - padEdge - composerHeight,
                               width: w - 2 * padEdge,
                               height: composerHeight)

        // The status sentence is the headline: LUPY's right, first row of the card.
        let statusBox = LupyBox(x: content.x, y: padEdge,
                                width: content.width, height: headlineRow)

        return LupyCanvas(frame: LupyBox(x: 0, y: 0, width: w, height: h),
                          corner: corner,
                          avatar: avatar,
                          content: content,
                          composer: composer,
                          status: .headline,
                          statusBox: statusBox,
                          glass: LupyGlass.panel)
    }

    /// How many rows the card needs, and how wide.
    ///
    /// This is "grows per need". Each number is the *minimum* that keeps the content
    /// legible, because progressive disclosure means nothing is shown just in case.
    private static func measure(_ need: LupyCanvasNeed) -> (rows: Int, width: Double) {
        switch need {
        case .answer(let lines, let chips, let provenance):
            // A row per line, plus one provenance row when the card carries one
            // ("researched 4 sources · $0.11 · 3m"). The count is what the card actually
            // draws, because the picture and the law have to agree about the rows.
            let rows = max(1, lines) + (provenance ? 1 : 0)
            return (rows, min(max(headlineMin, 240 + Double(chips) * 92), maxWidth - 120))

        case .task(let steps, let hasPlan, let hasPreview):
            // A plan line, a row per step, and a wider card when a live preview sits
            // beside the ledger.
            let rows = (hasPlan ? 1 : 0) + max(1, steps)
            return (rows, min(hasPreview ? 460 : 340, maxWidth - 120))

        case .decision(let options, let hasEvidence, let queue):
            // The evidence (a diff, a command — three rows, because an approval without
            // evidence is a guess) or one line of question, plus a queue line when others
            // wait. The headline is the status row and is measured separately; the options
            // are chips, not card rows: they are the answer, not the content.
            let rows = (hasEvidence ? 3 : 1) + (queue > 1 ? 1 : 0)
            return (rows, min(max(headlineMin, 320 + Double(options) * 96), maxWidth - 120))

        case .transcript(let lines):
            // Live words: two rows while listening, growing to four before it folds away.
            return (Int(LM.clamp(Double(lines), 2, 4)), 420)

        case .chat(let turns, _):
            // The conversation surface: the tallest thing the island does, and still never
            // taller than it is wide.
            return (Int(LM.clamp(Double(turns) * 2, 2, 8)), 520)

        case .settings(let rows):
            // On-demand and minimal: exactly the rows asked for, no dashboard chrome.
            return (max(1, rows), 380)

        case .capture(let actions):
            // The image, then what to do with it.
            return (4, min(max(headlineMin, 300 + Double(actions) * 88), maxWidth - 120))

        case .rest, .whisper:
            return (0, 0)
        }
    }

    /// Height of the quick-reply chip row, or 0 when this need has none.
    private static func chipRow(_ need: LupyCanvasNeed) -> Double {
        switch need {
        case .answer(_, let chips, _):      return chips > 0 ? chipHeight : 0
        case .decision(let options, _, _):  return options > 0 ? chipHeight : 0
        case .capture(let actions):         return actions > 0 ? chipHeight : 0
        default: return 0
        }
    }

    // MARK: Invariants

    /// Everything that must be true of every canvas this law produces.
    ///
    /// These are the founder's rules turned into assertions, so an edit that breaks one
    /// fails a test here instead of shipping to his Mac.
    static func violations(of c: LupyCanvas, need: LupyCanvasNeed) -> [String] {
        var v: [String] = []
        let f = c.frame
        func bad(_ m: String) { v.append(m) }

        // 1. Bounded — it has to fit a laptop screen. The cap always applies; the floor
        //    does not, because a collapsed island is the *device's* notch band, which can
        //    legitimately be narrower than anything we would choose to draw.
        let grown = need.isExpanded || c.status == .whisper
        if grown, f.width < minWidth - 0.5   { bad("canvas narrower than the floor (\(f.width))") }
        if grown, f.height < minHeight - 0.5 { bad("canvas shorter than the floor (\(f.height))") }
        if f.width > maxWidth + 0.5  { bad("canvas wider than the cap (\(f.width))") }
        if f.height > maxHeight + 0.5 { bad("canvas taller than the cap (\(f.height))") }

        // 2. Horizontal law: never a phone panel.
        if f.width < f.height { bad("canvas is portrait (\(f.width)×\(f.height)) — no vertical panels") }

        // 3. Stepped growth, for canvases that grew. Rest inherits the device's own notch
        //    band, which is not ours to round.
        if grown {
            let wg = f.width / grid, hg = f.height / grid
            if abs(wg - LM.rounded(wg)) > 0.01 { bad("width \(f.width) is off the \(grid) pt grid") }
            if abs(hg - LM.rounded(hg)) > 0.01 { bad("height \(f.height) is off the \(grid) pt grid") }
        }

        // 4. The corner sits in the glass range and never rounds past the frame.
        let small = f.width < f.height ? f.width : f.height
        if c.corner > small / 2 + 0.5 { bad("corner \(c.corner) is rounder than the frame allows") }
        if small > notchHeight + 2, c.corner < 8 || c.corner > 24 {
            bad("corner \(c.corner) is outside the 8–24 pt glass range")
        }

        // 5. LUPY is always in the frame, always square, always big enough to be LUPY.
        if !f.contains(c.avatar) { bad("LUPY escapes the canvas") }
        if c.avatar.width < avatarRest - 0.5 { bad("LUPY too small to read (\(c.avatar.width))") }
        if abs(c.avatar.width - c.avatar.height) > 0.01 { bad("LUPY is not square") }

        // 6. Everything lives inside the frame — and inside its *rounded* frame, which is
        //    what the island actually clips to.
        if !f.containsRounded(c.content, corner: c.corner)   { bad("content escapes the rounded canvas") }
        if !f.containsRounded(c.composer, corner: c.corner)  { bad("composer escapes the rounded canvas") }
        if !f.containsRounded(c.statusBox, corner: c.corner) { bad("status text escapes the rounded canvas") }
        if !f.containsRounded(c.avatar, corner: c.corner)    { bad("LUPY escapes the rounded canvas") }

        // 7. The status sentence — the founder's option B — floats clear of his body.
        if !c.statusBox.isEmpty, c.statusBox.intersects(c.avatar) {
            bad("status text sits on LUPY — it must float clear of his body")
        }

        // 8. Nothing overlaps LUPY.
        if c.content.intersects(c.avatar)  { bad("content overlaps LUPY") }
        if c.composer.intersects(c.avatar) { bad("composer overlaps LUPY") }

        // 9. The composer is the only permanent control: present in every open canvas,
        //    absent while collapsed, at the foot, full width.
        if c.isOpen {
            if c.composer.isEmpty { bad("open canvas with no composer") }
            if c.composer.maxY > f.height - padEdge + 0.5 { bad("composer is not at the foot") }
            if abs(c.composer.width - (f.width - 2 * padEdge)) > 0.5 { bad("composer is not full width") }
            if c.content.isEmpty { bad("open canvas with no card") }
            if c.content.intersects(c.composer) { bad("content overlaps the composer") }
            if c.content.width < 120 { bad("card too narrow to hold text (\(c.content.width))") }
        } else if !c.composer.isEmpty {
            bad("collapsed canvas is showing the composer")
        }

        // 10. The status sentence has exactly one home.
        switch c.status {
        case .motion:
            if !c.statusBox.isEmpty { bad("motion-only canvas is drawing text") }
        case .whisper:
            if c.statusBox.isEmpty { bad("whisper surface with no text box") }
            if !c.content.isEmpty { bad("a whisper and a card are competing for the same words") }
        case .headline:
            if c.statusBox.isEmpty { bad("headline surface with no headline box") }
            if !c.frame.contains(c.statusBox) { bad("headline is outside the canvas") }
        }

        // 11. The glass is legal: primary text clears AA over both desktop extremes.
        if c.glass.worstTextContrast() < LupyGlass.contrastFloor {
            bad("glass contrast \(LM.fixed(c.glass.worstTextContrast(), 2)) is under WCAG AA")
        }

        return v
    }
}
