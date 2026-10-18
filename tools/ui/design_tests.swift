// Sandbox test harness for LupyIslandDesign — the island's design law.
// Run:
//   node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \
//     Mac/Sources/Lupy/Character/LupyGeometry.swift \
//     Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
//     Mac/Sources/Lupy/UI/LupyIslandDesign.swift \
//     tools/ui/design_tests.swift
//
// This is the CI-free proof. There is no macOS in the sandbox and the project does not
// depend on GitHub Actions to tell it the truth: the layout, the palette and the glass are
// pure math, so they are checked here, in seconds, on any machine.

final class DesignTests {
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

    func atLeast(_ a: Double, _ lo: Double, _ what: String) {
        checks += 1
        if a < lo { failures += 1; print("FAIL  \(what): got \(a), want >= \(lo)") }
        else { print("ok    \(what)  (\(LM.fixed(a, 2)))") }
    }

    func atMost(_ a: Double, _ hi: Double, _ what: String) {
        checks += 1
        if a > hi { failures += 1; print("FAIL  \(what): got \(a), want <= \(hi)") }
        else { print("ok    \(what)  (\(LM.fixed(a, 2)))") }
    }

    func main() {
        maths()
        colours()
        palette()
        glass()
        typeSizes()
        layoutLaw()
        growth()
        statusSentence()
        regressions()

        print("")
        if failures == 0 {
            print("DESIGNTESTS PASSED (\(checks) checks)")
        } else {
            print("DESIGNTESTS FAILED (\(failures) of \(checks))")
        }
    }

    // MARK: 1. The maths the colour science stands on

    func maths() {
        print("== ln / pow (added for colour science) ==")
        near(LM.ln(1), 0, 1e-12, "ln(1)")
        near(LM.ln(2.718281828459045), 1, 1e-10, "ln(e)")
        near(LM.ln(2), 0.6931471805599453, 1e-12, "ln(2)")
        near(LM.ln(10), 2.302585092994046, 1e-11, "ln(10)")
        near(LM.ln(0.5), -0.6931471805599453, 1e-12, "ln(0.5)")
        near(LM.ln(1e6), 13.815510557964274, 1e-9, "ln(1e6)")
        near(LM.pow(2, 10), 1024, 1e-9, "pow(2,10)")
        near(LM.pow(0.5, 2.4), 0.18946457081379978, 1e-12, "pow(0.5,2.4) — the sRGB curve")
        // exp and ln must be inverses over the range the transfer function uses.
        var worst = 0.0
        var i = 1
        while i <= 100 {
            let x = Double(i) / 100
            let back = LM.exp(LM.ln(x))
            if abs(back - x) > worst { worst = abs(back - x) }
            i += 1
        }
        atMost(worst, 1e-12, "exp(ln(x)) round-trips over 0.01…1")
    }

    // MARK: 2. Colour science against published values

    func colours() {
        print("\n== colour: hex, luminance, contrast ==")
        let white = LupyColour.hex("#FFFFFF")!
        let black = LupyColour.hex("#000000")!
        ok(white == LupyColour(1, 1, 1), "#FFFFFF parses to 1,1,1")
        ok(black == LupyColour(0, 0, 0), "#000000 parses to 0,0,0")
        near(white.luminance, 1, 1e-12, "luminance(white)")
        near(black.luminance, 0, 1e-12, "luminance(black)")
        near(white.contrast(with: black), 21, 1e-9, "contrast(white, black) = 21:1")
        near(white.contrast(with: white), 1, 1e-12, "contrast(white, white) = 1:1")

        // Mid grey: sRGB 0.5 is NOT half the luminance — it is 0.214. This is the whole
        // reason contrast maths runs in linear light.
        let mid = LupyColour(0.5, 0.5, 0.5)
        near(mid.luminance, 0.21404114, 1e-7, "luminance(#808080) — linear light, not sRGB")

        // WCAG's own worked example: #767676 on white is 4.54:1, the classic AA pass.
        let gray = LupyColour.hex("#767676")!
        near(gray.contrast(with: white), 4.54, 0.02, "contrast(#767676, white) — WCAG's AA example")

        // Alpha: half-black over white is grey, and compositing must be source-over.
        let half = LupyColour(0, 0, 0, 0.5).over(white)
        near(half.r, 0.5, 1e-12, "50% black over white = 0.5")
        near(half.luminance, LupyColour(0.5, 0.5, 0.5).luminance, 1e-12, "…and its luminance agrees")

        // Hex round-trip.
        ok(LupyColour.hex("#0A84FF")!.hexString == "#0A84FF", "hex round-trips #0A84FF")
        ok(LupyColour.hex("253256")!.hexString == "#253256", "hex parses without the #")
        ok(LupyColour.hex("#GGGGGG") == nil, "a bad hex is refused, not guessed")
        ok(LupyColour.hex("#12345") == nil, "a short hex is refused, not guessed")
        let rgba = LupyColour.hex("#FF800080")!
        near(rgba.a, 128.0 / 255, 1e-12, "#RRGGBBAA carries its alpha")
    }

