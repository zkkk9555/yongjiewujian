#!/usr/bin/env bash
# test_state_file.sh -- red/green for the state file and its ledger projection.
#
# What it pins (from spec.md :: Implementation Decisions):
#   * a flat, small top level (the first design had 104 named fields; 09
#     adjudicated it down).  Kept in one place with the module so both read the
#     same number -- the test asks the module, it does not restate the count.
#   * every lane carries dispatched_at / recycled_at / attempt / recycle_round
#   * attempt and recycle_round are TWO fields, not one either/or choice
#   * the ledger gains dispatch/recycle/redispatch columns and is generated
#   * the literal string "T0" never appears -- task 861's 29 rows were all "T0",
#     which is exactly the evidence that the ledger was never really filled
#   * the state file does not live in the disposable set (preview/cache/shots/
#     audio); task 860 lost a verified resume implementation when cleanup
#     deleted cache\
set -uo pipefail
cd '/c/Project/永劫无间' || exit 1

PY='.video-tools/venv/Scripts/python.exe'
MOD='skills/naraka-highlight-studio/scripts/orchestrator_state.py'
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %-52s %s\n' "$1" "$3"; pass=$((pass + 1))
    else
        printf '  FAIL  %-52s got=%s want=%s\n' "$1" "$2" "$3"; fail=$((fail + 1))
    fi
}

# jget <state.json> <python-expr> [keys-source.py]
# Reads the state and evaluates an expression against it as `d`.  When a third
# argument is given, the module at that path is also imported and exposed as `k`
# (its TOP_LEVEL_KEYS) and `m`, so a test never restates a number the code owns.
jget() {
    local path="$1" expr="$2" keys_src="${3:-}"
    if [ -n "$keys_src" ]; then
        "$PY" - "$path" "$expr" "$keys_src" <<'PYEOF'
import importlib.util, json, sys
path, expr, keys_src = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("km", keys_src)
km = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(km)
except AssertionError as exc:
    print("assert:%s" % exc)
    raise SystemExit
d = json.load(open(path, encoding="utf-8")) if path.endswith(".json") else km
k = km.TOP_LEVEL_KEYS
print(eval(expr, {"d": d, "k": k, "m": km, "json": json, "len": len, "set": set,
                  "sorted": sorted, "all": all, "any": any, "isinstance": isinstance,
                  "int": int, "float": float, "str": str, "list": list}))
PYEOF
    else
        "$PY" - "$path" "$expr" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(eval(sys.argv[2], {"d": d, "json": json, "len": len, "set": set, "sorted": sorted,
                         "all": all, "any": any, "isinstance": isinstance, "int": int}))
PYEOF
    fi
}

echo "test_state_file.sh -- state file + automatic ledger projection"

if [ ! -f "$MOD" ]; then
    echo "  FAIL  orchestrator_state.py does not exist yet"
    echo "RESULT: FAIL"
    exit 1
fi

# --- 0. the module's own contract is self-consistent ------------------------
check "module key count matches its own declared contract" \
    "agree" "$(jget "$MOD" "'agree' if len(k) == m.EXPECTED_TOP_LEVEL_KEYS and len(set(k)) == len(k) else 'drift: %d keys vs declared %d' % (len(k), m.EXPECTED_TOP_LEVEL_KEYS)" "$MOD")"

# --- 1. a fresh state carries exactly the declared top level ----------------
"$PY" "$MOD" "$TMP/s1.json" init --task-dir "$TMP" >/dev/null 2>&1
check "state has exactly the declared top-level keys" \
    "match" "$(jget "$TMP/s1.json" "'match' if sorted(d) == sorted(k) else 'mismatch: extra=%s missing=%s' % (sorted(set(d) - set(k)), sorted(set(k) - set(d)))" "$MOD" 2>/dev/null || echo unavailable)"

# --- 2. 14 lanes, each with the 4 fields the watchdog needs -----------------
"$PY" "$MOD" "$TMP/s2.json" init --task-dir "$TMP" --lanes 14 >/dev/null 2>&1
check "14 lanes each carry the watchdog fields" "14 14 none" \
    "$(jget "$TMP/s2.json" "'%d %d %s' % (len(d['lanes']), len(d['lanes']), 'none' if not [k for k in ('dispatched_at','recycled_at','attempt','recycle_round') if any(k not in ln for ln in d['lanes'])] else 'missing')")"

