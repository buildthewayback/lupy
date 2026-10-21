#!/usr/bin/env python3
"""audit_decls.py — duplicate top-level type declarations (body-checks step 6e).

The sandbox cannot type-check the AppKit target, so whole classes of compiler
error are invisible here until a founder's Mac finds them. Duplicate type
declarations are the exception: they are findable by pure counting. This
census exists because `LupyIslandChatView` was declared twice — the real
interactive chat (Sources/Lupy) and a read-only transcript renderer
(Sources/Lupy/UI/LupyIslandSurfaces.swift, since renamed
LupyIslandTranscriptView) — and kit 3.3's first field compile was the first
compiler ever to see both. One module, one name, one declaration.

Exit 0 + "COUNCIL, DECLARATIONS: SATISFIED (N types)" when unique.
"""
import os
import re
import sys

ROOT = "Mac/Sources"
DECL = re.compile(
    r"^(?:@[\w.()]+\s+)*(?:public\s+|private\s+|internal\s+|fileprivate\s+)?"
    r"(?:final\s+)?(struct|class|enum|actor|protocol)\s+(\w+)")


def main():
    decls = {}
    for dp, _dirs, files in os.walk(ROOT):
        for fname in sorted(files):
            if not fname.endswith(".swift"):
                continue
            path = os.path.join(dp, fname)
            for i, ln in enumerate(open(path, encoding="utf-8").read().splitlines()):
                m = DECL.match(ln)
                if m:
                    decls.setdefault(m.group(2), []).append(f"{path}:{i + 1}")
    dupes = {n: w for n, w in sorted(decls.items()) if len(w) > 1}
    for name, where in dupes.items():
        print(f"DUPLICATE {name}:")
        for w in where:
            print(f"    {w}")
    if dupes:
        print(f"COUNCIL, DECLARATIONS: FAILED — {len(dupes)} type(s) declared more than once")
        return 1
    print(f"COUNCIL, DECLARATIONS: SATISFIED ({len(decls)} top-level types, all unique)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