    // MARK: 3. The palette: two families, and the roles are earned

    func palette() {
        print("\n== palette: Milkinside is the room, status RGB is the meaning ==")
        // Every founder-supplied Milkinside colour is present and exact.
        let milkinside = ["#253256": LupyPalette.ink, "#374772": LupyPalette.slate,
                          "#576692": LupyPalette.dusk, "#5D5D69": LupyPalette.stone,
                          "#7F8493": LupyPalette.fog, "#989FAB": LupyPalette.mist,
                          "#C0C5D4": LupyPalette.chalk]
        for (hex, colour) in milkinside {
            ok(colour.hexString == hex, "Milkinside \(hex) is in the palette")
        }

        // The accent is LUPY's blue — and it is *his* blue, read from the character
        // kernel, so the app cannot drift away from the character it is named after.
        ok(LupyPalette.accent == LupyCharacterState.working.colour,
           "accent is LUPY's working light, not a second invented blue")
        ok(LupyPalette.accent.hexString == "#0A84FF", "accent is #0A84FF")

        // No mango, no Coucou orange, anywhere in the roles that mean something.
        let forbidden = ["#FF9F0A", "#FF9500", "#F2994A", "#FF9166", "#FFA500"]
        let roles: [LupyColour] = [LupyPalette.accent, LupyPalette.destructive,
                                   LupyPalette.success, LupyPalette.warning,
                                   LupyPalette.textPrimary, LupyPalette.textBody,
                                   LupyPalette.iconography, LupyPalette.decoration]
        for f in forbidden {
            let bad = LupyColour.hex(f)!
            var hit = false
            for r in roles where r == bad { hit = true }
            ok(!hit, "no role is \(f) (the rejected mango/orange)")
        }

        // Status colours come from the character, one per state, all distinct — so no two
        // states can be confused at a glance.
        var seen: [String] = []
        var distinct = true
        for s in LupyCharacterState.allCases {
            let h = s.colour.hexString
            if seen.contains(h) { distinct = false; print("      duplicate: \(s.name) = \(h)") }
            seen.append(h)
        }
        ok(distinct, "all \(seen.count) state colours are distinct")
        ok(seen.count == LupyCharacterState.allCases.count, "every state has a colour")

        // The status glow dims by the character's own strength — never a second brightness.
        for s in LupyCharacterState.allCases {
            let g = LupyPalette.statusGlow(s)
            let want = s.colour.mixed(with: .black, 1 - s.glowStrength)
            ok(g == want, "statusGlow(\(s.name)) uses his own glowStrength")
        }

        // Vivid, not pastel: every state colour keeps at least one channel saturated and
        // one channel low. A pastel has all three channels crowded together.
        for s in LupyCharacterState.allCases where s != .idle {
            let c = s.colour
            let hi = max(max(c.r, c.g), c.b)
            let lo = min(min(c.r, c.g), c.b)
            atLeast(hi - lo, 0.5, "\(s.name) is vivid (channel spread), not pastel")
        }
    }

