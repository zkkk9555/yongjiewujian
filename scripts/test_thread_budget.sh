#!/usr/bin/env bash
# E2E check for the thread-budget change in seg_render_master.sh.
#
# Builds a throwaway 6-second timeline over real source media, runs the real
# render script, and verifies the master is still 3840x2160 CFR 60 with a video
# stream.  A thread cap must be output-neutral: same geometry, same frame rate,
# non-empty file.  It also records the wall clock so a regression is visible.
set -uo pipefail

ROOT='/c/Project/永劫无间'
SCRIPT="$ROOT/scripts/seg_render_master.sh"
PY="$ROOT/.video-tools/venv/Scripts/python.exe"
FFPROBE="$ROOT/.video-tools/LosslessCut/resources/ffprobe.exe"

JOB="$(mktemp -d)"
trap 'rm -rf "$JOB"' EXIT

SRC=$(find /e/OBS /e/PR导出 -maxdepth 1 -name '*.mp4' -size +100M 2>/dev/null | head -1)
if [ -z "$SRC" ]; then
    echo "RESULT: FAIL -- no source media found"
    exit 1
fi

mkdir -p "$JOB/timeline"
"$PY" - "$JOB/timeline/t1.json" <<'PYEOF'
import json, sys
json.dump({
    "schema": "naraka-combat-roughcut-timeline/v1",
    "version": "thread-budget-e2e",
    "source_duration": 300.0,
    "combat_episodes": [{"id": "t1", "source_start": 120.0, "source_end": 126.0}],
    "deleted_intervals": [
        {"start": 0.0, "end": 120.0, "category": "traversal"},
        {"start": 126.0, "end": 300.0, "category": "outro"},
    ],
}, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PYEOF

echo "source: $(basename "$SRC")"
START=$(date +%s)
bash "$SCRIPT" \
    "$(cygpath -w "$JOB")" \
    "$(cygpath -w "$SRC")" \
    "$(cygpath -w "$JOB/timeline/t1.json")" \
    "$(cygpath -w "$JOB/out.mp4")" \
    "$(cygpath -w "$JOB/render.log")" >/dev/null 2>&1
RC=$?
ELAPSED=$(( $(date +%s) - START ))

if [ $RC -ne 0 ] || [ ! -s "$JOB/out.mp4" ]; then
    echo "  FAIL  render exited $RC"
    tail -6 "$JOB/render.log" 2>/dev/null | sed 's/^/      /'
    echo "RESULT: FAIL"
    exit 1
fi

BYTES=$(stat -c %s "$JOB/out.mp4")
INFO=$("$FFPROBE" -v error -select_streams v:0 \
    -show_entries stream=width,height,r_frame_rate,codec_name \
    -of json "$JOB/out.mp4" 2>/dev/null)
# JSON, not csv=p=0 and not default=nw=1:nk=1: ffprobe prints the fields in its OWN
# order (codec_name first, width second), not the order they were requested in, so
# positional parsing silently yields height=3840 and sends the test chasing a
# phantom geometry bug.  Two of my own attempts failed exactly this way.
read -r W H FR CODEC <<EOF
$(printf '%s' "$INFO" | tr -d ' \n' | sed 's/.*"codec_name":"\([^"]*\)".*"width":\([0-9]*\).*"height":\([0-9]*\).*"r_frame_rate":"\([^"]*\)".*/\2 \3 \4 \1/')
EOF

fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf '  PASS  %-34s %s\n' "$1" "$3"
    else
        printf '  FAIL  %-34s got=%s want=%s\n' "$1" "$2" "$3"
        fail=1
    fi
}
check "width"        "$W"  "3840"
check "height"       "$H"  "2160"
check "frame rate"   "$FR" "60/1"
check "codec"         "$CODEC" "h264"
[ "$BYTES" -gt 100000 ] && printf '  PASS  %-34s %s B\n' "non-empty output" "$BYTES" || { printf '  FAIL  %-34s %s B\n' "non-empty output" "$BYTES"; fail=1; }

grep -q 'SEG_RENDER_START' "$JOB/render.log" && printf '  PASS  %-34s\n' "log has SEG_RENDER_START" || { printf '  FAIL  %-34s\n' "log has SEG_RENDER_START"; fail=1; }

echo "  (wall clock ${ELAPSED}s for a 6 s 4K master)"
echo
if [ $fail -eq 0 ]; then
    echo "RESULT: PASS -- the thread cap left the master byte-compatible (3840x2160 CFR60)"
    exit 0
fi
echo "RESULT: FAIL"
exit 1
