# LUPY 3 UI RESEARCH — the design system for the rebuild (17 Oct 2026)

Founder directive (verbatim): "u need resech heavily ui modern and things etc that other ai
agentic now a days making stiles and undertant bcs this si need fine like amaizng."
This doc distills what today's best AI / agent / island apps do, and turns it into Lupy's
design rules. Concept render: docs/concepts/lupy3-island-concept.png (direction only).

## 1. What the best apps do now (findings)

**Island apps (NotchNook, Boring Notch, Seam, DynamicLake)**
- The notch is an *ambient layer*: live activities (now-playing with album art + wave
  animation, countdowns, timers) shown around the notch with no click needed.
- Hover expands; click opens the full "nook". Works on non-notch Macs as a top-center island.
- Best-loved feature: the **file shelf** — drag any file onto the island, it sits in a tray,
  drag it out later or AirDrop it. Reviewers love this more than the widgets.
- Widgets scroll horizontally and auto-fit; the island never feels crowded.

**AI chat surfaces (ChatGPT / Claude / Perplexity conventions, 2026)**
- Dark mode is the default for AI panels, with system-aware switching.
- **Streaming text with a visible cursor** is the standard; skeleton + shimmer + honest
  "thinking" micro-copy replace spinners.
- Desktop: history rail + message column capped ~720–768px + a detail/artifact panel that
  slides in only when there's something to show.
- Composer is docked, never floating over messages. Auto-scroll only when already at the
  bottom; otherwise a "jump to latest" chip appears.
- The **first message does more work than the model**: scope + limits + one concrete next
  move, rendered instantly (never streamed). Conversation starters only in the empty state.
- Keep messages short: two 40-word beats beat one 80-word block.
- Voice is first-class: persistent mic, waveform while listening, live transcription, and a
  clear "mic is active" trust indicator.
- Trust UI: citations and confidence are first-class elements, not footnotes. Design the
  failure states first (refused, timed out, low confidence) — the happy path rarely builds
  trust; the failures decide it.

**Agent surfaces (Manus, agentic-UX pattern libraries)**
- Agent UI ≠ chat UI: the unit is a *task*, not a turn. The user is absent for most of the
  run, so the UI must stay trustworthy without being watched.
- **Plans are interface objects**: an editable card — goal, steps, which steps touch the
  outside world, which are reversible, where it pauses for approval, assumptions.
- **Live step ledger**: vertical list, one line per step, status glyphs (○ pending, ● running
  animated, ✓ done, ✗ failed), expandable into details, running step pinned in view.
  Elapsed time + completed steps instead of percent bars (total length is unknown).