    // MARK: 4. The glass, and the number in it that is derived

    func glass() {
        print("\n== glass: dark glassmorphism that is readable over any desktop ==")
        let g = LupyGlass.panel

        // Craft ranges from the research: blur + saturation boost, hairline white 10–25%,
        // soft shadow, radius handled by the layout's corner law.
        atLeast(g.blur, 8, "panel blur is a real backdrop blur")
        atLeast(g.saturation, 1.2, "panel boosts saturation — glass, not plain frost")
        atLeast(g.hairline.a, 0.10, "hairline border is at least white 10%")
        atMost(g.hairline.a, 0.25, "hairline border is at most white 25%")
        atLeast(g.shadowRadius, 8, "the island casts a soft shadow")
        ok(g.shadow.r == 0 && g.shadow.g == 0 && g.shadow.b == 0, "the shadow is black, not tinted")

        // The derived number: primary text clears AA over BOTH desktop extremes.
        let onBright = LupyPalette.textPrimary.contrast(with: g.composited(over: LupyGlass.behindBright))
        let onDark   = LupyPalette.textPrimary.contrast(with: g.composited(over: LupyGlass.behindDark))
        print("      primary text on panel: \(LM.fixed(onBright, 2)):1 over a white desktop, \(LM.fixed(onDark, 2)):1 over a black one")
        atLeast(g.worstTextContrast(), LupyGlass.contrastFloor, "panel glass clears WCAG AA (4.5:1) worst case")

        // Body text clears AA too — the card carries sentences, not just a headline.
        atLeast(g.worstContrast(LupyPalette.textBody), LupyGlass.contrastFloor,
                "body text (chalk) clears AA on the panel")

        // The two tones that are NOT allowed to carry words, proven rather than asserted
        // in a comment. mist reaches only WCAG's large-text floor, and nothing on the
        // island is large text (11–15 pt), so it draws icons and dividers.
        atLeast(g.worstContrast(LupyPalette.iconography), LupyGlass.contrastFloorLarge,
                "iconography (mist) is visible: clears large-text AA (3:1)")
        atMost(g.worstContrast(LupyPalette.iconography), LupyGlass.contrastFloor,
               "…but mist does NOT clear AA — so it is never a sentence")
        atMost(g.worstContrast(LupyPalette.decoration), LupyGlass.contrastFloorLarge,
               "decoration (fog) is structure only: it clears no text floor at all")

        // The two derived numbers, and the trade-off between them. Deeper base ⇒ the fill
        // can stay more translucent for the same contrast. If that relationship ever
        // breaks, the derivation is not a derivation any more.
        let shallow = LupyGlass.minimumFillAlpha(base: LupyPalette.ink, text: LupyGlass.strictestText)
        let deep    = LupyGlass.minimumFillAlpha(base: LupyGlass.panelBase, text: LupyGlass.strictestText)
        atLeast(shallow, deep, "deepening the base buys back transparency")
        atMost(g.fillAlpha, 0.85, "the shipped panel is still translucent — it is glass, not a rectangle")
        atLeast(g.fillAlpha, deep, "…and it keeps margin over the legal floor")
        print("      base \(LupyGlass.panelBase.hexString) at alpha \(LM.fixed(g.fillAlpha, 3)): \(LM.fixed(1 - g.fillAlpha, 3)) of the desktop still comes through")

        // Deeper must not mean "neutral black". The panel keeps the Milkinside blue the
        // founder chose, or the whole palette argument was for nothing.
        let b = LupyGlass.panelBase
        ok(b.b > b.r, "the panel base is still blue-family (b > r)")
        atLeast(b.b - b.r, 0.05, "…and still visibly Milkinside, not neutral black")
        ok(b == LupyPalette.ink.mixed(with: .black, LupyGlass.panelDepth),
           "the base is Milkinside ink deepened by exactly panelDepth")

        // A lighter base needs more ink to stay readable: the derivation responds to the
        // base rather than being a constant in a function's clothes.
        atLeast(LupyGlass.minimumFillAlpha(base: LupyPalette.dusk, text: LupyGlass.strictestText),
                deep, "a lighter base needs at least as much opacity")

        // The alpha really is the minimum: one step below it fails, at it passes.
        let legal = LupyGlass.minimumFillAlpha(base: LupyGlass.panelBase,
                                               text: LupyGlass.strictestText)
        // Measured against the *strictest* text — the one the alpha was derived from.
        // Testing it against primary text would pass at any alpha and prove nothing.
        func worst(_ a: Double) -> Double {
            var t = g
            t.fillAlpha = a
            return t.worstContrast(LupyGlass.strictestText)
        }
        atLeast(worst(legal), LupyGlass.contrastFloor, "minimumFillAlpha itself is legal for body text")
        atMost(worst(max(0, legal - 0.02)), LupyGlass.contrastFloor,
               "…and one step below it is not (so it really is the minimum)")
        print("      legal minimum alpha \(LM.fixed(legal, 3)) → shipped \(LM.fixed(g.fillAlpha, 3))")

        // The card is a lifted surface and still legal.
        let card = LupyGlass.card()
        atLeast(card.worstTextContrast(), LupyGlass.contrastFloor, "card glass clears AA worst case")
        ok(card.base != g.base, "the card is visibly lifted off the panel")
        atLeast(card.worstContrast(LupyPalette.textBody), LupyGlass.contrastFloor,
                "body text still clears AA on a card")
        atMost(card.blur, g.blur, "the card blurs less — it sits over glass, not the desktop")

        // Restraint: glass on the key surfaces only. The recipe must not tint everything —
        // the base is Milkinside ink, never a status colour.
        ok(card.base != LupyPalette.accent, "no surface is made of the accent")
    }

