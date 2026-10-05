#!/usr/bin/env bash
# test_watchdog.sh -- red/green for lane timeout detection and re-dispatch.
#
# What it pins (from spec.md :: Implementation Decisions):
#   * threshold = clamp(3 x p50 of this wave's recycle latency, 60, 240) minutes
#   * it may only fire once >= 50% of the wave has recycled
#   * a slow-but-recycled lane is never touched
#   * re-dispatch caps at attempt <= 2, and exhausting it must WITHHOLD by name
#   * the watchdog is a pure reader of the state file, so its own crash cannot
#     disturb a lane in flight
#
# On "replay 861"
# ----------------
# An earlier draft asserted the watchdog "would have fired at 19:35 on task 861".
# That timestamp was invented.  Re-reading the ledger showed six rows carrying any
# timestamp at all, none of them per-lane, and 33 cells holding the literal string
# "T0" -- per-lane dispatch/recycle times were never recorded, so no threshold can
# recover them.  That absence is ticket 01's reason for existing, and it is why
# these cases feed *measured-shaped* latencies with an injected clock instead of
# claiming to replay history that does not exist.
set -uo pipefail
cd '/c/Project/永劫无间' || exit 1

PY='.video-tools/venv/Scripts/python.exe'
STATE='skills/naraka-highlight-studio/scripts/orchestrator_state.py'
WATCH='skills/naraka-highlight-studio/scripts/watchdog.py'
KIT='scripts/watchdog_testkit.py'
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

NOW=1786000000
pass=0; fail=0
# check <name> <want> <got>
# The failure branch prints $3 as got and $2 as want.  An earlier version had
# these swapped, which made every mismatch read backwards: the *expected* value
# appeared where "got" was printed, so a genuine watchdog failure looked like the
# watchdog was correct and the test was wrong.
check() {
    local name="$1" want="$2" got="$3"
    if [ "$want" = "$got" ]; then
        printf '  PASS  %-54s %s\n' "$name" "$got"; pass=$((pass + 1))
    else
        printf '  FAIL  %-54s\n              got  %s\n              want %s\n' "$name" "$got" "$want"
        fail=$((fail + 1))
    fi
}

# --ago 600 means the wave was dispatched 10 hours before the evaluation instant,
# so every latency below (max 200 min) yields a positive span.
build() { "$PY" "$KIT" build --state-py "$STATE" --out "$1" --recycled "$2" --stuck "$3" --now "$NOW" --ago "${4:-600}" >/dev/null 2>&1; }
ask()   { "$PY" "$KIT" ask --watchdog-py "$WATCH" --state "$1" --now "$NOW" 2>/dev/null; }

echo "test_watchdog.sh -- timeout detection, re-dispatch, withhold"

if [ ! -f "$WATCH" ]; then
    echo "  FAIL  watchdog.py does not exist yet"
    echo "RESULT: FAIL"
    exit 1
fi

# --- 1. above the floor: threshold exists and the stuck lanes are named -----
build "$TMP/a.json" "5,4,6,3,7,5,4,6" 2
check "8/10 recycled -> threshold computed, stuck lanes named" \
    "fired-at-60|9:stuck;10:stuck" "$(ask "$TMP/a.json")"

# --- 2. below the floor: total silence --------------------------------------
build "$TMP/b.json" "" 10
check "0/10 recycled -> silent, no threshold" "silent|below-50-floor" "$(ask "$TMP/b.json")"

build "$TMP/b2.json" "5,4,6,3" 6
check "4/10 recycled -> silent, still under the 50% floor" \
    "silent|below-50-floor" "$(ask "$TMP/b2.json")"

# --- 3. exactly at the floor is allowed to speak ---------------------------
build "$TMP/c.json" "5,4,6,3,7,5" 4
check "6/10 recycled (at the floor) -> may fire" \
    "fired-at-60|7:stuck;8:stuck;9:stuck;10:stuck" "$(ask "$TMP/c.json")"

# --- 4. a slow-but-recycled lane is never touched --------------------------
# Lane 2 took 200 min -- far above the 60 min threshold -- but it did come back,
# so it must not be fired.  An earlier version of this case matched the output
# with `case` and had the sense inverted, reporting a pass when the lane was in
# fact listed.
build "$TMP/d.json" "5,200,4,3,7,5,4,6" 2
v=$(ask "$TMP/d.json")
fired_lanes=$(printf '%s' "$v" | sed -n 's/^[^|]*|\(.*\)$/\1/p' | tr ';' '\n' | cut -d: -f1 | grep -v '^none$' | sort -n | tr '\n' ',' )
check "slow-but-done lane 2 is never fired" "9,10," "$fired_lanes"

