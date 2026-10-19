# LUPY 3 BLUEPRINT — the personal AI orchestrator (v2, 17 Oct 2026)

The contract for the rebuild. Founder reviews and approves this before building.
Source: docs/LUPY3_PLAN.md (the interview, rounds 1–4). Status: DRAFT for founder review.
v2 changes: swarm architecture confirmed (one face, many models); utilities decision
(music/mail/notes/clipboard/iPhone stay, island-first); UI design system linked.

## 1. Identity

**Lupy is your personal AI orchestrator + assistant.** One lightweight Mac app that lives in
the island. The conductor: it decomposes what you want, routes each piece to the right model,
agent or tool, carries the context so nothing repeats, checks the work, and keeps you in the
loop when it matters. JARVIS-class usefulness; zero fake confidence.

## 2. The core pipeline (every real task flows through this)

```
INTAKE → CLARIFY → RESEARCH → PLAN → PREVIEW → APPROVE → DELEGATE → VERIFY → DELIVER → LEARN
```

1. **Intake** — chat (island or window), dictation, or a routine trigger.
2. **Clarify** — the brain asks the *minimal* questions ("who's it for? deadline? hours?") and
   proposes defaults from memory first ("last time we did X — same?"). Quick, never an interrogation.
3. **Research** — always research-first, like a human pro: Google for knowledge, Pinterest/
   Behance for design anchors. Gathers sources, spends real time, **anchors on the best
   reference** and aims to beat it. Never "run and start with anything." Sources are stored
   with the task as evidence.
4. **Plan** — a structured plan: steps, which agent/tool does each, time estimates, limits,
   acceptance criteria. Rendered as a **plan card** (an editable interface object).
5. **Preview + approve** — the founder approves before anything big runs; optional AI-image
   preview for visual work.
6. **Delegate** — per-step briefs with **exact directions, limitations, and times**, written
   the way AIs parse well, auto-built from memory + plan (this kills the repeat-yourself tax).
   Delivered to ChatGPT / Arena / Muse via the browser handoff.
7. **Verify (hard)** — Lupy opens the work, looks, compares against the approved plan. Off-spec
   → sent back with notes (bounded retries, then escalates to the founder). Pass → deliver.
   The founder only sees work that passed.
8. **Deliver** — what was done, the evidence, and the cost ("this task ≈ $0.23").
9. **Learn** — corrections and approvals become memory; repeated patterns become recipes;
   **mistakes become rules that fire before the same mistake can happen again.**

## 3. One face, a swarm behind — the model pool

**You talk to Lupy; Lupy runs a swarm.** One personality in front; behind it a pool of models
from every provider the founder connects (many free tiers) plus sub-agents spun up per task —
"5 or 10, whatever the task needs." Sub-agents (researcher, planner, brief-writer, verifier,
browser driver) are stateless workers: **Lupy's brain holds all memory** and hands each one a
brief; results flow back through Lupy so the experience always feels like one assistant.

- **Roles, not brands.** Router (intent, small edits, summaries — free/cheapest), thinker
  (clarify, synthesis, plans, briefs, verification — the strong model, where the money goes),
  eyes (vision, chosen per task, cheap↔best).
- **Pool economics.** The engine drains free-tier quota first and spreads load across
  providers, paying only when a step truly needs the strong model. Target stays ≤ ~$15/month;
  the swarm makes it cheaper, not more expensive.
- Cost is driven by **thinking-steps, not model names**: memory hits, cached research and
  non-repeating briefs are the money savers.
- Every call: engine ledger + policy + budget caps ($15/mo ≈ $0.50/day default, adjustable);
  per-task cost always shown. Auto-failover across providers (already built and tested).

## 4. The second brain

Layers (all engine-side; survive model switches; nothing vendor-hosted):
1. **Profile** — who the founder is, tastes, preferences, how he likes things.
2. **Projects** — context, decisions, references, standing rules, current status. *Built first.*
3. **Episodic** — what was asked, what every agent was told, what came back (the no-repeat core).
4. **Recipes** — learned workflows ("the salon-site recipe": research → anchors → structure →
   agents → checks), improving with every run.
5. **Mistake rules** — every correction becomes a rule that fires *before* the same mistake;
  repeated success promotes autonomy.

## 5. The browser agent (hands + eyes)

- **Hybrid**: Accessibility/DOM-first (fast, precise, free) for known-simple pages; **vision
  mode** (screenshots → model → human-like cursor) for visual, complex or hostile pages.
- Cursor behavior: Lupy's own cursor overlay (his pointer is never moved), human-paced, with
  the eyes rule choosing the vision model per task.
