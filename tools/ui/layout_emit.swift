// Emits the island's layout as plain lines, so the proof picture is drawn from the
// shipping law rather than from a re-implementation of it.
//
// Same discipline as tools/character/rig_states.swift: every number here comes from
// LupyIslandLayout / LupyGlass / LupyPalette / LupyType — the code the app runs. The
// Python renderer only fills the boxes this file prints. If the picture is wrong, the
// law is wrong; nothing is fudged on the way out.
//
//   node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \
//     Mac/Sources/Lupy/Character/LupyGeometry.swift \
//     Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
//     Mac/Sources/Lupy/UI/LupyIslandDesign.swift \
//     tools/ui/layout_emit.swift > /tmp/island_layout.txt

/// One canvas to draw, with the words that go in it.
///
/// The copy is real, not lorem: it is what each surface actually says, so the picture
/// proves the law against content that has to fit.
struct Sheet {
    let id: String
    let need: LupyCanvasNeed
    /// LUPY's state — which face and which light he wears in this canvas.
    let state: LupyCharacterState
    /// The status sentence. One home, chosen by the law.
    let headline: String
    /// Card body lines.
    let lines: [String]
    /// Quick-reply chips, with their keyboard shortcuts.
    let chips: [String]
    /// The provenance line, when the card earns one.
    let provenance: String
}

enum LayoutEmitter {

    static func num(_ d: Double) -> String { LM.fixed(d, 3) }

    static func box(_ tag: String, _ b: LupyBox) {
        print("BOX \(tag) \(num(b.x)) \(num(b.y)) \(num(b.width)) \(num(b.height))")
    }

    static func glass(_ tag: String, _ g: LupyGlass) {
        let b = g.base
        print("GLASS \(tag) \(num(b.r)) \(num(b.g)) \(num(b.b)) \(num(g.fillAlpha))"
              + " \(num(g.blur)) \(num(g.saturation))"
              + " \(num(g.hairline.a)) \(num(g.shadow.a)) \(num(g.shadowRadius)) \(num(g.shadowY))")
    }

    static func emit(_ s: Sheet) {
        let c = LupyIslandLayout.canvas(s.need)
        print("CANVAS \(s.id)")
        print("NEED \(describe(s.need))")
        print("STATE \(s.state.name)")
        print("FRAME \(num(c.width)) \(num(c.height)) \(num(c.corner))")
        let surface: String
        switch c.status {
        case .motion: surface = "motion"
        case .whisper: surface = "whisper"
        case .headline: surface = "headline"
        }
        print("SURFACE \(surface)")
        box("avatar", c.avatar)
        box("content", c.content)
        box("composer", c.composer)
        box("status", c.statusBox)
        // The light behind him, at his own strength — the island borrows it, never invents.
        let glow = LupyPalette.statusGlow(s.state)
        print("GLOW \(num(glow.r)) \(num(glow.g)) \(num(glow.b)) \(num(s.state.glowStrength))")
        print("TEXT HEADLINE \(s.headline)")
        for l in s.lines { print("TEXT LINE \(l)") }
        for ch in s.chips { print("TEXT CHIP \(ch)") }
        if !s.provenance.isEmpty { print("TEXT PROVENANCE \(s.provenance)") }
        // Every violation, so the picture cannot be drawn from an illegal canvas without
        // the emitter saying so out loud.
        let v = LupyIslandLayout.violations(of: c, need: s.need)
        if v.isEmpty { print("LEGAL yes") }
        else { for m in v { print("LEGAL no \(m)") } }
        print("")
    }

    static func describe(_ n: LupyCanvasNeed) -> String {
        switch n {
        case .rest: return "rest"
        case .whisper(let t): return "whisper(\(Int(t)))"
        case .answer(let l, let c, let p): return "answer(lines:\(l),chips:\(c),provenance:\(p))"
        case .task(let s, let p, let v): return "task(steps:\(s),plan:\(p),preview:\(v))"
        case .decision(let o, let e, let q): return "decision(options:\(o),evidence:\(e),queue:\(q))"
        case .transcript(let l): return "transcript(\(l))"
        case .chat(let t, let s): return "chat(turns:\(t),streaming:\(s))"
        case .settings(let r): return "settings(rows:\(r))"
        case .capture(let a): return "capture(actions:\(a))"
        }
    }

