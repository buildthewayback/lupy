# LUPY on your Mac — three steps, no jargon

Your Mac: macOS Sequoia 15.7.4 (24G517). That is the floor; nothing below it is
supported. You need **Xcode** (free, App Store) and **Homebrew** (you likely have it).

1. **Get the code.** In Terminal:
   `git clone -b arena/47c739ab-lupy https://github.com/buildthewayback/lupy.git lupy3 && cd lupy3`
2. **One command:** `bash scripts/run-mac.sh`
   It installs the project generator (once), builds the Xcode project, opens Xcode.
3. **In Xcode press ⌘R.** LUPY runs. On your M1 2020 the island is the capsule
   under the menu bar; type in its box to talk to him; when a hooked session asks
   permission, the card opens with **Allow once / Deny** — or ⌘Y / ⌘N from the
   keyboard.

If you ever want the old v0.2 island back for comparison:
`defaults write <your.bundle.id> lupy3LegacyIsland -bool true` and relaunch.