    // MARK: 5. Type sizes have a floor, and the floor is proven

    func typeSizes() {
        print("\n== type: nothing on the island is smaller than 11 pt ==")
        // The character's own lesson: at 4 pt his floating label was mush. UI type gets the
        // same treatment — a measured floor, not a vibe.
        for t in LupyType.all {
            atLeast(t, LupyType.floor, "text size \(t) pt clears the floor")
        }
        ok(LupyType.headline > LupyType.body, "the status sentence is the largest text")
        ok(LupyType.headline >= 15, "the headline is at least 15 pt (research: 15–16 pt body)")
        // The headline must clear AA at its own size; small text needs more contrast, so
        // this is the size that carries the strictest requirement.
        let g = LupyGlass.panel
        atLeast(g.worstContrast(LupyPalette.textPrimary), LupyGlass.contrastFloor,
                "the headline's colour clears AA on the glass")
    }

    // MARK: 6. The growth law, over every need the island has

    func layoutLaw() {
        print("\n== layout: every need produces a legal canvas ==")
        var total = 0
        for need in LupyCanvasNeed.samples {
            let c = LupyIslandLayout.canvas(need)
            let v = LupyIslandLayout.violations(of: c, need: need)
            total += 1
            if v.isEmpty {
                print("ok    \(describe(need)) → \(Int(c.width))×\(Int(c.height)) r\(Int(c.corner))  avatar \(Int(c.avatar.width))  \(c.status)")
            } else {
                failures += v.count
                print("FAIL  \(describe(need)) → \(Int(c.width))×\(Int(c.height))")
                for m in v { print("        · \(m)") }
            }
            checks += 1
        }
        print("      \(total) needs checked")

        // Rest is the notch band, exactly, with nothing in it but LUPY.
        let rest = LupyIslandLayout.canvas(.rest)
        near(rest.width, LupyIslandLayout.notchWidth, 0.5, "rest is the notch band's width")
        near(rest.height, LupyIslandLayout.notchHeight, 0.5, "rest is the notch band's height")
        near(rest.corner, LupyIslandLayout.notchHeight / 2, 0.5, "rest is a capsule")
        ok(rest.composer.isEmpty, "rest has no composer — nothing is open")
        ok(rest.content.isEmpty, "rest has no card")
        ok(rest.status == .motion, "rest speaks through motion and colour, not text")
        near(rest.avatar.midX, rest.width / 2, 0.5, "rest centres LUPY under the camera")

        // The whisper keeps the band's silhouette and only fills it.
        let w1 = LupyIslandLayout.canvas(.whisper(textWidth: 120))
        near(w1.height, LupyIslandLayout.notchHeight, 0.5, "a whisper does not change the island's height")
        ok(w1.avatar.x < rest.avatar.x, "…it moves LUPY left to make room for the words")

        // The avatar column: big enough that his ∪∪ lids stay two distinct marks. The
        // floor is on his *body*, not on the frame the island hands him — the character
        // kernel fits him at min(w,h) × unitFraction inside that frame. Testing the frame
        // would pass while his face silently collapsed into a dash.
        for need in LupyCanvasNeed.samples where need.isExpanded {
            let c = LupyIslandLayout.canvas(need)
            let body = LupyComposition.unit(width: c.avatar.width, height: c.avatar.height)
            ok(LupyComposition.showsCupEyes(bodyWidth: body),
               "\(describe(need)): his \(LM.fixed(body, 1)) pt body keeps the cup eyes")
            atLeast(body, 31, "\(describe(need)): …with margin over the 30 pt floor")
            ok(LupyComposition.showsBadge(bodyWidth: body),
               "\(describe(need)): his badge glyph still fits")
        }
        // And the island must not ask the character for a body-relative label at a size
        // where that label is mush — that is why the island owns its own words.
        let open = LupyIslandLayout.canvas(.answer(lines: 2, chips: 0, provenance: false))
        let openBody = LupyComposition.unit(width: open.avatar.width, height: open.avatar.height)
        ok(!LupyComposition.showsBubble(bodyWidth: openBody),
           "the island's LUPY is under the character's 46 pt label floor — so the island owns the words")
        ok(LupyComposition.showsCupEyes(bodyWidth: openBody),
           "…but over his cup-eye floor, so his face is still his face")
        // And the converse: a surface that gives him a big frame must let *him* speak,
        // or the two systems will both draw the sentence and fight over it.
        let big = LupyComposition.detailFloor / LupyComposition.unitFraction
        ok(LupyComposition.showsBubble(bodyWidth: LupyComposition.unit(width: big, height: big)),
           "a frame of \(LM.fixed(big, 0)) pt is where his own bubble takes over")

        // The composer is the only permanent control.
        for need in LupyCanvasNeed.samples where need.isExpanded {
            let c = LupyIslandLayout.canvas(need)
            ok(!c.composer.isEmpty, "\(describe(need)): the composer is always there")
            near(c.composer.height, LupyIslandLayout.composerHeight, 0.5,
                 "\(describe(need)): composer height")
        }
    }

