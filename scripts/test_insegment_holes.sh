#!/bin/bash
# test_insegment_holes.sh -- assert the two implementations of the in-segment
# hole rule agree, and that malformed holes are rejected.
#
# WHY THIS TEST EXISTS
# --------------------
# The program-duration formula
#
#     program_seconds = sum((source_end - source_start) - sum(hole.end - hole.start))
#
# is implemented twice on purpose: once in Python
# (skills/naraka-highlight-studio/scripts/episode_geometry.py) for the QA gate
# and the timeline validator, and once in PowerShell
# (scripts/read_episode_bounds.ps1) because the 4K master path is deliberately
# Python-free.  Two copies of one rule drift apart the moment someone edits one
# of them, and when they drift the symptom is a 4K master that fails
# verify_master.sh's duration check for no visible reason.
#
# So: both sides are fed the same fixtures and their cut lists are diffed byte
# for byte.  A rule change that only lands on one side fails here.
#
# Usage:  bash scripts/test_insegment_holes.sh
# Exit 0 = all cases agree.  Exit 1 = divergence or a rejected-invalid-hole miss.
set -uo pipefail

PS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$PS_DIR/.." && pwd)"
GATE_DIR="$ROOT/skills/naraka-highlight-studio/scripts"
PY="$ROOT/.video-tools/venv/Scripts/python.exe"
[ -x "$PY" ] || PY="$(command -v python || command -v python3 || true)"
if [ -z "$PY" ]; then
  echo "[SKIP] no python interpreter found" >&2
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILED=0

emit_python() {
  "$PY" - "$1" "$GATE_DIR" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[2])
from episode_geometry import timeline_cut_segments, timeline_program_seconds, timeline_hole_problems

data = json.load(open(sys.argv[1], encoding="utf-8"))
eps = data.get("combat_episodes", data if isinstance(data, list) else [])
problems = timeline_hole_problems(eps)
if problems:
    print("HOLE_REJECT " + problems[0])
    raise SystemExit(0)
segs = timeline_cut_segments(eps)
print(f"NEPISODES={len(eps)}")
print(f"N={len(segs)}")
for s, e in segs:
    print(f"S={s} E={e}")
print(f"PROGRAM={round(timeline_program_seconds(eps), 3)}")
PYEOF
}

emit_powershell() {
  powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "$(cygpath -m "$PS_DIR/read_episode_bounds.ps1")" "$(cygpath -w "$1")" 2>&1 | tr -d '\r'
}

check_case() {
  local name="$1" expect_reject="$2" json="$3"
  local f="$WORK/$name.json"
  printf '%s' "$json" > "$f"

  local py_out ps_out
  py_out="$(emit_python "$f" 2>&1)"
  ps_out="$(emit_powershell "$f" 2>&1)"

  if [ "$expect_reject" = "reject" ]; then
    local py_rej=0 ps_rej=0
    printf '%s' "$py_out" | grep -q 'HOLE_REJECT\|\[FAIL\]' && py_rej=1
    printf '%s' "$ps_out" | grep -q '\[FAIL\]' && ps_rej=1
    if [ "$py_rej" = 1 ] && [ "$ps_rej" = 1 ]; then
      echo "  PASS  $name (both sides reject the malformed hole)"
    else
      echo "  FAIL  $name  python_rejected=$py_rej powershell_rejected=$ps_rej"
      FAILED=1
    fi
    return
  fi

  # Both sides must succeed and emit byte-identical cut lists.
  if printf '%s' "$py_out" | grep -q 'HOLE_REJECT'; then
    echo "  FAIL  $name  python rejected a VALID timeline:"
    printf '%s\n' "$py_out" | sed 's/^/          /'
    FAILED=1
    return
  fi
  if printf '%s' "$ps_out" | grep -q '\[FAIL\]'; then
    echo "  FAIL  $name  powershell rejected a VALID timeline:"
    printf '%s\n' "$ps_out" | sed 's/^/          /'
    FAILED=1
    return
  fi

  # Compare the header NUMERICALLY.  PowerShell's [math]::Round prints 25 where
  # Python prints 25.0; the invariant is the value, not its spelling.
  num_eq() { awk -v a="$1" -v b="$2" 'BEGIN{d=a-b; if(d<0)d=-d; print (d<0.001)?"ok":"BAD"}'; }
  for key in NEPISODES N PROGRAM; do
    py_v="$(printf '%s\n' "$py_out" | sed -n "s/^$key=//p" | head -1)"
    ps_v="$(printf '%s\n' "$ps_out" | sed -n "s/^$key=//p" | head -1)"
    if [ "$(num_eq "$py_v" "$ps_v")" != "ok" ]; then
      echo "  FAIL  $name  $key mismatch: python=$py_v powershell=$ps_v"
      FAILED=1
      return
    fi
  done

  if [ "$(printf '%s\n' "$py_out" | grep -c '^S=')" != \
       "$(printf '%s\n' "$ps_out" | grep -c '^S=')" ]; then
    echo "  FAIL  $name  segment count mismatch"
    FAILED=1
    return
  fi

  local i=1
  while IFS= read -r py_line; do
    local ps_line
    ps_line="$(printf '%s\n' "$ps_out" | grep '^S=' | sed -n "${i}p")"
    local py_s py_e ps_s ps_e
    py_s="$(printf '%s' "$py_line" | sed 's/^S=\([^ ]*\) .*/\1/')"
    py_e="$(printf '%s' "$py_line" | sed 's/.*E=//')"
    ps_s="$(printf '%s' "$ps_line" | sed 's/^S=\([^ ]*\) .*/\1/')"
    ps_e="$(printf '%s' "$ps_line" | sed 's/.*E=//')"
    if [ "$(num_eq "$py_s" "$ps_s")" != "ok" ] || [ "$(num_eq "$py_e" "$ps_e")" != "ok" ]; then
      echo "  FAIL  $name  segment $i differs: python [$py_s,$py_e] vs powershell [$ps_s,$ps_e]"
      FAILED=1
      return
    fi
    i=$((i+1))
  done <<< "$(printf '%s\n' "$py_out" | grep '^S=')"

  echo "  PASS  $name  ($(printf '%s\n' "$py_out" | grep '^S=' | wc -l) segments, PROGRAM=$(printf '%s\n' "$py_out" | sed -n 's/^PROGRAM=//p'))"
}

