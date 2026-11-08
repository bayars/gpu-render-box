#!/usr/bin/env bash
# Render 2D sprites with Blender (Cycles CUDA). The examples are Dodger's. Usage: sprites.sh [name|all] [frame_size]
# Each art-src/sprites/<name>.py builds its own scene and renders frames; animated sprites are
# tiled into one horizontal sheet (8 frames). Output: build/sprites/<name>_sheet.png, build/sprites/background.png
# frame_size defaults to 64 px; try 256 for design previews.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/config.sh"
WHAT="${1:-all}"
SIZE="${2:-64}"
OUT="$ROOT/build/sprites"
mkdir -p "$OUT"

NAMES=(player hazard coin background)
[[ "$WHAT" == "all" ]] || NAMES=("$WHAT")

for n in "${NAMES[@]}"; do
  [[ -f "$ROOT/art-src/sprites/$n.py" ]] || { echo "no such sprite script: art-src/sprites/$n.py" >&2; exit 2; }
  rm -rf "$OUT/$n"; mkdir -p "$OUT/$n"
  "$BLENDER" -b --factory-startup -t "${BLENDER_THREADS:-8}" \
    --python "$ROOT/art-src/sprites/$n.py" -- "$OUT/$n" --size "$SIZE"
  if [[ "$n" == "background" ]]; then
    cp "$OUT/$n/background.png" "$OUT/background.png"
  else
    ffmpeg -nostdin -hide_banner -loglevel error -y -start_number 0 -framerate 1 -i "$OUT/$n/frame_%02d.png" \
      -vf "tile=8x1" -frames:v 1 "$OUT/${n}_sheet.png"
  fi
  echo "SPRITE_DONE $n"
done
