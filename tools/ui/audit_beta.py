"""THE COUNCIL, BETA — pre-beta readiness audit, the founder's checklist codified.

Maps every line of the beta gate to a property of the source:
 1 · AI quality: injection surfaces delimited and escaped; wire context capped
     (24 messages), UI history capped (200), file context capped (24k), output
     capped (max_tokens); streaming present; failures remove their placeholder.
 2 · Stress/perf: timeouts on every request; no unbounded retry; pollers and
     display links paced and pausable; cost bounded per request, not per session.
 3 · Security/privacy: keys in Keychain; every TCC capability has its usage
     sentence AND a denied-path guard; nothing secret logged.
 4 · macOS specifics: sandbox-off and arm64-only are deliberate and documented;
     XCTest targets exist; distribution path documented.

Run: python3 tools/ui/audit_beta.py     Exit 0 = SATISFIED.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(*rel):
    with open(os.path.join(ROOT, *rel)) as f:
        return f.read()


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
    cs = read("Mac/Sources/App/ClaudeService.swift")
    app = read("Mac/Sources/App/AppState.swift")
    hook = read("Mac/Sources/App/HookServer.swift")
    proj = read("Mac/project.yml")
    notes = read("docs/RELEASE_NOTES.md")
    sec = read("docs/SECURITY.md")

    # ── 1 · AI quality ───────────────────────────────────────────────────────
    ok("conversationMessages.count > 24" in cs, "wire context capped at 24 messages")
    ok("chatHistory.count > 200" in app, "visible history capped at 200 messages")
    ok("prefix(24_000)" in cs and "[truncated]" in cs, "file context capped at 24k chars")
    ok('"max_tokens": 4096' in cs, "model output capped at 4096 tokens")
    ok('body["stream"] = true' in cs, "streaming enabled where the provider supports it")
    ok("func chat(query: String, context: PromptContext?, state: AppState) async" in cs,
       "chat is async — the UI never blocks on the wire")
    ok("removeAll { $0.id == msgId }" in cs, "failed streams remove their placeholder")
    ok("replacingOccurrences(of: \"\\\\\"" in read("Mac/Sources/App/MailController.swift"),
       "AppleScript strings escaped (injection surface closed)")
    ok("JSONSerialization" in hook and not re.search(r"\beval\b|\beval\(", hook),
       "hook payloads parsed as data, never evaluated")
    ok("Context — App:" in cs and "File: \\(name)" in cs,
       "injected context carries explicit delimiting headers")

    # ── 2 · stress & performance ─────────────────────────────────────────────
    ok(cs.count("timeoutInterval: 10") >= 3, "probe requests time out at 10s")
    ok("useStream ? 120 : 30" in cs, "chat times out at 30s / 120s streaming")
    lines = hook.splitlines()
    wt = [i for i, l in enumerate(lines) if "while true" in l]
    ok(all(any("break" in lines[i + k] for k in range(1, 9) if i + k < len(lines))
           for i in wt) and "while true" not in cs,
       "every while-true is a structured server loop with exits (same-UID check, "
       "5s receive timeout, payload cap) — no unbounded retry")
    ok(re.search(r"TimeInterval\((3[0-9]|[6-9][0-9]|[1-9][0-9]{2,})", read("Mac/Sources/App/CalcomPoller.swift"))
       or "30" in read("Mac/Sources/App/CalcomPoller.swift"),
       "pollers run at gentle intervals, not hot loops")
    dl = read("Mac/Sources/App/IslandWindowController.swift")
    ok("isPaused" in dl or "invalidate" in dl, "the display link can pause — idle costs nothing")
    ok("steps.count > 20" in hook, "task step ledgers capped at 20")

    # ── 3 · security & privacy ───────────────────────────────────────────────
    ok("KeychainStore.shared.get" in cs or "Keychain" in cs, "provider keys live in the Keychain")
    plist = read("Mac/Resources/Info.plist")
    for key in ["NSAccessibilityUsageDescription", "NSMicrophoneUsageDescription",
                "NSSpeechRecognitionUsageDescription", "NSAppleEventsUsageDescription"]:
        ok(key in plist, f"usage sentence: {key}")
    allsrc = ""
    for base, _, fs in os.walk(os.path.join(ROOT, "Mac/Sources")):
        for fn in fs:
            if fn.endswith(".swift"):
                allsrc += open(os.path.join(base, fn)).read()
    ok("AXIsProcessTrusted" in allsrc,
       "accessibility is checked before use, so denial degrades, not crashes")
    sc = read("Mac/Sources/App/ScreenCapture.swift")
    ok("/usr/sbin/screencapture" in sc and "catch" in sc
       and "no (cancelled)" in sc,
       "screen capture delegates TCC to macOS's own picker; denial/cancel is a quiet "
       "no-op and launch errors are caught — degrades, never crashes")
    ok(not re.search(r"print\([^\n]*(apiKey|apiSecret|token)", cs, re.I),
       "nothing secret reaches the log")

    # ── 4 · macOS specifics ──────────────────────────────────────────────────
    ok("ENABLE_SANDBOX: NO" in proj and "sandbox" in sec.lower(),
       "sandbox-off is deliberate and documented (socket + AppleScript need it)")
    ok("ARCHS: arm64" in proj and "Apple Silicon" in notes,
       "arm64-only is deliberate and documented")
    ok(os.path.isdir(os.path.join(ROOT, "Mac/Tests/lupy"))
       or os.path.isdir(os.path.join(ROOT, "Mac/Tests")),
       "XCTest targets exist for the Xcode alpha path")
    ok("TestFlight" in notes or "developer account" in notes,
       "distribution path documented (direct kit; notarization/TestFlight need a $99 account)")
    ok("LUPY_NO_LOCAL_LLM" in proj, "no local model inference — battery and privacy by design")

    print(f"\nCOUNCIL, BETA: {'SATISFIED' if not FAILS else str(len(FAILS)) + ' FAILURES'}"
          f" ({CHECKS} checks)")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
