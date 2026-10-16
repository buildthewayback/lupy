# Prior Arena Assessment — Working Context (Re-verify Before Relying on It)

This note summarizes the report already supplied by Arena, so the new execution session can use prior findings without treating them as unquestionable facts.

## Prior reported findings

- Arena’s report described its environment as Linux x86_64, without Swift, Xcode, Apple SDKs, a macOS GUI, or direct native-Mac runtime testing.
- Arena reported it did not have a GitHub connector or `gh` CLI in that particular session; a public shallow clone was possible. This may differ by session/account and must be rechecked.
- Coucou repository: `https://github.com/Louis-CFM/coucou`.
- Prior inspected commit reported: `a95d309a4752c23ae28453819245339800557609` (reported date 2026-10-15). Re-fetch the repository and record the actual commit currently inspected.
- Coucou is a native macOS SwiftUI/AppKit codebase; the report described Swift 6, macOS 15+, Xcode 16+ and XcodeGen requirements. Verify from current source/configuration.
- The root code licence was reported as MIT. A separate `LICENSE-ASSETS.md` was reported to reserve Coucou/Mochi branding, character design, icons, sounds, and listed artwork. Verify the actual files and exact conditions before reusing or distributing protected assets.
- The report described existing provider calling/settings patterns, Keychain patterns, hooks/session handling, approvals/questions/diffs, integration pollers and CI/tests. This does not prove the app already has Lupy’s end-to-end task ownership, evidence verification, recovery or generic browser automation.
- Prior test note: a bare Node invocation failed when attempting to load `.ts` under Node v20; this was considered a test-command/environment mismatch, not proof that application tests passed or failed.
- Prior planning-only estimates were wide and low-confidence. They are not an authorized scope cap or a reliable promise. The current instruction is to build in one coordinated campaign and use measured progress to report realistic status.

## Instructions for the execution agents

1. Verify current repository, branch, commit, license files, build configuration, tools, account access and GitHub Actions billing/quota in the actual session. Mark each item **observed**, **tested**, **documented**, **inferred**, or **unknown**.
2. Do not assume the earlier Linux-only limitation is universal; test your current sandbox. Do not claim that Arena can build/launch/sign a Mac app unless you actually perform that step in a macOS environment.
3. Work from a Lupy branch/repository. Never edit Coucou upstream directly. Preserve required licence notices.
4. Keep Coucou’s familiar layout, visual language, interaction patterns and animations where permitted. Do not copy reserved art/branding into a distributed build unless its permission is clearly established. Resolve this with the lowest-friction lawful option; do not let asset ambiguity block backend/core work.
5. The first deliverable is not another report. It is a working, tested Lupy implementation with honest limitations and a clear path to a native installable build.
