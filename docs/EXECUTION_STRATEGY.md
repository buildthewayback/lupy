# Tool and computer execution — strategy decision (requirements §5.3, §9, §18)

Status labels: Implemented & tested · Documented only · Not implemented.

## Constraints that decide this

- MacBook Air M1, 8 GB, ~1 GB free → nothing heavy may stay resident (no Docker, no permanent
  browser/Node/Python runtimes, no local models).
- Every action must pass Lupy's policy gate, carry an idempotency key, and be **verified** before
  Lupy claims it happened ("sent a command" ≠ "it happened").
- CAPTCHA/MFA/human verification must never be bypassed; Lupy prepares and asks the founder.

## Options compared

| Option | What it is | Resident RAM | Reliability / verification | Security & isolation | Fit |
|---|---|---|---|---|---|
| Direct APIs (GitHub, email providers, calendars, social APIs) | HTTPS calls through Lupy connectors; keys in Keychain | ~0 (in-process) | Highest; responses are checkable evidence | Scoped tokens, per-service | **Primary** |
| Native macOS automation (AppleScript/JXA Apple Events, EventKit, Shortcuts) | Built into macOS; per-app Automation permission prompts | ~0 | Good for Finder, Mail, Calendar, Reminders, Notes, Safari tabs; results re-queryable (e.g. list tabs after closing one) | macOS TCC prompts per app; can be scoped to one app/window | **Secondary** |
| Safari WebDriver (`safaridriver`, built in) | Scripted Safari automation windows | 0 until used; Safari process while running | Medium; DOM-level checks possible; layouts change | Automation sessions are isolated from normal browsing; logins (and MFA) happen inside the session with the founder | On demand only, for web tasks without APIs |
| Playwright / Puppeteer | Bundled Chromium + Node | 300–600 MB per browser + runtime | High control, but heavy and must be shipped/updated | Separate profiles | Rejected for this Mac (RAM, bundle size, maintenance) |
| Visual computer use (screenshot → cloud model → click; e.g. Open Interpreter, vendor "computer use") | Model drives mouse/keyboard | Moderate locally; high API cost per step | Lowest; error-prone on GUI changes; hard to verify | Needs Screen Recording + Accessibility (broad) | Rejected for v1 (risk, cost); revisit for GUI-only chores |
| Delegation to agents (Arena, Muse, Orin) | Brief → agent | 0 | Only as good as independent evidence (GitHub etc.) | No API Lupy can use → manual relay | Implemented as manual relay |

## Decision (D-017)

**One primary strategy: API-first, with native macOS automation as the only fallback layer.**
Safari WebDriver may be added later strictly on demand for specific web workflows; Playwright and
visual control are not adopted. All execution goes through the same action ledger:

`propose → policy gate → (approval) → beginAction (idempotency key) → do it → verify by an
independent read-back → finishAction (evidence) → or "outcome unknown" after a crash`.

## What exists today

| Capability | Status | Evidence |
|---|---|---|
| Action ledger (policy-gated, idempotent, crash-safe unknown outcome, settle-by-founder) | Implemented & tested | `LupyCore/Sources/LupyCore/Actions.swift`; test "action ledger: …" |
| Save a deliverable to `~/Documents/Lupy`, read back, compare SHA-256, record file evidence | Implemented (app); native check pending founder Mac | `AppModel.saveDraftToFile`; file-path policy tests |
| GitHub read-only verification (branch, PR, commit, CI) | Implemented & tested with fixtures; live use needs founder token | `Connectors.swift`, engine tests |
| Cloud model as a worker (drafts with deterministic checks) | Implemented & tested with fixtures | engine test "cloud-model worker…" |
| Manual relay to Arena / Muse / Orin with honest "delivery unconfirmed" | Implemented & tested | engine tests |
| Sending email / posting to social / Displate listings | Not implemented (drafts only; publishing always needs approval) | KNOWN_LIMITATIONS |
| Closing browser tabs, operating other apps (AppleScript) | Not implemented — design below | — |
| Visual computer control | Not implemented (rejected for v1) | — |

## Next steps (designed, not built)

1. **Safari tab actions via Apple Events** (secondary layer): list tabs (window index, tab index,
   URL, title) → founder picks/approves "close tab X" → `close tab` → re-list to verify it is gone →
   evidence. Only Safari windows the founder designates; never other browsers/profiles.
2. **Email via provider API** (e.g. Gmail API or Resend) behind `sendExternalMessage` approval,
   with delivery evidence from the provider response and sent-folder check.
3. **Calendar/Reminders via EventKit** (native framework, permission prompt) for deadlines and
   checkpoints, verified by reading the event back.
