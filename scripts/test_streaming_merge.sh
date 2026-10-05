#!/usr/bin/env bash
# test_streaming_merge.sh -- island merge per roughcut-launch.md §2.8.
#
# The three clauses this pins, all taken from the rule rather than invented:
#
#   §2.3 / §2.8  partial NEVER becomes final; the subtitle / render / self-audit
#                 stages refuse anything carrying `-partial`
#   §2.8 island   island = a closed run of CONSECUTIVE recycled lanes; internal
#                 5-second overlap needs dual-sided independent evidence
#   §2.8 seams    a missing lane is recorded as SEAM-<lane>L/R; no conclusion is
#                 asserted across it
#
# And the one thing the module must NOT do: decide the overlap verdict.  §2.8
# gives that to a single arbiter with dual-sided evidence.  A test that accepted
# a script-made verdict would be pinning the exact failure this project keeps
# paying for.
set -uo pipefail
cd '/c/Project/永劫无间' || exit 1

PY='.video-tools/venv/Scripts/python.exe'
STATE='skills/naraka-highlight-studio/scripts/orchestrator_state.py'
MERGE='skills/naraka-highlight-studio/scripts/merge_partial.py'
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() {
    local name="$1" want="$2" got="$3"
    if [ "$want" = "$got" ]; then
        printf '  PASS  %-54s %s\n' "$name" "$got"; pass=$((pass + 1))
    else
        printf '  FAIL  %-54s\n              got  %s\n              want %s\n' "$name" "$got" "$want"
        fail=$((fail + 1))
    fi
}

# The evaluator lives in merge_probe.py, not in a heredoc.  Inlining it failed
# three ways in one session and each failure made a working module look broken:
# PowerShell parses `<<EOF` as a syntax error; an unquoted heredoc expands `$2`
# before the argument is bound; and under `2>/dev/null` a dead probe prints
# nothing, so every case compares empty strings.  A probe that fails must SAY so.
m() { "$PY" scripts/merge_probe.py "$MERGE" "$@" 2>&1; }
isl() { "$PY" scripts/merge_probe.py "$MERGE" islands "$1" 2>&1; }

# wave <recycled csv> <total>
wave() {
    "$PY" - "$STATE" "$TMP/w.json" "$1" "$2" <<'PYEOF'
import importlib.util, json, pathlib, sys
spec = importlib.util.spec_from_file_location("st", sys.argv[1])
st = importlib.util.module_from_spec(spec); spec.loader.exec_module(st)
rec = [int(x) for x in sys.argv[3].split(",") if x.strip()]
doc = st._blank(pathlib.Path("/tmp"), int(sys.argv[4]))
doc["source_path"] = "E:/OBS/demo.mp4"
doc["source_duration"] = 1000.0
for row in doc["lanes"]:
    if row["id"] in rec:
        row["status"] = "recycled"
        row["report_path"] = "reports/seg%d.md" % row["id"]
        # one candidate episode per lane, so the merge has something to carry
        row["episodes"] = [{"id": "e%02d" % row["id"], "source": "seg%d" % row["id"],
                            "source_start": row["id"] * 10.0,
                            "source_end": row["id"] * 10.0 + 8.0}]
    else:
        row["status"] = "in-flight"
        row["dispatched_at"] = 1.0
doc["lanes_recycled"] = len(rec)
doc["phase"] = "scan"
st.save(pathlib.Path(sys.argv[2]), doc)
PYEOF
}

echo "test_streaming_merge.sh -- island merge, PARTIAL only (§2.8)"

if [ ! -f "$MERGE" ]; then
    echo "  FAIL  merge_partial.py does not exist yet"
    echo "RESULT: FAIL"
    exit 1
fi

# --- 1. consecutive recycled lanes form one island; a gap splits it ---------
wave "1,2,3" 6
check "lanes 1-3 consecutive -> one island" "[[1, 2, 3]]" "$(isl "1,2,3")"
check "lanes 1,2,4 -> two islands" "[[1, 2], [4]]" "$(isl "1,2,4")"
check "lanes 2,3 only -> one island" "[[2, 3]]" "$(isl "2,3")"
check "lanes 5 alone -> one island" "[[5]]" "$(isl "5")"
check "no lanes -> no islands" "[]" "$(isl "")"

# --- 2. a partial is named as §2.8 reserves and refuses the shipping stages --
check "partial name carries -partial" "True" "$(m "m.refuse_partial('merge_decision_v6-partial-r1.json')")"
check "frozen name is not refused" "False" "$(m "m.refuse_partial('merge_decision_v6.json')")"
check "only -partial triggers refusal" "False" "$(m "m.refuse_partial('merge_decision_v6-draft.json')")"