echo "== in-segment hole consistency: Python vs PowerShell =="

check_case no_holes accept '{"combat_episodes":[
  {"id":"a","source_start":10,"source_end":40},
  {"id":"b","source_start":60,"source_end":75.5}]}'

check_case one_middle_hole accept '{"combat_episodes":[
  {"id":"a","source_start":10,"source_end":40,"excluded_inside":[{"start":20,"end":25}]}]}'

check_case hole_flush_against_start accept '{"combat_episodes":[
  {"id":"a","source_start":10,"source_end":40,"excluded_inside":[{"start":10,"end":25}]}]}'

check_case hole_flush_against_end accept '{"combat_episodes":[
  {"id":"a","source_start":10,"source_end":40,"excluded_inside":[{"start":30,"end":40}]}]}'

check_case two_holes accept '{"combat_episodes":[
  {"id":"a","source_start":0,"source_end":100,"excluded_inside":[{"start":10,"end":20},{"start":50,"end":55.5}]}]}'

check_case overlapping_holes_merged accept '{"combat_episodes":[
  {"id":"a","source_start":0,"source_end":100,"excluded_inside":[{"start":20,"end":40},{"start":30,"end":50}]}]}'

check_case adjacent_holes_merged accept '{"combat_episodes":[
  {"id":"a","source_start":0,"source_end":100,"excluded_inside":[{"start":20,"end":40},{"start":40,"end":50}]}]}'

check_case unsorted_holes accept '{"combat_episodes":[
  {"id":"a","source_start":0,"source_end":100,"excluded_inside":[{"start":70,"end":80},{"start":10,"end":20}]}]}'

# The real-world shape: 861 v4, which is the incident this whole rule exists for.
check_case task861_v4_shape accept '{"combat_episodes":[
  {"id":"combat_004","source_start":876,"source_end":999,"excluded_inside":[
    {"start":920,"end":931},{"start":961.2,"end":962.7},{"start":964.8,"end":965.4}]},
  {"id":"combat_013","source_start":2269,"source_end":2346.4,"excluded_inside":[
    {"start":2322.2,"end":2338}]}]}'

echo "-- malformed holes must be rejected by both sides --"

check_case hole_out_of_bounds reject '{"combat_episodes":[
  {"id":"a","source_start":10,"source_end":40,"excluded_inside":[{"start":5,"end":25}]}]}'

check_case hole_past_end reject '{"combat_episodes":[
  {"id":"a","source_start":10,"source_end":40,"excluded_inside":[{"start":20,"end":45}]}]}'

check_case hole_negative_length reject '{"combat_episodes":[
  {"id":"a","source_start":10,"source_end":40,"excluded_inside":[{"start":25,"end":20}]}]}'

check_case hole_eats_whole_episode reject '{"combat_episodes":[
  {"id":"a","source_start":10,"source_end":40,"excluded_inside":[{"start":10,"end":40}]}]}'

if [ "$FAILED" = 0 ]; then
  echo "RESULT: PASS -- both implementations agree on every case"
  exit 0
fi
echo "RESULT: FAIL -- the two implementations disagree, or a malformed hole slipped through"
exit 1
