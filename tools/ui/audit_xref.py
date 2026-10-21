#!/usr/bin/env python3
"""audit_xref.py — static cross-reference audit of the never-compiled frontier
(body-checks step 6f).

The sandbox's Swift frontend has no Foundation, let alone AppKit, so the Mac
app's ~50 Lupy-era files are parsed but never symbol-resolved here. Three
field runs (kit 3.3, Oct 2026) taught us the shape of the errors that hide
there: code written against imagined APIs. A real compiler is the cure (see
.github/workflows/compile-check.yml — parked behind the account's Actions
billing); until then this audit nets the sweepable half:

  every `OurType.member` static reference in Mac/Sources/Lupy +
  Mac/Sources/CoucouKit must resolve to a member actually declared on that
  type (types/members collected from declarations + extensions across the
  whole module; LupyCore is separately compiled by scripts/test-core.sh).

Instance-member and result-builder errors remain compiler-only territory;
this audit says so honestly rather than pretending to be one.

Exit 0 + "COUNCIL, CROSS-REFERENCE: SATISFIED (N refs)" when all resolve.
"""
import os
import re
import sys

ROOT = "Mac/Sources"
FRONTIER = ("Mac/Sources/Lupy/", "Mac/Sources/CoucouKit/")
TYPE = re.compile(r"^(?:@[\w.()]+\s+)*(?:public\s+|private\s+|internal\s+|fileprivate\s+)?"
                  r"(?:final\s+)?(struct|class|enum|actor|protocol)\s+(\w+)")
EXT = re.compile(r"^extension\s+(\w+)")
MEMBER = re.compile(r"\b(?:func|let|var|typealias)\s+(\w+)")
CASE = re.compile(r"^\s+case\s+([\w,\s]+)")
NESTED = re.compile(r"^\s+(?:.*\s)?(?:struct|class|enum|actor)\s+(\w+)")
STRING = re.compile(r'"(?:\\.|[^"\\])*"')
STAT = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\.(\w+)")
ALWAYS_OK = {"shared", "allCases", "self", "Type", "none", "some", "max", "min",
             "zero", "distantPast", "distantFuture", "current", "default",
             "standard", "main", "general", "system", "global", "userInitiated",
             "background", "utility", "interactive"}


def collect(lines, start):
    mem, depth, seen = set(), 0, False
    for j in range(start, len(lines)):
        ln = lines[j]
        depth += ln.count("{") - ln.count("}")
        if "{" in ln:
            seen = True
        if seen:
            for m in MEMBER.finditer(ln):
                mem.add(m.group(1))
            n = NESTED.match(ln)
            if n and depth == 1:
                mem.add(n.group(1))
            c = CASE.match(ln)
            if c:
                for nm in c.group(1).split(","):
                    nm = nm.strip().split("=")[0].split("(")[0].strip()
                    if nm:
                        mem.add(nm)
        if seen and depth <= 0 and j > start:
            break
    return mem


def main():
    files = {}
    for dp, _dirs, fs in os.walk(ROOT):
        for f in sorted(fs):
            if f.endswith(".swift"):
                p = os.path.join(dp, f)
                files[p] = open(p, encoding="utf-8").read().splitlines()

    types = {}
    for p, lines in files.items():
        for i, ln in enumerate(lines):
            m = TYPE.match(ln)
            if m:
                types.setdefault(m.group(2), set()).update(collect(lines, i))
    for p, lines in files.items():
        for i, ln in enumerate(lines):
            e = EXT.match(ln)
            if e and e.group(1) in types:
                types[e.group(1)].update(collect(lines, i))

    refs, bad = 0, []
    for p in sorted(files):
        if not p.startswith(FRONTIER):
            continue
        for i, raw in enumerate(files[p]):
            if raw.lstrip().startswith("//"):
                continue
            ln = STRING.sub('""', raw).split("//")[0]   # strings + trailing comments off
            for m in STAT.finditer(ln):
                t, mem = m.group(1), m.group(2)
                if t in types:
                    refs += 1
                    if mem not in types[t] and mem not in ALWAYS_OK:
                        bad.append(f"{p}:{i + 1}  {t}.{mem}  | {raw.strip()[:78]}")
    for b in bad:
        print(b)
    if bad:
        print(f"COUNCIL, CROSS-REFERENCE: FAILED — {len(bad)} unresolved static "
              f"member(s) in the Lupy frontier (imagined APIs?)")
        return 1
    print(f"COUNCIL, CROSS-REFERENCE: SATISFIED ({refs} static refs resolve across "
          f"{len(types)} declared types)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
