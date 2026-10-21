# Lupy work log

Chronological, newest last. Times UTC. Each entry: package · what changed · tests · outcome · evidence.

## 2026-10-15

### 17:29 — Campaign start (WP-0)
- Read handoff package in prescribed order; verified checksums (5/5 match). `PASTE_TO_ARENA.txt` listed but not attached.
- Sandbox: Linux x86_64, no Swift/Xcode. GitHub: private repo, ADMIN integration token; **Actions billing endpoints return 403** → remaining minutes unknown.
- Fetched official billing docs: Free = 2,000 min; macOS $0.062/min vs Linux $0.006/min.
- Cloned Coucou read-only @ `f09ac0b`; verified MIT code licence + reserved assets (LICENSE-ASSETS.md).
- Found and validated a Swift 6.3.3 compiler compiled to WebAssembly on npm; Node WASI segfaults on link, browser_wasi_shim works → full compile/link/run of Swift programs in-sandbox.
- Decisions D-001…D-014 recorded (`docs/DECISIONS.md`).
- Evidence: `docs/ENVIRONMENT_VERIFICATION.md`, `docs/CI_BUDGET.md`, `docs/COUCOU_REUSE_MAP.md`.

### 18:25 — WP-2 part 1: LupyCore foundations (Tested)
- Dev compiler: fixed two real problems in the Swift-on-WASM toolchain harness — Node's built-in WASI segfaults randomly (moved compile/link/run to the pure-JS WASI shim), and the shim's file writes were quadratic (multi-MB object files took >10 min; patched to amortized growth → Codable-heavy file 4.4 s).
- Added `LupyCore`: JSON parser/writer (strict, depth-limited), Codable↔JSON bridge without Foundation, UTC timestamps/ISO-8601, IDs, SHA-256 (FIPS vectors), FNV-1a, domain model (projects, goals, plans, tasks with explicit lifecycle, evidence, handoffs, workers, reliability, memory, decisions, actions/policy/approvals, providers/budgets/usage, settings), event payloads + deterministic reducer, file-system abstraction with fault injection, durable event store (write-ahead batches, checksums, torn-tail recovery, snapshots + rotation + archive, idempotency keys across restarts, v0→v1 migration, interrupted-action detection), backup/restore (SHA-256, tamper detection, restore archives old data), per-project export/import with ID remapping, Markdown export.
- `scripts/lint-core.sh` guards macOS-14 availability (WASM stdlib has no OS availability), stdlib-only purity, secrets.
- Tests: `scripts/test-core.sh` → **24/24 passed, 125 checks** (Swift 6.3.3 WASM, Node 22).

