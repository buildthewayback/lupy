#!/usr/bin/env bash
# installer-harness.sh — sandbox rehearsal of the Install LUPY step machine.
#
# The founder asked for a setup that is "stress tested, install tested … perfect
# not partially". AppKit cannot run here, but the installer's BRAIN — the step
# machine between the two marker comments in Install-LUPY — is plain shell, so
# this harness extracts those exact lines verbatim and drives them with
# synthetic build logs: the happy path, the founder's real 3.2 freeze
# (replayed from his pasted log), a silent stall, a compile failure, weird
# milestones, and the field helpers. What the Setup window would show at each
# moment is asserted against the v3 status line. Wired into
# scripts/body-checks.sh as step 6c so the rehearsal runs with the gates.
#
# Exit 0 = every scenario behaved. Any FAIL prints expected vs actual.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INST="$ROOT/Install LUPY.app/Contents/MacOS/Install-LUPY"
FAILURES=0
CHECKS=0

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# what the installer script expects in its environment
KIT="$T/kit"; mkdir -p "$KIT/build-noxcode"
FACE_STATUS_FILE="$T/face.txt"
BUILD_STATUS_FILE="$T/build-status.txt"

# ── extract the machine, verbatim ─────────────────────────────────────────────
sed -n '/^# ── step machine/,/^# ── end step machine/p' "$INST" > "$T/machine.sh"
if ! grep -q 'refine_and_compose' "$T/machine.sh" || ! grep -q 'compose_face' "$T/machine.sh"; then
  echo "FAIL: could not extract the step machine from Install-LUPY (markers moved?)"
  exit 1
fi
# shellcheck disable=SC1091
. "$T/machine.sh"

face_line() { cat "$FACE_STATUS_FILE" 2>/dev/null; }
check() { # $1 what · $2 actual · $3 expected
  CHECKS=$((CHECKS + 1))
  if [ "$2" = "$3" ]; then
    echo "  ok   $1"
  else
    FAILURES=$((FAILURES + 1))
    echo "  FAIL $1"
    echo "       expected: $3"
    echo "       actual:   $2"
  fi
}
check_contains() { # $1 what · $2 haystack · $3 needle
  CHECKS=$((CHECKS + 1))
  case "$2" in
    *"$3"*) echo "  ok   $1" ;;
    *) FAILURES=$((FAILURES + 1))
       echo "  FAIL $1"
       echo "       expected to contain: $3"
       echo "       actual:              $2" ;;
  esac
}
reset_machine() {
  STEP_STATES="......"; OVERALL_PCT=0; STUCK_FLAG=""; LAST_DETAIL=""
  STEP_STARTED="0 0 0 0 0 0"; STEP_ENDED="0 0 0 0 0 0"
  LAST_LOG_SIZE=-1; LAST_LOG_GROWTH=0; BUILD_STARTED=0
  : > "$KIT/build-noxcode/build.log"
  : > "$BUILD_STATUS_FILE"
}

# ══════════════════════════════════════════════════════════════════════════════
echo "== 1. field helpers"
check "field_set middle" "$(field_set "10 20 30 40 50 60" 3 99)" "10 20 99 40 50 60"
check "field_set first"  "$(field_set "10 20 30" 1 7)" "7 20 30"
check "field_get"        "$(field_get "10 20 30" 2)" "20"
check "step_name 1"      "$(step_name 1)" "Check this Mac"
check "step_name 6"      "$(step_name 6)" "Launch & prove he's alive"

echo "== 2. step_set / step_state / active_step"
reset_machine
step_set 1 '>'
check "state after 1>"  "$STEP_STATES" ">....."
step_set 1 '+'; step_set 2 '>'
check "state after 1+/2>" "$STEP_STATES" "+>...."
check "step_state 2"    "$(step_state 2)" ">"
check "step_state 5"    "$(step_state 5)" "."
check "active_step"     "$(active_step)" "2"
step_set 2 '!'; step_set 6 '>'
check "active_step finds 6" "$(active_step)" "6"
check "states final"    "$STEP_STATES" "+!...>"
step_set 6 '-'
check "active_step none" "$(active_step)" "0"

echo "== 3. compose_face: shape + monotonic percent"
reset_machine
step_set 1 '>'; compose_face 2 "hello"
check "v3 line" "$(face_line)" "3|2|>.....||hello"
compose_face 40 "up"; compose_face 25 "down-ignored"
check "monotonic" "$(face_line)" "3|40|>.....||down-ignored"
compose_face "garbage" "bad pct is a no-op"
check "garbage pct" "$(face_line)" "3|40|>.....||bad pct is a no-op"
compose_face "" "empty pct too"
check "empty pct" "$(face_line)" "3|40|>.....||empty pct too"

