# Test report

## Environments

| Environment | What runs there | How |
|---|---|---|
| Arena sandbox (Debian 12 x86_64, Node 22) | All LupyCore tests, lint, syntax check of the app | Swift 6.3.3 compiled to WebAssembly (`tools/swiftwasm`), Swift 6 language mode, strict concurrency |
| GitHub `macos-latest` (macOS 26.6.2, Apple M1 VM, Xcode 26.6, Swift 6.3.3) | Same LupyCore tests natively; full app build; native self-test inside Lupy.app; GUI launch smoke with screenshots | `.github/workflows/mac-build.yml` (manual) |
| Fresh GitHub `macos-14` (macOS 14.8.9) and `macos-latest` (macOS 26.6.2) VMs, Apple M1 virtual, that never saw the build | Download verification of the exact published file: download → contents → unzip → signature → install → launch/quit/relaunch → self-test → Gatekeeper preview | `verify` job in `.github/workflows/mac-build.yml` |
| Founder's MacBook Air M1 | Acceptance checklist | `docs/MAC_ACCEPTANCE_CHECKLIST.md` — **not yet run** |

## Commands

```sh
scripts/lint-core.sh          # availability (macOS 14), stdlib-only purity, credential patterns
scripts/test-core.sh          # all LupyCore tests, incl. the computer-control rules (native swiftc on macOS, WASM elsewhere)
node tools/swiftwasm/syntax-check.mjs Mac/Sources/Lupy/*.swift Mac/Sources/Lupy/Control/*.swift   # SwiftSyntax parse
scripts/build-mac-app.sh      # macOS: build Mac/ (Coucou + Lupy), ad-hoc sign, package, checksum
scripts/smoke-mac-app.sh      # macOS: signature, --self-test, GUI launch, Mochi-animation check, memory/CPU, screenshots
scripts/verify-mac-download.sh <zip> <sha256> <out> <expected-name>   # macOS: check a downloaded build like a person would
scripts/coucou-fidelity.sh <coucou-checkout>   # byte-comparison with upstream Coucou (docs/COUCOU_FIDELITY.md)
Mac/Tests/coucou/test-*.sh    # Coucou's own unit tests (run in CI for the areas Lupy touches)
Mac/Tests/lupy/test-wake-lupy.sh   # "OK Lupy" wake phrase (Coucou's phrases still tested by test-voice-wake)
```

## Results (latest)

| Suite | Cases | Sandbox (WASM) | macOS runner (native) |
|---|---|---|---|
| Primitives (JSON, Codable bridge, ISO-8601 time, SHA-256 vectors, IDs) | 10 | pass | pass |
| Store (append/reload, torn write, disk failure, corruption, snapshots, idempotency, migration, interrupted actions, backup tamper, project isolation) | 14 | pass | pass |
| Safety & policy (redaction, injection, forbidden kinds, pause, untrusted origin, autonomy, standing approvals, never-automate, model consent/budget, file policy) | 12 | pass | pass |
| Work (verification rules, oversight, lifecycle guards, reliability, plan validation, heuristic planner, deadlines, dependencies, priority, scheduler, notification budget, retries) | 15 | pass | pass |
| Providers (4 API styles: requests, parsing, error taxonomy; model refresh; routing; budgets; context isolation; GitHub evidence; claims; briefs) | 11 | pass | pass |
| Engine end-to-end (bootstrap, offline plan flow, *agent says done vs GitHub*, CI re-check, manual relay honesty, approvals, model plan, failures/fallback, JSON repair, budget, pause, injection, memory conflicts, isolation, crash-restart, pause/cancel/reopen, model worker, action ledger, notice bounds, demo, brief) | 21 | pass | pass |
| **Total** | **83 cases / 515 checks** | **83/83** | **83/83** (run 38793640196) |

Native self-test inside the built app (run 38793640196, real disk + Keychain): **12/12 PASS** —
fresh store, bootstrap, plan approval, dependency release, manual relay stays "delivery unconfirmed",
bare "done" claim not verified, torn-write recovery, backup round trip, 400 durable writes
(1.0 s, 2.5 ms/write incl. F_FULLFSYNC), ranking 13 ms, cold reload 37 ms, Keychain round trip.

GUI launch smoke (same run): app running after 12 s with demo data in a temporary folder;
physical footprint 49.5 MB; screenshots retrieved and reviewed (island pill, menu bar icon, Today).

## Coucou fork and computer control (2026-10-16, builds F1–F3)