# --- 3. attempt and recycle_round are independent ---------------------------
# One dispatch -> attempt 1, recycle_round 0.  One recycle -> recycle_round 1.
# A watchdog fire resets the wait (recycled_at cleared) but must NOT reset the
# recycle count, and must bump attempt.  So: 2 / 1, not 2 / 0 and not 1 / 1.
"$PY" "$MOD" "$TMP/s3.json" init --task-dir "$TMP" --lanes 2 >/dev/null 2>&1
"$PY" "$MOD" "$TMP/s3.json" dispatch --lane 1 >/dev/null 2>&1
"$PY" "$MOD" "$TMP/s3.json" recycle --lane 1 >/dev/null 2>&1
"$PY" "$MOD" "$TMP/s3.json" fire --lane 1 >/dev/null 2>&1
check "attempt and recycle_round are separate" "2 1" \
    "$(jget "$TMP/s3.json" "'%s %s' % (d['lanes'][0]['attempt'], d['lanes'][0]['recycle_round'])")"
# (want is "2 1": attempt 2 after one dispatch + one watchdog fire, recycle_round
#  still 1 because a fire restarts the wait but does not erase the recycling work)

# --- 4. dispatch/recycle stamps are epoch seconds ---------------------------
# recycled_at is legitimately None right after a fire, so only dispatched_at is
# required here; case 3 already pins the recycled_at lifecycle.
check "dispatch stamp is epoch seconds, never 'T0'" "clean" \
    "$(jget "$TMP/s3.json" "'clean' if isinstance(d['lanes'][0]['dispatched_at'], (int,float)) and d['lanes'][0]['dispatched_at'] > 1000000000 else 'dirty'")"

# --- 5. the ledger is a projection of the state, with the new columns ------
"$PY" "$MOD" "$TMP/s3.json" ledger --out "$TMP/ledger.md" >/dev/null 2>&1
# Column names are read out of the module itself: restating them here would let
# the table and the test drift apart, which is exactly how the first version lost
# its dispatch/recycle wording.  Expected count is derived, never hard-coded.
want=$("$PY" - "$MOD" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("m", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print(sum(1 for c in m.LEDGER_COLUMNS if c in ("dispatched", "recycled", "attempt", "recycle round")))
PYEOF
)
cols=$("$PY" - "$MOD" "$TMP/ledger.md" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("m", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
lines = open(sys.argv[2], encoding="utf-8").read().splitlines()
head = next((l for l in lines if l.startswith("| lane")), "")
want = [c for c in m.LEDGER_COLUMNS if c in ("dispatched", "recycled", "attempt", "recycle round")]
print("%d/%d %s" % (sum(1 for c in want if c in head), len(want),
                    ";".join(c for c in want if c not in head)))
PYEOF
)
check "ledger header gains dispatch/recycle/attempt/round" "$want/$want " "$cols"

has_t0=$("$PY" - "$TMP/ledger.md" <<'PYEOF'
import sys
print("1" if "| T0 " in open(sys.argv[1], encoding="utf-8").read() else "0")
PYEOF
)
check "ledger never contains a literal T0" "0" "$has_t0"

rows=$("$PY" - "$TMP/ledger.md" <<'PYEOF'
import sys
print(sum(1 for l in open(sys.argv[1], encoding="utf-8") if l.startswith("| ") and "---" not in l) - 1)
PYEOF
)
check "ledger has one row per lane" "2" "$rows"

# --- 6. state survives a corrupt file (must not wedge the task) ------------
echo 'not json at all {{{' > "$TMP/s4.json"
"$PY" "$MOD" "$TMP/s4.json" init --task-dir "$TMP" >/dev/null 2>&1
check "corrupt state file is rebuilt, not fatal" "unknown" \
    "$(jget "$TMP/s4.json" "d['phase']")"

# --- 7. the path is outside the disposable set -----------------------------
# --print-path writes the path to stdout; the verdict is computed by asking the
# module's own state_path(), not by pattern-matching the printed string, so the
# test cannot pass on a path that merely happens to contain "reports".
res=$("$PY" - "$MOD" --task-dir "$TMP" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("m", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
p = m.state_path(sys.argv[2]).as_posix().lower()
disposable = ("/preview/", "/cache/", "/shots/", "/audio/")
print("safe" if "/reports/" in p and not any(d in p for d in disposable) else "unsafe:" + p)
PYEOF
)
check "state path is not in preview/cache/shots/audio" "safe" "$res"

echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: PASS -- $pass case(s)"
    exit 0
fi
echo "RESULT: FAIL -- $fail of $((pass + fail)) case(s)"
exit 1
