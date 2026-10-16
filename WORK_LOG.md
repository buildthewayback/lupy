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
