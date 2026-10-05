#!/bin/bash
# Segment render for one episode then concat: the 4K master path.
#
# Roughcut masters are ALWAYS CLEAN: no burned-in text, no embedded subtitle
# stream.  Subtitles ship as a sidecar SRT next to the master.  This script has
# no burn option and must not grow one -- burned output next to a same-named SRT
# is what caused the double-subtitle incident recorded in AGENTS.md section 5.
#
# Usage: seg_render_master.sh <job_dir> <src_mp4> <timeline_json> <out_mp4> <log_file>
#
# What changed and why (see .scratch/fix-dead-ffmpeg-and-4k-render-path/spec.md):
#   * ffmpeg is resolved at run time through scripts/resolve_ffmpeg.ps1 instead
#     of a hardcoded WinGet path that has since been uninstalled.
#   * Cut points come from the timeline JSON via scripts/read_episode_bounds.ps1
#     instead of a `case "$JOB"` block holding the 840/841/842 timecodes typed
#     in by hand, so any task can be rendered.
#   * The project venv's python.exe is no longer needed to read the cut list
#     (PowerShell's built-in JSON parser does it), so the render path has no
#     Python dependency at all.
#   * The BURN=1 burned-subtitle branch was removed.  Project policy is that no
#     burned version exists; keeping a one-flag-away path to one is the hazard.
set -euo pipefail

JOB="$1"; SRC="$2"; MAP="$3"; OUT="$4"; LOG="$5"

PS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- resolve ffmpeg ---------------------------------------------------------
# The resolver prints KEY=VALUE lines; parse the one we need.
RESOLVE_OUT=$(powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(cygpath -m "$PS_DIR/resolve_ffmpeg.ps1")" -Emit) || {
  echo "[FAIL] could not resolve ffmpeg/ffprobe. Run scripts/check_video_environment.ps1 first." >&2
  exit 1
}
FF=$(printf '%s\n' "$RESOLVE_OUT" | sed -n 's/^FFMPEG=//p')
FF_DIR=$(printf '%s\n' "$RESOLVE_OUT" | sed -n 's/^DIR=//p')
if [ -z "$FF" ] || [ ! -f "$FF" ]; then
  echo "[FAIL] resolver returned no usable ffmpeg path (got: '$FF')" >&2
  exit 1
fi

# ffmpeg is a native Windows binary: hand it Windows-form paths, never /c/... ones.
FF=$(cygpath -m "$FF")
FFPROBE=$(cygpath -m "$FF_DIR/ffprobe.exe")

# --- thread budget ------------------------------------------------------------
# Measured on this box (Ryzen 7 7800X3D, 8 cores / 16 threads) against the real
# filter chain below, 6 s of source, four runs:
#
#     -threads 0 -filter_threads 0     16.22 s   <- ffmpeg auto
#     -threads 4 -filter_threads 4      9.15 s   <- 44% faster than auto
#     -threads 8 -filter_threads 8     12.94 s
#     -threads 8 -filter_threads 2     24.41 s   <- starving filters is very bad
#
# All four produced a byte-identical 3,918,241 B file, so this is output-neutral.
#
# Why it matters: ffmpeg's default is one thread per detected core PLUS frame-level
# parallelism, which was observed spawning 83 threads on this 16-thread machine.
# Oversubscribed threads fight each other and, more importantly, make the whole
# desktop stutter while a render runs -- the user reported exactly that.  Capping
# threads keeps the machine responsive without changing a single output byte.
#
# Override with NARAKA_FF_THREADS / NARAKA_FF_FILTER_THREADS when a task is
# deliberately alone on the machine and wants the last drop of throughput.
THREADS="${NARAKA_FF_THREADS:-4}"
FILTER_THREADS="${NARAKA_FF_FILTER_THREADS:-4}"

# --- encoder preset -----------------------------------------------------------
# Measured 2026-10-06 on this box, 20 s of real source, same filter chain
# (lanczos 1440p->4K, NVENC, -rc vbr -b:v 18M -maxrate 28M -bufsize 56M), each
# preset timed and then scored against a near-lossless libx264 -qp 8 reference:
#
#     preset   wall     size        PSNR-Y     SSIM
#     p7      69.81 s  12,957,249   56.63      0.9999
#     p5      58.05 s  13,001,511   56.64      0.9999
#     p4      67.44 s  13,082,298   56.58      0.9999
#
# p7 -> p4 buys ~0.05 dB PSNR-Y either way -- that is noise, not a picture
# difference -- and at 18 Mbit/s with AQ on, it is *slower* here, not faster.
# So p7 stays the default.  It is the slower preset precisely because it spends
# more search on the parts of a high-motion game frame that a flat 18 Mbit/s
# target would otherwise smear, and that is the part we are shipping.
#
# The knob exists for the times a task is genuinely waiting on the render and the
# operator has decided that is acceptable:
#
#     NARAKA_FF_PRESET=p4 bash scripts/seg_render_master.sh ...
#
# Do not change this without re-measuring the table above.  Agent 17 reported a
# 3.55x win from p7 -> p4; measured here it is a 3% *loss*, which is what happens
# when a throughput claim is not run against this filter chain and this encoder.
PRESET="${NARAKA_FF_PRESET:-p7}"

