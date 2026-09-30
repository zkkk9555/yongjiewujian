#!/bin/bash
# End-to-end proof that the 4K master path honours excluded_inside holes
# WITHOUT any change to seg_render_master.sh.
#
# Builds a synthetic 60 s source, a timeline with one in-segment hole, runs the
# real render + verify scripts, and asserts the master's measured duration
# equals the hole-deducted program length.
#
#   episode  [10, 40]  with a hole at [20, 25]
#   -> cut segments (10,20) and (25,40)  ->  10 + 15 = 25 s
#
# A renderer that ignored the hole would produce 30 s; the buggy
# read_episode_bounds.ps1 reported PROGRAM=30 and the gate demanded 30.
set -uo pipefail

PS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$PS_DIR/.." && pwd)"
WORK="${TMPDIR:-/tmp}/hole_e2e_$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

RESOLVE_OUT=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -m "$PS_DIR/resolve_ffmpeg.ps1")" -Emit)
FF=$(printf '%s\n' "$RESOLVE_OUT" | sed -n 's/^FFMPEG=//p' | tr -d '\r')
FF=$(cygpath -m "$FF")
SRC="$WORK/src.mp4"
TL="$WORK/timeline.json"
OUT="$WORK/out.mp4"
LOG="$WORK/render.log"

echo "== building a 60 s synthetic source =="
"$FF" -hide_banner -y -v error -f lavfi -i "testsrc2=size=1920x1080:rate=60:duration=60" \
  -c:v libx264 -preset ultrafast -crf 30 -pix_fmt yuv420p "$(cygpath -m "$SRC")" || exit 1

cat > "$TL" <<'JSON'
{
  "schema": "naraka-combat-roughcut-qa/v1",
  "combat_episodes": [
    { "id": "e1", "source_start": 10, "source_end": 40,
      "excluded_inside": [ { "start": 20, "end": 25, "reason": "loot panel" } ] }
  ]
}
JSON

echo "== cut list as the 4K path will read it =="
BOUNDS=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -m "$PS_DIR/read_episode_bounds.ps1")" "$(cygpath -w "$TL")" | tr -d '\r')
printf '%s\n' "$BOUNDS" | sed 's/^/  /'
PROG=$(printf '%s\n' "$BOUNDS" | sed -n 's/^PROGRAM=//p')

if [ "$PROG" != "25" ] && [ "$PROG" != "25.0" ]; then
  echo "  [FAIL] expected PROGRAM=25 (30 minus the 5 s hole), got '$PROG'"
  exit 1
fi

echo "== rendering with the UNMODIFIED seg_render_master.sh =="
bash "$PS_DIR/seg_render_master.sh" "$(cygpath -w "$WORK")" "$(cygpath -w "$SRC")" "$(cygpath -w "$TL")" "$(cygpath -w "$OUT")" "$(cygpath -w "$LOG")" >/dev/null 2>&1
if [ ! -s "$OUT" ]; then
  echo "  [FAIL] render produced no output; log tail:"
  tail -15 "$LOG" 2>/dev/null | sed 's/^/    /'
  exit 1
fi

echo "== verifying with verify_master.sh (expected=$PROG) =="
bash "$PS_DIR/verify_master.sh" "$(cygpath -w "$OUT")" "$PROG" "$(cygpath -w "$WORK/verify.log")" 2>&1 | grep -E 'DURATION_CHECK|actual_program_sec|SUBTITLE|FAIL' | sed 's/^/  /'
VRC=${PIPESTATUS[0]}

ACTUAL=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { (Get-Item -LiteralPath '$OUT') }" >/dev/null 2>&1; \
  "$(cygpath -m "$FF" | sed 's/ffmpeg\.exe/ffprobe.exe/')" -v error -show_entries format=duration -of csv=p=0 "$(cygpath -m "$OUT")" | tr -d '\r')

echo ""
echo "  expected (hole deducted) : 25.000000 s"
echo "  measured on the master   : ${ACTUAL} s"
OK=$(awk -v a="$ACTUAL" 'BEGIN{d=a-25; if(d<0)d=-d; print (d<=0.1)?"ok":"BAD"}')
if [ "$OK" = "ok" ]; then
  echo ""
  echo "RESULT: PASS -- the 4K path honours the hole, and seg_render_master.sh needed no change"
  exit 0
fi
echo ""
echo "RESULT: FAIL -- master is ${ACTUAL}s, expected 25s"
exit 1
