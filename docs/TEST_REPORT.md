# Test report

## Environments

| Environment | What runs there | How |
|---|---|---|
| Arena sandbox (Debian 12 x86_64, Node 22) | All LupyCore tests, lint, syntax check of the app | Swift 6.3.3 compiled to WebAssembly (`tools/swiftwasm`), Swift 6 language mode, strict concurrency |
| GitHub `macos-latest` (macOS 26.6.2, Apple M1 VM, Xcode 26.6, Swift 6.3.3) | Same LupyCore tests natively; full app build; native self-test inside Lupy.app; GUI launch smoke with screenshots | `.github/workflows/mac-build.yml` (manual) |
| Founder's MacBook Air M1 | Acceptance checklist | `docs/MAC_ACCEPTANCE_CHECKLIST.md` — **not yet run** |

## Commands

```sh
scripts/lint-core.sh          # availability (macOS 14), stdlib-only purity, credential patterns
scripts/test-core.sh          # all LupyCore tests (native swiftc on macOS, WASM elsewhere)
node tools/swiftwasm/syntax-check.mjs App/Sources/*.swift   # SwiftSyntax parse of the app shell
scripts/build-mac-app.sh      # macOS: build, ad-hoc sign, package, checksum
scripts/smoke-mac-app.sh      # macOS: signature report, --self-test, GUI launch, memory/CPU, screenshots
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
