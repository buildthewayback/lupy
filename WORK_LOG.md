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

### 19:30 — WP-3/4/5/6/7 core logic (Tested in sandbox)
- Added: Safety (secret redaction incl. Luhn card check, PEM blocks, labelled secrets; prompt-injection signals; untrusted-content fencing), PolicyEngine (forbidden kinds, global pause, untrusted-origin access denial, project never-automate rules, autonomy modes, narrow expiring standing approvals with use/cost caps, founder-only grants), BudgetGuard (daily/monthly hard caps, per-task and per-call approval thresholds).
- Verification engine (claims never verify; per-kind latest-evidence judgment; ambiguous ≠ contradicted; stale evidence ignored; elevated/strict oversight), lifecycle guards, transparent reliability rules per worker × task kind with founder override.
- Planning: model-plan JSON validation (cycles, unknown deps, caps, clamping, default criteria, JSON extraction from prose), offline heuristic planner, deadline phrases in local time, dependency graph; explainable prioritization with project weights; scheduler (follow-up backoff, escalation, checkpoints, deadlines, stalls, neglect, daily review, budget warnings, bounded CI re-checks) with idempotency keys; notification budget (quiet hours, hourly cap, dedupe).
- Providers: OpenAI / Anthropic / Gemini / OpenAI-compatible request builders + response parsers + error taxonomy + model-list refresh; keys never enter the core (auth placement filled by the shell); routing over founder-approved providers only; cost estimation; context builder with project isolation, sensitive-memory withholding, redaction and a "what was sent" manifest.
- Connectors: honest catalog (Arena/Muse/Orin = not connected → manual relay), GitHub read-only evidence (branch/PR/commit/check-runs → supports/contradicts/inconclusive), claim extraction, handoff brief writer, file-path policy.
- LupyEngine facade: bootstrap (founder's 10 projects + rules), goals/plans/approval, task lifecycle, delegation with manual relay ("delivery unconfirmed"), worker replies, GitHub verification loop, rework, acceptance, approvals/standing approvals, memory conflicts, decisions, model jobs (consent, budget, approval parking, usage exactly once, retries/backoff, provider fallback, JSON repair, offline fallback), scheduler tick, attention/brief/search/diagnostics.
- Tests: **80/80 passed, 498 checks** — incl. "agent says done, GitHub disagrees", injection, crash-restart, budget, pause, isolation scenarios.
- Fixed during testing: redactor over-redaction ("Token economy"), founder override path from submitted, and a real verification flaw (PR-exists vs CI-failed judged "ambiguous" → now per-kind latest evidence).