### 18:52 — WP-3/4/5/6/7 core logic (Tested in sandbox)
- Added: Safety (secret redaction incl. Luhn card check, PEM blocks, labelled secrets; prompt-injection signals; untrusted-content fencing), PolicyEngine (forbidden kinds, global pause, untrusted-origin access denial, project never-automate rules, autonomy modes, narrow expiring standing approvals with use/cost caps, founder-only grants), BudgetGuard (daily/monthly hard caps, per-task and per-call approval thresholds).
- Verification engine (claims never verify; per-kind latest-evidence judgment; ambiguous ≠ contradicted; stale evidence ignored; elevated/strict oversight), lifecycle guards, transparent reliability rules per worker × task kind with founder override.
- Planning: model-plan JSON validation (cycles, unknown deps, caps, clamping, default criteria, JSON extraction from prose), offline heuristic planner, deadline phrases in local time, dependency graph; explainable prioritization with project weights; scheduler (follow-up backoff, escalation, checkpoints, deadlines, stalls, neglect, daily review, budget warnings, bounded CI re-checks) with idempotency keys; notification budget (quiet hours, hourly cap, dedupe).
- Providers: OpenAI / Anthropic / Gemini / OpenAI-compatible request builders + response parsers + error taxonomy + model-list refresh; keys never enter the core (auth placement filled by the shell); routing over founder-approved providers only; cost estimation; context builder with project isolation, sensitive-memory withholding, redaction and a "what was sent" manifest.
- Connectors: honest catalog (Arena/Muse/Orin = not connected → manual relay), GitHub read-only evidence (branch/PR/commit/check-runs → supports/contradicts/inconclusive), claim extraction, handoff brief writer, file-path policy.
- LupyEngine facade: bootstrap (founder's 10 projects + rules), goals/plans/approval, task lifecycle, delegation with manual relay ("delivery unconfirmed"), worker replies, GitHub verification loop, rework, acceptance, approvals/standing approvals, memory conflicts, decisions, model jobs (consent, budget, approval parking, usage exactly once, retries/backoff, provider fallback, JSON repair, offline fallback), scheduler tick, attention/brief/search/diagnostics.
- Tests: **80/80 passed, 498 checks** — incl. "agent says done, GitHub disagrees", injection, crash-restart, budget, pause, isolation scenarios.
- Fixed during testing: redactor over-redaction ("Token economy"), founder override path from submitted, and a real verification flaw (PR-exists vs CI-failed judged "ambiguous" → now per-kind latest evidence).

### 19:15 — WP-1/WP-9 macOS app shell written (not yet compiled)
- `App/` (XcodeGen project, no third-party packages): entry point with `--self-test`, `--demo`, `--data-dir`; AppModel (engine owner, effect executor, 60 s scheduler tick, wake/terminate hooks); platform layer (disk store with F_FULLFSYNC + atomic rename, Keychain adapted from Coucou, HTTPS executor that injects keys at send time, notifications, memory probe); Apple Speech dictation with review-before-send; original Lupy wolf-pup character (Canvas/TimelineView, 7 moods); notch island adapted from Coucou (geometry, shape, panel level) with click-to-open and auto-close; main window (Today, Projects, Tasks + detail, Needs you/approvals, Handoffs, Memory, Activity, Usage & budget, Settings, Onboarding); menu-bar extra.
- Original app icon rendered by `scripts/make-icon.py` from the same geometry as the in-app character.
- `scripts/build-mac-app.sh` (Release arm64, ad-hoc sign, verify, ditto zip, SHA-256, BUILD_INFO) and `scripts/smoke-mac-app.sh` (codesign/Gatekeeper report, native self-test, GUI launch with demo data in a temp folder, RSS/CPU, screenshots).
- Checks possible in the sandbox: SwiftSyntax parse of all app files (swift-format on WASM) = clean; 88 app→core call sites cross-checked against core signatures; core tests **81/81** (added demo seeding test; fixed demo labels).
- Decisions D-015 (app target Swift 5 mode, minimal concurrency checking) and D-016 (Dock app + island + menu bar).

### 19:19 — Native build #1 of the app: SUCCESS (run 38792443609, commit d119a7a)
- Xcode 26.6 / macOS 26.6.2 arm64 runner: **BUILD SUCCEEDED on the first attempt** (1 warning), 6.4 MB arm64 app, ad-hoc signed (valid), Gatekeeper rejects (expected: not notarized).
- Native self-test inside Lupy.app: 12/12 PASS incl. torn-write recovery on real disk, backup round trip, Keychain round trip, 400 durable writes in 557 ms (1.4 ms each incl. F_FULLFSYNC), ranking 7 ms, cold reload 28 ms.
- GUI launch with demo data: running, RSS ≈ 121 MB; CPU ≈ 15 % (ps lifetime average) → too high; screenshots retrieved via check runs show the island pill, menu-bar icon and Today screen rendering correctly.
- Artifact `Lupy-macOS-d119a7a…` 2.0 MB (zip SHA-256 476992c7…5d53), retained to 2026-10-29. Job 2 m 54 s ≈ 3 billed macOS minutes.

### 19:24 — Fixes from native evidence + action ledger (Tested in sandbox; app part pending build #2)
- CPU: attention summary cached per revision; sidebar character static; window animations only while Lupy is frontmost; island animates only when something needs you or Lupy is active; lower frame rates. Smoke test now samples instantaneous CPU with `top` (foreground and background) and physical footprint with `vmmap`.
- Plan titles: first line + "(+N more)" instead of the whole multi-line goal.
- Action ledger (`beginAction`/`finishAction`/`resolveUnknownAction`): policy-gated, idempotent, crash-safe "outcome unknown"; used by **Save to Documents/Lupy**, which writes the file, reads it back and compares SHA-256 before recording file evidence. "Needs you" lists interrupted actions to settle.
- Ask Lupy mode, model-written brief, advisory model reading of agent replies (UI for already-tested core features). Notices bounded to 800 in memory.
- Core tests **83/83, 515 checks**.

### 19:31 — Build #2 results recorded; final adjustments; delivery docs
- Build #2 (run 38793640196, commit bfb822a): build OK, self-test 12/12, physical footprint **49.5 MB**, CPU 12.4 % frontmost / 5.5 % background in the CI VM. Job 4 m 07 s ≈ 5 billed macOS minutes; cumulative ≈ 93 Linux-eq (4.6 %).
- Correction: the founder's MacBook Air M1 has **no notch** — the island appears as the top-centre pill seen in CI screenshots; guide, checklist and matrix corrected.
- Calm moods animate at 4 fps, island at 4 fps; "Offline planning" label no longer wraps.
- Added docs: EXECUTION_STRATEGY (D-017), ARCHITECTURE, FUNCTIONAL_MATRIX, TEST_REPORT, PERFORMANCE, KNOWN_LIMITATIONS (19 items), MAC_ACCEPTANCE_CHECKLIST, INSTALL_GUIDE; WORK_PACKAGES detailed.

### 19:36 — Final candidate build #3: SUCCESS (run 38794651725, commit 50c31bc)
- Native: 83/83 core tests; BUILD SUCCEEDED; self-test 12/12; footprint 50.0 MB (peak 51.9 MB); CPU 8.3 % frontmost / 3.9 % background in the CI VM; screenshot reviewed.
- Candidate: `Lupy-0.1.0-50c31bca33-macOS-arm64.zip` SHA-256 a40441c6f7b65a7bb5ffb28779ef4f9a577516053353cf6093493275f358338c inside artifact `Lupy-macOS-50c31bca…` (2,048,142 bytes, artifact digest sha256:4c983e6b…cc24, expires 2026-10-29).
- Job 3 m 40 s ≈ 4 billed macOS minutes; campaign total ≈ 13 macOS minutes ≈ 134 Linux-eq (6.7 %).
- LUPY_STATUS finalised with the six gates; draft PR opened for founder review (not merged).

## 2026-10-15/16 — Founder's “Mac build delivery request” (the downloaded ZIP was source code)

### 22:00 — Diagnosis
- The founder had used the repository's green **Code → Download ZIP**, which is the source code. The real build (artifact of run 38794651725) was a GitHub artifact zip *containing* `Lupy-0.1.0-50c31bca33-macOS-arm64.zip` (zip inside a zip), reachable only through Actions menus. It did contain a valid Lupy.app, but it was not a one-link, one-file download.
- Cannot download artifacts into the sandbox (artifact storage host is blocked), so the downloaded file has to be verified on GitHub's own Macs and reported back through check runs.

### 22:17 — Packaging fix + download verification; build #4 (run 38816041405, commit 5eff8b4)
- Workflow: single unwrapped file (`upload-artifact@v7`, `archive: false`, 90-day retention) → the link downloads `Lupy-<ver>-<sha10>-macOS-arm64.zip` directly; Coucou MIT notice copied into the app; new `verify` job (fresh `macos-14` + `macos-latest`) downloads that exact file and runs `scripts/verify-mac-download.sh` (34 checks + self-test + Gatekeeper preview). D-018.
- Result: build OK; on both Macs every check passed **except one: Lupy did not quit within 8 s on first launch** (forced). Demo-data launch quit cleanly.
- Root cause: the first-run welcome card was a SwiftUI `.sheet`; AppKit refuses `terminate:` while a sheet is attached (Cmd-Q, menu-bar Quit, and the quit request sent at log out / restart / shut down). Demo data marks onboarding complete, hence no sheet and a clean quit. Confirmed as known AppKit behaviour.
- Screenshot review also showed the download check's Gatekeeper line was wrong (“opened without a prompt”) — the prompt was on screen on both Macs; the blocked process exists while the prompt is up.
- 9 billed macOS minutes; cumulative ≈ 227 Linux-eq (11.4 %).

### 22:30 — Fix; build #5 (run 38817528779, commit 09c8c75): DELIVERED
- Welcome card is now an in-window overlay (name field focused, Return = Get started). D-019. Gatekeeper preview judged by on-screen windows; XProtect definitions version recorded.
- Build OK (same single compiler warning as before). Artifact **12011451588** `Lupy-0.1.0-09c8c7571c-macOS-arm64.zip`, 2,066,069 bytes, SHA-256 `161f022e39deccc5467c6d7861c9b43b22ad01b1d6c80bfe1a4da2476968d747`, until 2027-01-13; served as `application/zip` under that name.
- Downloaded-file verification: **34/34 checks + self-test 12/12 on macOS 14.8.9 and on macOS 26.6.2**; first launch quits cleanly; relaunch keeps data; security prompt seen on both (screenshots reviewed).
- 7 billed macOS minutes; cumulative ≈ 300 Linux-eq (15.0 %).
- Docs: INSTALL_GUIDE §1–2 + troubleshooting (direct link; “not Code → Download ZIP”; exact macOS 14 / 15+ prompts), LUPY_STATUS, TEST_REPORT (Download verification), KNOWN_LIMITATIONS (L-18 updated, L-20, L-21), DECISIONS (D-018, D-019), CI_BUDGET.

## 2026-10-16 00:00–02:00 — Founder's Coucou-fidelity + AI-cursor directives: Lupy becomes Coucou's app

### Directives and decisions
- Founder: Lupy must be Coucou extended (real icon, Mochi with its animations, original interface), adapted for the Mac, with a visible AI cursor for real computer control; go beyond the list; test; hand off honestly.
- Asset question answered: use the originals, strictly private, his own Mac only → D-021 (artwork in `Mac/CoucouAssets/`, NOTICE travels with the app). D-020 (fork, supersedes D-002/D-016), D-022 (macOS 14.0), D-023 (no local LLM), D-024 (Accessibility + policy-gated cursor), D-025 (delivery), D-026 (window opens on Lupy Today), D-027 (REQUIREMENTS_STATUS replaces FUNCTIONAL_MATRIX).

### Work
- `Mac/` = pristine Coucou f09ac0b (6c0f3cf) + commented hooks only: project.yml (Lupy product, app.lupy.Lupy, macOS 14, no local LLM), own support folder/socket/Keychain service/logs, "Coucou"→"Lupy" strings (10 languages; `scripts/rebrand-strings.py`, Xcode-exact JSON), OK Lupy wake phrase, entry point `LupyMain` (self-test / control self-test / app), AppDelegate hooks (Lupy Today + Stop computer control in the menu bar), Lupy pages in Coucou's window + sidebar group, Lupy pill + approvals + notes on the island, `--open-window/--show-island` launch flags.
- `Mac/Sources/Lupy/`: LupyModel (engine bridge, Coucou-window navigation), LupyPlatform (disk/Keychain/HTTP/notifiers), pages ported from the previous window with `scripts/port-lupy-views.py` and restyled with Coucou's components (LupyStyle), LupyHub (pages + welcome card), LupyIslandBridge, LupySelfTest.
- Computer control: `LupyCore/ComputerControl.swift` (rules: matcher, safety classification, run state machine, strict model-step parsing, delivery observation) + 13 tests (96/96, 606 checks); `uiInput`/`uiNavigate` action kinds; `controlStep` model job (consent/budget/ledger); `recordControlDelivery` (seen → sent, unseen → delivery unconfirmed). App side: LupyAX (Accessibility executor; never moves the founder's pointer), LupyCursorOverlay (click-through cursor windows + banner), LupyControlCenter (locate → classify → gate → execute → read back → record; Esc/Stop/pause-on-typing), LupyDelivery ("Deliver with Lupy"), LupyControlPage, control self-test (`--control-self-test`) with screenshot phases.
- Old `App/` retired (09c8c75 keeps it and the Build 5 artifact as the recovery reference). `scripts/build-mac-app.sh` builds Mac/, bundles Coucou MIT + artwork notice; smoke gains the Mochi-animation check; download verification checks the sounds/notices and renders the icon; CI runs Coucou's unit tests for touched areas + the OK-Lupy test, and the control self-test with screenshots; `scripts/coucou-fidelity.sh` generates `docs/COUCOU_FIDELITY.md` (169/187 files byte-identical, 18 hooked).

### Builds (macos-latest; 01:31Z start, before the day's macos-14 brownout)
- F1 38835587936: core 96/96, Coucou tests 13/13, compile failed on 3 errors (macOS 14.2 API in NoteAudio; missed rename) → fixed (4481ab0). 4 macOS min.
- F2 38836083750: **BUILD SUCCEEDED** — 45 MB app, zip 19,367,695 B, SHA-256 490f7d681a363d7cbe1435b8b53e01fb68595c0c89f21929c85d4a0a118bbfc3, artifact 12019398355. Download verification **ALL CHECKS PASSED** on macOS 14.8.9 and 26.6.2, incl. "Mochi is animated, not static" and quits cleanly on first launch. Run failed only in my control-self-test runner (`open -W` does not wait for a background app; TCC requirement parse) → fixed (afc0855). 13 macOS min.

### 02:04–02:20 — F4 green; CPU fix; F5
- F4 (run 38838652274, commit 84a51f6): **whole run green**. Download verification ALL CHECKS PASSED on macOS 14.8.9 and 26.6.2 (Mochi animated, quits cleanly, 29 sounds, notices, icon rendered). **Computer-control self-test 9/9 PASSED on both**: overlay click-through/above apps; typing into TextEdit with read-back; action ledger verified; Stop cancels the queued step; missing target fails honestly; declined Send not sent; approved Send clicked and observed on screen; password field refused. Artifact 12020059183. 13 macOS min.
- F4 also measured **29–53 % CPU with the window open, including in background** (the window's Mochi/particle canvases animate whenever visible; Coucou's Flow window is occasional, Lupy's stays open). Fix (c8bad17): the same `TimelineView(.animation(paused:))` Coucou keys on window visibility is now also keyed on the app being frontmost — animations resume the instant Lupy is. Frontmost unchanged (the real Coucou experience while watched).
- F5 requested (run 38839867821) as the delivery candidate.

### 02:19–02:35 — F5: DELIVERED
- F5 (run 38839867821, commit c8bad17): **whole run green — the delivery candidate**. Download verification ALL CHECKS PASSED on macOS 14.8.9 and 26.6.2 (Mochi animated, quits cleanly, 29 sounds, notices, icon); **computer-control self-test 9/9 PASSED on both**; background CPU down to 17 % / 32 % on the VMs (window canvases pause in background; the rest is Coucou's island, alive by design, hideable). Artifact **12021610015** `Lupy-0.2.0-c8bad17274-macOS-arm64.zip`, 19,370,871 B, SHA-256 `be51da82a3c1bb6abf505a80a6746baa84714f62686a71f6c6c1728a82f67fd5`, until 2027-01-14. 13 macOS min; campaign ≈ 888 Linux-eq (44.4 %).
- Docs finalised for handoff: INSTALL_GUIDE (Coucou-based app, computer control, new link), LUPY_STATUS, REQUIREMENTS_STATUS (one completion record), TEST_REPORT, KNOWN_LIMITATIONS (L-22..L-24), CI_BUDGET, MAC_ACCEPTANCE_CHECKLIST (Coucou fidelity + computer control rows), COUCOU_FIDELITY (regenerated), DECISIONS (D-020..D-027).

## 2026-10-16 — Island interaction directive (F6 campaign)
Directive: the island becomes Lupy's quick-access control centre (real interaction loop:
idle → activate → speak/type → correct before sending → understand/respond → execute →
ask → finish); Coucou's animation engine reflects Lupy's real states; island and workspace
share one conversation/state; settings organised around user needs; end-to-end journey tests.
Plan: LupyCore intent router + conversation turns (tested) → LupyChat shared conversation
(app) → island `.lupyChat` view on Coucou's chrome → Today page leads with the same
conversation → settings reorg → `--chat-self-test` + CI → docs → build F6.

## 2026-10-20 — the icon forge + double-click installer (session arena/95108471)

- **Context:** the founder asked this session to "pick up local commit e1af690 (full
  product + tools/ui/make_appicon.py icon forge)". That commit exists nowhere reachable:
  not in this clone, not on GitHub (API: no such SHA), and the Drive safety-net bundle
  (`lupy3-local-commits.bundle`, 16 Oct) predates it. It lived in a previous session's
  sandbox and was never pushed. So the forge + installer were **reconstructed from the
  repo's own law** (same sources the original would have used) rather than picked up.
  Baseline first: body-checks BODY GREEN + beta gate SATISFIED on the pristine tree
  (main 86c35ff) before any change.
- **The forge** (`tools/ui/make_appicon.py`): parses the shipped kernel geometry
  (`Mac/Sources/Lupy/Character/LupyGeometry.swift`) — outline, eye metrics,
  `showsBlush` (false → no blush), pure-white body — and renders the locked
  character at 4x with the kernel's idle glow (white, blur 0.09u, strength 0.24,
  scene.py's math) on the macOS 824-point dark squircle. Outputs:
  `Mac/CoucouAssets/Assets.xcassets/AppIcon.appiconset` (Xcode road; Contents.json
  byte-identical, only pixels new), `Mac/LupyAppIcon/AppIcon.icns` (+1024 preview,
  hand-written PNG-entry icns, ic04–ic14), and the installer's own copy.
  `--check` mode is now body-checks step 6a: the shipped icon must equal the locked
  character byte for byte. **The app icon is no longer Coucou's Mochi** — first step
  of the distribution swap (NOTICE.md updated; menu-bar icon + sounds still to swap
  or permission still to ask).
- **Wiring:** `Mac/Resources/Info.plist` gains `CFBundleIconFile=AppIcon`;
  `scripts/build-no-xcode.sh` copies `Mac/LupyAppIcon/AppIcon.icns` into the bundle
  before signing, strips quarantine and `lsregister -f`s + touches the installed app
  (icon cache), and feeds progress to `LUPY_INSTALL_STATUS_FILE` when set.
- **`Install LUPY.app`** (new, repo root): script-executable bundle
  (`Contents/MacOS/Install-LUPY`, LUPY icon, bundle id app.lupy.installer). Native
  osascript dialogues only — welcome, plain-language preflight (kit intact, Apple
  Silicon, macOS 15+, /Applications writable, Command Line Tools with Apple's own
  GUI + patient wait), native progress window fed by the build's status file with a
  working stop button, then `build-no-xcode.sh --install` → /Applications + launch.
  Every failure ends in a dialogue with a log (`/tmp/lupy-install.log`) and a way
  out. `Install LUPY.command` unchanged, kept as the Terminal backup.
- `scripts/make-icon.py` removed: its wolf-pup icon predates the locked LUPY 3
  character (a branding landmine under the "no character error" law) and its output
  path (`App/Resources/`) no longer exists; the forge supersedes it.
- Docs: `README-INSTALL.txt` + `docs/RELEASE_NOTES.md` rewritten for the app-first
  install; `Mac/LupyAppIcon/README.md` added. Verification: shell syntax, plist
  parsing, icns container walk (11 entries, PNG dims per type), appiconset dims vs
  Contents.json, forge `--check`, installer safe-degrade smoke on Linux (no
  osascript → clean exit, nothing touched). macOS GUI behaviour itself awaits the
  founder's Mac — the kit download remains the acceptance test.

## 2026-10-20 — installer learned to find its own kit (arena/847f264e)

- **Field report (the first real Mac):** the founder downloaded the lupy3-final kit,
  unzipped, ran Install LUPY.app, and got "I can't find the rest of the Lupy kit
  around me." Root cause: **App Translocation** — macOS runs a freshly downloaded,
  quarantined, never-moved app from a hidden randomized copy containing ONLY the
  bundle, so the installer's "$0 → ../.." kit resolution saw a folder without
  scripts/Mac/LupyCore. (Buried good news: bundle, icon and osascript dialogues
  all worked on hardware.)
- **Fix (installer 3.1/4):** a resolution ladder — (1) beside the app, stricter
  triple-check (`scripts/build-no-xcode.sh` + `Install LUPY.app` +
  `Mac/Package.swift`, absolute paths only); (2) search Downloads/Desktop/Documents,
  newest kit wins (pre-2026-10-20 kits lack Install LUPY.app and never match);
  (3) native folder picker ("choose folder"), forgiving a pick of the kit's
  parent. Once resolved and consented, the kit's quarantine is cleared so macOS
  never translocates it again. Resolution paths are logged.
- **Proof, Linux-simulated:** the shipped script run with only osascript stubbed
  through 6 scenarios — normal sibling, translocated + Downloads search (the
  founder's case), two kits → newest, picker exact, picker parent, cancel — all
  correct. (The harness caught a real bug pre-ship: an empty `find` fed the loop
  one empty line, `dirname ""` → `.`, which "matched" whenever cwd was the repo;
  fixed by empty-line skip + absolute-path law in looks_like_kit.) macOS-native
  confirmation still rests with the founder's next kit run.

## 2026-10-20 — the installer gets a face that cannot disappear (arena/4798e149)

- **Field report #2:** kit found (translocation fix worked), founder clicked
  Install, and the installer "disappeared" — the AppleScript progress panel
  never visibly appeared on his Mac, so minutes of real work looked like
  nothing. His words govern this fix: show a loading screen with stages and
  an estimated time, like other apps, so he can tell working from broken.
- **The face** (`Install LUPY.app/Contents/Resources/LupyProgress.swift`, new):
  a tiny native AppKit window compiled on the founder's Mac at install time by
  the same Command Line Tools that then build LUPY (no download, no
  quarantine). It shows his face, the stage, a progress bar fed by the
  compiler's own step count (`refine_status` maps SwiftPM's [n/m] lines onto
  the compile stretch), elapsed + estimated time ticking every second, the
  live build-text tail, a Cancel button, and a heartbeat that turns the
  window itself into the witness ("no news for Ns — screenshot me"). The
  AppleScript progress UI is deleted entirely. If the face cannot compile or
  dies mid-flight, self-refreshing modal dialogues carry stage + elapsed —
  including during the Apple-tools wait (which precedes any compiler). Every
  long stretch now has a visible window; there is no silent path left.
- **A loss found while fixing this (process lesson, recorded):** two of the
  three session-1 edits to `scripts/build-no-xcode.sh` never reached the
  shipped tree — parallel same-file edits raced, one writer survived, and a
  skimmed truncated diff hid it. The shipped 3.0/3.1 kits therefore never
  copied AppIcon.icns into the hand-built bundle (a founder-side install
  would wear the generic icon) and lacked the quarantine-strip/lsregister
  step; same pattern cost one kit-finder guard in 3.1 (latent). All restored
  by single-writer rewrites, grep-verified in the tree, and body-checks
  gained **step 6b** (install-wiring greps) so this class of loss fails the
  gate instead of shipping silently. Audited the rest of PR #3/#4: forge,
  plists, NOTICE, docs all intact.
- **Proofs here:** Swift face parses under the real frontend (swiftwasm);
  kit-ladder scenarios re-run green on the new script (osascript stubbed);
  refine_status unit-tested verbatim (fetch→12, 412/980→43%, 980/980→68%,
  post-70 no-stomp, garbage-safe). The face's runtime on macOS remains the
  founder's acceptance — with the modal net underneath it either way.

## 2026-10-20 — Kit 3.3: the proper Setup (founder field report #3 + his spec)

Field report #3: kit 3.2's run froze 33 min behind a macOS keychain window
(git's osxkeychain helper, consulted during SwiftPM's public-repo fetch),
then died when SwiftPM's binary-artifact authorization lookup hit the
keychain and returned status -128 (errSecUserCanceled) on the 87 MB
NemoTextProcessing.xcframework. The face's heartbeat kept saying "alive"
throughout — technically true (the shell lived), uselessly false (nothing
moved). The founder's review, verbatim-ish: wants "the standard way … not
always stays on top but anytime can see … step by step … so we know if did
work, show what error so I can show or tell you", and a setup that is
complete and stress-tested, not partial. 3.3 is that, end to end:

- Credential-blind builds (scripts/build-no-xcode.sh): git's credential
  helpers blanked process-scoped via GIT_CONFIG_* env (an empty helper
  RESETS the list — osxkeychain is never consulted; his config untouched),
  GIT_TERMINAL_PROMPT=0, and SwiftPM's own --disable-keychain, probed from
  `swift build --help` at runtime so older toolchains build exactly as
  before. Everything fetched is public; no password can ever be asked.
  (--help probing because the sandbox swiftwasm is swiftc-only.)
- The face v3 (LupyProgress.swift): a STANDARD window — normal level,
  minimize button, close tucks it away (Cancel is the explicit stop; Cmd-Q
  cancels), Dock-click reopens, Dock tile shows the bar + "%" badge and
  bounces with a check at the end. Six named steps (waiting/doing/done/
  failed, each with its own time), overall bar with honest ETA, live build
  tail, heartbeat confession, orange stall detail, and a final proof
  screen that stays until HE closes it: all-green summary + Show in
  Finder, or the exact failed step + Save report.
- Install-LUPY v3.3: a real step machine (v3 status line; steps never
  travel backwards; monotonic percent). Step 3 vs 4 split from the build's
  own bracket lines (Fetching/Downloading = step 3, byte totals spoken as
  MB; compile lines = step 4, 25->68% from [n/m]); step 5 from build
  milestones >=70. Freeze watchdog: build.log not growing for 150 s past a
  150 s grace -> STUCK warning (a hidden window can never again eat
  33 minutes silently). Step 6 verifies its own work — app in Applications,
  executable inside, icon on, and the process actually alive (24 s watch)
  — before anyone says "done". Every ending writes a plain-words report
  (/tmp/lupy-install-report.txt; failures also to the Desktop; the window
  can Save it anywhere). Modal-dialogue fallback kept throughout: no
  silent stretch exists at any point.
- Rehearsal before shipping, as specified: tools/ui/installer-harness.sh
  extracts the step machine verbatim and drives 34 checks — happy path,
  the founder's real freeze replayed from his pasted log (STUCK at 300 s,
  clears on growth), hostile inputs (garbage milestones, [0/0], deleted
  files; found and fixed a step state-regression: finished steps now
  never reopen). Wired into body-checks as step 6c; 6b grows greps for
  --disable-keychain, the window's standard manners, verify/report, and
  the six step names byte-identical across shell and Swift.
- NOT re-implemented from his paste of an unrelated "City Controlled
  Practice-Testing Pack" spec ("MISTKE-- GOO"): read as mistaken paste +
  GO, confirmed to him; nothing in it touches LUPY.

## 2026-10-20 — Kit 3.3 field run 1: the Setup caught its first real compile error

Founder screenshot, 16:02: the standard Setup window (traffic lights,
"LupyProgress" in the menu bar) showing steps 1–3 green (download done in
1:05 — the credential-blind fix field-proven, no keychain window ever
appeared), step 4 "Compile LUPY" failed after 3:25, orange line naming the
step, the compiler's own words in the log tail, Save-report + Close, badge
on the Dock icon. The Setup did every job it was built for; what died was a
bug in LUPY himself, found by the first true compile of the AppKit target
in this product's life (the sandbox frontend can only PARSE AppKit sources —
no macOS SDK — so this class of error was structurally invisible here).

