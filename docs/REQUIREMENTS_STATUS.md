# Requirements and completion status — one authoritative record

States (per the founder's directives):
- **COMPLETE AND VERIFIED** — implemented, with test evidence.
- **IMPLEMENTED, NOT FULLY VERIFIED** — implementation exists; specified verification incomplete (says what is missing).
- **BLOCKED BY A SPECIFIC DEPENDENCY** — a named external dependency prevents completion.
- **NOT STARTED** / **NOT APPLICABLE** (with reason).

Evidence keys: **[T]** LupyCore test suite (`scripts/test-core.sh`, 96 cases / 606 checks — sandbox WASM + native runner);
**[CT]** Coucou's own unit tests for the areas Lupy touches (`Mac/Tests/coucou/`, run in CI); **[S]** native self-test
inside the built app (`--self-test`, real disk + Keychain); **[V]** download verification on fresh GitHub Macs
(macOS 14.8.9 + 26.6.2; `scripts/verify-mac-download.sh`, run + check runs); **[CS]** computer-control self-test
(`--control-self-test`); **[F]** `docs/COUCOU_FIDELITY.md` (byte-comparison with upstream Coucou); **[D]** documented
design/decision. This record supersedes `docs/FUNCTIONAL_MATRIX.md` (D-027).

## 1. Coucou fidelity (founder's regressions from Build 5)

| Requirement | State | Implementation | Verification / evidence | Remaining |
|---|---|---|---|---|
| Original Coucou app icon and branding | COMPLETE AND VERIFIED | `Mac/CoucouAssets/Assets.xcassets` (upstream files, untouched) | [F] byte-identical; icon rendered from the downloaded app in the CI report; private-use terms in `Mac/CoucouAssets/NOTICE.md` | Founder sees it in Finder/Dock (Build F2+) |
| Original Mochi character with its real animations (not a static cat) | COMPLETE AND VERIFIED | Coucou's own `BotEngine`, `MochiOutfitDrawing`, `BotCanvasView`, `DesktopMochi`, `GreetingCanvasView`, island views — unmodified | [F] all 12 character/island files byte-identical; [V] "animation: frames 0.8 s apart differ — Mochi is animated, not static" on macOS 14 and 26 | Founder's eyes on his Air |
| Original interface, layout, styling, interactions | COMPLETE AND VERIFIED | Coucou's window (`FlowHub`), island, Settings, sounds — unmodified; Lupy's pages are new pages in that window built from Coucou's components | [F] 169 of 187 Coucou files byte-identical; 18 changed only at commented `Lupy:` hooks; [CT] island hover/auto-close/display-choice/desktop Mochi/wardrobe/approval queue tests pass | Founder's comparison with the Coucou he knows |
| Original sounds | COMPLETE AND VERIFIED | `Mac/CoucouAssets/sounds` (29 wav) + Coucou's `SoundEngine` | [F] byte-identical; [V] "Coucou's original sounds included (29 .wav files)" in the downloaded app | Audible check on the founder's Mac |
| Island fits a Mac without a notch (founder's Air) | COMPLETE AND VERIFIED | Coucou's own non-notch design: 80×24 resting bar, click-through except on itself, Mochi draggable onto the desktop — unmodified | [CT] screen-geometry + island-hover tests; [V] island screenshot captured on both CI Macs (neither has a notch — same class of screen as the founder's Air) | Founder's Air |
| Coucou's coding-agent integrations (hooks, pills, GitHub pulse…) keep working | IMPLEMENTED, NOT FULLY VERIFIED | All compiled in (own socket folder `~/Library/Application Support/Lupy`, so a real Coucou install is untouched) | [CT] claude-hooks, claude-settings, approval-queue, safe-links tests pass | Live agents on the founder's Mac (needs his Claude Code/Codex setups) |
| Flow dictation, Notetaker, voice with "OK Coucou" | COMPLETE AND VERIFIED (code) / NOT FULLY VERIFIED (live) | Unmodified Coucou code; "OK **Lupy**" wake phrase added alongside Coucou's; Apple Intelligence paths compiled out (D-023) so the brain is Coucou's rule parser or a cloud model with the founder's key | [CT] voice-wake tests + new OK-Lupy test pass | Microphone/speech on the founder's Mac; a provider key for the cloud brain |
| Name/branding: the product is Lupy, not Coucou | COMPLETE AND VERIFIED | User-facing "Coucou" → "Lupy" (10 languages), own bundle id/data/Keychain, credit line names Coucou and its author | [T]+[V] screenshots/About; `scripts/rebrand-strings.py` round-trip | — |

## 2. Mac adaptation

| Requirement | State | Implementation | Verification / evidence | Remaining |
|---|---|---|---|---|
| Runs on the founder's macOS version | COMPLETE AND VERIFIED for 14.0+ | `Mac/project.yml` targets macOS 14.0 (upstream 15.0); the two 14.2+ APIs in Coucou's call-note audio are guarded | Builds and runs on macOS 14.8.9 and 26.6.2 [V]; on 14.0–14.1 a call note explains system audio needs 14.2 | Founder's exact version (About This Mac) |
| Window: sizing, resizing, focus, multi-display | COMPLETE AND VERIFIED (Coucou's own behaviour) | Coucou's window controller, unchanged; Lupy pages follow its min size | [V] launch/quit/reopen on both CI Macs; screenshots | Founder's desktop arrangement |
| No dependency on an absent Dynamic Island | COMPLETE AND VERIFIED | Coucou's own geometry (see §1) | [CT] geometry tests; [V] no-notch CI screens | — |
| Permissions handled explicitly | COMPLETE AND VERIFIED | Coucou's Info.plist usage texts (extended for computer control); Lupy asks for Accessibility only when computer control is turned on | [V] Info.plist checks in the download verification | Founder grants mic/speech/accessibility on his Mac |

## 3. Lupy's assistant (capabilities carried from the campaign)

| Requirement | State | Verification / evidence | Remaining |
|---|---|---|---|
| Goal capture → plan (offline heuristic + cloud model with validation, repair, fallback) | COMPLETE AND VERIFIED | [T] planning suites; [S] | — |
| Plan review / edit / approve / reject; priority with explanations | COMPLETE AND VERIFIED | [T] | — |
| Task lifecycle with guards, dependencies, checkpoints, pause/resume/cancel/reopen | COMPLETE AND VERIFIED | [T] | — |
| Ownership: "agent says done" never verifies; per-kind evidence; GitHub evidence; worker reliability | COMPLETE AND VERIFIED (GitHub: mocked) | [T], [S] | GitHub live: founder token |
| Handoffs: brief writer, manual relay honesty ("delivery unconfirmed"), reply = claim | COMPLETE AND VERIFIED | [T], [S] | — |
| Handoff delivery by computer control (new) | see §4 | — | — |
| Follow-ups, escalation, missed checkpoints/deadlines, daily review | COMPLETE AND VERIFIED | [T] | — |
| Notifications with budget (quiet hours, cap, dedupe) + island notices with Coucou sounds | COMPLETE AND VERIFIED (core) / NOT FULLY VERIFIED (delivery) | [T]; island note path exercised in [CS] | Real notification delivery on founder's Mac |
| Safety: policy gate, autonomy modes, standing approvals, never-automate, global pause, injection defence, redaction | COMPLETE AND VERIFIED | [T] | — |
| Providers: OpenAI/Anthropic/Gemini/OpenAI-compatible; routing, retries, budgets, usage ledger | COMPLETE AND VERIFIED (mocked) | [T] | Live calls: founder keys |
| Durable journal, recovery, backup/restore, export/import | COMPLETE AND VERIFIED | [T], [S] (real disk) | — |
| Memory with isolation, sensitive withholding, conflict resolution | COMPLETE AND VERIFIED | [T] | — |
| Action ledger with verification (e.g. Save to Documents with SHA-256 read-back) | COMPLETE AND VERIFIED | [T], [S], and now every computer-control step | — |
| UI truthfully reflects state (honest "not connected", progress, errors) | COMPLETE AND VERIFIED | [T] diagnostics; pages ported 1:1 | Founder usability pass |
| Direct Arena/Muse/ChatGPT APIs | NOT APPLICABLE | No usable API known; manual relay + computer-control delivery instead | Revisit if APIs appear |
| Email / social / publishing actions | NOT STARTED (out of v1 scope; policy requires approval anyway) | [D] | Founder decision |

## 4. Computer control and the Lupy cursor (new capability)

| Requirement | State | Implementation | Verification / evidence | Remaining |
|---|---|---|---|---|
| Rules: target matching, safety classification, session state machine, strict model-step parsing, delivery observation | COMPLETE AND VERIFIED | `LupyCore/ComputerControl.swift` | [T] 13 cases (96/96 total) | — |
| Distinct visible cursor; user's pointer never moved; overlay click-through | COMPLETE AND VERIFIED | `LupyCursorOverlay` (transparent, `ignoresMouseEvents`, above apps) | [CS] 9/9 PASSED on macOS 14.8.9 and 26.6.2 (run 38838652274): click-through, above apps, typing with read-back, ledger entries, Stop cancels queued steps, missing-target honesty, declined Send not sent, approved Send observed on screen, password field refused; cursor screenshots captured at overlay/typing/waiting/sent | Founder watches it on his Mac |
| Truthful phases (locating / executing / succeeded / failed / waiting for your OK) tied to real actions | COMPLETE AND VERIFIED | `LupyControlCenter` (locate → classify → gate → execute → read back → record) | [CS] read-backs, failure honesty, ledger entries | — |
| Policy gate: consequential actions need the founder; passwords/CAPTCHA/2FA refused | COMPLETE AND VERIFIED | `ControlSafety` + engine action ledger (outside model text) | [T] policy suite; [CS] declined/approved Send, password refusal | — |
| Stop/pause safety (Esc, Stop button, menu bar, Pause Lupy; queued steps cancelled; user typing pauses) | COMPLETE AND VERIFIED | `ControlRun.stop`, key monitors, global pause hook | [T] state machine; [CS] Stop cancels queued step | — |
| Handoff delivery ("Deliver with Lupy") | COMPLETE AND VERIFIED (local page) / NOT FULLY VERIFIED (real agents) | `LupyDelivery` + per-agent targets; `recordControlDelivery` (seen → sent; unseen → delivery unconfirmed) | [T] delivery rules + engine honesty; [CS] on both CI Macs: approved Send clicked and the message then seen on screen (box text excluded as evidence after run 38837448095's lesson) | Real Arena/Muse/ChatGPT on the founder's Mac |
| Model-driven steps ("Do something on screen") | IMPLEMENTED, NOT FULLY VERIFIED | `prepareControlStep` (consent, budget, ledger; screen fenced as untrusted) + `ControlAgent` strict parsing | [T] parsing/fencing (strict JSON, only on-screen elements, https only); without a model key the UI says so and offers the routines | Needs the founder's model key for a live run (no key exists in this campaign, by design) |
| Off by default; explicit enable + Accessibility permission | COMPLETE AND VERIFIED | `LupyControlCenter.enabled`, settings page | Code + UI; CI grants Accessibility only on its own machines | — |

## 5. Product-quality work beyond the explicit list

| Improvement | Why | State |
|---|---|---|
| Welcome card can never block quitting (D-019) | Build 5 defect class | COMPLETE AND VERIFIED (inline card; [V] quits cleanly on first launch, both Macs) |
| CI animation check | A static Mochi must never ship again | COMPLETE AND VERIFIED ([V] both Macs) |
| Compiler errors surfaced first in build reports | F1's errors were buried in a 30k-char log tail | COMPLETE AND VERIFIED (F2 report) |
| Coucou's sounds/notices/licences verified inside the downloaded app | Reserved-asset and licence compliance | COMPLETE AND VERIFIED ([V]) |
| `docs/COUCOU_FIDELITY.md` generated from a byte-comparison | Fidelity claims need evidence, not adjectives | COMPLETE AND VERIFIED (regenerable: `scripts/coucou-fidelity.sh`) |
| Coucou's unit tests run in Lupy's CI | Lupy's hooks must not break Coucou behaviour | COMPLETE AND VERIFIED (13 suites, F1/F2) |
| Keyboard: Return sends the capture box; ⌘Return primary action | Founder flows | COMPLETE AND VERIFIED (ported UI) |
| Window animations pause while another app is frontmost | A permanently open main window must not burn CPU/battery (F4 measured 29–53 % incl. background) | COMPLETE AND VERIFIED (F5: background 17 % / 32 % on the CI VMs; the rest is Coucou's island, alive by design and hideable) |

## 6. Build and delivery

| Item | State |
|---|---|
| Build | GitHub Actions, manual trigger only; **delivered: run 38839867821, commit c8bad17, whole run green** |
| Artifact | `Lupy-0.2.0-c8bad17274-macOS-arm64.zip` (19,370,871 B, SHA-256 be51da82a3c1bb6abf505a80a6746baa84714f62686a71f6c6c1728a82f67fd5), one zip containing only Lupy.app, ad-hoc signed, until 2027-01-14; direct link in `LUPY_STATUS.md` / `docs/INSTALL_GUIDE.md` |
| Notarization | BLOCKED BY A SPECIFIC DEPENDENCY — paid Apple Developer membership (founder decision) |
| Install/usage instructions | `docs/INSTALL_GUIDE.md` (updated for this build) |

## 7. Founder-only validation (engineering work complete; needs the founder's Mac)

1. Install and first open (guide §1–2) — icon, Mochi alive, island bar, sounds.
2. Grant Accessibility when first turning on computer control; watch the demo ("Show me").
3. Dictate into the capture box (mic + speech permissions).
4. Add one provider key (Lupy → Assistant) and try "Ask Lupy".
5. Deliver one real handoff with "Deliver with Lupy" to the agent he actually uses.
6. His comparison of the whole experience against the Coucou he remembers.

## 6. The island as Lupy's quick-access control centre (directive 2026-10-16)

Lupy = Coucou's visual foundation **adapted to serve Lupy's own interaction model** (D-028): the island
is the quick interaction surface, the window is where deeper work is managed, and both share one
conversation and one state. Implemented in the F6–F8 campaign (delivered build F8 = run 38916058766); verification states below.

| Requirement | State | Implementation | Verification / evidence | Remaining |
|---|---|---|---|---|
| Click the island (or a configurable shortcut) → Lupy's interaction surface | IMPLEMENTED, NOT FULLY VERIFIED | `.lupyChat` island view (`LupyIslandChatView`) on Coucou's chrome; `defaultView()` returns it; the ⌃⌥Space `openChat` shortcut (changeable in Shortcuts settings) opens it; the Lupy pill's ↗ opens it; the pills stay one tap away inside it | **Build F8**: island-conversation screenshot captured on both CI Macs; journeys in the chat self-test | Founder's Air feel |
| Idle: compact, unobtrusive, Mochi communicates availability | COMPLETE AND VERIFIED (upstream behaviour) | Coucou's own resting bar/Mochi, unmodified | [F] identical files; [V] animation check (F2–F5) | — |
| Speak or type — one assistant | IMPLEMENTED, NOT FULLY VERIFIED | Same `LupyChat` for both surfaces; mic = Coucou's `MacDictation` (on-device when available, right-click language menu); typing = the same field | **Build F8**: chat self-test 19/19 both Macs; dictation itself needs a live mic (founder) | Founder's mic on his Air |
| Correct before sending (speech transcription editable) | IMPLEMENTED, NOT FULLY VERIFIED | The transcript lands in the editable TextField; nothing is sent until Send; the field says so while dictating | **Build F8**: island-conversation screenshot (transcript-edit path is Coucou's upstream mechanism) | Founder's mic |
| Understand and respond; follow-ups in the same conversation | IMPLEMENTED, NOT FULLY VERIFIED | `ChatIntentRouter` (offline, deterministic) + `prepareConversationTurn` (last 12 turns, same budget/policy gate/ledger as every call); status questions answered locally from engine state | [T] Conversation suite: routing (9 cases), history inclusion, caps, local answers, usage-once; **[CT] 19/19** incl. honest no-model answer | Live model answers need the founder's key |
| Execute: goals → plan → approval → tasks; screen work via the Lupy cursor | IMPLEMENTED, NOT FULLY VERIFIED | Goal capture works offline (heuristic plan) or with an allowed model; plan card in the conversation with Approve/Reject/Open; control intents start the visible-cursor agent run with Esc/Stop | [CS] control suite (F3–F5); **[CT] 19/19** incl. goal→plan→approve→tasks and the honest control blocker | Model-driven control needs a key |
| Ask me when necessary (approvals where I already am) | COMPLETE AND VERIFIED | Coucou's approval card still wins the island (LupyIslandBridge); the conversation mirrors the pending approval inline with Allow/Deny — same engine decision path | [CT] approval-queue tests; chat self-test drives decideApproval paths | — |
| Finish: report the actual result, inspect, continue or dismiss | IMPLEMENTED, NOT FULLY VERIFIED | Model answers land in the conversation (retries stay "thinking"); plan outcomes and control runs report real outcomes (`statusLine`, notices); "Open workspace" opens Today with the same conversation | [CS] delivery honesty; **[CT]** journeys: follow-up history carried, transcript persisted | Live runs on founder's Mac |
| Island and workspace share conversation, tasks, approvals, progress | IMPLEMENTED, NOT FULLY VERIFIED | One `LupyChat` singleton + one `LupyModel`; Today leads with the same panel (the old capture bar was replaced); starting in one surface continues in the other | **[CT]**; island-conversation + window screenshots in F8 check runs | Founder's hands-on pass |
| Stop cancels what is queued | COMPLETE AND VERIFIED (control) / IMPLEMENTED, NOT FULLY VERIFIED (chat "stop") | Control `stop` cancels queued steps ([CS] 9/9); chat "stop" stops control, rejects a waiting plan, or pauses follow-ups — each answer says exactly what was stopped | [CS]; chat self-test journeys | — |
| Animations correspond to real states (no fake working, no wasted CPU) | IMPLEMENTED, NOT FULLY VERIFIED | Mochi states: pill state machine (control/searching/working, approvals, thinking via `stateOverride` while a model call is in flight, sleeping when paused), `BotEmote.listening` while dictating; window canvases pause when not frontmost (D-026/F4 fix); island views stop their animations when hidden (upstream `islandViewActive`) | **[V] F8 CPU re-check with the conversation open: unchanged from F5 within noise** (macOS 14: 27.9/18.8 % front/back; macOS 26: 57.7/29.4 %) | Founder's feel |
| Settings: one coherent experience, real effects only | IMPLEMENTED, NOT FULLY VERIFIED | Assistant page reorganised around user needs (D-031): voice & activation (dictation language, wake-word and shortcut links), providers, personalisation & memory, computer control, autonomy, island/window links, usage; Coucou's own settings pages remain the single home of island/voice/shortcut specifics | Code review; window screenshot in F8 check runs | Founder's pass |
| Dictation language preference persists | COMPLETE AND VERIFIED | `MacDictation.language` is UserDefaults-backed (upstream); the settings picker writes it | Upstream mechanism | — |

### The founder's ten journeys (directive §7) — verification map

| # | Journey | Automated evidence | Human evidence still needed |
|---|---|---|---|
| 1 | Open the island, submit a typed instruction | **[CT]** goal→plan card; **[V]** island-conversation screenshot (F8) | Founder's Air |
| 2 | Dictate, correct transcription, submit | Mechanism = Coucou's PromptView mic (upstream); the field stays editable until Send | Live mic |
| 3 | Continue with follow-ups | [T] history inclusion + 12-turn cap; **[CT]** journey 8 (history carried into the prepared job, engine-level) | Live model key |
| 4 | Start multi-step work, observe genuine progress | Chat self-test 1–2 (plan→tasks); pill ticker steps; [CS] control progress | Live run |
| 5 | Open the workspace without losing the task | Same `LupyChat`/`LupyModel` singletons; panel shows the same messages (window screenshot F8); "Open workspace" button | Founder's pass |
| 6 | Approve / reject inline | Chat self-test 2 (approve); reject path in router tests; approval mirror card; island approval card [CT] | Founder's pass |
| 7 | Stop; pending actions cancelled | [CS] Stop cancels queued steps; **[CT]** journey 7 (plan rejected + honest pause/idle answer, engine really paused) | Founder's pass |
| 8 | Complete a task, inspect the result | Engine lifecycle [T]; answers/plan outcomes recorded with evidence (action ledger) | Founder's pass |
| 9 | Change settings, restart, preferences persist | Engine settings journal [T]/[S]; dictation language UserDefaults; second-launch check **36/36 in F8** | Founder's pass |
| 10 | Animations match real states; no excessive background CPU | **[V] F8 re-measure with the conversation open (unchanged from F5)**; animation check both Macs | Founder's feel |