Lupy is now Coucou's macOS app extended (D-020). What is tested, and how:

| What | How | Result |
|---|---|---|
| Coucou's behaviour in the areas Lupy touches | Coucou's own unit tests in Lupy's CI: screen geometry, island hover, auto-close, display choice, desktop Mochi, wardrobe, pill colours, approval queue, safe links, Claude hooks, Claude settings, voice wake | 13/13 PASS (runs 38835587936, 38836083750) |
| "OK Lupy" wake phrase (Coucou's kept) | `Mac/Tests/lupy/test-wake-lupy.sh` | PASS |
| LupyCore incl. computer-control rules | 96 cases / 606 checks (sandbox WASM + native) | 96/96 |
| The app builds from macOS 14.0 | Xcode 26.6, arm64; the two 14.2+ APIs guarded | BUILD SUCCEEDED (F2) |
| Mochi is animated, not a static image | CI compares two screen captures 0.8 s apart (below the menu bar) | differ on macOS 14 and 26 — PASS |
| The Lupy cursor never takes clicks, sits above apps | computer-control self-test checks its windows | PASS on both Macs |
| Typing with read-back; Stop cancels queued steps; missing targets fail honestly; declined Send not sent; approved Send sent and observed; password field refused | `--control-self-test` on the CI Macs (Accessibility granted there only) | **9/9 PASSED on macOS 14.8.9 and 26.6.2** (run 38838652274) |
| Fidelity to upstream Coucou | byte-comparison, `docs/COUCOU_FIDELITY.md` | 169/187 files byte-identical; 18 changed at commented `Lupy:` hooks |
| Screenshots | first launch, at rest, island, app icon, security prompt, cursor moments — published as check runs per build | captured on both CI Macs |

Note on screenshot review: builds #4/#5 (previous shell) were reviewed image by image. For the
F-series the automated evidence above (animation hash, window-owner probe, byte comparison,
unit tests) carries the verification; the screenshots are published for the founder's review.

## Download verification (run 38817528779 — the file behind the founder's link)

Artifact **12011451588** = `Lupy-0.1.0-09c8c7571c-macOS-arm64.zip`, 2,066,069 bytes, SHA-256
`161f022e39deccc5467c6d7861c9b43b22ad01b1d6c80bfe1a4da2476968d747`, built from commit `09c8c75`.
Uploaded as a single unwrapped file; GitHub's download endpoint serves it as `application/zip`
under that exact file name. Each verification Mac fetched it through GitHub's artifact API (digest
checked on download), then ran `scripts/verify-mac-download.sh`:

| Check group | macOS 14.8.9 (`macos-14`) | macOS 26.6.2 (`macos-latest`) |
|---|---|---|
| File: browser file name, `.zip`, SHA-256 equals the build's, `unzip -t` | 4/4 | 4/4 |
| Contents: Lupy.app is the only item; program + Info.plist present; no nested zip / source / stray metadata; licence notices included; no reserved Coucou/Mochi assets | 6/6 | 6/6 |
| App: unzips like Finder; Info.plist (name, id, APPL, macOS 14.0, mic/speech texts); executable; arm64; built for 14.0; libraries all from macOS; icon; signature seal; `codesign --verify --deep --strict`; ad-hoc | 16/16 | 16/16 |
| Install & run: into /Applications; signature intact; first launch (normal data folder) running; running copy is the installed one; data folder created; **quits cleanly**; relaunch with saved data; self-test + demo launch | 8/8 | 8/8 |
| **Total** | **34/34** | **34/34** |
| Native self-test inside the installed app | 12/12 | 12/12 |
| Physical footprint, first launch / demo data | 31.9 MB / 34.5 MB | 44.2 MB / 44.3 MB |
| CPU, demo data, frontmost / background (3 s samples) | 4.0 % / 2.1 % | 7.2 % / 3.1 % |

Gatekeeper preview (informational; quarantined copy unzipped by Archive Utility): `spctl` →
*rejected*; `syspolicy_check` → notary ticket missing (both) and “Internal Xprotect Error” (macOS 14
only, XProtect definitions 5278; macOS 26 has 5287 and no such entry). Double-clicking showed
macOS's security prompt on both: macOS 14 — “*“Lupy” cannot be opened because it is from an
unidentified developer*” [OK]; macOS 26 — “*“Lupy” Not Opened*” [Move to Trash] [Done] (screenshots
reviewed). macOS 14 did not show the malware warning (“will damage your computer”). The on-screen
window probe worked on macOS 26 and returned nothing on macOS 14; the screenshot is the evidence
there. Clicking through “Open Anyway” was not automated.