Cause, from his diagnostic text: "'orderOut' in a synchronous nonisolated
context … main actor isolation inferred from inheritance from class
NSResponder." NSWindow & family are @MainActor in the SDK; exactly one
Lupy-era controller lacked the annotation its every sibling wears.
Forensic census over all Mac/Sources (101 window/view sites) found the den
has precisely one address: LupyIslandShellController (NSPanel creation,
orderFrontRegardless, setFrame, orderOut…) plus its two LupyIslandPlacement
screen-readers (NSScreen/NSStatusBar). Neighbors audited clean by hand:
AppDelegate, FlowPillController, IslandWindowController,
DesktopMochiController, FlowHubController, ScreenCapture, RecapSharePanel,
VoiceCaptionManager, LupyCursorOverlay, LupyIslandDirector (the shell's
only owner — already @MainActor, so the fix costs nothing), FlowPaste,
CapturePaste, LiveMusicControl, the NSPasteboard helpers.

Fix: `@MainActor` on LupyIslandShellController + the two Placement funcs,
with the fossil in the doc comment. Guard: tools/ui/audit_isolation.py
(the same census, productized) wired into body-checks as step 6d — any
future nonisolated window/view site fails the gate here instead of on the
founder's Mac. His screen slept mid-install; display sleep does not pause
or fail compiles — different cause entirely (ours, in the code). Shipped as
a PR, deliberately NOT merged until the founder approves and (asked) shares
the Desktop install report, so the compiler's full list can be cross-checked
against the census before this lands on the tag.