echo "== 4. happy path through refine_and_compose"
reset_machine
step_set 1 '+'; step_set 2 '+'; step_set 3 '>'
BUILD_STARTED=$(date +%s)
printf '25|Compiling|building him\n' > "$BUILD_STATUS_FILE"
printf 'Fetching https://github.com/FluidInference/FluidAudio.git\n' > "$KIT/build-noxcode/build.log"
refine_and_compose
check_contains "fetch → step3 active, 12%" "$(face_line)" "3|12|++>..."
printf '[2723/87267919] Downloading https://github.com/x/NemoTextProcessing.xcframework.zip\n' >> "$KIT/build-noxcode/build.log"
refine_and_compose
check_contains "xcframework download stays step3, MB words" "$(face_line)" "++>..."
check_contains "download says MB" "$(face_line)" "of 83 MB"
printf '[412/980] Compiling Foo\n' >> "$KIT/build-noxcode/build.log"
refine_and_compose
check "412/980 → 43% step4" "$(face_line)" "3|43|+++>..||412 of 980 steps · Compiling Foo"
printf '[980/980] Build complete!\n' >> "$KIT/build-noxcode/build.log"
refine_and_compose
check_contains "980/980 → 68%" "$(face_line)" "3|68|+++>..|"
printf '70|Assembling|built; assembling him\n' > "$BUILD_STATUS_FILE"
refine_and_compose
check "milestone 70 → step5" "$(face_line)" "3|70|++++>.||built; assembling him"
printf '97|Installing|installing into Applications\n' > "$BUILD_STATUS_FILE"
refine_and_compose
check_contains "milestone 97 still step5" "$(face_line)" "3|97|++++>.|"
step_set 5 '+'; step_set 6 '>'; step_set 6 '+'; compose_face 100 "alive"
check "all green" "$(face_line)" "3|100|++++++||alive"

echo "== 5. the founder's 3.2 freeze, replayed (his real log lines)"
reset_machine
step_set 1 '+'; step_set 2 '+'; step_set 3 '>'
NOW=$(date +%s)
BUILD_STARTED=$((NOW - 2000))
LAST_LOG_GROWTH=$((NOW - 1995))
printf '25|Compiling|building him\n' > "$BUILD_STATUS_FILE"
cat > "$KIT/build-noxcode/build.log" <<'FIELDLOG'
Fetching https://github.com/FluidInference/FluidAudio.git
[1/47979] Fetching fluidaudio
FIELDLOG
refine_and_compose   # first sight of this log: size changes → growth = now
check_contains "fetch progress visible" "$(face_line)" "pieces"
LAST_LOG_GROWTH=$(( $(date +%s) - 300 ))   # now pretend 5 min of silence
refine_and_compose
check_contains "300s silence → STUCK" "$(face_line)" "|STUCK|"
check_contains "STUCK speaks plainly" "$(face_line)" "No movement for 5 min"
printf '[2000/47979] Fetching fluidaudio\n' >> "$KIT/build-noxcode/build.log"
refine_and_compose
check_contains "growth clears STUCK" "$(face_line)" "..||"

echo "== 6. hostile inputs never break the line"
reset_machine
step_set 3 '>'
printf 'garbage|||more\n' > "$BUILD_STATUS_FILE"
printf 'weird [a/b] lines\n[5/] broken\n[]\n' > "$KIT/build-noxcode/build.log"
refine_and_compose
check_contains "garbage milestone + log" "$(face_line)" "3|10|..>..."
printf '[0/0] Compiling Zero\n' >> "$KIT/build-noxcode/build.log"
refine_and_compose
check_contains "0/0 no div-by-zero" "$(face_line)" "3|25|..+>..|"
rm -f "$KIT/build-noxcode/build.log" "$BUILD_STATUS_FILE"
refine_and_compose
check_contains "missing files still compose, step3 stays done" "$(face_line)" "3|25|..+>..|"

echo "== 7. step timings recorded"
reset_machine
step_set 2 '>'
check "started stamped" "$([ "$(field_get "$STEP_STARTED" 2)" != "0" ] && echo yes || echo no)" "yes"
step_set 2 '+'
check "ended stamped"   "$([ "$(field_get "$STEP_ENDED" 2)" != "0" ] && echo yes || echo no)" "yes"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "INSTALLER REHEARSAL: SATISFIED ($CHECKS checks)"
  exit 0
fi
echo "INSTALLER REHEARSAL: $FAILURES of $CHECKS checks FAILED"
exit 1
