
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
