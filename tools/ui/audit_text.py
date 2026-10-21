#!/usr/bin/env python3
"""Council 6g — TEXT: dynamic text must be bounded, or it bleeds.

Born from the founder's red pen (2026-10-22): labels sliced by pill corners,
names sliding under icons, a source label squeezed into a dangling "/".
Every one of those was a `Text` carrying live data with no stated bound.

Bleeding is a disease of FIXED-GEOMETRY surfaces (the island's fixed
heights, chips, pills, headline rows) — inside a scrolling window page,
wrapping is correct behaviour. So THE LAW gates the fixed-geometry
surfaces: a `Text` whose content is dynamic — string interpolation or a
variable — must declare its bound within the next 6 lines: `lineLimit(`,
`truncationMode(` or `fixedSize(`. Everything else (window pages, Louis Raillé
island files) is censused report-only and burned down per surface with
photographs. Exempt: text inside a ScrollView span, menu/picker items
(the system truncates those), and the chat bubble family (scroll
children by design — their wrapping IS the bound).

Exit 1 on any gate violation. House output format: COUNCIL, TEXT: ...
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")

GATE_FILES = [
    "Mac/Sources/Lupy/LupyIslandChatView.swift",
    "Mac/Sources/Lupy/Character/LupyLabelBubble.swift",
]
GATE_DIRS = ["Mac/Sources/Lupy/UI"]
REPORT_FILES = [
    "Mac/Sources/App/IslandViewContent.swift",
    "Mac/Sources/App/IslandRootView.swift",
]
REPORT_DIRS = ["Mac/Sources/Lupy"]
EXEMPT_STRUCTS = ("LupyChatBubble", "LupyChatPlanCard", "LupyChatApprovalRow",
                  "LupySnapshotHarness", "LupyProbeField")
BOUND_TOKENS = ("lineLimit(", "truncationMode(", "fixedSize(")
TEXT_RE = re.compile(r"(?<![A-Za-z])Text\(")


def brace_spans(lines, start_idx):
    """From the line of a keyword, find its { ... } span (line range)."""
    depth = 0
    began = False
    for i in range(start_idx, len(lines)):
        for ch in lines[i]:
            if ch == "{":
                depth += 1
                began = True
            elif ch == "}":
                depth -= 1
                if began and depth == 0:
                    return (start_idx, i)
        if began and depth == 0:
            return (start_idx, i)
    return (start_idx, len(lines) - 1)


def exempt_spans(lines):
    spans = []
    for i, ln in enumerate(lines):
        if "ScrollView(" in ln or "ScrollView {" in ln or ln.strip().startswith("ScrollView"):
            if "ScrollView" in ln:
                spans.append(brace_spans(lines, i))
        for name in EXEMPT_STRUCTS:
            if re.search(r"\bstruct\s+" + name + r"\b", ln) or \
               re.search(r"\benum\s+" + name + r"\b", ln):
                spans.append(brace_spans(lines, i))
    return spans


def in_spans(spans, idx):
    return any(a <= idx <= b for a, b in spans)


def capture_arg(lines, idx, col):
    """Rough balanced-paren capture of the Text( argument."""
    text = "\n".join(lines[idx:idx + 4])
    start = text.find("(", col)
    if start < 0:
        return ""
    depth = 0
    for j in range(start, min(len(text), start + 600)):
        if text[j] == "(":
            depth += 1
        elif text[j] == ")":
            depth -= 1
            if depth == 0:
                return text[start + 1:j]
    return text[start + 1:start + 600]


def is_dynamic(arg):
    a = arg.strip()
    if "\\(" in a:
        return True
    if a.startswith('"'):
        return False                      # plain literal — the compiler-sized kind
    if a.startswith("verbatim:"):
        rest = a[len("verbatim:"):].strip()
        return not (rest.startswith('"') and "\\(" not in rest)
    return True                           # identifier / expression


def audit_file(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    spans = exempt_spans(lines)
    violations = []
    checked = 0
    for i, ln in enumerate(lines):
        for m in TEXT_RE.finditer(ln):
            if in_spans(spans, i):
                continue
            arg = capture_arg(lines, i, m.start())
            if not is_dynamic(arg):
                continue
            checked += 1
            window = "\n".join(lines[i:i + 7])
            if ".tag(" in "\n".join(lines[i:i + 3]):
                continue          # menu/picker item — the system bounds it
            if not any(tok in window for tok in BOUND_TOKENS):
                violations.append((i + 1, ln.strip()[:90]))
    return checked, violations


def main():
    gate_files = [os.path.join(ROOT, f) for f in GATE_FILES]
    for d in GATE_DIRS:
        for base, _dirs, files in os.walk(os.path.join(ROOT, d)):
            for f in sorted(files):
                if f.endswith(".swift"):
                    gate_files.append(os.path.join(base, f))
    gate_set = {os.path.normpath(p) for p in gate_files}

    gate_bad = 0
    gate_checked = 0
    for path in gate_files:
        checked, violations = audit_file(path)
        gate_checked += checked
        for line, snip in violations:
            gate_bad += 1
            print(f"VIOLATION {os.path.relpath(path, ROOT)}:{line}: {snip}")

    report_checked = 0
    report_bad = 0
    report_paths = [os.path.join(ROOT, f) for f in REPORT_FILES]
    for d in REPORT_DIRS:
        for base, _dirs, files in os.walk(os.path.join(ROOT, d)):
            for f in sorted(files):
                if f.endswith(".swift"):
                    pth = os.path.join(base, f)
                    if os.path.normpath(pth) not in gate_set:
                        report_paths.append(pth)
    for pth in report_paths:
        checked, violations = audit_file(pth)
        report_checked += checked
        report_bad += len(violations)

    print(f"TEXT census: {gate_checked} dynamic texts gated ({gate_bad} violations); "
          f"legacy island files: {report_checked} checked, {report_bad} unbounded (report-only)")
    if gate_bad:
        print(f"COUNCIL, TEXT: {gate_bad} FAILURES")
        return 1
    print(f"COUNCIL, TEXT: SATISFIED ({gate_checked} dynamic texts, all bounded)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
