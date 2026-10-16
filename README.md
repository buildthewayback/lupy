# Lupy

Lupy is a personal executive assistant for the Mac: it turns goals into plans, keeps track of who
owns what, follows up, checks real evidence before calling anything done, asks before doing
anything risky, and survives restarts without losing track.

- **Founder status page:** [`LUPY_STATUS.md`](LUPY_STATUS.md)
- **Work log:** [`WORK_LOG.md`](WORK_LOG.md)
- **Decisions:** [`docs/DECISIONS.md`](docs/DECISIONS.md) · **Limitations:** [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md)
- **Original handoff package:** [`docs/handoff/`](docs/handoff/)

## Layout

| Path | What |
|---|---|
| `LupyCore/` | The "brain": stdlib-only Swift (no Foundation) — state, events, recovery, policy, planning, verification, providers. Compiled and tested anywhere. |
| `App/` | The macOS app (SwiftUI + AppKit), Coucou-derived notch shell. Built on a Mac. |
| `scripts/` | `test-core.sh` (runs all core tests), `typecheck-core.sh`, `lint-core.sh`, Mac build scripts |
| `tools/swiftwasm/` | Dev-only: Swift compiler on WebAssembly so core tests run in Linux sandboxes |
| `docs/` | Decisions, environment evidence, CI budget, reuse map, guides |

## Running the core tests

```sh
scripts/test-core.sh        # macOS: native swiftc · elsewhere: Node 18+ (downloads the dev toolchain via npm)
```

Lupy is derived in part from [Coucou](https://github.com/Louis-CFM/coucou) (MIT); see
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). Lupy does not use Coucou's reserved name,
character, icons, or sounds.
