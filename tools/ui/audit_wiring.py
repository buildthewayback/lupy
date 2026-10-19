"""THE COUNCIL, WIRING — static cross-reference audit of the LUPY 3 Swift layer.

The picture councils measure pixels; this one measures references: every kernel
member, palette colour, type size, need case, character state, AppState publisher,
backend method and model field that the new UI files touch must EXIST where the
new files say it lives. A typo here is a compile error on the founder's Mac, and
he should never be the one to find it.

Run: python3 tools/ui/audit_wiring.py     Exit 0 = every reference resolves.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

NEW_UI = [
    "Mac/Sources/Lupy/UI/LupyIslandApprovalView.swift",
    "Mac/Sources/Lupy/UI/LupyIslandSurfaces.swift",
    "Mac/Sources/Lupy/UI/LupyIslandShell.swift",
    "Mac/Sources/Lupy/UI/LupyIslandDirector.swift",
    "Mac/Sources/Lupy/UI/LupyIslandCanvas.swift",
]

# symbol -> (file that must define it, pattern proving the definition)
DEFS = {
    # kernel metrics
    "padEdge": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let padEdge"),
    "padInner": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let padInner"),
    "rowHeight": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let rowHeight"),
    "chipHeight": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let chipHeight"),
    "chipPadH": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let chipPadH"),
    "chipIconGap": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let chipIconGap"),
    "chipCorner": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let chipCorner"),
    "fieldCorner": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let fieldCorner"),
    "composerHeight": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let composerHeight"),
    "headlineRow": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let headlineRow"),
    "softwareGap": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let softwareGap"),
    "canvas(": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static func canvas"),
    # type + palette
    "LupyType.headline": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let headline"),
    "LupyType.body": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let body"),
    "LupyType.chip": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let chip"),
    "LupyType.provenance": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let provenance"),
    "LupyType.font": ("Mac/Sources/Lupy/UI/LupyIslandCanvas.swift", r"static func font"),
    "palette.textPrimary": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let textPrimary"),
    "palette.textBody": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let textBody"),
    "palette.iconography": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let iconography"),
    "palette.decoration": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let decoration"),
    "palette.accent": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static var accent"),
    "palette.ink": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let ink"),
    "palette.paper": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"static let paper"),
    # needs + character states the director and surfaces switch on
    "need.decision": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"case decision"),
    "need.task": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"case task"),
    "need.chat": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"case chat"),
    "need.answer": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"case answer"),
    "need.whisper": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"case whisper"),
    "need.rest": ("Mac/Sources/Lupy/UI/LupyIslandDesign.swift", r"case rest"),
    "state.approval": ("Mac/Sources/Lupy/Character/LupyCharacterMath.swift", r"enum LupyCharacterState"),
    "state.question": ("Mac/Sources/Lupy/Character/LupyCharacterMath.swift", r"enum LupyCharacterState"),
    "state.error": ("Mac/Sources/Lupy/Character/LupyCharacterMath.swift", r"enum LupyCharacterState"),
    "state.finished": ("Mac/Sources/Lupy/Character/LupyCharacterMath.swift", r"enum LupyCharacterState"),
    "state.working": ("Mac/Sources/Lupy/Character/LupyCharacterMath.swift", r"enum LupyCharacterState"),
    "state.thinking": ("Mac/Sources/Lupy/Character/LupyCharacterMath.swift", r"enum LupyCharacterState"),
    "state.idle": ("Mac/Sources/Lupy/Character/LupyCharacterMath.swift", r"enum LupyCharacterState"),
    # backend seams the director lives on
    "AppState.shared": ("Mac/Sources/App/AppState.swift", r"static let shared"),
    "state.pendingApproval": ("Mac/Sources/App/AppState.swift", r"@Published var pendingApproval"),
    "state.pendingQuestion": ("Mac/Sources/App/AppState.swift", r"@Published var pendingQuestion"),
    "state.tasks": ("Mac/Sources/App/AppState.swift", r"@Published var tasks"),
    "state.chatHistory": ("Mac/Sources/App/AppState.swift", r"@Published var chatHistory"),
    "state.view": ("Mac/Sources/App/AppState.swift", r"@Published var view"),
    "hooks.sendApprovalDecision": ("Mac/Sources/App/HookServer.swift", r"func sendApprovalDecision"),
    "hooks.sendQuestionAnswers": ("Mac/Sources/App/HookServer.swift", r"func sendQuestionAnswers"),
    "HookServer.shared": ("Mac/Sources/App/HookServer.swift", r"static let shared"),
    # model fields read by the director
    "ApprovalInfo.queueCount": ("Mac/Sources/CoucouKit/IslandTypes.swift", r"var queueCount"),
    "ApprovalInfo.command": ("Mac/Sources/CoucouKit/IslandTypes.swift", r"var command"),
    "ApprovalInfo.tool": ("Mac/Sources/CoucouKit/IslandTypes.swift", r"var tool"),
    "ApprovalInfo.sessionId": ("Mac/Sources/CoucouKit/IslandTypes.swift", r"var sessionId"),
    "ApprovalInfo.projectName": ("Mac/Sources/CoucouKit/IslandTypes.swift", r"var projectName"),
    "AgentTask.steps": ("Mac/Sources/CoucouKit/IslandTypes.swift", r"var steps"),
    "AgentTask.stepIndex": ("Mac/Sources/CoucouKit/IslandTypes.swift", r"var stepIndex"),
    "AgentTask.finalLine": ("Mac/Sources/CoucouKit/IslandTypes.swift", r"var finalLine"),
    "AgentTask.sessionCwd": ("Mac/Sources/CoucouKit/IslandTypes.swift", r"var sessionCwd"),
    "AskQuestion.items": ("Mac/Sources/App/AskQuestion.swift", r"var items"),
    "AskQuestionItem.options": ("Mac/Sources/App/AskQuestion.swift", r"var options"),
    "AskQuestionItem.header": ("Mac/Sources/App/AskQuestion.swift", r"var header"),
    "AskQuestionItem.question": ("Mac/Sources/App/AskQuestion.swift", r"var question"),
    "ChatMessage.role": ("Mac/Sources/App/AppState.swift", r"let role"),
    "ChatMessage.content": ("Mac/Sources/App/AppState.swift", r"var content"),
    "ChatRole.user": ("Mac/Sources/App/AppState.swift", r"case user"),
    "chat.send": ("Mac/Sources/App/ClaudeService.swift", r"func chat\(query"),
    # shell + chrome the surfaces stand on
    "chrome": ("Mac/Sources/Lupy/UI/LupyIslandCanvas.swift", r"struct LupyCanvasChrome"),
    "morph": ("Mac/Sources/Lupy/UI/LupyIslandShell.swift", r"struct LupyIslandMorph"),
    "placement": ("Mac/Sources/Lupy/UI/LupyIslandShell.swift", r"static func forScreen"),
    "composerView": ("Mac/Sources/Lupy/UI/LupyIslandCanvas.swift", r"struct LupyComposer"),
    "statusLine": ("Mac/Sources/Lupy/UI/LupyIslandCanvas.swift", r"struct LupyStatusLine"),
    "characterView": ("Mac/Sources/Lupy/UI/LupyIslandCanvas.swift", r"LupyCanvasView"),
    "legacyFlag": ("Mac/Sources/App/AppDelegate.swift", r"lupy3LegacyIsland"),
    "directorLaunch": ("Mac/Sources/App/AppDelegate.swift", r"LupyIslandDirector\(\)"),
    "collapseNote": ("Mac/Sources/App/IslandWindowController.swift", r"static let islandCollapse"),
}

FAILS = []
CHECKS = 0


def ok(cond, label, detail=""):
    global CHECKS
    CHECKS += 1
    if cond:
        print(f"ok    {label}")
    else:
        print(f"FAIL  {label}  {detail}")
        FAILS.append(label)


def main():
    cache = {}

    def text(rel):
        if rel not in cache:
            with open(os.path.join(ROOT, rel)) as f:
                cache[rel] = f.read()
        return cache[rel]

    # 1 · every definition the new layer leans on exists, with its proof pattern
    for name, (rel, pat) in DEFS.items():
        ok(re.search(pat, text(rel)) is not None, f"defined: {name}",
           f"missing {pat} in {rel}")

    # 2 · every kernel member the new UI names is really used, and really defined
    ui = "\n".join(text(p) for p in NEW_UI)
    for member in sorted(set(re.findall(r"LupyIslandLayout\.(\w+)", ui))):
        ok(re.search(rf"static let {member}\b", text(DEFS["padEdge"][0])) is not None
           or re.search(rf"static func {member}\b", text(DEFS["padEdge"][0])) is not None,
           f"kernel member used by UI exists: {member}")

    for member in sorted(set(re.findall(r"LupyPalette\.(\w+)", ui))):
        ok(re.search(rf"static (let|var) {member}\b", text(DEFS["padEdge"][0])) is not None,
           f"palette colour used by UI exists: {member}")

    # 3 · the director only switches on states the character rig can actually be
    # cases come comma-listed ("case idle, working, …"): split, don't assume
    rig_states = set()
    for group in re.findall(r"case ([\w, ]+)",
                            text("Mac/Sources/Lupy/Character/LupyCharacterMath.swift")):
        rig_states |= {g.strip() for g in group.split(",") if g.strip()}
    for st in sorted(set(re.findall(r"character: \.(\w+)", ui)) |
                     set(re.findall(r"state: \.(\w+)", ui))):
        ok(st in rig_states, f"character state the UI asks for exists in the rig: {st}")

    # 4 · no new UI file reaches into the legacy view layer (the swap stays clean)
    for p in NEW_UI:
        bad = re.search(r"IslandViewContent|FlowPill|BotCanvasView", text(p))
        ok(bad is None, f"no legacy view dependency: {os.path.basename(p)}")

    # ---- 5 · WHOLE-BODY SEAMS: every cross-file reference in the app resolves ----
    import glob as _glob
    body = {}
    for f in _glob.glob(os.path.join(ROOT, "Mac/Sources/**/*.swift"), recursive=True):
        body[os.path.relpath(f, ROOT)] = open(f).read()
    allsrc = "\n".join(body.values())

    # 5a · #selector(foo) must have an @objc func foo somewhere in the same file
    for rel, txt in body.items():
        for sel in set(re.findall(r"#selector\((?:\w+\.)?(\w+)\)", txt)):
            ok(re.search(rf"@objc[^\n]*\n[^\n]*func {sel}\b|@objc func {sel}\b|func {sel}\(", txt) is not None,
               f"selector target exists: {rel} #{sel}")

    # 5b · notification names: every .forName(.x) / name: .x is a defined constant
    defined_names = set(re.findall(r"static let (\w+)\s*=\s*Notification\.Name", allsrc))
    defined_names |= set(re.findall(r"static let (\w+)\s*:\s*Notification\.Name", allsrc))
    system_ok = ("NSApplication", "NSWindow", "NSView", "NSText", "NSWorkspace",
                 "AVAudioSession", "AVAudioEngine", "UIScene", "NSStatusBar")
    for rel, txt in body.items():
        refs = set(re.findall(r"forName:\s*\.(\w+)", txt))
        # a bare `name: .x` only counts when the line is about a Notification
        for line in txt.splitlines():
            if "Notification" in line:
                refs |= set(re.findall(r"name:\s*\.(\w+)", line))
        for ref in refs:
            if ref in defined_names or ref.startswith(system_ok):
                continue
            ok(False, f"notification name resolves: {rel} .{ref}")
            break
        else:
            ok(True, f"notification names resolve: {os.path.basename(rel)}")

    # 5c · enum cases: qualified references match the enum's comma-listed cases
    enums = {}
    for en in ["IslandView", "BotState", "BotEmote", "LupyCharacterState", "LupyCanvasNeed"]:
        bodies = re.findall(rf"enum {en}[^{{]*{{(.*?)\n}}", allsrc, re.S)
        # extensions of the enum carry members too (static helpers, colours…)
        bodies += re.findall(rf"extension {en}\s*{{(.*?)\n}}", allsrc, re.S)
        if bodies:
            cases = {"allCases", "rawValue", "hashValue"}
            for b in bodies:
                for group in re.findall(r"case ([\w, ]+)", b):
                    cases |= {g.strip() for g in group.split(",") if g.strip()}
                # computed members count as members too
                cases |= set(re.findall(r"\b(?:var|func) (\w+)", b))
            enums[en] = cases
    for en, cases in enums.items():
        for ref in set(re.findall(rf"{en}\.(\w+)", allsrc)):
            ok(ref in cases, f"{en} case exists: .{ref}")

    # 5d · asset names: NSImage(named:/Image("x") live in an asset catalogue
    cats = set()
    for d in _glob.glob(os.path.join(ROOT, "Mac/**/Assets.xcassets/*.imageset"), recursive=True):
        cats.add(os.path.basename(d).replace(".imageset", ""))
    for rel, txt in body.items():
        for a in set(re.findall(r"NSImage\(named:\s*\"(\w[\"\w/]*)\"", txt)) | \
                   set(re.findall(r"(?<![\w])Image\(\"(\w[\"\w/]*)\"", txt)):
            ok(a in cats or "/" in a or a in ("", ), f"asset exists: {rel} '{a}'")

    # 5e · every state.$publisher the app observes is @Published on AppState
    appstate = body.get("Mac/Sources/App/AppState.swift", "")
    pub = set(re.findall(r"@Published var (\w+)", appstate))
    for rel, txt in body.items():
        for ref in set(re.findall(r"state\.\$(\w+)", txt)):
            ok(ref in pub, f"AppState publisher exists: {rel} ${ref}")

    print(f"\nCOUNCIL, WIRING: {'SATISFIED' if not FAILS else str(len(FAILS)) + ' FAILURES'}"
          f" ({CHECKS} checks)")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