    // MARK: 7. Growth is monotone and stepped

    func growth() {
        print("\n== growth: more need ⇒ more canvas, in steps ==")
        func h(_ n: LupyCanvasNeed) -> Double { LupyIslandLayout.canvas(n).height }
        func w(_ n: LupyCanvasNeed) -> Double { LupyIslandLayout.canvas(n).width }

        atLeast(h(.answer(lines: 3, chips: 0, provenance: false)), h(.answer(lines: 1, chips: 0, provenance: false)),
                "a longer answer is at least as tall")
        atLeast(h(.answer(lines: 9, chips: 0, provenance: true)), h(.answer(lines: 3, chips: 0, provenance: true)),
                "a much longer answer is taller still")
        atLeast(h(.task(steps: 6, hasPlan: true, hasPreview: true)),
                h(.task(steps: 1, hasPlan: false, hasPreview: false)),
                "a task ledger grows with its steps")
        atLeast(w(.task(steps: 6, hasPlan: true, hasPreview: true)),
                w(.task(steps: 6, hasPlan: true, hasPreview: false)),
                "a live preview buys width, not height")
        atLeast(w(.decision(options: 3, hasEvidence: true, queue: 1)),
                w(.decision(options: 2, hasEvidence: true, queue: 1)),
                "more options buy width")
        atLeast(h(.decision(options: 2, hasEvidence: true, queue: 1)),
                h(.decision(options: 2, hasEvidence: false, queue: 1)),
                "evidence buys height — an approval without evidence is a guess")
        atLeast(h(.chat(turns: 8, streaming: false)), h(.chat(turns: 1, streaming: false)),
                "the conversation surface grows with history")

        // Stepped: the same content need gives the same size, and sizes land on the grid.
        let a = LupyIslandLayout.canvas(.answer(lines: 3, chips: 2, provenance: true))
        let b = LupyIslandLayout.canvas(.answer(lines: 3, chips: 2, provenance: true))
        ok(a == b, "the same need gives the same canvas (no jitter between frames)")
        let grid = LupyIslandLayout.grid
        for need in LupyCanvasNeed.samples where need.isExpanded {
            let c = LupyIslandLayout.canvas(need)
            near(c.width / grid, LM.rounded(c.width / grid), 0.01,
                 "\(describe(need)): width is on the \(Int(grid)) pt grid")
            near(c.height / grid, LM.rounded(c.height / grid), 0.01,
                 "\(describe(need)): height is on the grid")
        }

        // The cap holds even for absurd content: 200 steps must not blow past the screen.
        let huge = LupyIslandLayout.canvas(.task(steps: 200, hasPlan: true, hasPreview: true))
        atMost(huge.height, LupyIslandLayout.maxHeight, "200 steps still fits the height cap")
        atMost(huge.width, LupyIslandLayout.maxWidth, "…and the width cap")
        ok(huge.width >= huge.height, "…and it stays landscape (content scrolls, the island does not tilt)")
    }

