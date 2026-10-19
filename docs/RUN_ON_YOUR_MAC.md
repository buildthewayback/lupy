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

## If the clone says "repository not found"

The repo is **private**, so an unsigned-in Terminal sees nothing (GitHub hides private
repos as "not found"). Two doors, pick either:

**Door 1 — your browser (no setup, two minutes).** You are already signed in at
github.com. Open https://github.com/buildthewayback/lupy → click the branch button
(it says `main`) → type `arena/47c739ab-lupy` and click it → green **Code** button →
**Download ZIP** → double-click the zip in Downloads. Then in Terminal:

```
cd ~/Downloads/lupy-arena-47c739ab-lupy && bash scripts/run-mac.sh
```

**Door 2 — sign the Terminal in once (best for updates later).** If `brew` exists on
your Mac (`which brew` prints a path):

```
brew install gh && gh auth login
```

Answer: GitHub.com · HTTPS · login in browser · paste the one-time code. Then:

```
gh repo clone buildthewayback/lupy lupy3 -- -b arena/47c739ab-lupy && cd lupy3 && bash scripts/run-mac.sh
```

**If anything says `brew: command not found`:** paste this one line first (it asks for
your Mac password once), then run the `bash scripts/run-mac.sh` line again:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## If the App Store refuses Xcode ("macOS XX or later is required")

The App Store only offers the newest Xcode, which demands a newer macOS than yours.
You do not need Xcode at all — Apple's small Command Line Tools carry the compiler:

```
xcode-select --install
bash scripts/build-mac-app.sh && bash scripts/smoke-mac-app.sh && open build/DerivedData/Build/Products/Release/Lupy.app
```

Build → native smoke evidence → LUPY launches. No OS upgrade, no 12 GB download.
