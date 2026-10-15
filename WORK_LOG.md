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
