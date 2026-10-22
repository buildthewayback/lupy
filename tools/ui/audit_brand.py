#!/usr/bin/env python3
"""Council 6h · WHITE-LABEL LAW (founder, 2026-10-22).

Coucou is the engineering blueprint; LUPY is the brand, the product and the
only character. This gate fails if the donor's brand or developer-product
layer returns to any founder-visible surface:

 - the string catalog may not present "Mochi" (any locale) nor "Coucou"
   (English) — except the one "Based on Coucou by Louis Raillé" credit line;
 - the editor/agent "Active pills" page stays out of the hub sidebar, and
   the Demo / Weekly-recap boxes stay out of Settings → General;
 - donor developer machinery (hooks, service pollers, crypto) may only
   start behind the `lupyDevHooks` opt-in;
 - heroes are drawn by the Lupy rig (LupyRenderer), never the donor canvas;
 - the shipped bundle takes its menu-bar icon and its sounds from
   Mac/LupyAssets (forged originals), never from CoucouAssets;
 - every sound name the engine can request has a forged file.
Internal identifiers (hook protocol keys, defaults keys, class names) are
plumbing, not branding, and are deliberately exempt.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
failures = []


def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()


def check(cond, msg):
    if not cond:
        failures.append(msg)


# 1 · Catalog presentation
cat_raw = read("Mac/Resources/Localizable.xcstrings")
check("Mochi" not in cat_raw, "catalog still presents the donor character name (Mochi)")
strings = json.loads(cat_raw)["strings"]
CREDIT_KEY = "Coucou · github.com/Louis-CFM/coucou"
en_bad = []
for k, v in strings.items():
    en = v.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value", "")
    if "Coucou" in en and k != CREDIT_KEY:
        en_bad.append(k)
check(not en_bad, f"english catalog values still brand Coucou: {en_bad[:4]}")
sec = strings.get("hub.section.notch", {}).get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value", "")
check(sec == "Island", f"hub.section.notch should read 'Island', reads {sec!r}")

# 2 · Sidebar / settings surfaces
hub = read("Mac/Sources/App/FlowHub.swift")
m = re.search(r"static let notchPages[^\n]*", hub)
check(m and ".pills" not in m.group(0), "hub notchPages lists the donor .pills page again")
settings = read("Mac/Sources/App/SettingsView.swift")
for gone in ('title: "Active pills"', 'title: "Agents"', "demo.groupbox.title",
             'GroupBox(String(localized: "Weekly recap"))'):
    check(gone not in settings, f"SettingsView shows the donor surface again: {gone}")

# 3 · Developer machinery opt-in only
delegate = read("Mac/Sources/App/AppDelegate.swift")
check(delegate.count("lupyDevHooks") >= 4, "AppDelegate dev-machinery gates weakened")
bare = re.findall(r"(?m)^        (?:HookServer|N8nPoller|VercelPoller|ResendPoller|GithubPoller|"
                  r"StripePoller|CalcomPoller|NotionPoller|CryptoController|PortfolioController)"
                  r"\.shared\.start\(\)$", delegate)
check(not bare, f"donor machinery starts unconditionally: {bare}")

# 4 · Heroes from our rig only
heroes = read("Mac/Sources/App/FlowHubMochis.swift")
check("LupyRenderer.draw" in heroes, "page heroes no longer use the Lupy rig")
check("actor.engine.draw" not in heroes, "page heroes draw the donor BotEngine again")

# 5 · Bundle assets are ours
build = read("scripts/build-no-xcode.sh")
check("CoucouAssets" not in build, "founder build copies donor assets into the bundle")
for need in ("LupyAssets/MenuBarIcon.png", "LupyAssets/sounds"):
    check(need in build, f"founder build lost our asset copy: {need}")
for f in ("Mac/LupyAssets/MenuBarIcon.png", "Mac/LupyAssets/MenuBarIcon@2x.png"):
    check(os.path.exists(os.path.join(ROOT, f)), f"forged icon missing: {f}")

# 6 · Every engine sound name forged
engine = read("Mac/Sources/App/SoundEngine.swift")
names = re.findall(r'"([a-z]+)"', re.search(r"static let soundNames = \[(.*?)\]", engine, re.S).group(1))
missing = [n for n in names if not os.path.exists(os.path.join(ROOT, f"Mac/LupyAssets/sounds/{n}.wav"))]
check(not missing and names, f"sounds not forged: {missing}")

if failures:
    print("COUNCIL, BRAND: VIOLATED")
    for f in failures:
        print("  ✗", f)
    sys.exit(1)
print(f"COUNCIL, BRAND: SATISFIED ({len(strings)} strings present Lupy, {len(names)} sounds ours, dev layer opt-in)")