## 2026-10-20 — The founder's report: census confirmed, + a second catch

The founder sent the Desktop "Lupy install report.txt" from his 15:23 run
(an earlier attempt than his 16:02 screenshot; its step 3 took 4:30 because
the 87 MB xcframework was really downloading that time — cached for the
16:02 run, which stepped through in 1:05). Every compiler error in the
tail sits in LupyIslandShell.swift (rootView/setFrame/frame/orderOut),
and swiftc's own note prescribes the fix: "add '@MainActor'". The
isolation census and the one compiler we cannot run agree exactly.

Bonus catch, invisible everywhere but this report: its header reads
"macOS 15.7.4 · x86_64" — on Apple Silicon. LaunchServices runs a
script-based .app under Rosetta, so the whole install (and would-be build)
inherited a pretend-Intel world: SwiftPM builds for the arch it believes
it's on, so the fixed rebuild could have produced an Intel Lupy or failed
to link an arm64-only artifact. build-no-xcode.sh now runs the toolchain
as `arch -arm64 swift` and stamps `file` of the built binary into
build.log (hence into every future report: "must say arm64"); body-checks
6b greps for it. The installer's own preflight already tolerated
translation (sysctl.proc_translated) — now the build no longer believes it.
Both fixes ride in PR #7, still unmerged pending the founder's approval.

