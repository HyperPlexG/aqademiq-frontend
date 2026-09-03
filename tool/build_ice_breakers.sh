#!/usr/bin/env bash
#
# Turn the raw Ice Breakers screen recordings into shippable app assets.
#
#   ./tool/build_ice_breakers.sh "/path/to/Aqademiq Ice Breakers/Tutorials"
#
# The recordings come off a phone at 1206x2622 HEVC with an audio track, about
# 15 MB for twenty seconds. Six of those is 94 MB, which is more than four times
# the app's entire existing asset budget. Transcoded here they are ~700 KB each:
# a screen recording of a mostly-static UI compresses enormously once it is not
# at native resolution, and the series is silent by design so the audio track is
# pure waste.
#
# That size is the whole reason these ship inside the bundle rather than from
# storage — no network on first watch, no cache layer, no egress, and it works
# in a lecture with no signal, which is exactly where a student watches these.
#
# Deliberate choices:
#   * H.264, not HEVC — universal hardware decode, and at this size the better
#     compression buys nothing worth the compatibility risk.
#   * 900 wide — the player is ~450pt, so this is 2x on the phones that matter.
#   * -an — silent by spec. Students watch in libraries; the instruction is
#     burned into the frame, so an audio track would only add bytes.
#   * +faststart — the moov atom leads, so playback can begin before the whole
#     file is read.
set -euo pipefail

SRC="${1:-}"
if [[ -z "$SRC" || ! -d "$SRC" ]]; then
  echo "usage: $0 <dir containing the six ScreenRecording_*.MP4/.mov files>" >&2
  exit 1
fi
command -v ffmpeg >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)" >&2; exit 1; }

OUT="$(cd "$(dirname "$0")/.." && pwd)/assets/ice_breakers"
mkdir -p "$OUT"

WIDTH=900
CRF=26

# Recording -> slot. Ordered by capture time, which is the order they were shot
# and the order they teach in. Keep this table if the sources are ever reshot:
# the filenames carry no hint of which lesson they are.
SOURCES=(
  "ScreenRecording_09-02-2026 21-22-20_1.MP4|01|add-one-small-thing"
  "ScreenRecording_09-02-2026 21-28-13_1.MP4|02|too-big-break-it-down"
  "ScreenRecording_09-02-2026 21-42-04_1.mov|03|five-minutes-not-twenty-five"
  "ScreenRecording_09-02-2026 21-46-18_1.MP4|04|freeze-dont-quit"
  "ScreenRecording_09-02-2026 21-52-07_1.MP4|05|push-it-to-tomorrow"
  "ScreenRecording_09-02-2026 21-57-48_1.MP4|06|start-a-session-from-a-task"
)

total=0
for entry in "${SOURCES[@]}"; do
  IFS='|' read -r file slot slug <<< "$entry"
  in="$SRC/$file"
  [[ -f "$in" ]] || { echo "missing source: $in" >&2; exit 1; }

  out="$OUT/${slot}-${slug}.mp4"
  ffmpeg -v error -y -i "$in" \
    -an \
    -vf "scale=${WIDTH}:-2" \
    -c:v libx264 -crf "$CRF" -preset slow -pix_fmt yuv420p \
    -movflags +faststart \
    "$out"

  bytes=$(stat -f%z "$out" 2>/dev/null || stat -c%s "$out")
  total=$((total + bytes))

  # Printed because the runtime badges in lib/features/ice_breakers/
  # ice_breaker.dart are written constants — the label has to be on screen
  # before anyone taps, so it cannot be read from the file at runtime. Recut a
  # video and the number here is what its `seconds:` should be, floored.
  secs=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")
  printf '  %s  %6s KB  %5.1fs\n' "$(basename "$out")" "$((bytes / 1024))" "$secs"
done

printf '\n%d videos, %d KB total in %s\n' "${#SOURCES[@]}" "$((total / 1024))" "$OUT"
printf 'Check the seconds above against `seconds:` in ice_breaker.dart.\n'