    /// The surfaces worth proving, in the order the founder would meet them.
    static let sheets: [Sheet] = [
        Sheet(id: "rest", need: .rest, state: .idle,
              headline: "", lines: [], chips: [], provenance: ""),

        Sheet(id: "whisper", need: .whisper(textWidth: 138), state: .working,
              headline: "Reading 12 files…", lines: [], chips: [], provenance: ""),

        Sheet(id: "answer", need: .answer(lines: 3, chips: 2, provenance: true), state: .finished,
              headline: "Done — 3 ways to cut the build time",
              lines: ["Cache the Swift module graph between runs; that alone saved 41 s.",
                      "Move the asset catalogue to a prebuilt step so it is not re-encoded.",
                      "Skip the universal slice — this Mac is arm64 only."],
              chips: ["1  Apply all three", "2  Show the diff"],
              provenance: "researched 4 sources · 2 agents · $0.11 · 3m 12s"),

        Sheet(id: "decision", need: .decision(options: 2, hasEvidence: true, queue: 1), state: .approval,
              headline: "Needs your OK",
              lines: ["Claude Code wants to run:",
                      "  rm -rf build/ && xcodegen generate",
                      "in ~/lupy  ·  session a91f"],
              chips: ["⌘Y  Allow once", "⌘N  Deny"],
              provenance: ""),

        Sheet(id: "task", need: .task(steps: 4, hasPlan: true, hasPreview: true), state: .working,
              headline: "Rebuilding the island UI",
              lines: ["1  Design kernel — 432 checks passing",
                      "2  Glass + palette — derived, not guessed",
                      "3  Canvas growth law — running",
                      "4  Wire the views — waiting"],
              chips: [],
              provenance: "step 3 of 4 · 1m 48s · Lupy's Computer"),

        Sheet(id: "question", need: .decision(options: 3, hasEvidence: false, queue: 1), state: .question,
              headline: "Which branch should I push to?",
              lines: ["I can see two remotes and I will not guess."],
              chips: ["1  arena/47c739ab", "2  main", "3  Neither — ask me"],
              provenance: ""),

        Sheet(id: "chat", need: .chat(turns: 3, streaming: true), state: .thinking,
              headline: "Thinking…",
              lines: ["You: does the island ever cover the menu bar?",
                      "Lupy: only while it is open, and it folds back to",
                      "        the notch 15 s after you stop looking at it.",
                      "You: and can it read what my terminal is doing?",
                      "Lupy: it can see the title, never the content, unless",
                      "        you turn computer control on yourself."],
              chips: [],
              provenance: ""),

        Sheet(id: "error", need: .answer(lines: 2, chips: 2, provenance: true), state: .error,
              headline: "The build failed",
              lines: ["Swift 6: cannot access 'ticker' from a nonisolated deinit.",
                      "IslandCharacterView.swift:59"],
              chips: ["1  Fix it", "2  Show me the log"],
              provenance: "run 39129202902 · 42s"),

        Sheet(id: "transcript", need: .transcript(lines: 2), state: .searching,
              headline: "Listening…",
              lines: ["“…and put the notes from this call into the",
                      "     second brain before I forget.”"],
              chips: [],
              provenance: ""),
    ]

    static func main() {
        print("# island layout, emitted by the shipping law")
        print("# CANVAS id / NEED / STATE / FRAME w h corner / SURFACE / BOX role x y w h")
        print("# GLASS tag r g b alpha blur saturation hairline shadow shadowR shadowY")
        print("")
        print("TYPE headline \(num(LupyType.headline)) body \(num(LupyType.body))"
              + " chip \(num(LupyType.chip)) provenance \(num(LupyType.provenance))"
              + " peek \(num(LupyType.peek))")
        glass("panel", LupyGlass.panel)
        glass("card", LupyGlass.card())
        let p = LupyPalette.textPrimary, b = LupyPalette.textBody
        print("COLOUR primary \(num(p.r)) \(num(p.g)) \(num(p.b))")
        print("COLOUR body \(num(b.r)) \(num(b.g)) \(num(b.b))")
        print("COLOUR accent \(num(LupyPalette.accent.r)) \(num(LupyPalette.accent.g)) \(num(LupyPalette.accent.b))")
        let i = LupyPalette.iconography, d = LupyPalette.decoration, st = LupyPalette.stone
        print("COLOUR icon \(num(i.r)) \(num(i.g)) \(num(i.b))")
        print("COLOUR decor \(num(d.r)) \(num(d.g)) \(num(d.b))")
        print("COLOUR line \(num(st.r)) \(num(st.g)) \(num(st.b))")
        // The two desktops the glass is proven against.
        let br = LupyGlass.behindBright, dk = LupyGlass.behindDark
        print("BEHIND bright \(num(br.r)) \(num(br.g)) \(num(br.b))")
        print("BEHIND dark \(num(dk.r)) \(num(dk.g)) \(num(dk.b))")
        print("METRIC grid \(num(LupyIslandLayout.grid)) pad \(num(LupyIslandLayout.padEdge))"
              + " inner \(num(LupyIslandLayout.padInner)) row \(num(LupyIslandLayout.rowHeight))"
              + " chip \(num(LupyIslandLayout.chipHeight)) composer \(num(LupyIslandLayout.composerHeight))")
        print("CONTRAST primary_bright \(num(LupyPalette.textPrimary.contrast(with: LupyGlass.panel.composited(over: br))))"
              + " primary_dark \(num(LupyPalette.textPrimary.contrast(with: LupyGlass.panel.composited(over: dk))))"
              + " body_bright \(num(b.contrast(with: LupyGlass.panel.composited(over: br))))"
              + " body_dark \(num(b.contrast(with: LupyGlass.panel.composited(over: dk))))")
        print("")
        for s in sheets { emit(s) }
    }
}

@main
struct Entry {
    static func main() {
        LayoutEmitter.main()
    }
}