## 2026-10-21 — Field run 3 (kit 3.3 + PR #7): past the isolation wall, into the never-compiled layer

Founder's run cleared steps 1–3 (0:26–3:02) and died again at step 4 (2:37)
— new errors, all in LupyIslandDirector.swift, a Lupy-era file written
against imagined APIs and never compiled anywhere: AskQuestion.items (the
member is `questions`) x2 + a self-capture, first(where:) reading
t.finalLine before t exists, and a CombineLatest5 sink whose five bare
'_' parameters the solver cannot infer. The census also found — before the
compiler even had to — LupyIslandChatView DECLARED TWICE (the real
interactive chat vs the director's read-only renderer, renamed
LupyIslandTranscriptView). His verdict, just: "u need test unltra big
testing of instalation before giving me ... 3rd time and wasting time".

What changed structurally this round:
- Director repaired; its whole ~40-symbol external surface verified
  against real declarations (AppState/ApprovalInfo/AgentTask/BotState/
  IslandView/ChatMessage/hooks/all Lupy view+payload types).
- THREE new gate councils approximating a symbol resolver over the
  never-compiled frontier: 6e declarations (645 types unique), 6f
  cross-reference (899 static refs resolve), 6d isolation (101 sites);
  plus a one-off instance-call audit (LupyModel->engine 23 names,
  pages/chat->model 68 names: all resolve; 35/35 LupyCore types exist).
