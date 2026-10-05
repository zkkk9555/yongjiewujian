#!/usr/bin/env bash
# test_coverage_regression.sh -- run coverage_complete over every real timeline
# the project has ever produced, not just the one fixture.
#
# Why: a gate that is stricter than reality is the same disease as no gate at
# all.  This project has been burned twice by exactly that (861
# `preview_duration` false FAIL, `verify_master.sh` false FAIL on a track-less
# master).  A unit test on one hand-made fixture proves nothing about the 30+
# timelines that were already delivered.
#
# A real timeline failing here is not automatically a bug in the gate, so the
# run reports rather than fails: every FAIL is printed with its reason and has
# to be read.  WARN is the expected outcome for timelines that declare no
# deletions or no source_duration -- the gate must stay quiet there.
set -uo pipefail
cd '/c/Project/永劫无间' || exit 1

PY='.video-tools/venv/Scripts/python.exe'
GATE='skills/naraka-highlight-studio/scripts/qa_gate.py'
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

mapfile -t FILES < <(find 123 -type f \( -name 'combat_episodes*.json' -o -name '*timeline*.json' \) -size -200k 2>/dev/null | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "RESULT: FAIL -- no timelines found to regress over"
    exit 1
fi

total=${#FILES[@]}
pass=0; warn=0; fail=0
declare -a FAILED=()

echo "coverage regression over $total real timelines"
echo

for f in "${FILES[@]}"; do
    tag=$(printf '%s' "$f" | tr '/ ' '__')
    res=$("$PY" - "$GATE" "$f" "$OUT/$tag.json" <<'PYEOF'
import json, subprocess, sys
gate, tl, out = sys.argv[1], sys.argv[2], sys.argv[3]
subprocess.run([sys.executable, gate, tl, "--output", out],
               capture_output=True, text=True, encoding="utf-8", errors="replace")
try:
    doc = json.load(open(out, encoding="utf-8"))
except Exception as exc:
    print("ERR\t%s" % exc)
    raise SystemExit
cov = next((c for c in doc.get("checks", []) if c["name"] == "coverage_complete"), None)
if cov is None:
    print("MISSING\tno coverage_complete in output")
else:
    print("%s\t%s" % (cov["result"], cov["measured"]))
PYEOF
)
    status="${res%%$'\t'*}"
    measured="${res#*$'\t'}"
    case "$status" in
        PASS)   pass=$((pass + 1)) ;;
        WARN)   warn=$((warn + 1)) ;;
        *)      fail=$((fail + 1)); FAILED+=("$f"$'\t'"$measured") ;;
    esac
done

echo "PASS $pass / WARN $warn / FAIL $fail  (of $total)"
if [ "$fail" -gt 0 ]; then
    echo
    echo "FAIL rows -- read each one; it is either a real defect on disk or the gate being too strict:"
    for row in "${FAILED[@]}"; do
        printf '  %s\n      %s\n' "${row%%$'\t'*}" "${row#*$'\t'}"
    done
fi
echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: PASS -- no already-delivered timeline is rejected by coverage_complete"
    exit 0
fi
echo "RESULT: FAIL -- $fail of $total delivered timelines rejected"
exit 1
