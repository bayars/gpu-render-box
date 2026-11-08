# Jobs

Every job runs as `scripts/delegate.sh [--detach] <job> [args…]` from the laptop. Paths in arguments are **relative to the repo root**. Results land in `renders/` or `build/` on the laptop.

## render

```bash
scripts/delegate.sh render <file.blend> <start> <end> [--samples N] [--res-percent N]
```

Renders a frame range of an existing `.blend` with Cycles, on CUDA only (exit 3 if Cycles sees no CUDA device). Output: `renders/<blend name>/frame_0001.png`, … (RGBA PNG). The scene's own camera, resolution and samples are used unless overridden. `BLENDER_THREADS` (default 8) limits the CPU threads Blender uses.

If the `.blend` is stored in LFS and the GPU box has only the pointer file, the job stops with a clear message (exit 2).

## export_gltf

```bash
scripts/delegate.sh export_gltf <file.blend> [out.glb]
```

Exports the whole scene to binary glTF for Godot: Y-up, modifiers applied, no cameras or lights. The default output is `build/gltf/<name>.glb`.

## models

```bash
scripts/delegate.sh models [--cpu] [name… | all]
```

Runs `art-src/models/<name>.py` for each name; `all` (or no name) runs every script except `common.py`. Each script builds a scene and calls `finish()`, which writes:
- `build/models/<name>.glb`, the model for the game;
- `build/models/<name>_preview.png`, a Cycles render of it. **Look at this before using the model.**

`--cpu` renders the previews on the CPU, for when the GPU's memory is taken. See [art-as-code.md](art-as-code.md).

## textures

```bash
scripts/delegate.sh textures [name…]
```

Bakes seamless 1024 px PBR sets from the recipes in `art-src/textures/pbr.py` (all recipes when no name is given):
- `build/textures/<name>_albedo.png`, `_normal.png` (tangent space, +Y up, Godot's default) and `_rough.png`;
- contact sheets `sheet_albedo.png` and `sheet_normal.png` for a quick look.

## sprites

```bash
scripts/delegate.sh sprites [name | all] [frame_size]
```

Renders the 2D sprite scripts in `art-src/sprites/<name>.py`: 8 frames each, tiled into `build/sprites/<name>_sheet.png`. A script called `background` produces a single `build/sprites/background.png` instead. `frame_size` defaults to 64 px; use 256 for design previews. The list of names for `all` is at the top of `scripts/sprites.sh`.

## build_linux, build_windows

```bash
scripts/delegate.sh build_linux <project_dir>
scripts/delegate.sh build_windows <project_dir>
```

Headless Godot export of the project in `<project_dir>/` (a top-level folder name; the default is `dodger`). The project needs an `export_presets.cfg` with presets named exactly **`Linux`** and **`Windows Desktop`**: create them once in the Godot editor, then commit the file. The job imports the project first, so new assets are processed. Output: `build/<config/name, lowercased>-linux.zip` / `-windows.zip`.

## release (laptop helper)

```bash
scripts/release.sh <project_dir> <version>
```

Runs both builds, then copies them to `releases/<name>-<version>-linux.zip` and `-windows.zip` (Git LFS). Commit `releases/` afterwards. The Windows build can't be run on Linux, so check it on Windows before sharing it.

## encode

```bash
scripts/delegate.sh encode <input> <out.mp4>
```

H.264 with NVENC (the GPU's video encoder), falling back to libx264 on the CPU if NVENC fails. For an image sequence, pass a pattern such as `renders/shot/frame_%04d.png`; `FPS` sets the frame rate (default 30).

## gen_test_blend

```bash
scripts/delegate.sh gen_test_blend
scripts/delegate.sh render renders/_gen/test.blend 1 1
```

Builds a tiny scene (cube, floor, light, camera) with the GPU box's Blender, then renders it. It's the quickest end-to-end check of the whole mechanism.

---

## Adding a new job

Say you want `bake_lightmaps`:

1. **Write the job script** `scripts/bake_lightmaps.sh`. It runs on the GPU box:
   ```bash
   #!/usr/bin/env bash
   # Bake lightmaps for a .blend. Usage: bake_lightmaps.sh <file.blend>
   set -euo pipefail
   ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
   source "$ROOT/scripts/config.sh"            # BLENDER, GODOT, ...
   [[ $# -eq 1 && -f "$ROOT/$1" ]] || { echo "usage: bake_lightmaps.sh <file.blend>" >&2; exit 2; }
   mkdir -p "$ROOT/build/lightmaps"
   "$BLENDER" -b "$ROOT/$1" --python "$ROOT/scripts/bake_lightmaps.py" -- "$ROOT/build/lightmaps"
   echo "BAKE_DONE"
   ```
   Rules for job scripts:
   - write **only** under `build/` or `renders/`;
   - exit 2 on bad arguments;
   - call binaries through `$BLENDER` / `$GODOT`;
   - give ffmpeg `-nostdin`;
   - finish with a `…_DONE` line, so the log is easy to scan.
2. **Register it** in `scripts/remote_run.sh`:
   ```bash
   bake_lightmaps) CMD=("$ROOT/scripts/bake_lightmaps.sh" "$@") ;;
   ```
   Also add it to the job list comments at the top of `remote_run.sh` and `delegate.sh`.
3. `chmod +x scripts/bake_lightmaps.sh`, commit, and run it: `scripts/delegate.sh bake_lightmaps art-src/room.blend`. You don't need to update the GPU box first; see "Sync the GPU box" in [how-it-works.md](how-it-works.md).
4. **Document it** in this file and in the README's job table.

If the job uses CUDA in Blender, copy `enable_cuda_only()` from `scripts/blender_render.py`. It also turns off the OptiX entry, which older cards list but can't use.
