#!/usr/bin/env bash
# test_partial_refusal.sh -- a -partial timeline cannot pass as a master.
#
# Ticket 03 makes merging early real: merge_partial.py emits
# merge_decision_vN-partial-r{k} the moment one lane comes back.  That removes
# task 861's 9.3-hour wait -- but only if the half-finished artefact is
# mechanically unable to pass.  Otherwise "merge early" quietly becomes
# "ship early", which is the exact failure this project already paid for once:
# an automated chain delivered a timeline nobody had judged.
#
# Roughcut-launch.md §2.6: a draft carries -partial, is never frozen, and is
# refused by the subtitle / render / self-audit stages.
# §2.8: partial never becomes final; only a line-repairer recomputes it.
set -uo pipefail
cd '/c/Project/永劫无间' || exit 1

PY='.video-tools/venv/Scripts/python.exe'
GATE='skills/naraka-highlight-studio/scripts/qa_gate.py'
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
# The PowerShell runner has to be resolved by bash: a bare `powershell.exe` call
# from a heredoc-using test silently succeeded while printing nothing, which read
# as "the reader accepted the partial".
PS_SCRIPT=$(command -v powershell.exe || true)
if [ -z "$PS_SCRIPT" ]; then
    PS_SCRIPT=$(command -v powershell || true)
fi
check() {
    local name="$1" want="$2" got="$3"
    if [ "$want" = "$got" ]; then
        printf '  PASS  %-54s %s\n' "$name" "$got"; pass=$((pass + 1))
    else
        printf '  FAIL  %-54s\n              got  %s\n              want %s\n' "$name" "$got" "$want"
        fail=$((fail + 1))
    fi
}

# gate <timeline.json> -> "<no_partial_timeline result>|<overall pass flag>"
gate() {
    "$PY" "$GATE" "$1" --output "$TMP/out.json" >/dev/null 2>&1
    "$PY" - "$TMP/out.json" <<'PYEOF'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
chk = next((c for c in doc["checks"] if c["name"] == "no_partial_timeline"), None)
if chk is None:
    print("MISSING|?")
else:
    any_fail = any(c.get("result") == "FAIL" for c in doc["checks"])
    print("%s|%s" % (chk["result"], "false" if any_fail else "true"))
PYEOF
}

echo "test_partial_refusal.sh -- a partial can never pass as a master (§2.6)"

# --- 1. a real partial, produced by merge_partial.py, is refused -------------
"$PY" scripts/stream_merge_kit.py --tmp "$TMP" >/dev/null 2>&1
check "merge_partial.py output is refused by qa_gate" "FAIL|false" "$(gate "$TMP/out/merge_decision_v6-partial-r1.json")"

# --- 2. the frozen timeline from a delivered task still passes --------------
check "delivered 864 v6 timeline is unaffected" "PASS|true" \
    "$(gate docs/lessons/examples/864_v6_combat_episodes.json)"

# --- 3. the three refusal signals each independently trigger ---------------
# The clean fixture needs a real episode, not an empty list: v1.015 made
# "0 episodes against a known-length source" a coverage FAIL, and an earlier
# version of this file used `combat_episodes: []`, so the case failed for a
# reason that had nothing to do with partial refusal.
"$PY" - "$TMP" <<'PYEOF'
import json, os, sys
tmp = sys.argv[1]
base = {
    "schema": "naraka-combat-roughcut-timeline/v1", "version": "v6",
    "source_duration": 100.0,
    "combat_episodes": [{"id": "e1", "source_start": 10.0, "source_end": 20.0}],
    "deleted_intervals": [{"start": 0.0, "end": 10.0, "category": "traversal"},
                          {"start": 20.0, "end": 100.0, "category": "outro"}],
}
json.dump(base, open(os.path.join(tmp, "by_name-partial.json"), "w", encoding="utf-8"))
flag = json.loads(json.dumps(base)); flag["partial"] = True
json.dump(flag, open(os.path.join(tmp, "by_flag.json"), "w", encoding="utf-8"))
ver = json.loads(json.dumps(base)); ver["version"] = "v6-partial-r1"
json.dump(ver, open(os.path.join(tmp, "by_version.json"), "w", encoding="utf-8"))
json.dump(base, open(os.path.join(tmp, "clean.json"), "w", encoding="utf-8"))
PYEOF
check "filename carrying -partial is refused" "FAIL|false" "$(gate "$TMP/by_name-partial.json")"
check "partial:true flag alone is refused" "FAIL|false" "$(gate "$TMP/by_flag.json")"
check "version suffix alone is refused" "FAIL|false" "$(gate "$TMP/by_version.json")"
check "an unmarked timeline is not refused by this gate" "PASS|true" "$(gate "$TMP/clean.json")"

# --- 4. the renderer refuses it too, not just the gate ---------------------
# §2.6 says the render stage must refuse partials.  read_episode_bounds.ps1 is
# the 4K chain's only entry point, so that is where the refusal belongs.
"$PS_SCRIPT" -File scripts/read_episode_bounds.ps1 "$TMP/by_name-partial.json" >/dev/null 2>&1
rc=$?
check "read_episode_bounds.ps1 rejects a partial" "1" "$rc"

"$PS_SCRIPT" -File scripts/read_episode_bounds.ps1 docs/lessons/examples/864_v6_combat_episodes.json >/dev/null 2>&1
rc=$?
check "read_episode_bounds.ps1 still accepts a real timeline" "0" "$rc"

echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: PASS -- $pass case(s); a partial is refused by both the gate and the 4K reader"
    exit 0
fi
echo "RESULT: FAIL -- $fail of $((pass + fail)) case(s)"
exit 1