- Watch-mode by default; **background only for routines with a proven record**.
- Guardrails (non-negotiable): asks before send/post/delete/pay; never types passwords, PINs,
  2FA; never touches CAPTCHAs (stops and says so); pauses when the founder types; Esc stops all.

## 6. Earned autonomy ladder

| Level | What Lupy may do | How it's earned |
|---|---|---|
| L0 (day one) | everything through the founder: clarify, approve, verified results shown | — |
| L1 | research + page checks + brief prep run alone; **nothing sent** | first clean weeks |
| L2 | proven routines run in background, report after | recipe success rate |
| L3 | starts before he wakes up ("morning start") | weeks of clean verified record |

Promotion AND demotion are automatic, based on the engine's verified track record (reliability
system already built). Low-effort output to please is a design impossibility: verification is
against the approved plan, not against "did it answer".

## 7. Surfaces — the smart-canvas island (v3, 17 Oct evening)

The founder's direction: **the island IS the app — a smart canvas.**

- **Rest state: just the avatar.** Lupy lives as a tiny living icon under the camera (like
  Siri's orb, but him). No UI until needed; ambient state readable at a glance (calm /
  working / needs-you) via motion, not text.
- **It grows as needed — a multi-purpose canvas, never fixed.** Ask -> a small glass canvas
  blooms with the answer (streaming text, citations, cost chip, quick-reply options 1/2).
  A real task -> the canvas grows into plan cards, the live step ledger, "Lupy's Computer"
  browser preview, approval cards (Allow / Deny with evidence). Then it folds away.
  Progressive disclosure: nothing shown "just in case"; micro-steps (wizard-style) for
  anything with a shape.
- **Always present: the composer** — mic button + text field at the canvas foot. The only
  permanent control.
- **Surge notifications**: finishes and needs-you surge beside the island for a few seconds,
  click to jump; missed ones fold into history under the island.
- **The window opens on demand only** — a minimal, Linear-grade dashboard for settings and
  deep management (tasks/projects/memory/usage). Never the home. No ordinary dashboard.
- **Morning briefing, now-playing, countdowns, file shelf** live on the canvas.
- **Look and feel**: Synvy-Neuro-style glassmorphism — deep dark canvas, frosted glass
  cards, soft gradients and gentle glow, 1px hairline borders — laid out HORIZONTAL and
  widget-like (PC/laptop first), never a vertical phone panel. The on-demand window keeps
  Linear-grade polish. Full system: **docs/LUPY3_UI_RESEARCH.md**; renders: docs/concepts/
  (first vertical attempt rejected by the founder, 17 Oct night).

## 8. What stays from the current build (already his, tested)

LupyCore engine (goals/plans/tasks/approvals/verification/ledger/budget/failover — 108 tests),
the conversation layer, the AI APIs hub, the control engine + cursor overlay, dictation,
sounds/character animations (private-use artwork), data formats (journal keeps loading — no
data loss). The character *system* (rig, frames, sounds) is kept as engineering; the mascot
himself is **the founder's own design** — same animation system, quality and
interactivity as Coucou's character, his own shape (reference saved at
docs/concepts/founder-ref-20261017.jpg) — rendered in **white** (the base color, right over
the dark notch; "mango" was the agent's wrong assumption — the org name is not the character)
with **tall solid-black capsule eyes, no pupils — THE signature trait**. Traits to design
after the base is approved: a crown + 5–6 accessories, ~5 seasonal items, a daily/night set
(pyjamas) — fancy, never overloaded. Workflow: AI candidates → founder approves → the
approved render becomes the persistent reference passed into every future generation.

## 9. What dies (final list in docs/LUPY3_AUDIT.md)

Coding pills and their services (Claude Code, Codex, "code helper"), agents/chat/integrations
settings, Flow's coding-adjacent pages, weekly recap (reborn as the morning briefing), every
Coucou-branded surface. **Utilities decided 17 Oct: music, mail, notes, clipboard, the iPhone
link and the Flow daily pages STAY** — rebuilt island-first in the new design system, quiet
and always usable; coding-era leftovers still die.

## 10. Verification of the rebuild itself

- Every pipeline stage has engine tests (sandbox, free).
- Chat self-test extended: the salon-story as an end-to-end journey (clarify→plan→approve→
  delegate→verify→deliver→learn) with a fake model — no network.
- Browser agent: local test pages, then real-site journeys on CI Macs (fresh minutes on the
  new GitHub account).
- Founder acceptance: the checklist reborn as the "JARVIS test"; he tests with a real API key
  before anything is called delivered.
