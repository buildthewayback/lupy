# Known limitations

Living list. Each item: what, why, impact, and what would remove it.

| # | Limitation | Why | Impact | Path to remove |
|---|---|---|---|---|
| L-01 | GitHub Actions billing usage/remaining minutes cannot be read by the agent | Session token is a GitHub App token without billing access (HTTP 403) | CI spend is estimated from job durations, not measured against the account total | Founder checks Settings → Billing, or grants billing read |
| L-02 | The Mac app cannot be compiled inside the Arena sandbox | No macOS/Xcode in Linux; only a Swift-on-WASM compiler without Foundation/SwiftUI | App-shell changes need a macOS runner build (scarce minutes) | Build on the founder's Mac or more CI runs |
| L-03 | Journal integrity uses FNV-1a checksums per batch, not cryptographic signatures | Detects corruption and torn writes, not deliberate tampering by someone with disk access | Edits made directly to files would not be detected | HMAC keyed from the Keychain |
| L-04 | Not Developer-ID signed or notarized (ad-hoc signature) | Needs a paid Apple Developer membership (not bought) | First open needs System Settings → “Open Anyway”; repeated after each update; Keychain may ask “Always Allow” after updates | Founder buys membership → sign + notarize in CI |
| L-05 | **No live cloud-model call has been made** | No API keys exist in this campaign by design | Adapters are verified against realistic fixtures only; first live call is the founder's “Test connection” | Founder adds a key and runs checklist items 10–11 |
| L-06 | Default model names and prices are estimates as of the build date | Providers change models/prices often | A default model may be rejected; costs are estimates | “Refresh models” + edit prices in Settings |
| L-07 | **No live GitHub verification has been run** | No founder token in this campaign | GitHub evidence logic is fixture-tested only; token permissions (Contents/Pull requests/Checks read) assumed from GitHub docs | Founder connects a token (checklist item 15) |
| L-08 | Arena, Muse and Orin/ChatGPT are manual relay only | No API Lupy can use is known for these services | Lupy cannot see delivery or progress inside them; it relies on pasted replies and GitHub evidence | Add connectors if official APIs appear |
| L-09 | No email, social media or Displate sending; no browser/app automation | Out of scope for v1 (see EXECUTION_STRATEGY.md); policy requires approval anyway | Lupy drafts; the founder sends/publishes | Implement API connectors / Apple Events actions |
| L-10 | Follow-ups and notifications only run while Lupy is open | No background daemon (resource budget) | Nothing fires while Lupy is quit; due items are processed (once) at next launch | Optional login item / launch at login |
| L-11 | Dictation needs microphone + speech permissions; uses the Mac's language; no automatic grammar tidy-up | Apple Speech; review-before-send first | The founder corrects text by hand | Optional model “tidy” step |
| L-12 | CPU was measured in a GPU-less CI virtual machine | No real hardware available to the agent | Real M1 numbers unknown (expected lower) | Checklist item 5 on the founder's Mac |
| L-13 | Notch-wrapping island layout untested | CI runner and the founder's M1 Air have no notch | Only matters on notched Macs/displays | Test on a notched Mac |
| L-14 | App target compiles in Swift 5 mode with minimal concurrency checking | Reduce first-build risk without a local Mac compiler (core is Swift 6 strict) | Less compiler help against threading mistakes in the shell | Move to Swift 6 once a Mac build loop exists |
| L-15 | Data folder is not separately encrypted | Relies on macOS FileVault | If FileVault is off, data is readable by anyone with the disk | Enable FileVault (recommended) |
| L-16 | One Mac, one user; no sync | Local-first design | Moving Macs = backup/restore | Future sync |
| L-17 | English UI, dark appearance only | Scope | — | Localization/light theme later |
| L-18 | GitHub artifacts expire after 14 days | Storage limits | Old builds disappear | Rebuild from the commit, or keep the zip |
| L-19 | Usage costs are estimates (tokens × configured prices) | Providers bill separately | Budget caps are as accurate as the prices entered | Edit prices; compare with the provider's dashboard |
