# Known limitations

Living list. Each item: what, why, impact, and what would remove it.

| # | Limitation | Why | Impact | Path to remove |
|---|---|---|---|---|
| L-01 | GitHub Actions billing usage/remaining minutes cannot be read by the agent | Session token is a GitHub App token without billing access (HTTP 403) | CI spend is estimated conservatively, not measured against the account total | Founder checks Settings → Billing, or grants a token with billing read |
| L-02 | The Mac app cannot be compiled inside the Arena sandbox | No macOS/Xcode in Linux; only a Swift-on-WASM compiler without Foundation/SwiftUI | App-shell code is only compiled on a GitHub macOS runner (scarce minutes) | Build on the founder's Mac or more CI runs |
| L-03 | LupyCore journal integrity uses FNV-1a checksums per batch, not cryptographic signatures | Detects corruption and torn writes, not deliberate tampering by someone with disk access | A person with access to the Mac's files could edit history undetected | Add an HMAC keyed from the Keychain (future) |
