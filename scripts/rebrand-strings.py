#!/usr/bin/env python3
"""Lupy rebrand of Coucou's Localizable.xcstrings, keeping Xcode's exact JSON layout.

User-facing "Coucou" (the app name) becomes "Lupy" in every language. Kept as they are:
lowercase paths the app really writes (~/.claude/coucou/nb-hook, plugins/coucou.ts, ...).
The voice wake word now reads "OK Lupy" (WakePhrase accepts both OK Lupy and OK Coucou).
The upstream credit line names Coucou and its author (MIT notice; honest attribution).
Usage: scripts/rebrand-strings.py Mac/Resources/Localizable.xcstrings [--check]
"""
import json, re, sys

CREDIT_KEY = "Coucou · github.com/Louis-CFM/coucou"
CREDIT_EN = "Based on Coucou by Louis Raillé · github.com/Louis-CFM/coucou"

def dump(d):
    out = json.dumps(d, indent=2, ensure_ascii=False, separators=(",", " : "))
    # Xcode writes an empty object as "{", a blank line, and "}" at the key's indentation.
    return re.sub(r'^( *)(.*) : \{\}(,?)$', lambda m: f'{m.group(1)}{m.group(2)} : {{\n\n{m.group(1)}}}{m.group(3)}',
                  out, flags=re.M)

def rebrand(text):
    text = text.replace("OK Coucou", "OK Lupy").replace("Hey Coucou", "Hey Lupy")
    return re.sub(r"\bCoucou\b", "Lupy", text)

def walk(node, changed):
    if isinstance(node, dict):
        unit = node.get("stringUnit")
        if isinstance(unit, dict) and isinstance(unit.get("value"), str):
            new = rebrand(unit["value"])
            if new != unit["value"]:
                unit["value"] = new; changed[0] += 1
        for v in node.values():
            walk(v, changed)

def main():
    path = sys.argv[1]
    raw = open(path, encoding="utf-8").read()
    d = json.loads(raw)
    if dump(d) != raw:
        sys.exit("layout check failed: re-serialising the unmodified file does not reproduce it")
    if "--check" in sys.argv:
        print("layout round-trip identical"); return
    changed = [0]; added = 0
    for key, entry in d["strings"].items():
        if key == CREDIT_KEY:
            entry.setdefault("localizations", {})["en"] = {"stringUnit": {"state": "translated", "value": CREDIT_EN}}
            added += 1
            continue
        walk(entry, changed)
        locs = entry.get("localizations", {})
        # Keys used as their own English text (no "en" entry) get an explicit English value.
        if "en" not in locs and re.search(r"\bCoucou\b", key):
            entry.setdefault("localizations", {})["en"] = {"stringUnit": {"state": "translated", "value": rebrand(key)}}
            added += 1
    open(path, "w", encoding="utf-8").write(dump(d))
    print(f"rebranded {changed[0]} translated values, added {added} English values")

main()
