#!/usr/bin/env bash
# test_deleted_voice_audit.sh -- the gate that can actually see a battle that was
# *cleanly declared* as deleted.
#
# Why it exists
# -------------
# Re-measuring 864's delivered v6 showed every already-delivered timeline has
# perfect coverage.  So the battle that 864 dropped was not "forgotten to
# declare" -- it was declared, cleanly.  coverage_complete cannot see that.
#
# This gate can, and it is deliberately an ABSENCE audit: a strong combat word
# inside a deleted interval demands a signed human verdict, never an automatic
# conclusion.  Measured on 864 v6 it flags 5 cues, and a human reading them
# exonerates all five:
#
#     17.26  「杀包」                    a plan ("kill the carrier"), not a fight
#     35.48  「给我来个金鸟冲」          an ability request
#    140.31  「大招应该也用不了吧」      predictive, and negated
#    144.30  「大招也用不了」            negated outright
#    880.38  「还有光诱,我来给你两个血药」  offering potions
#
# That is the mechanism working and the conclusion being wrong, which is the
# only acceptable shape here: the gate's job is to make a human look, not to
# assert.  The residual error classes are intent-vs-fact and negation, which is
# why this can never become an "this interval contains no combat" gate.
set -uo pipefail
cd '/c/Project/永劫无间' || exit 1

PY='.video-tools/venv/Scripts/python.exe'
GATE='skills/naraka-highlight-studio/scripts/qa_gate.py'
TL='docs/lessons/examples/864_v6_combat_episodes.json'
VI='123/21.864永劫无间 2026-09-30 02-57-13/analysis/combat_voice_index.json'
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0

# voice_result <timeline.json> <voice-index|none> -> PASS | WARN | FAIL
voice_result() {
    local tl="$1" vi="$2" out="$TMP/g.json"
    rm -f "$out"
    if [ "$vi" = "none" ]; then
        "$PY" "$GATE" "$tl" --output "$out" >/dev/null 2>&1
    else
        "$PY" "$GATE" "$tl" --voice-index "$vi" --output "$out" >/dev/null 2>&1
    fi
    "$PY" - "$out" <<'PYEOF'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
gate = next((c for c in doc["checks"] if c["name"] == "deleted_voice_audit"), None)
print(gate["result"] if gate else "MISSING")
PYEOF
}

check() {
    local name="$1" want="$2" got="$3"
    if [ "$want" = "$got" ]; then
        printf '  PASS  %-54s %s\n' "$name" "$got"; pass=$((pass + 1))
    else
        printf '  FAIL  %-54s got=%s want=%s\n' "$name" "$got" "$want"; fail=$((fail + 1))
    fi
}

# build <tag> <python body operating on `doc`>
build() {
    "$PY" - "$TL" "$TMP/$1.json" "$2" <<'PYEOF'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
exec(sys.argv[3])
json.dump(doc, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PYEOF
    printf '%s' "$TMP/$1.json"
}

echo "test_deleted_voice_audit.sh -- declared deletions still need a signed verdict"

# 1. No voice index -> cannot judge, must stay WARN.
check "no voice index supplied" WARN "$(voice_result "$TL" none)"

# 2. The real 864 v6 + its real voice index -> unadjudicated debt is a FAIL.
#    This is the finding, not a bug: 864 v6 passed twelve review routes and still
#    declared five strong cues with nobody signing off on them.
check "864 v6, real cues, no verdicts" FAIL "$(voice_result "$TL" "$VI")"

# 3. A proper verdict on every flagged interval -> PASS.
tl=$(build adjudicated '
import json
VI = json.load(open("123/21.864永劫无间 2026-09-30 02-57-13/analysis/combat_voice_index.json", encoding="utf-8"))
STRONG = ("杀","击杀","击败","砍死","大招","闪避","中刀","倒地","救","被击","血量","血条",
          "弹尽","没弹","预瞄","听声","射速","操作","追上","局势","我来","别急","撤",
          "残血","反打","振刀","格挡","处决","第一","第二","胜利","失败","淘汰","终结")
doc["deleted_voice_adjudications"] = [
    {"start": d["start"], "end": d["end"],
     "reason": "预战斗计划语与否定句，非交战期证据（人工复核 5 条原话）",
     "evidence": "reports/deleted_audit_v1.md"}
    for d in doc["deleted_intervals"]
    if any(any(w in c["text"] for w in STRONG)
           for c in VI["cues"] if min(d["end"], c["end"]) - max(d["start"], c["start"]) > 0.25)
]
')
check "864 v6 with signed verdicts on every hit" PASS "$(voice_result "$tl" "$VI")"

# 4. A verdict with no reasoning is not a verdict.
tl=$(build thin_reason '
doc["deleted_voice_adjudications"] = [
    {"start": 0.0, "end": 181.0, "reason": "ok", "evidence": "reports/x.md"},
    {"start": 810.0, "end": 894.0,
     "reason": "预战斗计划语与否定句，非交战期证据（人工复核 5 条原话）",
     "evidence": "reports/deleted_audit_v1.md"},
]
')
check "verdict with a 2-char reason" FAIL "$(voice_result "$tl" "$VI")"

# 5. A verdict with no evidence path is not traceable.
tl=$(build no_evidence '
doc["deleted_voice_adjudications"] = [
    {"start": 0.0, "end": 181.0,
     "reason": "预战斗计划语与否定句，非交战期证据（人工复核 5 条原话）"},
    {"start": 810.0, "end": 894.0,
     "reason": "预战斗计划语与否定句，非交战期证据（人工复核 5 条原话）",
     "evidence": "reports/deleted_audit_v1.md"},
]
')
check "verdict with no evidence path" FAIL "$(voice_result "$tl" "$VI")"

# 6. Weak wording must not demand adjudication.  打 also fires on 打药 / 打开,
#    which is why the strong list has two tiers.
"$PY" - "$TMP/weak.json" "$TMP/weak_vi.json" <<'PYEOF'
import json, sys
json.dump({"schema": "naraka-voice-index/v1", "cues": [
    {"start": 10.0, "end": 12.0, "text": "我打个药", "combat_hits": ["打"], "loot_hits": []},
]}, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PYEOF
check "weak wording only (打药) -> no verdict needed" PASS "$(voice_result "$TL" "$TMP/weak_vi.json")"

echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: PASS -- $pass case(s); a cleanly-declared deletion still needs a signed verdict"
    exit 0
fi
echo "RESULT: FAIL -- $fail of $((pass + fail)) case(s)"
exit 1