    // MARK: 8. The status sentence has exactly one home

    func statusSentence() {
        print("\n== the status sentence: one home, never twice, never on him ==")
        for need in LupyCanvasNeed.samples {
            let c = LupyIslandLayout.canvas(need)
            switch c.status {
            case .motion:
                ok(c.statusBox.isEmpty, "\(describe(need)): motion only draws no text")
            case .whisper:
                ok(!c.statusBox.isEmpty, "\(describe(need)): the whisper has a box")
                ok(!c.statusBox.intersects(c.avatar), "\(describe(need)): the whisper floats clear of LUPY")
                ok(c.frame.containsRounded(c.statusBox, corner: c.corner),
                   "\(describe(need)): the whisper survives the island's rounded clip")
                atLeast(c.statusBox.width, 24, "\(describe(need)): the whisper has room for a word")
            case .headline:
                ok(!c.statusBox.isEmpty, "\(describe(need)): the headline has a box")
                ok(c.frame.contains(c.statusBox), "\(describe(need)): the headline is inside the island")
                ok(!c.statusBox.intersects(c.avatar), "\(describe(need)): the headline never sits on LUPY")
                ok(c.composer.isEmpty || !c.statusBox.intersects(c.composer),
                   "\(describe(need)): the headline is not under the composer")
            }
            checks += 1
        }

        // A whisper with no room must fall back to motion rather than ship a sliced word.
        let tight = LupyIslandLayout.canvas(.whisper(textWidth: 8))
        ok(tight.status == .motion, "a whisper too short to read becomes motion, not a fragment")
        ok(tight.statusBox.isEmpty, "…and draws no text box")
        let none = LupyIslandLayout.canvas(.whisper(textWidth: 0))
        ok(none.status == .motion, "an empty whisper draws nothing")

        // And a long whisper is truncated to the band, never allowed to overflow it.
        let long = LupyIslandLayout.canvas(.whisper(textWidth: 5000))
        atMost(long.width, LupyIslandLayout.maxWidth, "an enormous whisper still respects the width cap")
        atMost(long.statusBox.maxX, long.width - LupyIslandLayout.padEdge + 0.5,
               "…and its text stays inside the padding")
    }

    // MARK: 9. The defects that actually shipped, kept dead

