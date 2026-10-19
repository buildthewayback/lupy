# LUPY 3 AUDIT — the dismantling map (v2, 17 Oct 2026)

Every Coucou surface, service and behaviour; verdict per part; nothing "half-half" survives.
Verdicts: **KEEP-CHASSIS** (engineering under the hood), **KEEP-FEATURE** (earns its place,
re-skinned), **REBUILD** (dies as-is; a Lupy-native version replaces it), **REMOVE**.

Founder decisions locked in: coding-era parts die. Utilities (music, mail, notes, clipboard,
iPhone link, Flow daily pages) **stay**, rebuilt island-first in the new design system
(docs/LUPY3_UI_RESEARCH.md). Contract: docs/LUPY3_BLUEPRINT.md.

## A. Island (the window machinery + views)

| Part | What it is | Verdict | Notes |
|---|---|---|---|
| IslandPanel / window controller / FSM | notch window, expand/collapse, modes | **KEEP-CHASSIS** | the hardest engineering in the app; stays |
| IslandRootView, IslandContainer, shapes | island chrome, animations | **KEEP-CHASSIS** | hover pop + click-outside already Lupy |
| Mochi drawing + animations + sounds | the character | **KEEP-CHASSIS** | he is Lupy now (private-use artwork) |
| `.lupyChat` island view | the conversation | **KEEP-FEATURE** | becomes the island's home; gains step ledger + briefing |
| `.overview` + TabButtons + pills row | Coucou's pill home ("code helper" etc.) | **REBUILD** | pills row dies; replaced by Lupy quick jumps + task ticker |
| Agent pills (Claude, Codex, custom) | coding agents in the island | **REMOVE** | the founder's #1 complaint |
| `.prompt` (Coucou chat w/ Claude) | Coucou's own chat | **REMOVE** | Lupy's conversation replaces it entirely |
| `.approval` card | approvals in the island | **KEEP-FEATURE** | already wired to the engine; becomes risk-ranked |
| `.mail`, mail pill + drafts | mail capture | **KEEP-FEATURE** | decided 17 Oct — island-first rebuild |
| `.capture` (⌃⌥X screenshot) | screenshot → ask Claude | **REBUILD** | becomes Lupy research: screenshot → Lupy's own brain/vision |
| `.wardrobe` | Mochi outfits | **KEEP-FEATURE** | delight; costs nothing |
| `.listening` / `.voiceResult` | voice command flow | **KEEP-CHASSIS** | wake word already "OK Lupy" |
| `.upload/.uploading/.choose` | Coucou's file-upload flow | **REMOVE** | essence absorbed: files enter via island file shelf + chat |
| Desktop Mochi (drag out of notch) | character on the desktop | **KEEP-FEATURE** | delight |
| VitalsHoverLine | system stats under Mochi | **KEEP-FEATURE** | quiet utility |
| *(new)* island file shelf | drop files on the island | **BUILD** | the best-loved island-app pattern (see UI research) |

## B. Services under the hood

| Part | Verdict | Notes |
|---|---|---|
| VoiceEngine + WakeSpotter + WakePhrase | **KEEP-CHASSIS** | voice commands; "OK Lupy" first |
| VoiceBrain (rule parser) | **KEEP-FEATURE** | offline commands (music, notes, mail) |
| ClaudeService + ClaudeVoiceBrain (cloud brain for voice) | **REBUILD** | routes to Lupy's API hub instead of its own |
| Claude/Codex hooks (HookServer, plan gauges, terminal hooks) | **REMOVE** | coding-agent integration — dead |
| MusicController + Spotify integration | **KEEP-FEATURE** | decided 17 Oct — island now-playing chip |
| Mail drafts + MailKit | **KEEP-FEATURE** | decided 17 Oct — island-first |
| PhoneLink / LiveActivityRelay (iPhone) | **KEEP-FEATURE** | decided 17 Oct — quiet link, island surface |
| WeeklyRecapView | **REBUILD** | becomes the morning briefing |
| CaptureCard annotate/ask | **REBUILD** | into Lupy research |
| DemoEngine | **KEEP-CHASSIS** | powers self-tests/screenshots |
| FluidAudio dictation + MacDictation | **KEEP-CHASSIS** | core input |
| ShortcutLogic (⌃⌥Space etc.) | **KEEP-FEATURE** | Lupy-first mapping |

## C. The window (hub)

| Part | Verdict | Notes |
|---|---|---|
| Hub window + sidebar | **KEEP-CHASSIS** | restyled dark-glass; Lupy group + kept utilities |
| Lupy pages: Today/Needs you/Tasks/Projects/Handoffs/Memory/Activity/Usage/Control/Assistant | **KEEP-FEATURE** | Today leads with the conversation; Handoffs grows into the agent-orchestration view with "Lupy's Computer" live preview |
| Flow pages: dictation, notes | **KEEP-FEATURE** | decided 17 Oct — island-first, same design system |
| Flow: insights | **ABSORB → REMOVE** | its essence becomes the morning briefing |
| Flow: dictionary | **ABSORB → REMOVE** | asking about words is Lupy research |
| Flow: snippets | **ABSORB → REMOVE** | becomes recipes/memory (one-time instructions) |
| Flow: styles | **ABSORB → REMOVE** | becomes Lupy personality settings |
| Notch settings: general, voice, shortcuts | **KEEP-FEATURE** | restyled |
| Notch settings: pills, agents, chat, integrations | **REMOVE** | their subjects die |
| GitHub poller/pulse | **REMOVE** | coding evidence; the founder doesn't code |
| SettingsView (Coucou's) | **REBUILD** | Lupy's simple settings absorb what's kept |

## D. Lupy's own (from the current build — all KEEP, extended)

LupyCore engine + tests; conversation layer (LupyChat); AI APIs hub (any-key + failover — the
front door of the model pool); control engine + cursor overlay + safety gates; memory/events;
quick jumps; HoverTips; data formats (journal, conversation.json, backups keep loading).

## E. The new parts (Phase 4 builds)

1. **Orchestrator core** (pipeline state machine: clarify→research→plan→approve→delegate→
   verify→deliver→learn) on the engine's task/approval/evidence system.
2. **Model pool manager** (roles router/thinker/eyes across many connected free tiers; quota
   ledger; drains free quota first; per-step selection).
3. **Research engine** (browser research runs; source storage; anchor references).
4. **Agent registry + brief builder** (ChatGPT/Arena/Muse; briefs from memory; reply parsing).
5. **Vision browser mode** (screenshot → eyes model → cursor steps; hybrid with AX).
6. **Second brain layers** (recipes, mistake rules, episodic no-repeat store).
7. **Morning briefing** + earned-autonomy ladder mechanics.
8. **New UI system** (dark glass, plan cards, step ledger, Lupy's Computer, file shelf —
   per docs/LUPY3_UI_RESEARCH.md).

## Decisions log
- 16 Oct: coding pills/services, Coucou chat, agent settings die; chassis (window/character/
  dictation/engine) stays; weekly recap → morning briefing.
- 17 Oct: music, mail, notes, clipboard, iPhone link, Flow daily pages STAY (island-first
  rebuild). Insights/dictionary/snippets/styles are absorbed into Lupy-native equivalents
  rather than kept as pages. Island gains a file shelf.
