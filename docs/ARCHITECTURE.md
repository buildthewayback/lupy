# Lupy architecture (one page)

```
┌──────────────────────── Lupy.app (SwiftUI + AppKit, one process) ────────────────────────┐
│  Island (NSPanel at the notch) · Main window · Menu-bar item · Dictation (Apple Speech)   │
│                                   AppModel (@MainActor)                                   │
│        executes Effects: HTTPS (keys from Keychain) · notifications · clipboard · files   │
│                │ commands                                   ▲ effects                     │
│  ┌─────────────▼────────────────────────────────────────────┴───────────────────────────┐ │
│  │ LupyCore (stdlib-only Swift, deterministic, tested in Linux sandbox and on macOS)    │ │
│  │  LupyEngine: goals→plans→tasks · lifecycle guards · handoffs · verification ·        │ │
│  │  reliability · policy/approvals · budgets · model routing/adapters · context/        │ │
│  │  redaction · scheduler · action ledger · memory · backup/export                      │ │
│  │  EventStore: append-only checksummed journal + snapshots (write-ahead, idempotent)   │ │
│  └──────────────────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────────────────┘
      ~/Library/Application Support/Lupy/store        macOS Keychain (API keys, GitHub token)
```

- **No background services.** One process; a 60-second scheduler tick (plus wake/foreground) and a
  0.3-second pointer check for the open island. Network waits are async and cost no CPU.
- **Functional core / imperative shell.** Every rule (what is verified, what needs approval, what it
  costs, what is due) lives in LupyCore and is unit-tested; the shell only performs effects.
- **Event sourcing.** Every change is an event in an append-only journal (the audit trail);
  state = fold(events). Snapshots bound start-up time; archives keep history.
- **Keys never enter the core.** Requests carry an auth *placement*; the shell inserts the key from
  the Keychain at send time.
- **Honest connectors.** Arena/Muse/Orin have no usable API → manual relay with "delivery
  unconfirmed"; GitHub is read-only evidence; email/social are not connected (drafts only).

Key files: `LupyCore/Sources/LupyCore/Engine*.swift`, `EventStore.swift`, `Policy.swift`,
`Verification.swift`, `Providers.swift`, `App/Sources/AppModel.swift`, `App/Sources/Island.swift`.