Evidence: check runs “Lupy download check · macOS …” and “Lupy screenshot · … · first launch | demo
data | island | security prompt” on commit `09c8c7571cecaff65047e9c5ad71387dee277e1b`.

## What is mocked

- **Cloud model providers**: request bodies and response parsing are tested against realistic
  recorded/fabricated JSON for OpenAI, Anthropic, Gemini and OpenAI-compatible APIs — **no live
  API call has been made** (no keys exist in this campaign, by design).
- **GitHub**: branch/PR/commit/check-run responses are fixtures; live verification needs the
  founder's token.
- **Time**: tests use a manual clock; the app uses the system clock.
- **Disk**: core tests use an in-memory file system with fault injection; the native self-test uses
  the real disk adapter (`F_FULLFSYNC`, atomic rename).

## Failures found and fixed during testing (selection)

| Found by | Problem | Fix |
|---|---|---|
| Sandbox toolchain | Node's WASI segfaulted randomly; shim writes were quadratic (builds >10 min) | Pure-JS WASI shim + amortized buffer growth |
| Core test | Redactor removed the word after "Token" in ordinary prose | Labels count only with `:`/`=` |
| Core test | PR-exists vs CI-failed at the same instant judged "ambiguous" | Judge latest evidence **per kind** |
| Core test | Founder could not explicitly accept submitted work | Lifecycle allows founder override from submitted/verifying |
| Core test | Demo steps lost their "[Demo]" label | Demo goals written one labelled step per line |
| Native run | 15 % CPU from always-running animations | Animations pause when Lupy is not frontmost; static sidebar; lower rates |
| Native screenshot | Plan title showed the whole multi-line goal | First line + "(+N more)" |
| Founder report | The repository's **Code → Download ZIP** is source code; the old build artifact was a zip inside a zip | Single-file artifact (`archive: false`) behind a direct link; every build now verifies the downloaded file on fresh macOS 14 and 26 machines |
| Download check (build #4) | First-run welcome card (a SwiftUI sheet) blocked quitting — AppKit refuses to terminate while a sheet is attached (Cmd-Q, menu-bar Quit, log out / restart / shut down) | Welcome card drawn as an in-window overlay; build #5: quits cleanly on macOS 14 and 26 |
| Screenshot review (build #4) | Download check said “opened without a security prompt” while its screenshots showed the prompt (the blocked process exists while the prompt is up) | Judge by on-screen windows; screenshots stay the ground truth |

## 2026-10-16 — F6–F8 campaign: the island conversation (directive: island = quick-access control centre)

Build loop: F6 failed on 9 compile errors (design-only symbols + Substring conversions); F7
compiled but 2 self-test assertions expected less honesty than the app delivers (see F7 entry in
CI_BUDGET.md); F8 green everywhere. CPU with the conversation open is unchanged from F5 within
sampling noise (macOS 14: 27.9 % front / 18.8 % back vs 29.5 / 17.4; macOS 26: 57.7 / 29.4 vs
59.6 / 32.4 — the 26 numbers are the virtualized runner, as in every build).

| Suite | Where | Result |
|---|---|---|
| **Conversation** (new) — intent routing (goals, questions, status, commands, control, plan decisions), local status answers, `prepareConversationTurn` (history included, policy gate, usage recorded once), history cap | LupyCore, sandbox WASM + native runner | **106/106 cases, 658 checks** (was 96/606; +10 cases, +52 checks) |
| Island conversation surface (`.lupyChat`) + shared `LupyChat` + window panel + hooks | App target — compiled on the macOS runner | **Build F8 (run 38916058766): compiles, installs, launches** |
| **Chat self-test** (`Lupy --chat-self-test`): typed instruction → goal → plan card; "approve it" → tasks; status answered from real state; honest no-model answer; honest control blocker; pause/resume; "stop" (plan rejected / honest idle); follow-up history through the engine (no network); transcript persisted and decoded | App binary on the installed download, fresh data dir | **Build F8: 19/19 checks on macOS 14.8.9 and 26.6.2** |
| Island-chat screenshot (conversation surface with welcome + chips) | `smoke-mac-app.sh` second demo launch (`--show-island-chat`) | **Build F8: captured on both Macs** (check run “island conversation”; decoded copies in `.cache/f8/`) |