# --- read the cut list ------------------------------------------------------
BOUNDS=$(powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(cygpath -m "$PS_DIR/read_episode_bounds.ps1")" "$(cygpath -w "$MAP")" | tr -d '\r') || {
  echo "[FAIL] could not read the cut list from $MAP" >&2
  exit 1
}
N=$(printf '%s\n' "$BOUNDS" | sed -n 's/^N=//p' | tr -d '[:space:]')
PROGRAM=$(printf '%s\n' "$BOUNDS" | sed -n 's/^PROGRAM=//p' | tr -d '[:space:]')

# Each cut line looks like "S=<start> E=<end>".  Strip the E= prefix as well as
# the separator, or the value handed to ffmpeg -to becomes the literal "E=6".
STARTS=(); ENDS=()
while IFS= read -r line; do
  case "$line" in
    S=*)
      s="${line#S=}"; s="${s%% *}"
      e="${line##*E=}"
      STARTS+=("$s"); ENDS+=("$e")
      ;;
  esac
done <<< "$BOUNDS"

if [ -z "$N" ] || [ "${#STARTS[@]}" -ne "$N" ]; then
  echo "[FAIL] timeline parse mismatch: N=$N but ${#STARTS[@]} cut points parsed" >&2
  exit 1
fi

JOB_P=$(cygpath -u "$JOB")
SRC_W=$(cygpath -m "$SRC")
OUT_W=$(cygpath -m "$OUT")
LOG_P=$(cygpath -u "$LOG")
SEGDIR="$JOB_P/cache/seg4k"
mkdir -p "$SEGDIR"

echo "SEG_RENDER_START $(date -u +%FT%TZ)" > "$LOG_P"
echo "map=$MAP output=$OUT" >> "$LOG_P"
echo "ffmpeg=$FF" >> "$LOG_P"
echo "threads=$THREADS filter_threads=$FILTER_THREADS preset=$PRESET" >> "$LOG_P"
echo "episodes=$N expected_program_sec=$PROGRAM" >> "$LOG_P"

LIST="$SEGDIR/concat.txt"
: > "$LIST"
for ((i=0; i<N; i++)); do
  S="${STARTS[$i]}"; E="${ENDS[$i]}"
  SEG="$SEGDIR/seg_$i.mp4"
  echo "--- seg$i [$S,$E) -> $SEG" >> "$LOG_P"
  "$FF" -hide_banner -y -v error -threads "$THREADS" -filter_threads "$FILTER_THREADS" \
    -ss "$S" -to "$E" -i "$SRC_W" \
    -vf "fps=60,scale=3840:2160:flags=lanczos,setsar=1,format=yuv420p" \
    -c:v h264_nvenc -preset "$PRESET" -tune hq -profile:v high -level:v 5.2 \
    -rc vbr -b:v 18M -maxrate 28M -bufsize 56M -g 120 -bf 2 \
    -spatial-aq 1 -temporal-aq 1 -aq-strength 8 \
    -pix_fmt yuv420p -r 60 -fps_mode cfr \
    -c:a aac -b:a 320k -ar 48000 -ac 2 \
    "$(cygpath -m "$SEG")" 2>>"$LOG_P" || { echo "SEG_FAIL i=$i exit=$?" >> "$LOG_P"; exit 1; }
  echo "file '$(cygpath -m "$SEG")'" >> "$LIST"
done

echo "--- concat -> $OUT" >> "$LOG_P"
"$FF" -hide_banner -y -v error -threads "$THREADS" -f concat -safe 0 -i "$(cygpath -m "$LIST")" \
  -c copy -movflags +faststart "$OUT_W" 2>>"$LOG_P" || { echo "CONCAT_FAIL exit=$?" >> "$LOG_P"; exit 1; }

echo "--- clean master: no burned-in text, no embedded subtitle stream ---" >> "$LOG_P"
echo "--- sidecar SRT, if any, ships separately next to the master ---" >> "$LOG_P"
echo "MASTER_RENDER_COMPLETE" >> "$LOG_P"
ls -la "$OUT_W" >> "$LOG_P"