- The install report now carries the COMPLETE grep of `error:` lines —
  never another 60-line tail hiding earlier files. Its chip line reads
  the true CPU brand instead of the installer's translated `uname -m`.
- A real compile oracle exists on paper: .github/workflows/compile-check.yml
  builds build-no-xcode.sh on a clean macOS runner. It cannot run today:
  dispatch needs the file on main AND this account's Actions are blocked
  by billing ("The job was not started because recent account payments
  have failed", runs 39251799153/39252101964: 5-7s failures). Only the
  founder can flip that (GitHub Settings -> Billing); the day he does,
  kits get proven on a cloud Mac before they reach his.
Honest residue: SwiftUI builder/generic/instance errors in view bodies are
compiler-only catches. The frontier is audited as far as static analysis
reaches; if anything remains, the new report enumerates it in ONE run.

## 2026-10-21 — Field run 4: complete list in hand; the build personality was the bug

The improved report paid off exactly as designed: ONE file carried all 39
errors. ~30 were one disease — Swift 6 strict-concurrency hard errors in
the inherited, already-shipped code (AppDelegate, IslandWindowController,
SettingsView: NotificationCenter closures touching @MainActor state they
only ever reach on the main queue). Root cause was ours: a Lupy-era session
had set the SwiftPM manifest to tools 6.0 + `-strict-concurrency=complete`
claiming to "mirror" project.yml, but the Xcode road (SWIFT_VERSION 6.0,
no strict-concurrency setting) compiles this code in Swift 5 language mode
with default checking — the personality it shipped under. The header
comment now records the false mirror. Fix: `.swiftLanguageMode(.v5)`, the
strict flag deleted — NO code surgery in Louis Raillé 2000-line state machine
(the founder needs output, not a blind refactor of proven logic).
Mode-independent errors fixed individually: CombineLatest5 doesn't exist
(Combine stops at 4; the fifth signal now nests), three `#Preview` blocks
wrapped in #if DEBUG (CLT-only toolchains lack the PreviewsMacros plugin),
and BotCanvasView's solver-timing-out body had its 99-line Canvas closure
moved verbatim into drawFrame(). The founder cannot pay for GitHub Actions
("i dont have or cant pay") — the compile-oracle stays parked in the repo;
this sandbox-side stack (censuses + audits + full-error reports) is the
testing road, and each field run now converges by a whole layer at a time.

## 2026-10-21 — Repo public; the cloud-Mac campaign (sellable-quality bar)

Run 4's report: **39 errors -> 1** — Swift 5 mode downgraded every strict
error to a warning exactly as intended; the last error was BotCanvasView's
body still timing out the solver through its 14-modifier chain. The founder
(no GitHub money, ever) demanded a free online Mac instead of his machine,
accepted Road A with conditions — public for visibility, NOT MIT, personal
use only, branding his, and check everything for private data first.

Privacy audit before the flip (tree + deepened 156-commit history): zero
secrets and zero founder identifiers; only FAKE-labelled redaction test
fixtures, Louis Raillé public email, localized "sk-ant-…" placeholder labels.
Founder flipped the repo public himself (Danger Zone), verified from
outside without a login. LICENSE added on his terms: all rights reserved,
no usage rights granted, third parties keep their notices.

BotCanvasView split #2: body -> canvasWithObservers + remaining chain, fat
handlers named (handleViewChange/handleModeChange/appear), verbatim code.

The oracle's road so far: runs 1-2 died un-acquired (GitHub arm64 free-pool
capacity starvation, 15-min give-ups); a 3-label matrix [macos-latest,
macos-15, macos-14] fixed that — macos-14 acquired and the installer
rehearsal + all three councils PASSED on real macOS/bash 3.2, then
test-core died in seconds (default Xcode's Swift 5.10 vs -swift-version 6 /
tools-6.0 manifests) blocking the build step; also learned Actions log
hosts are unreachable from the sandbox. Oracle v3 answers all three: pick
newest Xcode 16 first, BUILD before test-core, and push every step's
evidence to the `ci-evidence` branch (readable via git).
Founder's benchmark, stated plainly: sellable quality, user-tested, no
complaints — the campaign does not hand back a kit until a cloud Mac has
compiled the exact tree green.

