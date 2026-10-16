
## 2026-10-16 (F6 campaign) — the island conversation
1. Directive study (3 passes) → design: island = quick-access interaction surface; one shared
   conversation for island + window; deterministic offline intent router (D-028…D-031).
2. LupyCore: `Conversation.swift` (ChatIntentRouter, prepareConversationTurn, status answers);
   `ConversationTests.swift` — debug loop on WASM (Foundation-isms, router edge cases) →
   **106/106 tests, 658 checks**.
3. App: `LupyChat.swift` (transcript + routing + approvals + jobCompleted), `LupyIslandChatView`
   (.lupyChat), `LupyChatPanel` (Today replaces the capture bar), `LupyChatSelfTest`
   (`--chat-self-test`, 9 journeys, headless, no network). LupyModel.perform routes answers into
   the conversation.
4. Hooks (22 upstream files): IslandTypes (.lupyChat case), IslandViewContent (view),
   IslandRootView (isTall), IslandWindowController (default view + openChat shortcut),
   LupyIslandBridge (closeCard → conversation), LupyRuntime `--show-island-chat`,
   LupyPagesToday/Settings. Settings reorganised (D-031).
5. CI: island-chat screenshot (second demo launch), chat self-test in verify (36 checks now);
   check-run entry for the island-chat screenshot. Docs: REQUIREMENTS_STATUS §6 + journey table,
   D-028…D-031, L-25…L-27, TEST_REPORT, CI_BUDGET.
6. Review pass caught: `defaultView()` hook missing from IslandWindowController (edit_file had
   claimed success — grep first, trust later); exhaustive-switch audit over IslandView (all other
   switches have defaults; both `viewLayouts[view]!` sites covered).
7. Commit `61a1685`; build **F6 requested** (run 38912345728, commit `39e4831`).
8. F6 (run 38912345728, `39e4831`) failed fast: 9 compile errors — `captureInConversation` and
   `statusColor` existed only in the design, 6 Substring→String conversions. Wrote the real
   `captureInConversation` (outcome enum instead of toasts), `statusColor`, wrapped the substrings;
   audited every `chat.`/`model.` member access against the real types (clean).
9. F7 (run 38913748036, `5b9167f`) **compiled** — all 34 download checks green except the new chat
   self-test (17/19). The two failures were the test expecting less honesty than the app delivers:
   with active tasks, "stop" pauses follow-ups for real, and the paused engine correctly refuses
   the follow-up model call. Fixed the assertions (accept the honest branches; "resume" before the
   follow-up; print the unavailable reason). Also: the island-conversation check-run entry was
   missing from the workflow's screenshot loop — added.
10. **F8 (run 38916058766, `e8afb0f`) DELIVERED**: 36/36 download checks on macOS 14.8.9 and
    26.6.2, chat self-test **19/19** both, Coucou 13/13 + wake, control 9/9, island-conversation
    screenshots both Macs (decoded to `.cache/f8/`), CPU unchanged from F5 within noise. Campaign
    total ≈1,290 of 2,000 Linux-eq (64.5%).

## 2026-10-16 (after F8) — founder feedback → LUPY 2 directive
He tested download/open, island, and connected an AI key successfully. Feedback (full text in
docs/LUPY2_PLAN.md): rebrand character to Lupy everywhere (remove Mochi/Coucou text, keep the
art/animations); island = click-outside closes, input at bottom, hover zoom + labels, minimal,
fast; quick-jumps for his daily areas; ONE API hub with any-key support (mainstream + free-token
OpenAI-compatible like CodeCraft), auto-failover, current-model status in island, memory stable
across model switches; far fewer settings; remove coding/unused features; RAM target well under
1 GB (F8 already measures 46–93 MB physical); CI minutes scarce → research, ask, then 2–3 builds.
Asked the 4 open questions before starting.
