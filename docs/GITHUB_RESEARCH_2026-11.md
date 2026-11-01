# GitHub research: removing barriers in Lupy

Research snapshot: 2026-11-01. Ideas only; no third-party code, packages, models or assets were copied or added. Check current licences, provenance, compatibility and maintenance before adoption. Do not treat repository claims as proof that a feature works on the founder's Mac.

| Repository | Useful idea | Lupy relevance / constraint |
| --- | --- | --- |
| [Peekaboo](https://github.com/openclaw/Peekaboo) | Inspect a structured accessibility snapshot, use semantic actions, then check results; make permission onboarding explicit. The project describes foreground-consent and fresh-snapshot policies. | Lupy already has accessibility snapshots and control; explore **bounded, explicit post-action checks** before claiming completion. Do not replace Lupy's approval rules or install a separate agent. GitHub lists MIT; verify the exact revision and notices before any reuse. |
| [agent-swift](https://github.com/beastoin/agent-swift) | A readiness check and a snapshot → act → wait/assert → evidence workflow. | A simple in-app readiness checklist and verifiable outcomes could reduce failed automation. API metadata did not identify a licence; do not copy code without verifying rights. |
| [WhisperApp](https://github.com/wbfrancis/WhisperApp) | Replaceable dictation components and a small audio-fixture evaluation that reports word error rate. | Useful testing pattern: obtain consented recordings, include short/noisy clips, and measure errors and paste recovery. Its small dataset is not a general accuracy benchmark. API metadata did not identify a licence. |
| [TypeWhisper](https://github.com/TypeWhisper/typewhisper-mac) | User-visible dictation recovery and restore-raw-transcript features. | Explore recovery of words when cleanup changes meaning; consider history retention and privacy controls. GitHub lists GPL-3.0: inspiration only, no code/dependency reuse without legal review. |
| [Cloudless Voice](https://github.com/synth-inc/cloudless-voice) | Clearly separates local speech recognition from optional cloud cleanup and model download requirements. | Lupy should distinguish speech-recognition privacy from cleanup privacy and explain what is sent to whom. Its app is GPL-3.0-or-later and includes a separately licensed closed binary; do not import either without legal review. |

## Immediate barrier found in Lupy

The pending provider-neutral Flow cleanup work had an Anthropic-only **UI gate**: a user with Gemini or another approved provider could still see the cleanup switch disabled. The local follow-up changes the gate to use the same provider availability as cleanup, and corrects the privacy/setup wording in all supported translations. The gate is not a live connection test. This follow-up is not released; it still needs a native macOS build, a real provider test and hands-on dictation verification.

## Next practical experiments

1. On the founder's Mac, enable one approved provider, use its Test button, then enable Flow cleanup with **no legacy Anthropic key**. Dictate into a harmless text field; compare raw and cleaned text. Repeat with the provider disabled or offline and verify raw-text fallback. Never put credentials in logs or test fixtures.
2. Prototype a small readiness checklist that distinguishes permission granted, provider configured, live connection tested and actual action verified. Do not equate configuration with a successful network call.
3. Build a consented, local dictation fixture set and check short clips, names, corrections and failed-paste recovery. Report the actual audio, engine, locale, metric and limitations.
4. Evaluate accessibility post-action checks with a harmless app and explicit approval: if a result cannot be observed, report it as unverified. Keep privacy, Stop/Esc, and human oversight intact.
