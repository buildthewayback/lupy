# Performance and resource budget (requirements §16)

Measured on a GitHub `macos-latest` runner (macOS 26.6.2, Apple M1 virtual machine, 3 CPUs, 7 GB,
no GPU acceleration for the window server). The founder's MacBook Air M1 must confirm these
(acceptance checklist items 4–5); VM CPU numbers are pessimistic for drawing.

| Metric | Measured | Budget | Source |
|---|---|---|---|
| Memory as Activity Monitor shows it (physical footprint), idle with demo data | **49.5 MB** | ≤ 250 MB | `vmmap --summary`, run 38793640196 |
| Resident set (includes shared macOS frameworks) | 128 MB | — | `ps -o rss`, same run |
| CPU, frontmost, idle, demo data (VM) | 12.4 % (before final frame-rate trim) | < 3 % on real hardware | `top` 3 s sample |
| CPU, background, idle, demo data (VM) | 5.5 % (island pulsing because items need you) | < 2 % | `top` 3 s sample |
| Durable write (append + F_FULLFSYNC) | 1.4–2.5 ms each | < 20 ms | native self-test |
| Rank + attention over 400+ tasks | 7–13 ms | < 100 ms | native self-test |
| Cold load of all data (400+ tasks) | 28–37 ms | < 1 s | native self-test |
| App size | 6.5 MB | — | build info |

## What runs and when

- **One process, no helpers.** No Docker, VM, browser engine, database server, Node/Python
  runtime or local model.
- **Timers:** scheduler tick every 60 s (and on wake/foreground); island pointer check every 0.3 s
  (only does work while the island is open).
- **Animations:** Lupy's character animates only while Lupy is the active app (main window) or,
  in the island, when something needs you; calm moods tick at 4 fps, active moods 10–15 fps; the
  sidebar character is static.
- **Network waits** are async (URLSession) and consume no CPU while waiting. Model calls are
  bounded by budget, retries (≤ 2) and per-task limits.

## Growth bounds

- In-memory activity feed: last 1,500 events (journal on disk keeps everything).
- Notices in memory: newest 800. Idempotency keys remembered: 10,000.
- Snapshot every 500 events; old journal segments move to `archive/`.
- Disk use is text (JSON lines) — typically a few MB per year of normal use.

## Under memory pressure

Lupy holds little memory and has no caches worth evicting; macOS can compress or page it. All
state is durable on every change, so if macOS terminates Lupy it restarts with nothing lost.