# --- 5. the threshold scales with p50 and clamps at both ends --------------
build "$TMP/e1.json" "5,4,6,3,7,5,4,6" 2
check "p50 5 min -> clamped up to the 60 min floor" \
    "fired-at-60|9:stuck;10:stuck" "$(ask "$TMP/e1.json")"

build "$TMP/e2.json" "100,110,95,105,120,98,102,101" 2
check "p50 ~100 min -> clamped down to the 240 min ceiling" \
    "fired-at-240|9:stuck;10:stuck" "$(ask "$TMP/e2.json")"

build "$TMP/e3.json" "40,38,42,41,39,40,43,37" 2
check "p50 40 min -> 3x = 120 min, inside the band" \
    "fired-at-120|9:stuck;10:stuck" "$(ask "$TMP/e3.json")"

# --- 6. a stuck lane under the threshold is not fired yet ------------------
# The wave started 5 minutes ago and the fastest lanes came back instantly, so
# p50 = 0 -> the 60 min floor applies.  The two stuck lanes have waited 5 min,
# nowhere near 60, so nothing fires.  (An earlier version ran this wave 600
# minutes back, which made the stuck lanes genuinely overdue and then asserted
# the opposite -- the expectation contradicted the setup.)
build "$TMP/f.json" "0,0,0,0,0,0,0,0" 2 5
check "fast lanes but young wave -> threshold set, nothing overdue" \
    "fired-at-60|none" "$(ask "$TMP/f.json")"

# --- 6b. the same wave, ten hours later -> the stuck lanes must fire --------
build "$TMP/f2.json" "0,0,0,0,0,0,0,0" 2 600
check "same wave 10 h later -> stuck lanes now overdue" \
    "fired-at-60|9:stuck;10:stuck" "$(ask "$TMP/f2.json")"

# --- 7. at the attempt cap: withheld by name, never re-dispatched ---------
# Read the verdict by re-reading the state file, not by capturing what apply()
# prints: apply() prints a JSON line to stdout, so an earlier version that
# captured it got that line instead of the lane, and the case compared empty
# strings for three rounds before the fixture itself turned out to be missing.
"$PY" "$KIT" cap --state-py "$STATE" --out "$TMP/g.json" \
    --recycled 8 --stuck 1 --at-cap 9 --now "$NOW" --ago 600 >/dev/null 2>&1
"$PY" "$WATCH" "$TMP/g.json" --now "$NOW" >/dev/null 2>&1
status=$("$PY" - "$TMP/g.json" <<'PYEOF'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
print(next(r["status"] for r in doc["lanes"] if r["id"] == 9))
PYEOF
)
check "attempt cap reached -> withheld, not re-dispatched" "withheld" "$status"

why=$("$PY" - "$TMP/g.json" <<'PYEOF'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
row = next(r for r in doc["lanes"] if r["id"] == 9)
err = row.get("last_error") or ""
print("named" if err.startswith("WITHHELD") and "attempts" in err else "unnamed:%s" % err)
PYEOF
)
check "withheld lane is named with a reason" "named" "$why"

nextact=$("$PY" - "$TMP/g.json" <<'PYEOF'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
print("blocked" if "withheld" in (doc.get("next_action") or "") else "ignored:%s" % doc.get("next_action"))
PYEOF
)
check "a withheld lane blocks the merge step" "blocked" "$nextact"

fired=$("$PY" - "$TMP/g.json" <<'PYEOF'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
row = next(r for r in doc["lanes"] if r["id"] == 9)
print("redispatched" if row["status"] == "in-flight" and row["recycled_at"] is None else "not-redispatched")
PYEOF
)
check "a capped lane is not re-dispatched a third time" "not-redispatched" "$fired"

# --- 8. the watchdog writes nothing when it stays silent --------------------
build "$TMP/h.json" "" 10
before=$(cksum < "$TMP/h.json")
"$PY" "$WATCH" "$TMP/h.json" --now "$NOW" >/dev/null 2>&1
after=$(cksum < "$TMP/h.json")
check "silent run leaves the state file untouched" "same" \
    "$([ "$before" = "$after" ] && echo same || echo changed)"

echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: PASS -- $pass case(s); a wedged lane is named, re-dispatched, then withheld"
    exit 0
fi
echo "RESULT: FAIL -- $fail of $((pass + fail)) case(s)"
exit 1