## 2026-10-21 (evening) — BUILD GREEN ON A REAL MAC

The oracle drew blood, then went quiet — in the good way.

- First full verdict (run 39632578177, macos-14, Swift 6.0.3/Xcode 16.2):
  exactly ONE error in ~220 files — `escaping closure captures
  non-escaping parameter 'surface'` in LupyIslandDirector's `show()`
  (LupyIslandMorph stores the builder). Fix: one token, `@escaping`.
  BotCanvasView split #2 compiled clean — the five-run saga's last
  error class is dead. (6fdd556)
- Runs 39634037015 and 39637827158: **full founder-road build green
  twice on real Macs** — 0 errors, `Mach-O 64-bit executable arm64`,
  BUNDLE-PROOF-OK (icons/sounds/plist/codesign), installer rehearsal
  34/34 + councils on real bash 3.2, native core tests 108/108
  (668 checks). Evidence on the `ci-evidence` branch.
- Runtime steps on macos-14 abort with dyld exit 134 BEFORE main():
  the binary's LC_BUILD_VERSION says minos 15.0, runner is 14.8.9.
  By design (Package.swift `.macOS(.v15)`); the founder's Mac runs
  15.7.4. Runtime proof needs a macos-15/latest acquisition — those
  pools have refused 4/4 races so far; macos-14 is the label that runs.
