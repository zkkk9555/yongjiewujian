#!/bin/bash
# test_whole_battle_gates.sh -- lock the 864 gates (G-1, G-2) and the
# whole-battle policy they enforce.
#
# WHY
# ---
# Task 864 was rejected six times in a row because one rule was missing from the
# workflow: a battle must be kept whole.  Looting a corpse, drinking a potion,
# disengaging and re-engaging, picking a talent card -- all of it is the fight.
# Punching those out, or splitting one fight into two episodes, is what made the
# cut feel chopped.  The user said it plainly:
#
#   「我不想中间有断断档的时间，因为一断之后，战斗就不连贯了，观看体验就会很差。」
#
# Two gates encode it:
#   G-1  no excluded_inside hole inside (engage_start, outcome_time)
#   G-2  adjacent episodes must not share a boundary second
#
# G-1 judges hole POSITION, not hole existence: cleaning the post-outcome map
# screen is legitimate and 864's accepted v6 carries three such holes.
#
# Usage:  bash scripts/test_whole_battle_gates.sh
set -uo pipefail

PS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$PS_DIR/.." && pwd)"
GATE="$ROOT/skills/naraka-highlight-studio/scripts/qa_gate.py"
EX="$ROOT/docs/lessons/examples"
PY="$ROOT/.video-tools/venv/Scripts/python.exe"
[ -x "$PY" ] || PY="$(command -v python3 || command -v python || true)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILED=0

run_gate() {  # run_gate <timeline.json> <out.json> ; echoes nothing, sets RC
  "$PY" "$GATE" "$1" --output "$2" >/dev/null 2>&1
}

get_check() {  # get_check <out.json> <check-name> -> "RESULT measured"
  "$PY" -c "
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
for c in d['checks']:
    if c['name']==sys.argv[2]:
        print(c['result'], str(c['measured'])[:150]); break
else:
    print('MISSING','')
" "$1" "$2"
}

expect() {  # expect <label> <actual "RESULT measured"> <wanted-result>
  local label="$1" actual="$2" wanted="$3"
  local got; got="$(printf '%s' "$actual" | awk '{print $1}')"
  local detail; detail="$(printf '%s' "$actual" | cut -d' ' -f2-)"
  if [ "$got" = "$wanted" ]; then
    echo "  PASS  $label  [$got]"
  else
    echo "  FAIL  $label  wanted $wanted, got [$got]"
    FAILED=1
  fi
  [ -n "$detail" ] && echo "          $detail"
  return 0
}

mkfix() {  # mkfix <name> <json>
  printf '%s' "$2" > "$WORK/$1.json"
  echo "$WORK/$1.json"
}

echo "== 864 gates: 一整场完整战斗，中间不许断 =="

# --- F1. 864 v6, the version the user accepted, must pass both gates ----------
V6="$EX/864_v6_combat_episodes.json"
if [ -f "$V6" ]; then
  run_gate "$V6" "$WORK/v6.json"
  expect "864 v6 (用户认可的最终版)" "$(get_check "$WORK/v6.json" no_holes_in_battle)" PASS
  expect "864 v6 (用户认可的最终版)" "$(get_check "$WORK/v6.json" no_zero_gap_pseudo_cuts)" PASS
else
  echo "  FAIL  missing positive example $V6"
  FAILED=1
fi

# --- F2. the defect that got six versions rejected: a hole mid-battle ---------
T="$(mkfix hole_mid_battle '{"whole_battle_policy":"864","combat_episodes":[
 {"id":"c1","source_start":100,"source_end":300,"engage_start":120,"outcome_time":260,
  "excluded_inside":[{"start":180,"end":195,"reason":"选择强化面板"}]}]}')"
run_gate "$T" "$WORK/hole.json"
expect "战斗中挖洞（864 v1-v4 的病根）" "$(get_check "$WORK/hole.json" no_holes_in_battle)" FAIL

# --- F3. hole BEFORE engage / AFTER outcome is legal (864 v6 has three) --------
T="$(mkfix hole_legal '{"whole_battle_policy":"864","combat_episodes":[
 {"id":"c1","source_start":100,"source_end":400,"engage_start":150,"outcome_time":300,
  "excluded_inside":[{"start":105,"end":118,"reason":"前置跑图"},
                     {"start":310,"end":330,"reason":"结果后大地图"}]}]}')"
run_gate "$T" "$WORK/legal.json"
expect "洞在战斗窗口之外（合法）" "$(get_check "$WORK/legal.json" no_holes_in_battle)" PASS

# --- F4. 0-second gap: continuous on source but split in program (864 c005/c006)
T="$(mkfix zero_gap '{"whole_battle_policy":"864","combat_episodes":[
 {"id":"c005","source_start":495,"source_end":517.5,"engage_start":500,"outcome_time":515},
 {"id":"c006","source_start":517.5,"source_end":561.2,"engage_start":520,"outcome_time":555}]}')"
run_gate "$T" "$WORK/gap.json"
expect "零间隙假切口（视觉上会闪）" "$(get_check "$WORK/gap.json" no_zero_gap_pseudo_cuts)" FAIL

# --- F5. a real gap is fine; it does not mean "split is always wrong" ---------
T="$(mkfix real_gap '{"whole_battle_policy":"864","combat_episodes":[
 {"id":"c1","source_start":100,"source_end":200,"engage_start":110,"outcome_time":190},
 {"id":"c2","source_start":244,"source_end":400,"engage_start":250,"outcome_time":390}]}')"
run_gate "$T" "$WORK/realgap.json"
expect "有真实间隙的两场（不误报）" "$(get_check "$WORK/realgap.json" no_zero_gap_pseudo_cuts)" PASS

# --- F6. legacy timelines: WARN, never FAIL -----------------------------------
# 849/860/863 carry 16/19/2 in-battle holes and are already delivered.  863's
# source MP4 has been deleted, so "re-cut it" is not an available instruction.
# They must be reported, never failed.
T="$(mkfix legacy '{"combat_episodes":[
 {"id":"c1","source_start":100,"source_end":300,"engage_start":120,"outcome_time":260,
  "excluded_inside":[{"start":180,"end":195}]}]}')"
run_gate "$T" "$WORK/legacy.json"
expect "历史时间线（已交付，不冤枉）" "$(get_check "$WORK/legacy.json" no_holes_in_battle)" WARN

# --- F7. missing engage_start/outcome_time is reported, not silently passed ----
T="$(mkfix nowindow '{"combat_episodes":[
 {"id":"c1","source_start":100,"source_end":300,"excluded_inside":[{"start":180,"end":195}]}]}')"
run_gate "$T" "$WORK/nowin.json"
expect "缺 engage/outcome 须显式提示" "$(get_check "$WORK/nowin.json" no_holes_in_battle)" WARN

# --- F8. the gates must not break the geometry gate from v1.004 --------------
if [ -f "$V6" ]; then
  got="$(get_check "$WORK/v6.json" in_segment_holes | awk '{print $1}')"
  if [ "$got" = "PASS" ]; then
    echo "  PASS  v1.004 的几何门禁未受影响 [PASS]"
  else
    echo "  FAIL  v1.004 几何门禁回归 [$got]"
    FAILED=1
  fi
fi

echo ""
if [ "$FAILED" = 0 ]; then
  echo "RESULT: PASS -- 一整场完整战斗 的两条门禁都成立"
  exit 0
fi
echo "RESULT: FAIL"
exit 1