# --- 3. seams name the missing lanes, both sides, and assert nothing ---------
seams=$(m "[s['seam'] for s in m.seams_for([2,3], 6)]")
check "island 2-3 of 6 -> seams SEAM-1L and SEAM-4R/5R/6R" \
    "['SEAM-1L', 'SEAM-4R', 'SEAM-5R', 'SEAM-6R']" "$seams"

seams2=$(m "[s['seam'] for s in m.seams_for([1,2,3,4,5,6], 6)]")
check "complete island -> no seams at all" "[]" "$seams2"

# --- 4. the module never asserts a verdict across a seam --------------------
wave "1,2,3" 6
out=$("$PY" "$MERGE" "$TMP/w.json" --out-dir "$TMP/out" --parent-version v6 2>/dev/null)
ep=$(cat "$TMP/out/merge_decision_v6-partial-r1.json" 2>/dev/null | "$PY" -c "import json,sys;d=json.load(sys.stdin);print(d['needs_arbitration'][0]['status'])" 2>/dev/null)
check "overlap verdict left to a human arbiter" "needs-arbitration" "$ep"

reason=$(cat "$TMP/out/merge_decision_v6-partial-r1.json" 2>/dev/null | "$PY" -c "import json,sys;print(json.load(sys.stdin)['partial_reason'])" 2>/dev/null)
case "$reason" in
    *"still missing"*) check "partial says how many lanes are missing" "yes" "yes" ;;
    *)                   check "partial says how many lanes are missing" "no" "yes" ;;
esac

# --- 5. one lane back is already a partial -- that is the whole point --------
wave "1" 6
rm -rf "$TMP/out"
out=$("$PY" "$MERGE" "$TMP/w.json" --out-dir "$TMP/out" --parent-version v6 2>/dev/null)
check "1 of 6 lanes -> a partial is written immediately" "1" \
    "$(printf '%s' "$out" | "$PY" -c "import json,sys;print(len(json.load(sys.stdin)['written']))")"

flag=$(cat "$TMP/out/merge_decision_v6-partial-r1.json" 2>/dev/null | "$PY" -c "import json,sys;print(json.load(sys.stdin)['partial'])" 2>/dev/null)
check "the artefact is flagged partial=true" "True" "$flag"

ver=$(cat "$TMP/out/merge_decision_v6-partial-r1.json" 2>/dev/null | "$PY" -c "import json,sys;print(json.load(sys.stdin)['version'])" 2>/dev/null)
check "version carries the -partial suffix, never bare v6" "v6-partial-r1" "$ver"

eps=$(cat "$TMP/out/merge_decision_v6-partial-r1.json" 2>/dev/null | "$PY" -c "import json,sys;d=json.load(sys.stdin);print(len(d['combat_episodes']))" 2>/dev/null)
check "the one recycled lane's episodes are carried" "1" "$eps"

# --- 6. two islands produce two partials, numbered r1 and r2 --------------
wave "1,2,5" 6
rm -rf "$TMP/out"
out=$("$PY" "$MERGE" "$TMP/w.json" --out-dir "$TMP/out" --parent-version v6 2>/dev/null)
n=$(printf '%s' "$out" | "$PY" -c "import json,sys;print(len(json.load(sys.stdin)['written']))")
check "lanes 1,2,5 of 6 -> two partials" "2" "$n"
check "partials are named r1 and r2" "yes" \
    "$([ -f "$TMP/out/merge_decision_v6-partial-r1.json" ] && [ -f "$TMP/out/merge_decision_v6-partial-r2.json" ] && echo yes || echo no)"

# --- 7. nothing is emitted when no lane has come back -----------------------
wave "" 6
rm -rf "$TMP/out"
out=$("$PY" "$MERGE" "$TMP/w.json" --out-dir "$TMP/out" --parent-version v6 2>/dev/null)
n=$(printf '%s' "$out" | "$PY" -c "import json,sys;print(len(json.load(sys.stdin)['written']))")
check "0 lanes recycled -> nothing written" "0" "$n"

# --- 8. a partial never appears on the frozen timeline path -----------------
wave "1,2,3" 6
rm -rf "$TMP/out"
"$PY" "$MERGE" "$TMP/w.json" --out-dir "$TMP/out" --parent-version v6 >/dev/null 2>&1
stray=$(ls "$TMP/out" 2>/dev/null | grep -v -- '-partial' | wc -l | tr -d ' ')
check "no artefact without the -partial marker escapes" "0" "$stray"

echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: PASS -- $pass case(s); a partial appears after one lane and never claims to be final"
    exit 0
fi
echo "RESULT: FAIL -- $fail of $((pass + fail)) case(s)"
exit 1