- Oracle self-inflicted wounds, fixed in v3.2: Actions runs steps
  under `bash -e` (`;` is no shield — use `set +e` + `|| ec=$?`), and
  macOS has no GNU `timeout` (bash watchdog instead).
- Remaining before "sellable": first-launch visual check on the
  founder's Mac (one screenshot) and, when a macos-15 runner deigns
  to appear, the binary's own self-tests + launch smoke in CI.

## 2026-10-21 (night) — Runtime proven on macOS 15; the oracle earns its keep

The PR #10 run finally won a macos-15 runner (macOS 15.7.9) and the
binary told the truth about itself: `--self-test` PASSED (store,
bootstrap, torn-write recovery, 400 durable writes @2ms, Keychain
round-trip; 18.8MB resident), `--character-self-test` PASSED (all
sizes/moods/glows, 11 island states), `--chat-self-test` PASSED
(20 checks: plan→approve→tasks, honest stop/pause answers, transcript
persistence). Every local gate green too.

Then the launch smoke caught what would have been founder run #6
dying at the finish line: `open Lupy.app` → "cannot be opened because
its executable is missing". The no-Xcode road copied Info.plist
verbatim — Xcode variables and all — so LaunchServices hunted for a
program literally named `$(EXECUTABLE_NAME)`. The binary itself ran
fine when exec'd directly (8s alive until the watchdog). Fix (e1a1dd7):
build-no-xcode.sh stamps CFBundleExecutable=Lupy and
CFBundleDevelopmentRegion=en via PlistBuddy, failing loudly if it
can't; gate 6b and the CI bundle-proof both refuse green without the
stamp. Re-proven on macos-14 (build #5 green, bundle-proof with the
new assertion green). A post-stamp `open` ALIVE on a macos-15 runner
remains at the mercy of GitHub's capacity dice (1 acquisition in 7
races); if it somehow still failed, installer step 6 reports it
honestly — silent death is not an available outcome.

## 2026-10-22 — Installed at last; founder's visual verdict; ONE-NOTCH LAW

Run #6 on the founder's M1: **installation works, Lupy opens.** The
five-run compile war is over. His annotated screenshots then opened
the quality war: TWO pills on screen (the v0.2 Coucou island in the
menu bar + the LUPY 3 director's navy capsule below it — the
never-completed "swap-over"), a "Ready" word showing for no reason,
UI too small, bleeding, clicks buggy/laggy, installer popping 3 times.

Founder's orders, recorded as law:
- ONE notch only, Coucou-style, at Coucou's sizes ("coucou one is
  perfect"); the navy second pill dies. Canvas grows as ONE pill.
- No always-on word labels. The character speaks visually first
  (colour/mood — red = needs me); words only when needed, e.g. after
  no response. Icon only at rest.
- Installer: one standard Apple-style window, no popup chain.
- Screenshot-everything QA: observe/test/fail/fix/re-verify loops,
  micro-level, 100k+ mechanised iterations per council, hours OK.

First moves this session (branch arena/2343e721-lupy):
- The twin retires: AppDelegate starts the director only under the
  opt-in `lupy3DirectorIsland` defaults flag (wiring-council law
  updated to match). One island, and no more .islandCollapse fights.
- Eyes: `Lupy --snapshot-states <dir>` renders every island state
  (compact + 9 expanded views, light/dark), all 11 character moods,
  and the twin for the record, via ImageRenderer at the founder's
  own no-notch geometry. CI (oracle v4) runs it on macos-15 and
  files evidence per-OS on ci-evidence (merge push, no more
  last-writer-wins), plus a best-effort real screencapture.
- Next loops, in order: grade the photos; Coucou-parity geometry
  grind (sizes up, no bleeding); icon-first label law with timed
  word escalation; lag census (full-rate TimelineViews); payload
  stress shots (long text/emoji/queues); resize/boundary + text
  councils; installer one-window. Then PR -> approval -> kit.
