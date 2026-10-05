#!/usr/bin/env bash
# test_auto_chain.sh -- authorisation stays manual; once granted the chain runs on.
#
# The 6.57 h wait, measured (research 07)
# ----------------------------------------
#   "frozen -> 4K actually rendering" idled 6.57 h across two tasks (864 4.97 h,
#   863 1.60 h) with every gate green and the machine idle.
#
#   The gate is genuinely the user's: `docs\粗剪提示词.md:143` and `:174` both say
#   the 4K master may not be produced unless the user has said 「输出 4K 成片」.
#   That part is right and this test pins it hard.
#
#   What was broken is everything after: no record of the grant, no orchestration,
#   no watchdog.  Measured after the grant the whole chain takes 16-25 min
#   (863 16.5, 864 24.5), so >=85% of the 6.57 h was dead time with the grant
#   already in hand.
#
# This is NOT auto-render
# -----------------------
# Measured 2026-10-06, 30 s of real source: 720p preview 25.70 s, 4K 108.65 s --
# 4.2x, i.e. ~47 min for a 13-minute master.  The user rejected auto-render for
# exactly that reason: 「改一点就得重渲」.  So the grant stays manual and per batch;
# only the dead time after it goes away.
#
# Test-shape notes (each cost a round; written down so it does not cost another)
#   * every read goes through the module's own CLI -- a probe that re-implements
#     the call granted correctly and then printed the pre-call snapshot, so eight
#     cases reported the opposite of what happened;
#   * the CLI's JSON is captured to a FILE, never a pipe.  `cmd | python -c` lost
#     stdin through PowerShell -> bash -lc -> pipeline, and every read raised
#     IndexError on an empty stdin, which reads exactly like "returned nothing";
#   * `run-step` writes state itself, so a case asserts on the *next* read rather
#     than on what run-step printed.
set -uo pipefail
cd '/c/Project/永劫无间' || exit 1

PY='.video-tools/venv/Scripts/python.exe'
AUTOM='skills/naraka-highlight-studio/scripts/auto_chain.py'
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

# read <expr>  -- run the CLI's grant-status, then evaluate expr against its JSON
read() {
    "$PY" "$AUTOM" "$2" grant-status > "$TMP/last.json" 2>&1
    "$PY" -c "
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as exc:
    print('UNREADABLE:%s' % exc); raise SystemExit
print(eval(sys.argv[2], {'d': d, 'len': len}))
" "$TMP/last.json" "$1" 2>&1
}

init() {
    "$PY" -c "
import importlib.util, pathlib, sys
s = importlib.util.spec_from_file_location('a', sys.argv[1])
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
m.save_state(pathlib.Path(sys.argv[2]), m._blank(pathlib.Path(sys.argv[2]).parent, 0))
" "$AUTOM" "$1" 2>&1
}

run() { "$PY" "$AUTOM" "$1" "${@:2}" > "$TMP/step.json" 2>&1; }

echo "test_auto_chain.sh -- grant stays manual, the chain after it does not idle"

if [ ! -f "$AUTOM" ]; then
    echo "  FAIL  auto_chain.py does not exist yet"
    echo "RESULT: FAIL"
    exit 1
fi

# --- 1. THE RED LINE: unauthorised means nothing runs -----------------------
init "$TMP/s.json"
check "no grant -> chain stays not-requested" "not-requested" \
    "$(read "d['authorization']['chain_state']" "$TMP/s.json")"
check "no grant -> no step executed" "0" \
    "$(read "len(d['authorization'].get('steps') or [])" "$TMP/s.json")"
check "no grant -> verdict asks for the grant" "needs-grant" \
    "$(read "d['verdict']" "$TMP/s.json")"

# --- 2. a paraphrase is not a grant (docs\粗剪提示词.md:174) ----------------
init "$TMP/p.json"
run "$TMP/p.json" grant --phrase '出 4K'
check "a paraphrase is NOT accepted as a grant" "needs-grant" \
    "$(read "d['verdict']" "$TMP/p.json")"
check "'出 4K' does not flip the state" "not-requested" \
    "$(read "d['authorization']['chain_state']" "$TMP/p.json")"
check "the refused phrase is recorded, not swallowed" "yes" \
    "$(case "$(read "d['authorization']['chain_error']" "$TMP/p.json")" in *'not accepted'*) echo yes;; *) echo no;; esac)"

# --- 3. granting records it, with a timestamp -------------------------------
init "$TMP/g.json"
run "$TMP/g.json" grant --phrase '输出 4K 成片' --at 1786000000
check "the exact phrase grants" "run-chain" "$(read "d['verdict']" "$TMP/g.json")"
check "the grant is stamped (research 07 found no time on record)" "1786000000.0" \
    "$(read "'%.1f' % d['authorization']['granted_at']" "$TMP/g.json")"
check "granted -> verdict runs the chain" "run-chain" "$(read "d['verdict']" "$TMP/g.json")"

# --- 4. steps run in order, and only after the grant ------------------------
init "$TMP/s2.json"
check "steps are known and ordered" "render,verify,cleanup" \
    "$("$PY" scripts/auto_chain_probe.py "$AUTOM" step_names 2>&1)"
run "$TMP/s2.json" grant --phrase '输出 4K 成片'
run "$TMP/s2.json" run-step --step render
check "after the grant, render runs" "render-done" \
    "$(read "d['authorization']['chain_state']" "$TMP/s2.json")"
run "$TMP/s2.json" run-step --step cleanup
check "cleanup refused while render is unverified" "render" \
    "$(read "d['authorization']['steps'][-1]" "$TMP/s2.json")"
run "$TMP/s2.json" run-step --step verify
check "verify runs after render" "verify-done" \
    "$(read "d['authorization']['chain_state']" "$TMP/s2.json")"

run "$TMP/s2.json" run-step --step cleanup
check "only cleanup completes the chain" "done" "$(read "d['authorization']['chain_state']" "$TMP/s2.json")"

# --- 5. a failure stops the chain, named -----------------------------------
init "$TMP/f.json"
run "$TMP/f.json" grant --phrase '输出 4K 成片'
run "$TMP/f.json" run-step --step render --result failed --detail 'ffmpeg exit 1'
check "a failed render halts the chain" "halted" \
    "$(read "d['authorization']['chain_state']" "$TMP/f.json")"
check "the failure is named, not swallowed" "yes" \
    "$(case "$(read "d['authorization']['chain_error']" "$TMP/f.json")" in *'ffmpeg exit 1'*) echo yes;; *) echo no;; esac)"
run "$TMP/f.json" run-step --step cleanup
check "cleanup will not run after a failure" "render" \
    "$(read "d['authorization']['steps'][-1]" "$TMP/f.json")"

# --- 6. the master destination is fixed and never overwritten --------------
check "master directory is the delivery folder" "E:\\Cujian导出" \
    "$("$PY" scripts/auto_chain_probe.py "$AUTOM" master_dir 2>&1)"
check "an existing master is never overwritten" "refuse-overwrite" \
    "$("$PY" scripts/auto_chain_probe.py "$AUTOM" plan_output --master-exists yes 2>&1)"

echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: PASS -- $pass case(s); nothing runs without the grant, everything runs after it"
    exit 0
fi
echo "RESULT: FAIL -- $fail of $((pass + fail)) case(s)"
exit 1
