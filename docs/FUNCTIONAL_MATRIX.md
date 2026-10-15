# Functional matrix

Legend — **Tested**: automated tests pass (sandbox WASM + native macOS runner) · **Native-run**: exercised
inside the real Lupy.app on a macOS runner (self-test / launch smoke) · **Needs Mac test**: compiled
and built, but behaviour needs the founder's Mac (notch, mic, real accounts) · **Needs credentials**:
works only once the founder adds a key/token · **Mocked**: verified against recorded/fake responses ·
**Not implemented** / **Deferred** with reason.

| Area | Capability | Status |
|---|---|---|
| Shell | Native macOS app (SwiftUI/AppKit), Dock + menu bar + notch island | Built & Native-run (launch smoke, screenshots of the no-notch pill — the same layout the founder's notch-less M1 Air uses); notch-wrapping layout only applies to notched Macs and is untested |
| Shell | Original Lupy character (7 moods), original icon, Coucou-style dark UI | Built & Native-run (screenshots) |
| Shell | Onboarding, Today, Projects, Tasks, Needs you, Handoffs, Memory, Activity, Usage, Settings | Built; interaction Needs Mac test |
| Input | Text capture → plan | Tested (core) · Built |
| Input | Dictation with review-before-send (Apple Speech, on-device when supported) | Built; Needs Mac test (no microphone on CI) |
| Input | Spelling/grammar tidy-up of dictation | Not implemented (founder edits the transcript) |
| Planning | Offline heuristic planner (steps, kinds, deadlines in local time, income signals) | Tested |
| Planning | Cloud-model planner with JSON validation, repair attempt, fallback | Tested (Mocked responses) · Needs credentials |
| Planning | Plan review / edit / approve / reject | Tested · Built |
| Priority | Explainable score (urgency, deadline, consequence, value, income, strategy, unblocking, confidence, effort, risk, cost, project weights, pins) | Tested |
| Ownership | Explicit lifecycle (planned…dispatched, delivery unconfirmed, acknowledged, progress evidenced, submitted, verifying, verified, accepted, completed, waiting/blocked/escalated…) with guards | Tested |
| Ownership | Pause / resume / cancel / reopen / checkpoints / dependencies | Tested |
| Assurance | "Agent says done" never verifies; per-kind latest evidence; ambiguous ≠ contradicted; stale evidence ignored | Tested · Native-run (self-test) |
| Assurance | GitHub evidence (branch, PR, commit, CI; bounded re-checks of pending CI) | Tested (Mocked) · Needs credentials |
| Assurance | Worker reliability per task kind with explanations and founder override (never affects permissions) | Tested |
| Handoffs | Brief writer (scope, constraints, project rules, acceptance, evidence requested, checkpoint, reference) | Tested |
| Handoffs | Manual relay to Arena / Muse / Orin, honest "delivery unconfirmed", reply = acknowledgement, claims = self-reports | Tested · Native-run (self-test) |
| Handoffs | Direct Arena / Muse / ChatGPT conversation APIs | Not implemented — no usable API known (shown as "not connected") |
| Follow-up | Bounded follow-ups with backoff, escalation, missed checkpoints, deadlines, stalls, neglected projects, daily review | Tested |
| Notifications | Budget (quiet hours, hourly cap, dedupe, urgent override) | Tested; delivery Needs Mac test |
| Safety | Policy gate (forbidden kinds, global pause, untrusted-origin denial, never-automate project rules, autonomy modes, narrow expiring standing approvals) | Tested |
| Safety | Prompt-injection signals + untrusted fencing; injection cannot change permissions | Tested |
| Safety | Secret redaction (keys, labelled secrets, PEM, cards) in prompts, evidence, errors | Tested |
| Models | OpenAI, Anthropic, Gemini, OpenAI-compatible (DeepSeek, OpenRouter…) adapters + error taxonomy + model refresh | Tested (Mocked) · Needs credentials |
| Models | Routing only to founder-approved providers; fallback; retries with backoff; recurring-failure detection | Tested |
| Cost | Daily/monthly hard caps, per-task cap, per-call approval, usage ledger recorded exactly once | Tested |
| Data | Durable journal + snapshots, torn-write recovery, idempotency, migration, interrupted-action detection | Tested · Native-run (real disk) |
| Data | Backup / restore (checksummed, archive-not-delete), project export/import with ID remap, Markdown export | Tested · Native-run (backup round trip) |
| Data | Keychain storage of keys/tokens | Native-run (Keychain round trip on runner) |
| Memory | Preferences/rules/decisions/facts/lessons, project isolation, sensitive withholding, conflict detection + resolution | Tested |
| Actions | Action ledger with verification; Save to Documents/Lupy with SHA-256 read-back | Tested (core); app path Needs Mac test |
| Actions | Email / social / Displate publishing | Not implemented (drafts only; approval required by policy) |
| Actions | Browser tab / app control | Not implemented — designed (docs/EXECUTION_STRATEGY.md) |
| Ops | Diagnostics, recovery notices, activity (audit) feed, usage view | Built; Tested (core diagnostics) |
| Distribution | Ad-hoc-signed .zip from GitHub Actions with SHA-256 and build info | Produced (see LUPY_STATUS) |
| Distribution | Developer ID signing + notarization | Deferred — needs paid Apple Developer membership (founder decision) |
