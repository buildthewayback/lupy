#!/usr/bin/env python3
"""One-time port of the previous Lupy window's screens (App/Sources/*.swift, git 09c8c75) into
Lupy pages inside Coucou's window (Mac/Sources/Lupy/). Keeps every screen's logic and engine call;
renames types with a Lupy prefix (Coucou's module shares the namespace), routes navigation through
Coucou's window pages, and uses LupyStyle (Coucou's hub colours and components) for the look.
Hand edits after the port are marked "Lupy (port):" in the output files."""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OLD = ROOT / "App" / "Sources"
OUT = ROOT / "Mac" / "Sources" / "Lupy"

TYPES = ["RankedTaskRow", "PlanReviewCard", "AttentionRow", "CaptureBar", "TodayView",
         "ProjectsView", "ProjectDetail", "TaskDetailView", "TasksView", "RankedItem", "TaskRow",
         "HandoffsView", "HandoffPanel", "ApprovalsView", "ApprovalCard",
         "MemoryView", "ActivityView", "UsageView",
         "SettingsCard", "AutonomySettings", "ProvidersSettings", "ProviderRow", "ModelRow",
         "BudgetSettings", "GitHubSettings", "ConnectorsSettings", "WorkersSettings",
         "PrivacySettings", "BackupSettings", "DiagnosticsSettings", "AboutSettings",
         "SettingsView", "CardBackground", "StatusChip", "SectionTitle", "EmptyHint"]
RENAME = {t: "Lupy" + t for t in TYPES}
RENAME.update({"TodayView": "LupyTodayContent", "ProjectsView": "LupyProjectsContent", "TasksView": "LupyTasksContent",
               "HandoffsView": "LupyHandoffsContent", "ApprovalsView": "LupyApprovalsContent",
               "MemoryView": "LupyMemoryContent", "ActivityView": "LupyActivityContent", "UsageView": "LupyUsageContent",
               "SettingsView": "LupyAssistantSettings"})
SECTIONS = {"today": "lupyToday", "tasks": "lupyTasks", "handoffs": "lupyHandoffs", "approvals": "lupyNeedsYou",
            "projects": "lupyProjects", "memory": "lupyMemory", "usage": "lupyUsage", "settings": "lupyAssistant",
            "activity": "lupyActivity"}

def convert(src: str) -> str:
    s = re.sub(r"@Environment\(AppModel\.self\) private var (\w+)", r"private var \1: LupyModel { LupyModel.shared }", src)
    for old in sorted(RENAME, key=len, reverse=True):
        s = re.sub(r"\b%s\b" % old, RENAME[old], s)
    s = re.sub(r"\bSystemClock\(\)", "LupySystemClock()", s)
    s = re.sub(r"(?<![A-Za-z])relativeTime\(", "lupyRelativeTime(", s)
    s = re.sub(r"(?<![A-Za-z])shortDate\(", "lupyShortDate(", s)
    s = re.sub(r"(\w+)\.section = \.(\w+)", lambda m: "%s.open(.%s)" % (m.group(1), SECTIONS[m.group(2)]), s)
    s = s.replace("import SwiftUI", "import LupyCore\nimport SwiftUI", 1)
    return s

def cut(text: str, start_marker: str, end_marker: str | None) -> str:
    a = text.index(start_marker)
    b = text.index(end_marker, a) if end_marker else len(text)
    return text[a:b]

header = "// Ported from the previous Lupy window (App/Sources/{0}, git 09c8c75) by scripts/port-lupy-views.py.\n// Coucou's hub colours and components via LupyStyle.swift; logic and engine calls unchanged.\n\n"

work = convert((OLD / "WorkViews.swift").read_text())
work = work.split("\n", 1)[1]
(OUT / "LupyPagesWork.swift").write_text(header.format("WorkViews.swift") + work.lstrip())

more = convert((OLD / "MoreViews.swift").read_text()).split("\n", 1)[1]
(OUT / "LupyPagesMore.swift").write_text(header.format("MoreViews.swift") + more.lstrip())

settings_src = (OLD / "SettingsViews.swift").read_text()
settings_src = settings_src[:settings_src.index("// MARK: - Onboarding")].rstrip() + "\n"
settings = convert(settings_src).split("\n", 1)[1]
(OUT / "LupyPagesSettings.swift").write_text(header.format("SettingsViews.swift") + settings.lstrip())

main_src = (OLD / "MainWindow.swift").read_text()
today = "import SwiftUI\n\n" + cut(main_src, "struct TodayView: View {", None)
today = convert(today)
(OUT / "LupyPagesToday.swift").write_text(header.format("MainWindow.swift") + today)
print("ported:", ", ".join(p.name for p in sorted(OUT.glob("LupyPages*.swift"))))
