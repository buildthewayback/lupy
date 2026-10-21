#!/usr/bin/env python3
"""audit_isolation.py — the NSResponder isolation census (body-checks step 6d).

Why this exists: the sandboxed Swift frontend can only PARSE the AppKit target
(no macOS SDK here), so a Swift 6 isolation error in the Mac app is invisible
to every other gate. Exactly one such error reached the founder: kit 3.3's
first field compile (2026-10-20) stopped at `panel?.orderOut(nil)` inside
LupyIslandShellController — one controller lacking @MainActor, in an app where
every sibling has it. The compiler's note said it plainly: "main actor
isolation inferred from inheritance from class NSResponder".

This census scans every window/view-family token (orderOut, setFrame,
NSPanel(, NSHostingView, contentView =, animator(), …) in Mac/Sources and
checks its enclosing type is isolated — @MainActor, an NSResponder descendant,
or a SwiftUI View/App (bodies and actions are main-actor contexts). Anything
else is reported file:line and fails the gate. It is a tripwire, not a
type-checker; the founder's Mac remains the final judge.

Exit 0 + "COUNCIL, ISOLATION: SATISFIED (N sites)" when the den is empty.
"""
import os
import re
import sys

ROOT = "Mac/Sources"
TOK = re.compile(
    r"\.orderOut\(|\.orderFront|\.makeKeyAndOrderFront|\.makeKey\(|\.setFrame\("
    r"|\.addSubview\(|NSHostingView|NSPanel\(|NSWindow\(|NSAnimationContext"
    r"|\.contentView\s*=|\.animator\(\)|becomeFirstResponder")
TYPE = re.compile(
    r"^\s*(?:final\s+)?(class|struct|enum|actor)\s+(\w+)\s*(?:<[^>{]+>)?\s*(?::\s*([^{]+))?\{?")
ISOLATED_SUPER = re.compile(
    r"\bNS\w*(View|Window|Panel|Responder|Controller)\b|\bNSApplicationDelegate\b"
    r"|\bView\b|\bApp\b|\bScene\b|\bObservableObject\b")


def census_dir(root):
    sites = 0
    violations = []
    for dp, _dirs, files in os.walk(root):
        for fname in sorted(files):
            if not fname.endswith(".swift"):
                continue
            path = os.path.join(dp, fname)
            lines = open(path, encoding="utf-8").read().splitlines()
            stack = []  # [depth-after-open, name, kind, isolated]
            depth = 0
            enc = {}
            for i, ln in enumerate(lines):
                m = TYPE.match(ln)
                opens, closes = ln.count("{"), ln.count("}")
                if m and opens > 0:
                    prev = " ".join(lines[max(0, i - 3):i])
                    supers = m.group(3) or ""
                    isolated = ("@MainActor" in prev or "@MainActor" in ln
                                or ISOLATED_SUPER.search(supers) is not None)
                    stack.append([depth + 1, m.group(2), m.group(1), isolated])
                depth += opens - closes
                while stack and depth < stack[-1][0]:
                    stack.pop()
                enc[i] = stack[-1] if stack else None
            for i, ln in enumerate(lines):
                if ln.lstrip().startswith("//"):  # doc comments quote the fossil on purpose
                    continue
                if TOK.search(ln):
                    sites += 1
                    e = enc.get(i)
                    if e is None or not e[3]:
                        where = f"{e[2]} {e[1]}" if e else "top level"
                        violations.append(
                            f"{path}:{i + 1} [{where} — NONISOLATED] {ln.strip()[:76]}")
    return sites, violations


def main():
    sites, violations = census_dir(ROOT)
    for v in violations:
        print(v)
    if violations:
        print(f"COUNCIL, ISOLATION: FAILED — {len(violations)} nonisolated "
              f"window/view site(s) of {sites} (Swift 6 field errors)")
        return 1
    print(f"COUNCIL, ISOLATION: SATISFIED ({sites} window/view sites, all isolated)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