- **"The agent's computer" panel** (Manus's signature): a live view of the agent's browser.
  Collapsed = a bottom dock with a live thumbnail, status dot, timer, step counter (e.g. 2/5).
  Expanded = the full live preview with the step list beside it.
- **Approval queue ranked by risk**, each with enough context to decide without opening five
  tabs. Checkpoints proportional to risk and impossible to miss.
- Steps in plain human language ("Reading the salon's current site"), never tool-call names.
- Every action auditable after the fact, undo where possible, and a clear "return moment"
  when the agent finishes. Usage/credits chip always visible.

**Material (Apple Liquid Glass, 2025–2026)**
- Apple's Liquid Glass (macOS Tahoe 26): translucent layers, specular highlights, content
  first, controls recede. In the 2026 revamp Apple *reduced* default transparency and added a
  clear↔frosted user slider — the lesson: **restrained, adaptive glass, never heavy**.
- 12px-class corner radii are the modern Mac language; dark-first palettes with one accent.

## 2. Lupy's design rules (what we build)

1. **Dark-first glass island.** Adapts to light/dark; frosted panels with subtle highlights;
   a "clear ↔ calm" transparency preference. Never heavy blur.
2. **Island = ambient layer.** Collapsed: character + tiny status (active-task ticker,
   now-playing, next-event countdown, mic state). Hover pops a summary; click opens the
   conversation. A **file shelf**: drop files on the island to hand them to Lupy.
3. **Conversation home.** Streaming text with cursor, docked composer, ~720px column in the
   window, jump-to-latest chip, first message instant (scope + one next move).
4. **Plan cards.** Every plan is an editable card: steps, outside-touching steps marked,
   reversibility, pause points, assumptions. Approve / edit / reject.
5. **Live step ledger** for every running task — glyphs, one-line steps, pinned running step,
   elapsed time, human-language step names.
6. **"Lupy's Computer"** — the watch-it-work view: collapsed bottom dock (live screenshot
   thumbnail, timer, step counter) inside the task view; expands to the full live browser.
7. **Needs-you queue, risk-ranked.** One list, riskiest on top, enough context inline to
   decide at a glance. Chat itself is never gated.
8. **Calm design.** One accent color, generous spacing, no visual theatrics; motion explains
   state changes and nothing else.
9. **Trust surfaces.** Citations on research, cost per task, "why" labels when Lupy adapts,
   and designed failure states (stalled, low-confidence, refused).
10. **Utilities island-first.** Music, mail, notes, clipboard, iPhone link live as quiet
    island surfaces + window pages in the same design system.

## 3. Design tokens (starting point, tune during build)

- Backgrounds: #0F0F0F base, #1A1A1A panel, #2A2A2A elevated (light mode mirrors these).
- Accent: TBD with the founder (NOT mango — the org name is not the character; first guess
  rejected 17 Oct). Synvy-style soft glow on dark. Status: blue running, green done,
  gray pending, red destructive.
- Text: white primary / #9A9A9A secondary. Radius: 12–16px. Type: SF system, tight titles,
  comfortable 15–16px body.
- Motion: 150–250ms ease; running-step pulse; streaming cursor; nothing bounces.

## Sources
- Island apps: howtogeek.com, macstories.net, theverge.com, lifehacker.com, imore.com
  (NotchNook reviews 2024–26); comparisons: getseam.app, notchy.dev (2026).
- AI chat UI 2026: groovyweb.co.uk (12 trends), setproduct.com (chat states),
  designpixil.com (chatbot patterns), uxpin.com.
- Agent UX: setproduct.com (16 agent UI patterns), agentic-ux.com (lifecycle framework),
  fuselabcreative.com (agent UX), Manus design-system gist on GitHub, workos.com.
- Liquid Glass: apple.com newsroom, theverge.com (WWDC25 + Tahoe hands-on),
  en.wikipedia.org ("Liquid Glass" — 2026 revamp), macrumors.com.

## 4. Round 2 — the smart canvas (founder direction) + new references (17 Oct, evening)

The founder sharpened the vision: **the island IS the app — a smart canvas.** Collapsed it's
just Lupy's avatar under the camera (Siri-orb-like, "no UI"). When asked, it blooms into an
answer canvas; when working, it grows into a task canvas — "multi purpose canvas not need to
be same." Persistent UI = mic + text composer only. No ordinary dashboard; settings open a
minimal one on demand. Micro-steps, progressive disclosure, glassmorphism, stepped flows —
his reference patterns (Dribbble: agentic personalization/memory UI; Synvy Neuro — mobile,
adapted smaller/nicer for the island). Linear = the polish bar.

**References studied (founder-supplied, 17 Oct):**
- **Vibe Island** (vibeisland.app) — dynamic island for AI agents: monitor/approve/jump from
  the notch. Steal: permission requests with diff preview + Allow ⌘Y / Deny ⌘N; agent
  questions with numbered quick-answers (⌘1/⌘2/⌘3); "Done — click to jump"; per-step activity
  trees (Read/Edit/Bash with sizes); usage/quota at a glance; synthesized sound alerts;
  pure Swift under 100MB RAM; famously great onboarding.
- **AgentsRoom** (agentsroom.dev) — floating always-on-top island: three states read in ¼
  second via animation (idle / active / needs-input); hides when idle; finish notification
  "surges" beside the island for seconds, click → jump; missed alerts fold into a history
  list under the island; per-agent status dots grouped by project.
- **Coworker — orchestration guide** (coworker.ai) — validates our architecture: orchestration
  = decide what runs + move state between steps + handle the unhappy path; "an orchestration
  layer does not have to be an agent — deterministic code is easier to reason about than a
  model deciding"; context fragmentation (not coordination bugs) kills orchestration
  projects — synthesized memory must come BEFORE orchestration (our second brain, first).
  Multi-agent beats isolated agents (~30% efficiency); workflows must pause for human input
  for days and resume without losing state (our engine already does).
- **Linear** (linear.app) — the polish bar: agent replies as short result cards with
  provenance lines ("Worked for 8 sec"; "created via Slack on behalf of…"); calm dark UI,
  speed, keyboard-first, zero noise.

## 5. Revised design rules (supersede §2 where they conflict)

1. **Avatar-first.** Rest state = Lupy as a tiny living icon under the camera. Ambient state
   readable at a glance (calm / working / needs-you) via motion, not text. Hides when idle
   is optional; default stays visible-but-tiny.
2. **The canvas grows per need, never fixed.** Answer → small bloom (streaming text,
   citations, cost chip, quick-reply ⌘1/⌘2). Task → grows into plan card, step ledger,
   "Lupy's Computer" preview, approval cards (Allow/Deny + evidence). Then folds away.
3. **Composer is the only permanent control** — mic + text field at the canvas foot.
4. **Progressive disclosure everywhere.** Nothing shown "just in case." Micro-steps
   (wizard-style) for anything with a shape; save/confirm inline, contextual.
5. **Surge notifications** for finishes and needs-you; click to jump; missed ones fold into
   island history.
6. **Window = on-demand, minimal, Linear-grade.** Settings + deep management only.
7. Keyboard-first on every card (⌘Y/⌘N approvals, ⌘1–3 quick answers, Esc stops everything).
8. Result cards carry provenance ("researched 4 sources · 2 agents · $0.11 · 3m").
9. Utilities (music/mail/notes/clipboard/iPhone) are canvas surfaces + ambient chips, never
   dashboard rows.
10. Character: **original mascot, capsule eyes, same-or-better quality than the current
    one** — Coucou's asset/rig system as the engineering base, artwork fully ours.

Sources added: vibeisland.app, agentsroom.dev/features/dynamic-island,
coworker.ai/blog/ai-agent-orchestration-platform, linear.app,
dribbble.com/shots/27265967 + 27420244 (pattern references).


## 6. Round 3 — corrections + the real style target (17 Oct, night)

**Rejected by the founder:** the first concept renders ("the ui u make is so bad") — vertical
phone-style panels and a mango accent. Lessons: the island UI must be HORIZONTAL (PC/laptop
first), widget-like; never assume theme from names — ask.

**The style target: Synvy Neuro** (RonDesignLab, Dribbble shot 27420244) — dark
glassmorphism health-app aesthetic: deep dark canvas, frosted-glass cards, soft gradient
glow, rounded corners, gentle charts. The founder: "i love this."

**Glassmorphism craft rules (from the research):**
- Restraint: glass on the few key surfaces (island panels, cards), not everything.
- Dark mode is its own problem: light-mode glass disappears on dark; plan both.
- Text contrast: pair blur with a 10–30% tint overlay; WCAG 4.5:1 minimum on glass.
- Recipe: semi-transparent fill, backdrop blur + saturation boost (what separates Liquid
  Glass from plain frost), 1px hairline border (white 10–25%), soft shadow, 8–24px radius.
- Avoid the "AI-default" look: no three big animated blurred orbs; use 2–3 static radial
  gradients as directional light.
- The Dynamic Island should morph like a living organism — one spring animating width,
  height, radius together (Apple's own Live Activities guidance: "deliberate elasticity").

**Order of work (founder directive):** 1) character base → approve; 2) UI per use case →
approve; 3) backend. AI images must be persistent and accurate: approved options become
references that all future generations follow.

Sources added: dribbble.com/RonDesignLab (Synvy Neuro), nngroup.com glassmorphism,
uxpilot.ai glassmorphism guide, rocket.new glass reference data, codefronts.com dynamic
island morphing pill, developer.apple.com WWDC23 "Design dynamic Live Activities",
github.com/Ebullioscopic/Atoll (macOS island OSS).