    func regressions() {
        print("\n== regressions: the things that broke once ==")
        // (a) The island clipped its own status label at the rounded corner and it read
        //     "…your OK". No status text may start inside the corner radius, ever.
        for need in LupyCanvasNeed.samples {
            let c = LupyIslandLayout.canvas(need)
            guard !c.statusBox.isEmpty else { continue }
            ok(c.frame.containsRounded(c.statusBox, corner: c.corner),
               "\(describe(need)): the status text survives the island's rounded clip")
        }

        // The containment rule itself, on the geometry that actually shipped: a capsule
        // band 32 pt tall, and a label hung off LUPY's shoulder at the frame's left edge.
        // It was clipped to "…your OK". The rule must reject it and accept the fix.
        let band = LupyBox(x: 0, y: 0, width: 336, height: 32)
        let r = 16.0
        let clipped = LupyBox(x: -40, y: 7, width: 120, height: 18)
        ok(!band.contains(clipped), "a label hanging off the left edge is outside the frame")
        let biting = LupyBox(x: 0, y: 7, width: 120, height: 18)
        ok(!band.containsRounded(biting, corner: r),
           "…and one starting at the edge is bitten by the capsule's corner")
        let safe = LupyBox(x: 60, y: 7, width: 120, height: 18)
        ok(band.containsRounded(safe, corner: r),
           "the kernel's placement — inboard of the corner — survives the clip")
        // In an open canvas the corner is 24 pt and the padding 16 pt, so content sits a
        // hair inside the arc. That has to be legal, or every card would fail.
        let openFrame = LupyBox(x: 0, y: 0, width: 640, height: 320)
        ok(openFrame.containsRounded(LupyBox(x: 16, y: 16, width: 600, height: 280), corner: 24),
           "a card at the 16 pt padding survives a 24 pt corner")
        ok(!openFrame.containsRounded(LupyBox(x: 4, y: 4, width: 632, height: 312), corner: 24),
           "…and one pushed into the corner does not")

        // (b) Two characters in one app: the island drew Coucou's orange while the approved
        //     LUPY lived only in a preview. One source of truth for the state colour.
        ok(LupyPalette.accent == LupyCharacterState.working.colour,
           "the interface's accent and the character's working light are the same value")
        for s in LupyCharacterState.allCases {
            ok(LupyPalette.statusGlow(s) == s.colour.mixed(with: .black, 1 - s.glowStrength),
               "no second brightness for \(s.name)")
        }

        // (c) A vertical phone panel. Every canvas, from every need, is landscape.
        for need in LupyCanvasNeed.samples {
            let c = LupyIslandLayout.canvas(need)
            atLeast(c.width, c.height, "\(describe(need)): the canvas is horizontal")
        }

        // (d) A canvas that ignores the device's own band. Whatever notch width arrives,
        //     rest matches it — the island never invents a silhouette of its own.
        for nw in [120.0, 180.0, 200.0, 260.0, 320.0] {
            let c = LupyIslandLayout.canvas(.rest, notchWidth: nw)
            near(c.width, nw, 0.5, "rest follows a \(Int(nw)) pt notch")
            ok(LupyIslandLayout.violations(of: c, need: .rest).isEmpty,
               "…and a \(Int(nw)) pt notch still produces a legal canvas")
        }
    }

    // MARK: Helpers

    func describe(_ n: LupyCanvasNeed) -> String {
        switch n {
        case .rest: return "rest"
        case .whisper(let t): return "whisper(\(Int(t)))"
        case .answer(let l, let c, let p): return "answer(\(l) lines, \(c) chips\(p ? ", provenance" : ""))"
        case .task(let s, let p, let v): return "task(\(s) steps\(p ? ", plan" : "")\(v ? ", preview" : ""))"
        case .decision(let o, let e, let q): return "decision(\(o) options\(e ? ", evidence" : "")\(q > 1 ? ", queue \(q)" : ""))"
        case .transcript(let l): return "transcript(\(l))"
        case .chat(let t, let s): return "chat(\(t) turns\(s ? ", streaming" : ""))"
        case .settings(let r): return "settings(\(r) rows)"
        case .capture(let a): return "capture(\(a) actions)"
        }
    }
}

@main
struct Entry {
    static func main() {
        DesignTests().main()
    }
}
