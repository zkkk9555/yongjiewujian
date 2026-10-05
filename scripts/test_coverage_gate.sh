#!/usr/bin/env bash
# test_coverage_gate.sh -- regression for the "coverage_complete" rule:
# kept episodes + declared deleted intervals must tile the whole source.
#
# Why this rule exists
# -------------------
# Measured on 864 v6 before the rule existed: deleting any one of its 7 real
# battles left every existing gate green (7/7).  The largest single deletion
# was combat_009 at 233.45 s, i.e. 35% of the whole programme.  Nothing ever
# compared kept + deleted against source_duration, because:
#   * timeline_mutex only compares episodes with each other;
#   * source_range only inspects kept episodes;
#   * program_sum compares against a program_map the commander rewrote in the
#     same pass, so the bookkeeping agreed with itself.
#
# Two implementations are asserted against each other on purpose:
#   qa_gate.py::gate_coverage_complete    the gate (proves the rule)
#   read_episode_bounds.ps1               the 4K cut-list reader (proves the
#                                         4K chain actually enforces it)
# They must agree, otherwise a gate can pass while the render still drops a
# fight -- which is the exact failure this file exists to prevent.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$ROOT/.video-tools/venv/Scripts/python.exe"
GATE="$ROOT/skills/naraka-highlight-studio/scripts/qa_gate.py"
READER="$ROOT/scripts/read_episode_bounds.ps1"
FIXTURE="$ROOT/docs/lessons/examples/864_v6_combat_episodes.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

report() {
    local name="$1" want_gate="$2" want_reader="$3" got_gate="$4" got_reader="$5"
    if [ "$want_gate" = "$got_gate" ] && [ "$want_reader" = "$got_reader" ]; then
        printf '  PASS  %-52s gate=%-4s reader=%-4s\n' "$name" "$got_gate" "$got_reader"
        pass=$((pass + 1))
    else
        printf '  FAIL  %-52s gate=%-4s (want %-4s) reader=%-4s (want %s)\n' \
            "$name" "$got_gate" "$want_gate" "$got_reader" "$want_reader"
        fail=$((fail + 1))
    fi
}

# gate_status <timeline.json> -> PASS | FAIL | ERR
gate_status() {
    local tl="$1" out="$TMP/gate.$$.json"
    rm -f "$out"
    "$PY" "$GATE" "$tl" --output "$out" >/dev/null 2>&1
    if [ ! -f "$out" ]; then printf 'ERR'; return; fi
    "$PY" - "$out" <<'PYEOF'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
bad = [c["name"] for c in doc.get("checks", []) if c.get("result") == "FAIL"]
print("FAIL" if bad else "PASS")
PYEOF
}

# reader_status <timeline.json> -> PASS | FAIL | ERR
reader_status() {
    local tl="$1"
    if powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$READER" "$tl" >/dev/null 2>&1; then
        printf 'PASS'
    else
        printf 'FAIL'
    fi
}

# mutate <tag> <python-body>
mutate() {
    local tag="$1" body="$2"
    "$PY" - "$FIXTURE" "$TMP/$tag.json" "$body" <<'PYEOF'
import copy, json, sys
src, dst, body = sys.argv[1], sys.argv[2], sys.argv[3]
doc = json.load(open(src, encoding="utf-8"))
exec(body)
json.dump(doc, open(dst, "w", encoding="utf-8"), ensure_ascii=False)
PYEOF
    printf '%s' "$TMP/$tag.json"
}

echo "test_coverage_gate.sh -- kept + deleted must tile the source"

if [ ! -f "$FIXTURE" ]; then
    echo "  FAIL  fixture missing: $FIXTURE"
    exit 1
fi

# --- 1. the honest timeline must pass both -----------------------------------
report "864 v6 untouched" PASS PASS "$(gate_status "$FIXTURE")" "$(reader_status "$FIXTURE")"

# --- 2. dropping any single real battle must be caught by both ---------------
# The fixture path must arrive as argv, never embedded in a `-c` string: under
# msys the `$PY` is a native Windows binary, and a `/c/Project/...` path baked
# into the program text is never translated, so it cannot be opened.
n=$("$PY" - "$FIXTURE" <<'PYEOF'
import json, sys
print(len(json.load(open(sys.argv[1], encoding="utf-8"))["combat_episodes"]))
PYEOF
)
for i in $(seq 0 $((n - 1))); do
    tl=$(mutate "drop_$i" "
doc['combat_episodes'].pop($i)
")
    report "battle #$i dropped (no deletion declared)" FAIL FAIL "$(gate_status "$tl")" "$(reader_status "$tl")"
done

# --- 2b. emptying the timeline must also be caught ----------------------------
# main() used to skip every timeline gate when the episode list was empty, so
# deleting all seven battles of 864 v6 reported green.  Zero episodes means an
# empty programme, which is never a pass.
tl=$(mutate "drop_all" "doc['combat_episodes'] = []")
report "all battles dropped (0 episodes)" FAIL FAIL "$(gate_status "$tl")" "$(reader_status "$tl")"

# --- 3. the largest battle specifically (233.45 s = 35% of the programme) ----
tl=$(mutate "drop_largest" "
doc['combat_episodes'] = [e for e in doc['combat_episodes'] if e['id'] != 'combat_009']
")
report "combat_009 (233.45s) dropped" FAIL FAIL "$(gate_status "$tl")" "$(reader_status "$tl")"

# --- 4. head and tail gaps ----------------------------------------------------
tl=$(mutate "head_gap" "doc['deleted_intervals'][0]['start'] = 40.0")
report "40s gap at the head of the source" FAIL FAIL "$(gate_status "$tl")" "$(reader_status "$tl")"

tl=$(mutate "tail_gap" "doc['deleted_intervals'][-1]['end'] = 1140.0")
report "12s gap at the tail of the source" FAIL FAIL "$(gate_status "$tl")" "$(reader_status "$tl")"

# --- 5. a second both kept and declared deleted ------------------------------
tl=$(mutate "double" "doc['deleted_intervals'].append({'start': 200.0, 'end': 260.0, 'category': 'bogus'})")
report "kept [181,266.5] also declared deleted" FAIL FAIL "$(gate_status "$tl")" "$(reader_status "$tl")"

# --- 6. the gates must NOT invent failure on thin input ----------------------
# source_duration missing / no deletions declared: cannot judge, so stay quiet.
tl=$(mutate "no_duration" "doc.pop('source_duration', None)")
report "no source_duration -> cannot judge, stays quiet" PASS PASS "$(gate_status "$tl")" "$(reader_status "$tl")"

tl=$(mutate "no_deletions" "doc['deleted_intervals'] = []")
report "no deleted_intervals -> cannot judge, stays quiet" PASS PASS "$(gate_status "$tl")" "$(reader_status "$tl")"

echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: PASS -- $pass case(s); a dropped battle can no longer pass unnoticed"
    exit 0
fi
echo "RESULT: FAIL -- $fail of $((pass + fail)) case(s)"
exit 1
