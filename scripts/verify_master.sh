#!/bin/bash
# Verify a 4K cujian master: probe + full decode + duration check.
# Usage: verify_master.sh <master_mp4> <expected_program_sec> <log_file>
#
# expected_program_sec is the PROGRAM= value printed by read_episode_bounds.ps1
# for the timeline this master was rendered from.  It is compared against the
# master's real duration with a 2 s tolerance; a master that silently lost or
# gained a segment is exactly what this gate exists to catch.  Pass 0 to skip
# the comparison.
#
# ffmpeg/ffprobe are resolved at run time through scripts/resolve_ffmpeg.ps1
# rather than a hardcoded WinGet path that has since been uninstalled
# (see .scratch/fix-dead-ffmpeg-and-4k-render-path/spec.md).
set -euo pipefail

M="$1"; EXP="$2"; LOG="$3"

PS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RESOLVE_OUT=$(powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(cygpath -m "$PS_DIR/resolve_ffmpeg.ps1")" -Emit) || {
  echo "[FAIL] could not resolve ffmpeg/ffprobe. Run scripts/check_video_environment.ps1 first." >&2
  exit 1
}
FF=$(printf '%s\n' "$RESOLVE_OUT" | sed -n 's/^FFMPEG=//p')
FP=$(printf '%s\n' "$RESOLVE_OUT" | sed -n 's/^FFPROBE=//p')
if [ -z "$FF" ] || [ ! -f "$FF" ] || [ -z "$FP" ] || [ ! -f "$FP" ]; then
  echo "[FAIL] resolver returned no usable ffmpeg/ffprobe pair" >&2
  exit 1
fi
FF=$(cygpath -m "$FF")
FP=$(cygpath -m "$FP")

M_W=$(cygpath -m "$M")
LOG_P=$(cygpath -u "$LOG")

# Subtitles must ship as a sidecar SRT, never burned in and never as an embedded
# stream.  Any subtitle stream here is a delivery violation, not a warning.
SUBSTREAMS=$("$FP" -v error -select_streams s -show_entries stream=codec_name -of csv "$M_W" 2>/dev/null | tr -d '\r' | sed '/^$/d')
SUB_COUNT=$(printf '%s\n' "$SUBSTREAMS" | grep -c . || true)

{
  echo "VERIFY_START $(date -u +%FT%TZ)"
  echo "file=$M expected_program_sec=$EXP"
  echo "ffmpeg=$FF"
  ls -la "$M_W"
  echo "--- streams ---"
  "$FP" -v error -show_entries stream=codec_name,width,height,r_frame_rate,codec_type,sample_rate,channels -of default=noprint_wrappers=1 "$M_W"
  echo "--- format ---"
  "$FP" -v error -show_entries format=duration,size,bit_rate -of default=noprint_wrappers=1 "$M_W"
  echo "--- subtitle streams (expect none) --- count=$SUB_COUNT"
  if [ "$SUB_COUNT" -ne 0 ]; then
    echo "VIOLATION: master carries $SUB_COUNT subtitle stream(s); policy is a clean picture with a sidecar SRT"
    printf '%s\n' "$SUBSTREAMS"
  fi
  echo "--- full decode ---"
  # -xerror makes ffmpeg exit non-zero on a real decode error.  Capture the code
  # explicitly: under `set -e` a plain call would abort before printing it, and
  # the whole point of this gate is to report that number.
  #
  # The audio map is OPTIONAL.  A hardcoded `-map 0:a:0` made ffmpeg abort with
  # "Stream map '' matches no streams" (exit 127) on any master cut from a
  # source with no audio track, so this gate reported a decode failure for a file
  # that decodes perfectly -- the same false-alarm disease as the qa_gate duration
  # bug.  Map audio only when the master actually has one, and say so in the log.
  DECODE_MAP=(-map 0:v:0)
  HAS_AUDIO=$("$FP" -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 "$M_W" | tr -d '\r ')
  if [ -n "$HAS_AUDIO" ]; then
    DECODE_MAP+=(-map 0:a:0)
  fi
  echo "decode_map=video$( [ -n "$HAS_AUDIO" ] && echo '+audio' || echo ' (no audio stream in master)')"
  set +e
  "$FF" -v error -xerror -i "$M_W" "${DECODE_MAP[@]}" -f null -
  DECODE_EXIT=$?
  set -e
  echo "DECODE_EXIT=$DECODE_EXIT"

  echo "--- duration check ---"
  DUR=$("$FP" -v error -show_entries format=duration -of csv=p=0 "$M_W" | tr -d '\r')
  echo "actual_program_sec=$DUR"
  if [ "$EXP" = "0" ] || [ -z "$EXP" ]; then
    echo "DURATION_CHECK=SKIPPED (no expected value supplied)"
  else
    DIFF=$(awk -v a="$DUR" -v b="$EXP" 'BEGIN { d = a - b; if (d < 0) d = -d; printf "%.3f", d }')
    echo "abs_diff_sec=$DIFF (tolerance 2.000)"
    if awk -v d="$DIFF" 'BEGIN { exit !(d > 2.0) }'; then
      echo "DURATION_CHECK=FAIL (master does not match the timeline cut list)"
    else
      echo "DURATION_CHECK=PASS"
    fi
  fi
  echo "VERIFY_DONE"
} > "$LOG_P" 2>&1

cat "$LOG_P"

# Surface the three verdicts in the exit code so a caller does not have to parse
# the log to know whether the master passed.  Written as `if` rather than
# `grep && exit` on purpose: the good path is "grep finds nothing", which exits
# non-zero, and leaning on set -e's exact semantics there is fragile.
if ! grep -q 'DECODE_EXIT=0' "$LOG_P"; then
  echo "[FAIL] full decode did not exit 0" >&2
  exit 1
fi
if [ "$SUB_COUNT" -ne 0 ]; then
  echo "[FAIL] master has $SUB_COUNT subtitle stream(s); policy is clean picture + sidecar SRT" >&2
  exit 1
fi
if grep -q 'DURATION_CHECK=FAIL' "$LOG_P"; then
  echo "[FAIL] duration does not match the cut list" >&2
  exit 1
fi
exit 0
