#!/usr/bin/env bash
# Build 3D models with Blender and export glTF. Usage: models.sh [--cpu] [name...|all]
# Each art-src/models/<name>.py builds its own scene (see art-src/models/common.py) and calls finish(),
# which exports build/models/<name>.glb and renders a Cycles preview build/models/<name>_preview.png.
# --cpu renders the previews with Cycles on the CPU (when something else holds the GPU's memory).
# Move the .glb files into your Godot project (e.g. <project>/assets/models/) on the laptop and commit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/config.sh"
CPU=""
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --cpu) CPU=1 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done
NAMES=()
if [[ $# -eq 0 || "$1" == "all" ]]; then
  for f in "$ROOT"/art-src/models/*.py; do
    n="$(basename "$f" .py)"
    [[ "$n" == "common" ]] || NAMES+=("$n")
  done
else
  NAMES=("$@")
fi
mkdir -p "$ROOT/build/models"

for n in "${NAMES[@]}"; do
  script="$ROOT/art-src/models/$n.py"
  [[ -f "$script" ]] || { echo "no such model script: art-src/models/$n.py" >&2; exit 2; }
  CYCLES_CPU="$CPU" "$BLENDER" -b --factory-startup --python "$script" -- "$ROOT/build/models/$n.glb"
  [[ -s "$ROOT/build/models/$n.glb" ]] || { echo "export produced no file for $n" >&2; exit 1; }
  echo "MODEL_DONE $n"
done
