# LUPY 2 — "simple front, monster back" (founder feedback, 16 Oct 2026, after testing F8)

Founder's own words, condensed into workstreams. This supersedes parts of earlier directives
where they conflict (fidelity now means *character and animation*, not Coucou's feature set).

## What the founder said (source of truth)

- Character is **Lupy** from now on; remove every leftover "Mochi"/"Coucou" text in the UI.
  Keep the drawn character, animations, island design and sounds (private use, D-021).
- Island: **click outside closes it** (no X button), typing box **at the bottom**, minimal
  design, **hover labels** on every button, compact island **pops/zooms on hover** so it feels
  ready, opens fast (he hit slow opens).
- Island home = **the chat, always**, plus **quick-jump buttons for HIS daily things**
  (browser, work categories — his 10 activity areas, not Coucou's defaults).
- **One place for all AI APIs**: add any key (mainstream: Gemini/OpenAI/Anthropic **and**
  free-token third parties like CodeCraft — OpenAI-compatible), Lupy figures out the rest.
  **Auto-switch when one API hits limits/errors**, show **which model is running** in the
  island, and keep **agent memory consistent across model changes**.
- **Settings: far fewer, simple, non-tech.** He was confused by separate API setups (Coucou
  chat providers vs Lupy engine providers — real flaw). Keep the dashboard/projects he likes.
- **Remove what he doesn't use**: coding agents / VS Code / coding-oriented integrations, and
  default Coucou features he doesn't use (asked — see open questions).
- **RAM**: MacBook Air M1 2020, 8 GB, ~2 GB free. Target **well under 1 GB**. (Reality check:
  F8 measures 46–93 MB physical footprint already — the app is small; removing features trims
  further. Report honestly, don't "optimize" theatre.)
- **CI minutes are scarce**: research and plan first, ask before building, few builds.

## Workstreams

| # | Workstream | Notes |
|---|---|---|
| W1 | Rebrand all user-facing text to Lupy | strings sweep; character/animations unchanged |
| W2 | Island UX | input at bottom; click-outside close; hover zoom on compact bar; hover labels on buttons; snappy open; minimal chrome |
| W3 | Quick jumps for his 10 areas | island chat gets a small row of jumps (browser/sites/work) — content from his answer |
| W4 | One API hub | single APIs page: presets (Gemini/OpenAI/Anthropic/…) + custom OpenAI-compatible (name+URL+key); auto model discovery; ONE provider pool feeding everything (chat, plans, control agent, Coucou's chat); remove the separate provider settings |
| W5 | Auto-failover + status | provider chain: on limit/error switch to next; island shows current model; memory/history carried across switches (engine-side, already partly true) |
| W6 | Settings simplification | few simple cards; hide/remove coding things (Claude hooks, VS Code, workers/coding agents), unused integrations; keep dashboard/projects |
| W7 | Trim & RAM | remove unused code paths where cheap; verify footprint; no fake numbers |
| W8 | Research pass | check how other assistants do provider hubs/failover before coding; then one build |

## Answers (2026-10-16)

1. Quick-jumps: **browser + chat for now** (simple start; a "+" can let him add more later).
2. APIs: **"not sure — just make any key work"** → universal hub: presets + custom
   OpenAI-compatible (name + URL + key), auto-discover models, auto-failover chain.
3. Coucou extras (music, mail, notes, clipboard): **keep them all for now.**
4. His Mac: **macOS 15 (Sequoia)**, MacBook Air M1 2020, 8 GB RAM.

## Constraints carried over

- Budget: ≈1,290/2,000 Linux-eq min used (64.5%); plan for **at most 2–3 builds** this campaign.
- Honesty rules unchanged (no fake model replies, no pretending delivery).
- Keep: watchable computer control, approvals, plans/tasks, reminders, handoff honesty.
